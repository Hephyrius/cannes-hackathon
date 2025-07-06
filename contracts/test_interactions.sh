#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Contract addresses (you'll need to update these after deployment)
USDC_ADDRESS="0x5FbDB2315678afecb367f032d93F642f64180aa3"
FACTORY_ADDRESS="0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
MARKET_ADDRESS="0xCafac3dD18aC6c6e92c921884f9E4176737C052c"

# Test accounts (Anvil defaults)
DEPLOYER_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
LP1_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
LP2_KEY="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
TRADER_KEY="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"

DEPLOYER_ADDR="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
LP1_ADDR="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
LP2_ADDR="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
TRADER_ADDR="0x90F79bf6EB2c4f870365E785982E1f101E93b906"

RPC_URL="http://localhost:8545"

echo -e "${BLUE}=== PREDICTION MARKET TESTING SCRIPT ===${NC}"
echo ""

function print_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  setup       - Setup test accounts with USDC"
    echo "  seed        - Seed liquidity to the market"
    echo "  vote        - Run voting phase"
    echo "  trade       - Run trading phase"
    echo "  full        - Run complete market lifecycle"
    echo "  balances    - Check all balances"
    echo "  status      - Check market status"
    echo ""
}

function setup_accounts() {
    echo -e "${YELLOW}Setting up test accounts with USDC...${NC}"
    
    # Mint USDC to test accounts
    echo "Minting USDC to LP1..."
    ~/.foundry/bin/cast send $USDC_ADDRESS \
        "mint(address,uint256)" $LP1_ADDR 50000000000 \
        --private-key $DEPLOYER_KEY --rpc-url $RPC_URL
    
    echo "Minting USDC to LP2..."
    ~/.foundry/bin/cast send $USDC_ADDRESS \
        "mint(address,uint256)" $LP2_ADDR 30000000000 \
        --private-key $DEPLOYER_KEY --rpc-url $RPC_URL
    
    echo "Minting USDC to Trader..."
    ~/.foundry/bin/cast send $USDC_ADDRESS \
        "mint(address,uint256)" $TRADER_ADDR 10000000000 \
        --private-key $DEPLOYER_KEY --rpc-url $RPC_URL
    
    # Approve market to spend USDC
    echo "Approving market for LP1..."
    ~/.foundry/bin/cast send $USDC_ADDRESS \
        "approve(address,uint256)" $MARKET_ADDRESS 115792089237316195423570985008687907853269984665640564039457584007913129639935 \
        --private-key $LP1_KEY --rpc-url $RPC_URL
    
    echo "Approving market for LP2..."
    ~/.foundry/bin/cast send $USDC_ADDRESS \
        "approve(address,uint256)" $MARKET_ADDRESS 115792089237316195423570985008687907853269984665640564039457584007913129639935 \
        --private-key $LP2_KEY --rpc-url $RPC_URL
    
    echo "Approving market for Trader..."
    ~/.foundry/bin/cast send $USDC_ADDRESS \
        "approve(address,uint256)" $MARKET_ADDRESS 115792089237316195423570985008687907853269984665640564039457584007913129639935 \
        --private-key $TRADER_KEY --rpc-url $RPC_URL
    
    echo -e "${GREEN}✓ Account setup complete!${NC}"
}

function seed_liquidity() {
    echo -e "${YELLOW}Seeding liquidity...${NC}"
    
    echo "LP1 seeding 10,000 USDC..."
    ~/.foundry/bin/cast send $MARKET_ADDRESS \
        "seedLiquidity(uint256)" 10000000000 \
        --private-key $LP1_KEY --rpc-url $RPC_URL
    
    echo "LP2 seeding 5,000 USDC..."
    ~/.foundry/bin/cast send $MARKET_ADDRESS \
        "seedLiquidity(uint256)" 5000000000 \
        --private-key $LP2_KEY --rpc-url $RPC_URL
    
    echo -e "${GREEN}✓ Liquidity seeding complete!${NC}"
}

