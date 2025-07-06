# Prediction Market Local Deployment Guide

## Quick Start (Recommended)

### 1. Start Local Blockchain
```bash
# Terminal 1: Start Anvil (keep this running)
~/.foundry/bin/anvil --host 0.0.0.0 --port 8545
```

### 2. Deploy Contracts
```bash
# Terminal 2: Deploy to local blockchain
cd contracts
~/.foundry/bin/forge script script/LocalDeploy.s.sol:LocalDeployScript \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    -vv
```

### 3. Update Testing Script
After deployment, copy the contract addresses from the output and update `test_interactions.sh`:

```bash
# Update these variables in test_interactions.sh
USDC_ADDRESS="<your_deployed_usdc_address>"
FACTORY_ADDRESS="<your_deployed_factory_address>"
MARKET_ADDRESS="<your_deployed_market_address>"
```

### 4. Run Tests
```bash
# Make scripts executable
chmod +x test_interactions.sh

# Run complete test suite
./test_interactions.sh full

# Or run individual commands
./test_interactions.sh setup    # Setup accounts
./test_interactions.sh seed     # Seed liquidity
./test_interactions.sh vote     # Run voting
./test_interactions.sh trade    # Run trading
./test_interactions.sh status   # Check status
```

## Manual Testing Commands

### Get Contract Addresses
```bash
# Get factory address from deployment output
# Get market address
~/.foundry/bin/cast call <factory_address> "getMarket(uint256)" 0 --rpc-url http://localhost:8545
```

### Setup Test Accounts
```bash
# Mint USDC to test accounts
~/.foundry/bin/cast send <usdc_address> "mint(address,uint256)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 50000000000 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --rpc-url http://localhost:8545

# Approve market for spending
~/.foundry/bin/cast send <usdc_address> "approve(address,uint256)" <market_address> 115792089237316195423570985008687907853269984665640564039457584007913129639935 --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d --rpc-url http://localhost:8545
```

### Phase 1: Seeding
```bash
# Seed liquidity
~/.foundry/bin/cast send <market_address> "seedLiquidity(uint256)" 10000000000 --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d --rpc-url http://localhost:8545
```

### Phase 2: Voting
```bash
# Fast forward time (2 hours)
~/.foundry/bin/cast rpc evm_increaseTime 7200 --rpc-url http://localhost:8545
~/.foundry/bin/cast rpc evm_mine --rpc-url http://localhost:8545

# Start voting
~/.foundry/bin/cast send <market_address> "startVoting()" --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --rpc-url http://localhost:8545

# Propose criteria
~/.foundry/bin/cast send <market_address> "proposeCriteria(string)" "CoinGecko price on Dec 31, 2024 at 11:59 PM UTC" --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d --rpc-url http://localhost:8545

# Vote on criteria
~/.foundry/bin/cast send <market_address> "voteOnCriteria(string)" "CoinGecko price on Dec 31, 2024 at 11:59 PM UTC" --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d --rpc-url http://localhost:8545
```

### Phase 3: Trading
```bash
# Fast forward time (1 hour)
~/.foundry/bin/cast rpc evm_increaseTime 3600 --rpc-url http://localhost:8545
~/.foundry/bin/cast rpc evm_mine --rpc-url http://localhost:8545

# Start trading
~/.foundry/bin/cast send <market_address> "startTrading()" --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --rpc-url http://localhost:8545

# Buy YES tokens
~/.foundry/bin/cast send <market_address> "buyYes(uint256)" 1000000000 --private-key 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6 --rpc-url http://localhost:8545

# Buy NO tokens
~/.foundry/bin/cast send <market_address> "buyNo(uint256)" 500000000 --private-key 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6 --rpc-url http://localhost:8545
```

## Account Information

### Default Anvil Accounts
- **Account 0 (Deployer)**: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
  - Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
  - Role: Deployer, Market Admin

- **Account 1 (LP1)**: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
  - Private Key: `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d`
  - Role: Liquidity Provider

- **Account 2 (LP2)**: `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`
  - Private Key: `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a`
  - Role: Liquidity Provider

- **Account 3 (Trader)**: `0x90F79bf6EB2c4f870365E785982E1f101E93b906`
  - Private Key: `0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6`
  - Role: Trader

## Network Configuration

- **RPC URL**: `http://localhost:8545`
- **Chain ID**: `31337`
- **Block Time**: Instant (for testing)

## Checking Status

### Market Status
```bash
# Check current phase
~/.foundry/bin/cast call <market_address> "currentPhase()" --rpc-url http://localhost:8545

# Check total LP contributions
~/.foundry/bin/cast call <market_address> "totalLPContributions()" --rpc-url http://localhost:8545

# Check resolution criteria (if set)
~/.foundry/bin/cast call <market_address> "resolutionCriteria()" --rpc-url http://localhost:8545

# Check token prices
~/.foundry/bin/cast call <market_address> "getTokenPrices()" --rpc-url http://localhost:8545
```

### Balances
```bash
# Check USDC balance
~/.foundry/bin/cast call <usdc_address> "balanceOf(address)" <account_address> --rpc-url http://localhost:8545

# Check YES token balance
~/.foundry/bin/cast call <yes_token_address> "balanceOf(address)" <account_address> --rpc-url http://localhost:8545

# Check NO token balance
~/.foundry/bin/cast call <no_token_address> "balanceOf(address)" <account_address> --rpc-url http://localhost:8545
```

## Frontend Integration

### Contract ABIs
The contract ABIs are automatically generated in `out/` directory after compilation:
- `out/SimplePredictionMarket.sol/SimplePredictionMarket.json`
- `out/SimpleMarketFactory.sol/SimpleMarketFactory.json`
- `out/LocalDeploy.s.sol/MockUSDC.json`

### Web3 Connection
```javascript
// Connect to local blockchain
const provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
const signer = new ethers.Wallet('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80', provider);

// Contract instances
const usdc = new ethers.Contract(USDC_ADDRESS, MockUSDC.abi, signer);
const factory = new ethers.Contract(FACTORY_ADDRESS, SimpleMarketFactory.abi, signer);
const market = new ethers.Contract(MARKET_ADDRESS, SimplePredictionMarket.abi, signer);
```

## Troubleshooting

### Common Issues

1. **Anvil not responding**: Restart anvil and redeploy
2. **Transaction reverted**: Check phase timing and approvals
3. **Insufficient balance**: Check USDC balance and approvals
4. **Contract not found**: Verify contract addresses

### Reset Testing Environment
```bash
# Kill anvil
pkill anvil

# Restart anvil
~/.foundry/bin/anvil --host 0.0.0.0 --port 8545

# Redeploy contracts
~/.foundry/bin/forge script script/LocalDeploy.s.sol:LocalDeployScript --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 -vv
```

## Next Steps

1. **Frontend Development**: Build React/Vue frontend using the deployed contracts
2. **Mobile Testing**: Test with mobile wallets using ngrok for public access
3. **Load Testing**: Run the scale tests for performance evaluation
4. **Security Testing**: Audit contracts before mainnet deployment

The prediction market is now ready for comprehensive testing! 🚀 