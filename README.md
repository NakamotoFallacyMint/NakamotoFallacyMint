# NakamotoFallacyMint (NAKV)

## Overview
NakamotoFallacyMint is an ERC20 token implementation with a unique minting and reflection mechanism designed for the Avalanche C-Chain. The contract incorporates a phased minting system with decreasing rewards and a proportional reflection mechanism that distributes tokens to existing holders.

## Technical Specifications

### Token Metrics
- Name: Nakamoto Fallacy Mint
- Symbol: NAKV
- Decimals: 18
- Initial Owner Allocation: 10,000 NAKV

### Core Features

#### Phase-Based Minting System
The minting mechanism operates in phases, with each phase doubling the wallet limit and halving the rewards:
- Phase 1 (0-100k wallets): 1 NAKV per mint
- Phase 2 (100k-200k wallets): 0.5 NAKV per mint
- Phase 3 (200k-400k wallets): 0.25 NAKV per mint
- Phase 4 (400k-800k wallets): 0.125 NAKV per mint
- Subsequent phases follow the same pattern

#### Reflection Mechanism
During each mint operation, a percentage of the minted amount is distributed to existing token holders:
- Phase 1: 50% reflection rate
- Phase 2: 25% reflection rate
- Phase 3: 12.5% reflection rate
- Phase 4: 6.25% reflection rate
- Distribution is proportional to holders' token balance
- Contract owner is excluded from reflection distribution

#### Minting Eligibility
- One-time minting per wallet address
- Minimum gas expenditure requirement: 1.1 nAVAX
- Gas usage verification within the last 1,000,000 blocks

### Smart Contract Architecture

#### State Variables
```solidity
uint256 public constant INITIAL_OWNER_ALLOCATION = 10_000 * 10**18;
uint256 public constant PHASE_WALLET_COUNT = 100_000;
uint256 public constant BLOCKS_LOOKBACK = 1_000_000;
uint256 public constant MIN_GAS_SPENT = 11 * 10**8; // 1.1 nAVAX

uint256 public totalMintedWallets;
uint256 public totalReflected;
mapping(address => bool) public hasMinted;
mapping(address => uint256) public lastMintBlock;
```

#### Token Holder Management
- Automatic tracking of token holders
- Dynamic holder list updates during transfers
- Automatic removal of zero-balance addresses
- Efficient holder management for reflection distribution

#### Events
```solidity
event TokensMinted(address indexed wallet, uint256 amount, uint256 reflectedAmount);
event ReflectionDistributed(uint256 amount);
```

### Security Features

#### Access Control
- Owner-specific functions protected by `onlyOwner` modifier
- Ownership transfer capabilities
- Ownership renouncement option

#### Safety Mechanisms
- Double-minting prevention
- Zero-address transaction prevention
- Overflow/underflow protection (Solidity ^0.8.20)
- Automated holder list management
- Owner exclusion from reflection system

### Public Functions

#### View Functions
- `getCurrentMintAmount()`: Returns current phase mint amount
- `getCurrentReflectionRate()`: Returns current phase reflection rate
- `isEligibleForMint(address)`: Checks wallet eligibility for minting
- Standard ERC20 view functions

#### State-Modifying Functions
- `mint()`: Primary minting function with reflection distribution
- Standard ERC20 transfer functions
- Ownership management functions

## Implementation Notes

### Gas Optimization
- Efficient token holder management
- Optimized reflection distribution algorithm
- Smart storage usage for holder tracking

### Oracle Integration
The contract includes a placeholder for gas expenditure verification, which should be replaced with a proper oracle implementation in production:
```solidity
// Current placeholder implementation
gasSpent = wallet.balance > 0 ? MIN_GAS_SPENT : 0;
```

## License
MIT License

## Security Considerations
1. The contract implements standard ERC20 security practices
2. Reflection calculations should be monitored for large holder counts
3. Gas expenditure verification should be implemented via a reliable oracle
4. Phase transitions are automatic and deterministic

## Future Improvements
1. Implementation of a proper oracle for gas expenditure verification
2. Optional emergency pause mechanism
3. Enhanced reflection distribution optimization for large holder bases
4. Additional holder incentive mechanisms

---

For detailed implementation and deployment instructions, please refer to the source code and comments within the smart contract.