function run_voting() {
    echo -e "${YELLOW}Running voting phase...${NC}"
    
    # Fast forward time to voting phase (2 hours)
    echo "Fast forwarding time to voting phase..."
    ~/.foundry/bin/cast rpc evm_increaseTime 7200 --rpc-url $RPC_URL
    ~/.foundry/bin/cast rpc evm_mine --rpc-url $RPC_URL
    
    echo "Starting voting phase..."
    ~/.foundry/bin/cast send $MARKET_ADDRESS \
        "startVoting()" \
        --private-key $DEPLOYER_KEY --rpc-url $RPC_URL
    
    echo "LP1 proposing criteria..."
    ~/.foundry/bin/cast send $MARKET_ADDRESS \
        "proposeCriteria(string)" "CoinGecko price on Dec 31, 2024 at 11:59 PM UTC" \
        --private-key $LP1_KEY --rpc-url $RPC_URL
    
    echo "LP2 proposing criteria..."
    ~/.foundry/bin/cast send $MARKET_ADDRESS \
        "proposeCriteria(string)" "Binance price on Dec 31, 2024 at market close" \
        --private-key $LP2_KEY --rpc-url $RPC_URL
    
    echo "LP1 voting..."
    ~/.foundry/bin/cast send $MARKET_ADDRESS \
        "voteOnCriteria(string)" "CoinGecko price on Dec 31, 2024 at 11:59 PM UTC" \
        --private-key $LP1_KEY --rpc-url $RPC_URL
    
    echo "LP2 voting..."
    ~/.foundry/bin/cast send $MARKET_ADDRESS \
        "voteOnCriteria(string)" "Binance price on Dec 31, 2024 at market close" \
        --private-key $LP2_KEY --rpc-url $RPC_URL
    
    echo -e "${GREEN}✓ Voting phase complete!${NC}"
}

function run_trading() {
    echo -e "${YELLOW}Running trading phase...${NC}"
    
    # Fast forward time to trading phase (1 hour)
    echo "Fast forwarding time to trading phase..."
    ~/.foundry/bin/cast rpc evm_increaseTime 3600 --rpc-url $RPC_URL
    ~/.foundry/bin/cast rpc evm_mine --rpc-url $RPC_URL
    
    echo "Starting trading phase..."
    ~/.foundry/bin/cast send $MARKET_ADDRESS \
        "startTrading()" \
        --private-key $DEPLOYER_KEY --rpc-url $RPC_URL
    
    echo "Trader buying YES tokens with 1000 USDC..."
    ~/.foundry/bin/cast send $MARKET_ADDRESS \
        "buyYes(uint256)" 1000000000 \
        --private-key $TRADER_KEY --rpc-url $RPC_URL
    
    echo "Trader buying NO tokens with 500 USDC..."
    ~/.foundry/bin/cast send $MARKET_ADDRESS \
        "buyNo(uint256)" 500000000 \
        --private-key $TRADER_KEY --rpc-url $RPC_URL
    
    echo -e "${GREEN}✓ Trading phase complete!${NC}"
}

