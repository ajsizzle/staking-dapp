// stake: Lock tokens into our smart contract
// withdraw: unlock tokens from our smart contract
// claimReward: users get their reward tokens
//      What's a good reward mechanism?
//      What's some good reward math?

// SPDX-License-Identifier: MIT

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error Staking__TransferFailed();
error Withdraw__TransferFailed();

contract Staking {
    IERC20 public s_stakingToken;

    uint256 private s_totalSupply;
    mapping(address => uint256) public s_balances;

    constructor(address stakingToken) {
        s_stakingToken = IERC20(stakingToken);
    }

    function stake(uint256 amount) external {
        // keep track of how much this user has staked
        // keep track of how much token we have total
        // transfer the tokens to this contract
        /** @notice Be mindful of reentrancy attack here */
        s_balances[msg.sender] += amount;
        s_totalSupply += amount;
        //emit event
        bool success = s_stakingToken.transferFrom(msg.sender, address(this), amount);
        // require(success, "Failed"); Save gas fees here
        if (!success) {
            revert Staking__TransferFailed();
        }
    }

    function withdraw(uint256 amount) external {
        s_balances[msg.sender] -= amount;
        s_totalSupply -= amount;
        // emit event
        bool success = s_stakingToken.transfer(msg.sender, amount);
        if (!success) {
            revert Withdraw__TransferFailed();
        }
    }

    function claimReward() external {
        // contract emits X reward tokens per second
        // disperse tokens to all token stakers
        // reward emission != 1:1
    }
}
