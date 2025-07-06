# 🚀 Hackathon Deployment Guide

## Quick Overview

Your prediction market is now ready for deployment on **Base**, **Mantle**, and **Flow** networks with hackathon-optimized settings:

- ⚡ **1-minute phases** for rapid demos
- 💰 **0.000001 USDC minimum** to save on testing costs
- 🔧 **Automated deployment scripts** for all networks
- 🎯 **Pre-configured demo markets** ready to go

## 🌐 Network Configurations

### Base Network 🔵
- **Network Name**: Base
- **RPC URL**: `https://mainnet.base.org`
- **Chain ID**: `8453`
- **Gas Token**: ETH
- **USDC Address**: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- **Explorer**: https://basescan.org
- **Bridge**: https://bridge.base.org

### Mantle Network 🟢
- **Network Name**: Mantle
- **RPC URL**: `https://rpc.mantle.xyz`
- **Chain ID**: `5000`
- **Gas Token**: MNT
- **USDC Address**: `0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9`
- **Explorer**: https://explorer.mantle.xyz
- **Bridge**: https://bridge.mantle.xyz

### Flow Network 🟣
- **Network Name**: Flow EVM
- **RPC URL**: `https://mainnet.evm.nodes.onflow.org`
- **Chain ID**: `747`
- **Gas Token**: FLOW
- **USDC Address**: `0xF1815bd50389c46847f0Bda824eC8da914045D14`
- **Explorer**: https://evm.flowscan.org
- **Portal**: https://port.onflow.org

## 📦 Deployment Options

### Option 1: Local Testing (Recommended First)
```bash
# Start local blockchain
./start_anvil.bat

# Deploy locally
./deploy_windows.bat
```

### Option 2: Deploy to Base
```bash
# Deploy to Base mainnet
./deploy_base.bat
```

### Option 3: Deploy to Mantle
```bash
# Deploy to Mantle mainnet
./deploy_mantle.bat
```

### Option 4: Deploy to Flow
```bash
# Deploy to Flow mainnet
./deploy_flow.bat
```

## ⚙️ Hackathon Settings

### Timing (Perfect for Demos)
- **Seeding Phase**: 1 minute ⏱️
- **Voting Phase**: 1 minute ⏱️
- **Trading Phase**: Unlimited ♾️

### Minimum Amounts (Cost-Effective)
- **Min Seed**: 0.000001 USDC (1 wei)
- **Min Trade**: 0.000001 USDC (1 wei)
- **No maximum limits**

### Demo Markets
- **Base**: "Will Bitcoin reach $100,000 by end of 2024?"
- **Mantle**: "Will Ethereum reach $5,000 by end of 2024?"
- **Flow**: "Will Flow reach $10 by end of 2024?"

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
Add networks to MetaMask:
- Base: Use bridge.base.org
- Mantle: Use bridge.mantle.xyz
- Flow: Use port.onflow.org

### 2. Get Gas Tokens
- **Base**: Need ETH for gas fees
- **Mantle**: Need MNT for gas fees
- **Flow**: Need FLOW for gas fees

### 3. Get USDC
- **Base**: Bridge from Ethereum or buy on DEX
- **Mantle**: Bridge from Ethereum or buy on DEX
- **Flow**: Bridge from other networks or buy on DEX

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
- ✅ Cost-effective minimums (0.000001 USDC)
- ✅ Three major networks (Base + Mantle + Flow)
- ✅ Automated deployment scripts
- ✅ Pre-configured demo markets

**Choose your network, run the deployment script, and start demoing!** 🎯

---

*Good luck with your hackathon! 🏆* 