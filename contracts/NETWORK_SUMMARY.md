# 🌐 Network Deployment Summary

## Quick Reference Table

| Network | Chain ID | Gas Token | USDC Address | RPC URL | Deployment Script |
|---------|----------|-----------|--------------|---------|-------------------|
| **Base** 🔵 | 8453 | ETH | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | https://mainnet.base.org | `deploy_base.bat` |
| **Mantle** 🟢 | 5000 | MNT | `0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9` | https://rpc.mantle.xyz | `deploy_mantle.bat` |
| **Flow** 🟣 | 747 | FLOW | `0xF1815bd50389c46847f0Bda824eC8da914045D14` | https://mainnet.evm.nodes.onflow.org | `deploy_flow.bat` |
| **Local** 🖥️ | 31337 | ETH | Mock USDC | http://localhost:8545 | `start_anvil.bat` + `deploy_windows.bat` |

## Demo Markets

| Network | Demo Market Question |
|---------|---------------------|
| **Base** | "Will Bitcoin reach $100,000 by end of 2024?" |
| **Mantle** | "Will Ethereum reach $5,000 by end of 2024?" |
| **Flow** | "Will Flow reach $10 by end of 2024?" |
| **Local** | "Will ETH reach $5000 by end of 2024?" |

## Hackathon Settings

- ⚡ **Phase Duration**: 1 minute each (Seeding → Voting → Trading)
- 💰 **Minimum Amounts**: 0.000001 USDC (1 wei)
- 🔧 **Automated Deployment**: One-click batch scripts
- 🎯 **Ready for Demo**: Pre-configured markets

## Quick Start Commands

```bash
# Choose your network:
./deploy_base.bat     # Deploy to Base
./deploy_mantle.bat   # Deploy to Mantle  
./deploy_flow.bat     # Deploy to Flow
./start_anvil.bat     # Start local blockchain
```

## Resources

- **Explorers**: BaseScan, MantleScan, FlowScan
- **Bridges**: bridge.base.org, bridge.mantle.xyz, port.onflow.org
- **Docs**: Base, Mantle, Flow developer documentation
- **Support**: Discord communities for each network

Perfect for hackathon demos with rapid phase transitions! 🚀 