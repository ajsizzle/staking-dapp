
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// error Staking__TransferFailed();
// error Withdraw__TransferFailed();
// error Staking__NeedsMoreThanZero();

contract StakeDsync is ReentrancyGuard {
    // IERC20 public s_stakingToken;
    // IERC20 public s_rewardToken;
    IERC20 public cDsync;

    // ============================STAKE========================================
    struct aStake {
        bool initialized;
        // beneficiary of tokens after they are released
        address  beneficiary;
        // date of deposit
        uint256  depositDate;
        // amount of tokens staked
        uint256  value;
        // reward rate: number of tokens earned every day the token value is staked in the contract
        uint256  rewardRate;
        // the date when the user can start claiming rewards
        uint256  rewardStartDate;
        // the date when users can withdraw their tokens
        uint256  withdrawDate;
        // Total value of tokens claimed by user
        uint256  Claimed;
        //nonce: used to count the number of times a user has staked
        uint8  nonce;
    }

    mapping(address => uint8) public mNonces;

    mapping(bytes32 => aStake) public mStakes;
    // ============================OWNER========================================

    struct aOwner {
        address owner;
        uint8  nonce;
        uint balance;
        uint totalClaimed;
        uint totalWithdrawn;
    }

    mapping(address => aOwner) public mOwners;

    // ============================STATE========================================

    uint256 public s_totalSupply;
    uint256 public s_totalClaimed;
    uint public s_totalWithdrawn;
    /** @dev Mapping from address to the amount the user has staked */
    mapping(address => uint256) public s_balances;

    constructor(address _token) {
        cDsync = IERC20(_token);
    }

    function getIndexBytes(address _address, uint8 _nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_address, _nonce));
    }

    function getTokenRewardDay() public pure returns (uint256) {
        //60% APR = 0.016% per day
        //this function returns the reward for 1 token per day
        return 1e18 / 10000 * 16;
    }

    function stake(uint value) external nonReentrant returns (bytes32) {
        require(value > 0, "StakeDsync: Cannot stake 0");
        require(cDsync.transferFrom(msg.sender, address(this), value), "StakeDsync: Transfer failed");

        mNonces[msg.sender] += 1;
        mOwners[msg.sender].owner = msg.sender;
        mOwners[msg.sender].nonce += 1;
        uint8 nonce = mNonces[msg.sender];
        bytes32 index = getIndexBytes(msg.sender, nonce);

        mStakes[index] = aStake({
            initialized: true,
            beneficiary: msg.sender,
            //deposited now
            depositDate: block.timestamp,
            //amount deposited
            value: value,
            //reward rate: number of tokens earned every day the token value is staked in the contract
            rewardRate: getTokenRewardDay() * value, 
            //the date when the user can start claiming rewards is 4 months
            rewardStartDate: block.timestamp + (4 * 30 days),
            //the date when users can withdraw their tokens is 6 months
            withdrawDate: block.timestamp + (6 * 30 days),
            Claimed: 0,
            nonce: nonce
        });

        mOwners[msg.sender].balance += value;
        s_totalSupply += value;

        return index;
    }

    function claimReward(bytes32 index) external nonReentrant {
        require(mStakes[index].initialized, "StakeDsync: Stake not initialized");
        require(mStakes[index].beneficiary == msg.sender, "StakeDsync: Not beneficiary");
        require(block.timestamp >= mStakes[index].rewardStartDate, "StakeDsync: Reward not available yet");
        require(cDsync.balanceOf(address(this)) >= s_totalSupply, "StakeDsync: Reward Tokens surplus error");

        uint256 reward = getUserReward(index);
        require(cDsync.transfer(msg.sender, reward), "StakeDsync: Transfer failed");
        mStakes[index].Claimed += reward;
        mOwners[msg.sender].totalClaimed += reward;
        s_totalClaimed += reward;
    }

    function getUserReward(bytes32 index) public view returns (uint256) {
        // require(mStakes[index].initialized, "StakeDsync: Stake not initialized");
        // require(mStakes[index].beneficiary == msg.sender, "StakeDsync: Not beneficiary");
        // require(block.timestamp >= mStakes[index].rewardStartDate, "StakeDsync: Reward not available yet");
        // require(cDsync.balanceOf(address(this)) >= s_totalSupply, "StakeDsync: Reward Tokens surplus error");
        uint256 reward = mStakes[index].rewardRate * ((block.timestamp - mStakes[index].depositDate) / 1 days);
        return reward;
    }

    function withdraw(bytes32 index) external nonReentrant {
        require(mStakes[index].initialized, "StakeDsync: Stake not initialized");
        require(mStakes[index].beneficiary == msg.sender, "StakeDsync: Not beneficiary");
        require(block.timestamp >= mStakes[index].withdrawDate, "StakeDsync: Withdraw not available yet");
        require(cDsync.transfer(msg.sender, mStakes[index].value), "StakeDsync: Transfer failed");
        mStakes[index].initialized = false;
        mOwners[msg.sender].balance -= mStakes[index].value;
        s_totalSupply -= mStakes[index].value;
        mOwners[msg.sender].totalWithdrawn += mStakes[index].value;
        s_totalWithdrawn += mStakes[index].value;
    }
}
