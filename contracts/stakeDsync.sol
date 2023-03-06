// stake: Lock tokens into our smart contract (Synthetix version?)
// withdraw: unlock tokens from our smart contract
// claimReward: users get their reward tokens
//      What's a good reward mechanism?
//      What's some good reward math?

// Added functionality ideas: Use users funds to fund liquidity pools to make income from that?

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error Staking__TransferFailed();
error Withdraw__TransferFailed();
error Staking__NeedsMoreThanZero();

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

    // ============================STATE========================================

    uint256 public s_totalSupply;
    // uint256 public constant REWARD_RATE = 100;
    // uint256 public s_rewardPerTokenStored;
    // uint256 public s_lastUpdateTime;

    /** @dev Mapping from address to the amount the user has staked */
    // mapping(address => uint256) public s_balances;

    /** @dev Mapping from address to the amount the user has been rewarded */
    // mapping(address => uint256) public s_userRewardPerTokenPaid;

    /** @dev Mapping from address to the rewards claimable for user */
    // mapping(address => uint256) public s_rewards;

    // modifier updateReward(address account) {
    //     // how much reward per token?
    //     // get last timestamp
    //     // between 12 - 1pm , user earned X tokens. Needs to verify time staked to distribute correct amount to each
    //     // participant
    //     s_rewardPerTokenStored = rewardPerToken();
    //     s_lastUpdateTime = block.timestamp;
    //     s_rewards[account] = earned(account);
    //     s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;

    //     _;
    // }

    // modifier moreThanZero(uint256 amount) {
    //     if (amount == 0) {
    //         revert Staking__NeedsMoreThanZero();
    //     }
    //     _;
    // }

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
    }

    function getUserReward(bytes32 index) public view returns (uint256) {
        // require(mStakes[index].initialized, "StakeDsync: Stake not initialized");
        // require(mStakes[index].beneficiary == msg.sender, "StakeDsync: Not beneficiary");
        // require(block.timestamp >= mStakes[index].rewardStartDate, "StakeDsync: Reward not available yet");
        // require(cDsync.balanceOf(address(this)) >= s_totalSupply, "StakeDsync: Reward Tokens surplus error");
        uint256 reward = mStakes[index].rewardRate * ((block.timestamp - mStakes[index].depositDate) / 1 days);
        return reward;
    }

    // function earned(address account) public view returns (uint256) {
    //     uint256 currentBalance = s_balances[account];
    //     // how much they were paid already
    //     uint256 amountPaid = s_userRewardPerTokenPaid[account];
    //     uint256 currentRewardPerToken = rewardPerToken();
    //     uint256 pastRewards = s_rewards[account];
    //     uint256 _earned = ((currentBalance * (currentRewardPerToken - amountPaid)) / 1e18) +
    //         pastRewards;

    //     return _earned;
    // }

    // /** @dev Basis of how long it's been during the most recent snapshot/block */
    // function rewardPerToken() public view returns (uint256) {
    //     if (s_totalSupply == 0) {
    //         return s_rewardPerTokenStored;
    //     } else {
    //         return
    //             s_rewardPerTokenStored +
    //             (((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18) / s_totalSupply);
    //     }
    // }

    // function stake(uint256 amount) external updateReward(msg.sender) moreThanZero(amount) {
    //     // keep track of how much this user has staked
    //     // keep track of how much token we have total
    //     // transfer the tokens to this contract
    //     /** @notice Be mindful of reentrancy attack here */
    //     s_balances[msg.sender] += amount;
    //     s_totalSupply += amount;
    //     //emit event
    //     bool success = s_stakingToken.transferFrom(msg.sender, address(this), amount);
    //     // require(success, "Failed"); Save gas fees here
    //     if (!success) {
    //         revert Staking__TransferFailed();
    //     }
    // }

    // function withdraw(uint256 amount) external updateReward(msg.sender) moreThanZero(amount) {
    //     s_balances[msg.sender] -= amount;
    //     s_totalSupply -= amount;
    //     // emit event
    //     bool success = s_stakingToken.transfer(msg.sender, amount);
    //     if (!success) {
    //         revert Withdraw__TransferFailed();
    //     }
    // }

    // function claimReward() external updateReward(msg.sender) {
    //     uint256 reward = s_rewards[msg.sender];
    //     bool success = s_rewardToken.transfer(msg.sender, reward);
    //     if (!success) {
    //         revert Staking__TransferFailed();
    //     }
    //     // contract emits X reward tokens per second
    //     // disperse tokens to all token stakers
    //     // reward emission != 1:1
    //     // MATH
    //     // @ 100 tokens / second
    //     // @ Time = 0
    //     // Person A: 80 staked
    //     // Preson B: 20 staked
    //     // @ Time = 1
    //     // Person A: 80 staked, Earned: 80, Withdraw 0
    //     // Perosn B: 20 staked, Earned: 20, Withdraw: 0
    //     // @ Time = 2
    //     // Person A: 80 staked, Earned: 160, Withdraw 0
    //     // Person B: 20 staked, Earned: 40, Withdraw: 0
    //     // @ Time = 3
    //     // New person enters!
    //     // staked 100
    //     // Person A: 80 staked, Earned 240 + (80/200 * 100) => (40), Withdraw 0
    //     // Perosn B: 20 staked, Earned: 60 + (20/200 * 100) => (10), Withdraw 0
    //     // Person C: 100 staked, Earned: 50, Withdraw 0
    //     // @ Time = 4
    //     // Person A Withdraws & claimed rewards on everything!
    //     // Person A: 0 staked, Withdraw: 280
    // }

    // // Getter for UI
    // function getStaked(address account) public view returns (uint256) {
    //     return s_balances[account];
    // }
}