function check_balances() {
    echo -e "${YELLOW}Checking balances...${NC}"
    
    echo "=== USDC Balances ==="
    LP1_USDC=$(~/.foundry/bin/cast call $USDC_ADDRESS "balanceOf(address)" $LP1_ADDR --rpc-url $RPC_URL)
    LP2_USDC=$(~/.foundry/bin/cast call $USDC_ADDRESS "balanceOf(address)" $LP2_ADDR --rpc-url $RPC_URL)
    TRADER_USDC=$(~/.foundry/bin/cast call $USDC_ADDRESS "balanceOf(address)" $TRADER_ADDR --rpc-url $RPC_URL)
    
    echo "LP1 USDC:    $((LP1_USDC / 1000000)) USDC"
    echo "LP2 USDC:    $((LP2_USDC / 1000000)) USDC"
    echo "Trader USDC: $((TRADER_USDC / 1000000)) USDC"
    echo ""
    
    # Get token addresses
    YES_TOKEN=$(~/.foundry/bin/cast call $MARKET_ADDRESS "yesToken()" --rpc-url $RPC_URL)
    NO_TOKEN=$(~/.foundry/bin/cast call $MARKET_ADDRESS "noToken()" --rpc-url $RPC_URL)
    
    echo "=== YES Token Balances ==="
    TRADER_YES=$(~/.foundry/bin/cast call $YES_TOKEN "balanceOf(address)" $TRADER_ADDR --rpc-url $RPC_URL)
    echo "Trader YES: $((TRADER_YES / 1000000)) tokens"
    echo ""
    
    echo "=== NO Token Balances ==="
    TRADER_NO=$(~/.foundry/bin/cast call $NO_TOKEN "balanceOf(address)" $TRADER_ADDR --rpc-url $RPC_URL)
    echo "Trader NO:  $((TRADER_NO / 1000000)) tokens"
}

function check_status() {
    echo -e "${YELLOW}Checking market status...${NC}"
    
    PHASE=$(~/.foundry/bin/cast call $MARKET_ADDRESS "currentPhase()" --rpc-url $RPC_URL)
    TOTAL_LP=$(~/.foundry/bin/cast call $MARKET_ADDRESS "totalLPContributions()" --rpc-url $RPC_URL)
    
    case $PHASE in
        0) PHASE_NAME="SEEDING" ;;
        1) PHASE_NAME="VOTING" ;;
        2) PHASE_NAME="TRADING" ;;
        3) PHASE_NAME="ENDED" ;;
        *) PHASE_NAME="UNKNOWN" ;;
    esac
    
    echo "Current Phase: $PHASE_NAME ($PHASE)"
    echo "Total LP Contributions: $((TOTAL_LP / 1000000)) USDC"
    
    if [ "$PHASE" -ge 2 ]; then
        CRITERIA=$(~/.foundry/bin/cast call $MARKET_ADDRESS "resolutionCriteria()" --rpc-url $RPC_URL)
        echo "Resolution Criteria: $CRITERIA"
        
        # Get prices
        PRICES=$(~/.foundry/bin/cast call $MARKET_ADDRESS "getTokenPrices()" --rpc-url $RPC_URL)
        echo "Current Prices: $PRICES"
    fi
}

function run_full_test() {
    echo -e "${BLUE}Running complete market lifecycle test...${NC}"
    echo ""
    
    setup_accounts
    echo ""
    
    seed_liquidity
    echo ""
    
    run_voting
    echo ""
    
    run_trading
    echo ""
    
    check_balances
    echo ""
    
    check_status
    echo ""
    
    echo -e "${GREEN}✓ Complete market lifecycle test finished!${NC}"
}

# Check if contract addresses are set
if [ -z "$USDC_ADDRESS" ] || [ -z "$FACTORY_ADDRESS" ] || [ -z "$MARKET_ADDRESS" ]; then
    echo -e "${RED}Error: Contract addresses not set!${NC}"
    echo "Please update the script with deployed contract addresses."
    echo ""
    echo "You can get them from the deployment output or by running:"
    echo "cast call <factory_address> 'getMarket(uint256)' 0 --rpc-url http://localhost:8545"
    echo ""
    exit 1
fi

# Process commands
case ${1:-""} in
    "setup")
        setup_accounts
        ;;
    "seed")
        seed_liquidity
        ;;
    "vote")
        run_voting
        ;;
    "trade")
        run_trading
        ;;
    "full")
        run_full_test
        ;;
    "balances")
        check_balances
        ;;
    "status")
        check_status
        ;;
    "")
        print_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        print_usage
        exit 1
        ;;
esac 