// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./Adminable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * 1. one contract for one staking pool
 */
contract TokenStaking is Ownable, Adminable {
    struct StakingPool {
        uint256 size;
        uint256 prizeSize;
        address prizeAddress;
        uint256 stakeBeginTime;
        uint256 stakeEndTime;
        uint256 withdrawTime;
        bool initialized;
    }

    struct Staker {
        uint256 stakeAmount;
        bool withdraw;
    }

    // contract name
    string private _name;
    // staking pool info
    StakingPool private _stakingPool;
    // staker address => staker
    mapping(address => Staker) private _stakingMap;
    uint256 private _totalStaking;

    function name() public view returns (string memory) {
        return _name;
    }

    function totalStake() public view returns (uint256) {
        return _totalStaking;
    }

    function stakeAmount() public view returns (uint256) {
        return stakeAmount(_msgSender());
    }

    function stakeAmount(address staker) public view returns (uint256) {
        return _stakingMap[staker].stakeAmount;
    }

    /**
     * owner can set name for the contract
     */
    function setName(string memory name_) public onlyOwner {
        _name = name_;
    }

    function getStakingPool() public view returns (StakingPool memory) {
        return _stakingPool;
    }

    /**
     * @dev Initializes the contract by setting a `name`
     */
    constructor(string memory name_) {
        setName(name_);
    }

    /**
     * owner can init pool
     */
    function initPool(
        uint256 size_,
        uint256 prizeSize_,
        address prizeAddress_,
        uint256 stakeBeginTime_,
        uint256 stakeEndTime_,
        uint256 withdrawTime_
    ) public onlyOwner {
        console.log("init pool");
        console.log("size:", size_);
        console.log("prizeSize:", prizeSize_);
        console.log("prizeAddress:", prizeAddress_);
        console.log("stakeBeginTime:", stakeBeginTime_);
        console.log("stakeEndTime:", stakeEndTime_);
        console.log("withdrawTime:", withdrawTime_);

        require(size_ > 0, "Pool size must greater than 0");

        require(prizeSize_ > 0, "Prize size must greater than 0");

        require(prizeAddress_ != address(0), "Prize address is zero");

        require(
            stakeEndTime_ > stakeBeginTime_,
            "End time must greater than begin time"
        );

        require(
            withdrawTime_ >= stakeEndTime_,
            "Withdraw time must greater than end time"
        );

        ERC20 prizeContract = ERC20(address(prizeAddress_));
        uint8 decimals = prizeContract.decimals();

        _stakingPool = StakingPool(
            size_ * 10**decimals,
            prizeSize_ * 10**decimals,
            prizeAddress_,
            stakeBeginTime_,
            stakeEndTime_,
            withdrawTime_,
            true
        );
    }

    /**
     * user request stake
     */
    function stake(uint256 stakeAmount_) public {
        console.log("stake request... staker:", _msgSender());
        console.log("stake amount:", stakeAmount_);

        require(
            _stakingPool.initialized,
            "Staking Pool hasn't been initialized"
        );
        require(
            block.timestamp >= _stakingPool.stakeBeginTime,
            "Staking Pool hasn't started"
        );

        require(
            block.timestamp <= _stakingPool.stakeEndTime,
            "Staking Pool is over"
        );

        require(
            _totalStaking + stakeAmount_ <= _stakingPool.size,
            "You can't stake such amount"
        );

        ERC20 prizeContract = ERC20(address(_stakingPool.prizeAddress));

        prizeContract.approve(address(this), stakeAmount_); // approve
        prizeContract.transferFrom(_msgSender(), address(this), stakeAmount_); // transfer token to this contract

        // calc stake rate
        _stakingMap[_msgSender()].stakeAmount += stakeAmount_;
        _totalStaking += stakeAmount_;

        console.log("stake success");
    }

    function withdraw() public {
        console.log("withdraw request... staker:", _msgSender());
        require(
            _stakingPool.initialized,
            "Staking Pool hasn't been initialized"
        );
        require(
            block.timestamp >= _stakingPool.withdrawTime,
            "You can't withdraw at the moment, plase be patient"
        );

        require(
            _stakingMap[_msgSender()].stakeAmount > 0,
            "You didn't stake any token"
        );

        require(
            _stakingMap[_msgSender()].withdraw == false,
            "You've already withdrawed"
        );

        // calc reward
        uint256 reward = ((_stakingMap[_msgSender()].stakeAmount *
            _stakingPool.prizeSize) / _stakingPool.size);
        console.log("staking reward:", reward);

        uint256 withdrawAmount = _stakingMap[_msgSender()].stakeAmount + reward;

        ERC20 prizeContract = ERC20(address(_stakingPool.prizeAddress));
        prizeContract.transfer(_msgSender(), withdrawAmount);
        _stakingMap[_msgSender()].withdraw = true;
        console.log("withdraw success");
    }
}
