# 🚀 Hackathon Deployment Guide

## Quick Overview

Your prediction market is now ready for deployment on **Mantle Testnet** and **Flow Testnet** with hackathon-optimized settings:

- ⚡ **1-minute phases** for rapid demos
- 💰 **0.000001 token minimum** to save on testing costs
- 🧪 **Testnet deployment** with free test tokens
- 🔧 **Automated deployment scripts** for both networks
- 🎯 **Pre-configured demo markets** ready to go

## 🌐 Network Configurations

### Mantle Testnet 🟢
- **Network Name**: Mantle Testnet
- **RPC URL**: `https://rpc.testnet.mantle.xyz`
- **Chain ID**: `5001`
- **Gas Token**: MNT (testnet)
- **Token**: Test USDC (deployed by script, 18 decimals)
- **Explorer**: https://explorer.testnet.mantle.xyz
- **Faucet**: https://faucet.testnet.mantle.xyz

### Flow Testnet 🟣
- **Network Name**: Flow Testnet
- **RPC URL**: `https://testnet.evm.nodes.onflow.org`
- **Chain ID**: `545`
- **Gas Token**: FLOW (testnet)
- **Token**: USDF `0xd7d43ab7b365f0d0789aE83F4385fA710FfdC98F` (18 decimals)
- **Explorer**: https://testnet.flowscan.org
- **Faucet**: https://testnet-faucet.onflow.org

## 📦 Deployment Options

### Option 1: Local Testing (Recommended First)
```bash
# Start local blockchain
./start_anvil.bat

# Deploy locally
./deploy_windows.bat
```

### Option 2: Deploy to Mantle Testnet
```bash
# Deploy to Mantle testnet with test USDC
./deploy_mantle.bat
```

### Option 3: Deploy to Flow Testnet
```bash
# Deploy to Flow testnet with USDF
./deploy_flow.bat
```

## ⚙️ Hackathon Settings

### Timing (Perfect for Demos)
- **Seeding Phase**: 1 minute ⏱️
- **Voting Phase**: 1 minute ⏱️
- **Trading Phase**: Unlimited ♾️

### Minimum Amounts (Cost-Effective)
- **Min Seed**: 0.000001 tokens (1e12 wei for 18 decimals)
- **Min Trade**: 0.000001 tokens (1e12 wei for 18 decimals)
- **No maximum limits**
- **Free test tokens** available on both testnets

### Demo Markets
- **Mantle Testnet**: "Will Mantle reach $5 by end of 2024?"
- **Flow Testnet**: "Will Flow reach $10 by end of 2024?"

## 🎯 Quick Demo Flow

### Phase 1: Seeding (1 minute)
1. LP1 seeds 0.01 USDC → Gets LP voting rights
2. LP2 seeds 0.005 USDC → Gets LP voting rights
3. Tokens minted at $0.50 each (YES/NO)

### Phase 2: Voting (1 minute)
1. LP1 proposes: "CoinGecko price on Dec 31, 2024"
2. LP2 proposes: "Binance price on Dec 31, 2024"
3. Both LPs vote (weighted by contribution)
4. Winning criteria selected

### Phase 3: Trading (Unlimited)
1. Traders buy YES tokens with USDC
2. Traders buy NO tokens with USDC
3. Prices change based on demand (AMM)
4. 0.3% trading fee applied

## 💳 Getting Started

### 1. Setup Wallet
Add testnet networks to MetaMask:
- Mantle Testnet: Chain ID 5001
- Flow Testnet: Chain ID 545

### 2. Get Testnet Gas Tokens
- **Mantle**: Get testnet MNT from https://faucet.testnet.mantle.xyz
- **Flow**: Get testnet FLOW from https://testnet-faucet.onflow.org

### 3. Get Test Tokens
- **Mantle**: Use faucet() function on deployed Test USDC contract (18 decimals)
- **Flow**: Get USDF tokens from testnet faucet (18 decimals)

### 4. Deploy & Test
Run deployment script for your chosen network

## 🔧 Contract Addresses (After Deployment)

### Base Deployment
```
Factory: [Will be generated]
Demo Market: [Will be generated]
YES Token: [Will be generated]
NO Token: [Will be generated]
```

### Mantle Deployment
```
Factory: [Will be generated]
Demo Market: [Will be generated]
YES Token: [Will be generated]
NO Token: [Will be generated]
```

### Flow Deployment
```
Factory: [Will be generated]
Demo Market: [Will be generated]
YES Token: [Will be generated]
NO Token: [Will be generated]
```

## 📱 Frontend Integration

### Contract ABIs
Located in `out/` after compilation:
- `SimplePredictionMarket.json`
- `SimpleMarketFactory.json`

### Web3 Connection Example
```javascript
// Base network
const provider = new ethers.providers.JsonRpcProvider('https://mainnet.base.org');

// Mantle network
const provider = new ethers.providers.JsonRpcProvider('https://rpc.mantle.xyz');

// Flow network
const provider = new ethers.providers.JsonRpcProvider('https://mainnet.evm.nodes.onflow.org');

// Contract instances
const factory = new ethers.Contract(FACTORY_ADDRESS, FactoryABI, signer);
const market = new ethers.Contract(MARKET_ADDRESS, MarketABI, signer);
```

## 🏆 Hackathon Tips

### For Judges/Demos
1. **Start with local deployment** to show full flow
2. **Use 1-minute timing** for rapid phase transitions
3. **Show multiple participants** (LP1, LP2, Trader)
4. **Demonstrate price discovery** through trading
5. **Highlight democratic resolution** through voting

### For Development
1. **Test locally first** before mainnet deployment
2. **Use minimal amounts** to save on gas
3. **Pre-approve USDC** to streamline interactions
4. **Monitor gas usage** for optimization
5. **Test edge cases** with multiple scenarios

## 🎨 Demo Market Ideas

### Crypto Markets
- "Will [TOKEN] reach $[PRICE] by [DATE]?"
- "Will [TOKEN] outperform [TOKEN] by [DATE]?"

### Real World Events
- "Will [EVENT] happen by [DATE]?"
- "Will [METRIC] exceed [VALUE] by [DATE]?"

### Hackathon Specific
- "Will our project win the hackathon?"
- "Will we deploy on mainnet during demo?"

## 🔍 Troubleshooting

### Common Issues
- **Insufficient gas**: Top up ETH/MNT
- **USDC not found**: Check network and address
- **Transaction fails**: Check phase timing
- **Prices don't update**: Ensure trading phase active

### Support Resources
- **Base Discord**: https://base.org/discord
- **Mantle Discord**: https://discord.gg/mantlenetwork
- **Flow Discord**: https://discord.gg/flow
- **Foundry Docs**: https://book.getfoundry.sh/

## 🚀 Ready to Launch!

Your prediction market is now optimized for hackathon success with:
- ✅ Rapid demo timing (1-minute phases)
- ✅ Cost-effective minimums (0.000001 tokens)
- ✅ Two testnet networks (Mantle + Flow)
- ✅ Free test tokens (18 decimals support)
- ✅ Automated deployment scripts
- ✅ Pre-configured demo markets

**Choose your network, run the deployment script, and start demoing!** 🎯

---

*Good luck with your hackathon! 🏆* 