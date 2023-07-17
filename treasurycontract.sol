// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { IERC20 } from "./interfaces/IERC20.sol";
import { Ownable } from "./lib/Ownable.sol";
import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "./interfaces/UniswapV2Factory.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";

contract Treasury is Ownable {

    //uniswaprouterv2 gorli - 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    //uniswapV2 factory - 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
    //ilending protocol aave - 0x4bd5643ac6f66a5237E18bfA7d47cF22f1c9F210
    //usdc token used - 0x9FD21bE27A2B059a288229361E2fA632D8D2d074
    //usdt token used - 0x65E2fe35C30eC218b46266F89847c63c2eDa7Dc7

    uint256 immutable SECONDS_PER_YEAR = 31536000;

    IUniswapV2Router02 public iuniswapv2router02;
    ILendingPool public ilendingpool;
    IUniswapV2Factory public uniswapV2factory;

    address public usdcTokenAddress;
    address public usdtTokenAddress;

    
    uint256 public uniswapRatio = 50; //initially set to 50
    uint256 public aaveRatio = 50; //initially set to 50

    event FundsAdded(uint256 amount);
    event FundsWithdrawFromPool(uint256 amount, uint256 key);
    event FundsWithdrawnToWallet(uint256 usdcbal, uint256 usdtbal);

    constructor(
        address _uniswapRouterContractAddress,
        address _uniswapV2FactoryContractAddress,
        address _ilendingpoolContractAddress,
        address _usdcTokenaddress,
        address _usdtTokenTokenAddress
    ) {
        iuniswapv2router02 = IUniswapV2Router02(_uniswapRouterContractAddress);
        uniswapV2factory = IUniswapV2Factory(_uniswapV2FactoryContractAddress);
        ilendingpool = ILendingPool(_ilendingpoolContractAddress);
        usdcTokenAddress = _usdcTokenaddress;
        usdtTokenAddress = _usdtTokenTokenAddress;
    }

    function getCurrentLiquidityRate(address asset) public view returns (uint128) {
        ILendingPool.ReserveData memory reserveData = ilendingpool.getReserveData(asset);
        return reserveData.currentLiquidityRate;
    }

    function onlyDeposit(uint256 amount) public returns (bool) {
        require(amount>0,"amount can't be 0");

        IERC20 usdcToken = IERC20(usdcTokenAddress);
        require(
            usdcToken.transferFrom(msg.sender, address(this), amount),
            "Failed to transfer USDC"
        );
        return true;
    }

    function setRatio(uint256 _uniRatio, uint256 _aaveRatio)public onlyOwner() returns(bool){
        require(_uniRatio+_aaveRatio == 100 , "total should be 100");

        uniswapRatio = _uniRatio;
        aaveRatio = _aaveRatio;

        return true ;
    }


    function addFundsToAave(uint256 _amount) public returns (bool) {
        require(_amount>0,"amount can't be 0");
        require(IERC20(usdcTokenAddress).balanceOf(address(this))>=_amount,"not enough funds");

        IERC20(usdcTokenAddress).approve(address(ilendingpool), _amount);
        ilendingpool.deposit(usdcTokenAddress, _amount, address(this), 0);

        return true;
    }

    function addLiquidityToUniswap(uint256 _amount) public returns (bool){
        require(_amount>0,"amount can't be 0");
        require(IERC20(usdcTokenAddress).balanceOf(address(this))>=_amount,"not enough funds");

        uint256 token1bal = _amount/2;
        IERC20(usdcTokenAddress).approve(address(iuniswapv2router02), _amount);
        
        address[] memory path = new address[](2);
        path[0] = usdcTokenAddress;
        path[1] = usdtTokenAddress;

        iuniswapv2router02.swapExactTokensForTokens(
            token1bal,
            0,
            path,
            address(this),
            block.timestamp + 600
        );

        uint256 token2bal = IERC20(usdtTokenAddress).balanceOf(address(this));
        IERC20(usdtTokenAddress).approve(address(iuniswapv2router02), token2bal);

        iuniswapv2router02.addLiquidity(usdcTokenAddress, usdtTokenAddress, token1bal, token2bal, 1, 1, address(this), block.timestamp);

        return true;
    }


    function depositAndDistributeFunds(uint256 _amount) public returns(bool)  {
        require(onlyDeposit(_amount),"fund deposit failed");

        uint256 uniswapAmount = (_amount * uniswapRatio) / 100;
        uint256 aaveAmount = (_amount * aaveRatio) / 100;
        
        addFundsToAave(aaveAmount);
        addLiquidityToUniswap(uniswapAmount);
         
        emit FundsAdded(_amount);

        return true;
    }

    function withdrawFromPool(uint256 _amount, uint256 key ) external onlyOwner() returns(bool) {
        require(_amount>0,"amount can't be 0");

        if(key == 1){
            address lpTokenAddress = uniswapV2factory.getPair(usdcTokenAddress, usdtTokenAddress);
            IERC20(lpTokenAddress).approve(address(iuniswapv2router02), _amount);
            iuniswapv2router02.removeLiquidity(usdcTokenAddress, usdtTokenAddress, _amount , 1, 1, address(this), block.timestamp);
        }else {
            ilendingpool.withdraw(usdcTokenAddress , _amount, address(this));
        }

        emit FundsWithdrawFromPool(_amount, key);

        return true;
    }

    function calculateUniswapYeild() public view returns (uint256) {
        address lpTokenAddress = uniswapV2factory.getPair(usdcTokenAddress, usdtTokenAddress);
        uint256 totalSupply =  IERC20(lpTokenAddress).totalSupply();
        uint256 liquidity =  IERC20(lpTokenAddress).balanceOf(address(this));
        address[] memory path = new address[](2);
            path[0] = usdcTokenAddress;
            path[1] = usdtTokenAddress;
        uint256 tradingVolume = iuniswapv2router02.getAmountsOut(1, path)[1];
        uint256 feesEarned = tradingVolume * liquidity / totalSupply * 3 / 1000; // Assuming 0.3% fee
        uint256 uniswapYeild = (feesEarned * SECONDS_PER_YEAR) / 2592000;

        return uniswapYeild;
    }

    function calculateAaveYield() public view returns (uint256) {
        uint128 currentLiquidityRate = getCurrentLiquidityRate(usdcTokenAddress);
        uint256 depositDurationYears = uint256(2592000 *10000000)/SECONDS_PER_YEAR; //assuming 2592000 seconds has passed since investment
        uint256 aaveYeild = currentLiquidityRate * depositDurationYears;
        return aaveYeild;
    }
    
    function calculateAggregatedYeild() public view returns (uint256){
        return calculateAaveYield() + calculateUniswapYeild();
    }

    function withdrawAllToWallet() public returns (bool){
        uint256 usdtBalance = IERC20(usdtTokenAddress).balanceOf(address(this));
        uint256 usdcBalance = IERC20(usdcTokenAddress).balanceOf(address(this));
        if(usdtBalance>0){
        IERC20(usdtTokenAddress).transfer(msg.sender, usdtBalance);
        }
        if(usdcBalance>0){
        IERC20(usdcTokenAddress).transfer(msg.sender, usdcBalance);
        }

        emit FundsWithdrawnToWallet(usdcBalance, usdtBalance);

        return true;
    }
}

