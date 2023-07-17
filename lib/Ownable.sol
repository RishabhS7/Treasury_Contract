// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {
    address payable public owner;
    address payable public newOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(payable(msg.sender));
    }

    function _transferOwnership(address payable _whom) internal {
        emit OwnershipTransferred(owner, _whom);
        owner = _whom;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner == msg.sender, "ERR_AUTHORIZED_ADDRESS_ONLY");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address payable _newOwner) external onlyOwner {
        newOwner = _newOwner;
    }

    function acceptOwnership() external returns (bool) {
        require(msg.sender == newOwner, "ERR_ONLY_NEW_OWNER");
        owner = newOwner;
        emit OwnershipTransferred(owner, newOwner);
        newOwner = payable(address(0));
        return true;
    }
}
