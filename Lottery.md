# Lottery System: Random Character of the Day - Design Document

## Prompt

We want to create a transaction lottery system that can be rapidly deployed onto emergent blockchains to incentivize use. Every day, users whose tx hash ends in the “character of the day” are eligible to claim a prize. The character of the day changes daily. If the last character of a user's transaction matches the character of the day they should be able to claim their reward through our application. Each address can win once per day, but multiple people (addresses) can win each day.

## Design Concept

### Backend (Serverless Functions)

- **API for Frontend**:
  - Endpoint to fetch signed tickets.
  - Endpoint to submit signed tickets and add them to the datastore.

### Network Monitoring Cluster

- **One Node Per Network**:
  - Connect to RPC.
  - Subscribe to new blocks, retrieve block by hash, and pull out transaction list.
  - Iterate through transaction hashes, checking the last character.
  - If the character matches, insert a ticket into the lottery.

- **Daily Character Generation**:
  - Generate the character of the day, maybe as simple as `Math.random().toString(16).slice(-1)`
  - Store the character with expiration.
  - Could do this as a cronjob or more simply with Redis expiring keys... 0 TTL == time to generate a new character.

- **Lottery Processing Cronjob**:
  - Daily retrieval of all tickets matching the daily character.
  - Filter unique winners and sign one ticket for each.
  - Store the signed ticket `eip712({ address, chainId, winningHash, expiration }) => signed ticket`.

### Smart Contract

- **Omnichain**:
  - Can/should be deployed to every supported chain.
- **Reward Management**:
  - Mechanism for depositing rewards. Pull approval preferable unless using native rewards.
- **Claim Function**:
  - Allow caller to claim prize using signed winning ticket provided by the backend.

### Frontend

- **Wallet Connection**:
  - Functionality to connect users' wallets. Probably viem/wagmi/web3modal.

- **User Interface**:
  - Simply a view to check if the user has won and provide a claim button if so.
  - Utilize useSWR() for backend communication and storing signed tickets if the user has won.
  - Include a claim button to trigger transactions to the contract using the signed tickets.
