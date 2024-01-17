// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/**
 * @title Rewarder
 * @notice A contract that allows users to stake a token and claim permissionlessly issued rewards.
 * @dev There are plenty of ways to improve this contract, but it does what it says on the box.
 */
contract Rewarder is ReentrancyGuard {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Issued(IERC20 token, uint256 amount);
    event Claimed(address indexed user, IERC20 token, uint256 amount);

    error InsufficientBalance();
    error TransferFailed();

    // The token that will be staked
    IERC20 public stakingToken;

    // The total amount of the staking token currently staked
    uint256 totalStaked;

    // Tracks the current snapshot index
    uint256 currentSnapshot;

    // A simple struct to represent a distribution
    struct Reward {
        IERC20 token;
        uint256 amount;
    }

    // A mapping from user address to the amount of staking tokens staked
    EnumerableMap.AddressToUintMap private stakersMap;

    // A mapping from snapshot index to the reward distributed at that snapshot
    mapping(uint256 => Reward) public rewards;

    // A mapping from user address to the last snapshot index they claimed
    // note this could have been part of the stakersMap
    mapping(address => uint256) public lastClaimed;

    /**
     * @notice Constructor for the Rewarder contract
     * @param _stakingToken The token that will be staked
     */
    constructor(IERC20 _stakingToken) {
        stakingToken = _stakingToken;
    }

    /**
     * @notice Stakes a given amount of the staking token.
     * @param amount The amount of the staking token to stake
     * @dev The caller must have approved this contract to transfer the staking token.
     */
    function stake(uint256 amount) external nonReentrant {
        // if the user has never staked before, set their last claimed snapshot
        // to the current snapshot so they can't claim rewards from before they
        // started staking
        uint256 staked = amount;
        if (!stakersMap.contains(msg.sender)) {
            lastClaimed[msg.sender] = currentSnapshot;
        } else {
            staked += stakersMap.get(msg.sender);
        }

        // transfer the staking token from the user to this contract
        // note that the caller must have pre-approved this transfer amount
        // another option would be to use the ERC20Permit standard
        if (!stakingToken.transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        // update the stakers map and total staked amount
        stakersMap.set(msg.sender, staked);
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstakes a given amount of the staking token.
     * @param amount The amount of the staking token to unstake
     * @dev The caller must have a balance of at least `amount` staked.
     *   The staking token will be transferred back to the caller, and
     *   and unclaimed rewards will be forfeited. Consider reverting if
     *   the caller has unclaimed rewards.
     */
    function unstake(uint256 amount) external nonReentrant {
        // TODO: ensure the user has no unclaimed rewards(?)
        // if (lastClaimed[msg.sender] < currentSnapshot) {
        //     revert HasUnclaimedRewards();
        // }

        // ensure this is a valid unstaking operation
        if (stakersMap.get(msg.sender) < amount) {
            revert InsufficientBalance();
        }

        // update the stakers map and total staked amount
        stakersMap.set(msg.sender, stakersMap.get(msg.sender) - amount);
        totalStaked -= amount;

        // transfer the staking token back to the user
        stakingToken.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Distributes a token to all stakers
     * @param distributedToken The token to distribute
     * @param totalAmount The total amount of the token to distribute
     * @dev The token contract may be malicious and attempt to reenter this contract or otherwise
     *    behave in an unexpected way. OpenZeppelin's ReentrancyGuard guards against reentrancy, but
     *    it is still possible for the token contract to behave in unexpected ways. This is a general
     *    problem with any contract that calls functions on arbitrary contracts. A simple mitigation
     *    technique is to whitelist tokens, but this breaks the permissionless nature of the contract.
     */
    function distribute(IERC20 distributedToken, uint256 totalAmount) external nonReentrant {
        // create a new snapshot index
        uint256 snapshot = currentSnapshot++;

        // transfer the token from the caller to this contract
        // a safety check could be to verify the expected balance change
        // before and after the transfer, but this is paranoid AF
        if (!distributedToken.transferFrom(msg.sender, address(this), totalAmount)) {
            revert TransferFailed();
        }

        // create new snapshot which any pre-existing staker can claim
        rewards[snapshot] = Reward(distributedToken, totalAmount);

        emit Issued(distributedToken, totalAmount);
    }

    /**
     * @notice Claim rewards for a given set of snapshots
     * @param snapshots The snapshot IDs to claim
     * @dev It is the responsibility of the caller to ensure that the provided
     *  snapshots are valid, unclaimed and ordered. This function will not
     *  revert if the caller attempts to claim a snapshot that has already
     *  been claimed; instead, it will simply skip that snapshot. Similarly,
     *  if the caller attempts to claim a snapshot that is in the future, it
     *  will be skipped. These cases will result in gas waste by the caller
     *  but will not result in otherwise unexpected behavior. Obviously, the
     *  implicit upper bound on the number of snapshots that can be claimed
     *  in a single transaction is constrained by the block gas limit.
     */
    function claimRewards(uint256[] calldata snapshots) external nonReentrant {
        for (uint256 i = 0; i < snapshots.length; i++) {
            Reward storage reward = rewards[snapshots[i]];

            // if the reward has already been claimed or is in the future, skip it
            if (lastClaimed[msg.sender] >= snapshots[i] || snapshots[i] >= currentSnapshot) {
                continue;
            }

            // update the last claimed snapshot for the user
            lastClaimed[msg.sender] = snapshots[i];

            // calculate the proportional reward amount for the user
            uint256 rewardAmount = reward.amount * stakersMap.get(msg.sender) / totalStaked;

            // transfer the reward to the user
            reward.token.transferFrom(address(this), msg.sender, rewardAmount);

            emit Claimed(msg.sender, reward.token, rewardAmount);
        }
    }
}
