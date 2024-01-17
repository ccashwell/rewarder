# A Simple Reward Distribution Contract

## 1. Problem

We want to allocate funds to a group of token holders that have staked their holdings of a specific token at will. It should be possible to distribute funds multiple times. Given that the staked token is an ERC20, how would you go about distributing funds of other arbitrary ERC20 tokens evenly to all holders based on their staked balance at the time of distribution? Assume that anyone can distribute funds.

### 1.1. Requirements

- Any holder of a given token can stake, unstake, or modify their stake at will;
- Anyone can distribute funds to all stakers;
- Funds are distributed evenly to all stakers based on their staked balance at the time of distribution;

## 2. Solution

We will use a simple mapping to keep track of the stakes of each user. The contract will be initialized with the staked token address, and any other ERC20 token can be distributed to the stakers proportional to their stake. The contract will keep track of the total staked amount, and the staked amount of each user. The contract will also keep track of the total distributed amount, and the distributed amount of each user.

- `stake`/`unstake` - staking and unstaking of the staked token;
  - the user can stake/unstake at will;
  - the user can stake/unstake multiple times;
  - the user can stake/unstake an arbitrary amount;
- `distribute` - accept arbitrary tokens rewards;
  - anyone can distribute funds;
  - any token can be distributed;
  - only existing stakers can receive the distribution;
- `claim` - claiming of distributed tokens;
  - can claim only if the user has a stake at the time of distribution;
  - can claim only once per distribution;
  - can claim an arbitrary number of distributions at once;
