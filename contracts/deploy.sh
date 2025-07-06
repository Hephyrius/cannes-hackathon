#!/bin/bash

echo "=== PREDICTION MARKET LOCAL DEPLOYMENT ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Anvil is running
echo -e "${BLUE}Checking if Anvil is running...${NC}"
if curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' http://localhost:8545 > /dev/null; then
    echo -e "${GREEN}✓ Anvil is running on localhost:8545${NC}"
else
    echo -e "${YELLOW}Starting Anvil local blockchain...${NC}"
    ~/.foundry/bin/anvil --host 0.0.0.0 --port 8545 &
    ANVIL_PID=$!
    echo "Anvil PID: $ANVIL_PID"
    sleep 3
fi

echo ""

# Deploy contracts
echo -e "${BLUE}Deploying contracts...${NC}"
~/.foundry/bin/forge script script/LocalDeploy.s.sol:LocalDeployScript \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    -vvv

echo ""
echo -e "${GREEN}=== DEPLOYMENT COMPLETE ===${NC}"
echo ""

# Display account information
echo -e "${YELLOW}=== TEST ACCOUNTS (Anvil Default) ===${NC}"
echo "Account 0 (Deployer): 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
echo "Private Key:          0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
echo "Balance:              10000 ETH"
echo ""
echo "Account 1 (LP1):      0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
echo "Private Key:          0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
echo "Balance:              10000 ETH"
echo ""
echo "Account 2 (LP2):      0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
echo "Private Key:          0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
echo "Balance:              10000 ETH"
echo ""
echo "Account 3 (Trader1):  0x90F79bf6EB2c4f870365E785982E1f101E93b906"
echo "Private Key:          0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
echo "Balance:              10000 ETH"
echo ""

echo -e "${YELLOW}=== QUICK START GUIDE ===${NC}"
echo "1. Contracts are deployed and ready for testing"
echo "2. Use the provided accounts and private keys"
echo "3. Connect your wallet to: http://localhost:8545"
echo "4. Chain ID: 31337 (Anvil default)"
echo ""

echo -e "${YELLOW}=== TESTING WORKFLOW ===${NC}"
echo "1. Seed liquidity (requires USDC approval first)"
echo "2. Wait 2 hours or use time manipulation"
echo "3. Propose and vote on resolution criteria"
echo "4. Wait 1 hour or use time manipulation"
echo "5. Start trading YES/NO tokens"
echo ""

echo -e "${BLUE}Local blockchain is ready for testing!${NC}"
echo "Press Ctrl+C to stop the blockchain when done testing" 