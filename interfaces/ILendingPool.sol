// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

interface ILendingPool {
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint256);
    
    struct ReserveData {
    //stores the reserve configuration
    ReserveConfigurationMap configuration;
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    //tokens addresses
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint8 id;
  }
  struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: Reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60-63: reserved
    //bit 64-79: reserve factor
    uint256 data;
  }
    
    function deposit(
        address reserve,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
    
    function withdraw(
        address reserve,
        uint256 amount,
        address to
    ) external;
    
    function borrow(
        address reserve,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
    
    function repay(
        address reserve,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external;
    
    function swapBorrowRateMode(address reserve, uint256 rateMode) external;
    
    function setUserUseReserveAsCollateral(address reserve, bool useAsCollateral) external;
    
    function liquidationCall(
        address collateral,
        address reserve,
        address user,
        uint256 purchaseAmount,
        bool receiveAToken
    ) external;
    
    function flashLoan(
        address receiver,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function getReserveData(address asset) external view returns (ReserveData memory);
    
    }
