# 🌐 Testnet Deployment Summary

## Quick Reference Table

| Network | Chain ID | Gas Token | Token Address | RPC URL | Deployment Script |
|---------|----------|-----------|---------------|---------|-------------------|
| **Mantle Testnet** 🟢 | 5001 | MNT (testnet) | Test USDC (deployed, 18 decimals) | https://rpc.testnet.mantle.xyz | `deploy_mantle.bat` |
| **Flow Testnet** 🟣 | 545 | FLOW (testnet) | `0xd7d43ab7b365f0d0789aE83F4385fA710FfdC98F` (USDF, 18 decimals) | https://testnet.evm.nodes.onflow.org | `deploy_flow.bat` |
| **Local** 🖥️ | 31337 | ETH | Mock USDC (6 decimals) | http://localhost:8545 | `start_anvil.bat` + `deploy_windows.bat` |

## Demo Markets

| Network | Demo Market Question |
|---------|---------------------|
| **Mantle Testnet** | "Will Mantle reach $5 by end of 2024?" |
| **Flow Testnet** | "Will Flow reach $10 by end of 2024?" |
| **Local** | "Will ETH reach $5000 by end of 2024?" |

## Network Details

### Mantle Testnet 🟢
- **Production Ready**: ❌ Testnet only
- **Gas Costs**: Free (testnet)
- **Token**: Test USDC (18 decimals, deployed by script)
- **Explorer**: https://explorer.testnet.mantle.xyz
- **Faucet**: https://faucet.testnet.mantle.xyz
- **Features**: Faucet function for 1000 test tokens

### Flow Testnet 🟣
- **Production Ready**: ❌ Testnet only
- **Gas Costs**: Free (testnet)
- **Token**: USDF (18 decimals, existing contract)
- **Explorer**: https://testnet.flowscan.org
- **Faucet**: https://testnet-faucet.onflow.org
- **Features**: Existing USDF token with 18 decimals

### Local Development 🖥️
- **Production Ready**: ❌ Development only
- **Gas Costs**: Free (local blockchain)
- **Token**: Mock USDC (6 decimals, 1M supply)
- **Explorer**: N/A (local)
- **Accounts**: 4 pre-funded accounts with 10,000 ETH each

## Hackathon Settings

- ⚡ **Phase Duration**: 1 minute each (Seeding → Voting → Trading)
- 💰 **Minimum Amounts**: 0.000001 tokens (1e12 wei for 18 decimals)
- 🔧 **Automated Deployment**: One-click batch scripts
- 🎯 **Ready for Demo**: Pre-configured markets
- 🧪 **Free Testing**: Testnet deployment with free tokens

## Quick Start Commands

```bash
# Choose your network:
./deploy_mantle.bat   # Deploy to Mantle Testnet
./deploy_flow.bat     # Deploy to Flow Testnet
./start_anvil.bat     # Start local blockchain
```

## Resources

- **Explorers**: Testnet explorers for both networks
- **Faucets**: Free testnet tokens for gas and trading
- **Docs**: Mantle and Flow developer documentation
- **Support**: Discord communities for each network

Perfect for hackathon demos with rapid phase transitions! 🚀 