#!/bin/bash

echo "🚀 PREDICTION MARKET QUICK DEPLOY 🚀"
echo "====================================="

# Check if we're in the right directory
if [ ! -f "foundry.toml" ]; then
    echo "❌ Error: Not in contracts directory. Please run from contracts/ folder"
    exit 1
fi

# Start Anvil if not running
echo "🔧 Starting Anvil..."
if ! pgrep -f anvil > /dev/null; then
    ~/.foundry/bin/anvil --host 0.0.0.0 --port 8545 > anvil.log 2>&1 &
    echo "✅ Anvil started in background"
    sleep 3
else
    echo "✅ Anvil already running"
fi

# Deploy contracts
echo "📦 Deploying contracts..."
~/.foundry/bin/forge script script/LocalDeploy.s.sol:LocalDeployScript \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    -vv > deploy.log 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Contracts deployed successfully!"
    echo ""
    echo "📋 DEPLOYMENT SUMMARY:"
    echo "====================="
    
    # Extract addresses from deployment log
    USDC_ADDR=$(grep "Mock USDC deployed at:" deploy.log | awk '{print $NF}')
    FACTORY_ADDR=$(grep "Factory deployed at:" deploy.log | awk '{print $NF}')
    MARKET_ADDR=$(grep "Sample market deployed at:" deploy.log | awk '{print $NF}')
    
    echo "🏦 Mock USDC:     $USDC_ADDR"
    echo "🏭 Factory:       $FACTORY_ADDR"
    echo "📊 Sample Market: $MARKET_ADDR"
    echo ""
    
    # Update test script
    echo "🔄 Updating test script..."
    sed -i "s/USDC_ADDRESS=\"\"/USDC_ADDRESS=\"$USDC_ADDR\"/" test_interactions.sh
    sed -i "s/FACTORY_ADDRESS=\"\"/FACTORY_ADDRESS=\"$FACTORY_ADDR\"/" test_interactions.sh
    sed -i "s/MARKET_ADDRESS=\"\"/MARKET_ADDRESS=\"$MARKET_ADDR\"/" test_interactions.sh
    
    echo "✅ Test script updated!"
    echo ""
    echo "🎯 NEXT STEPS:"
    echo "=============="
    echo "1. Run: chmod +x test_interactions.sh"
    echo "2. Run: ./test_interactions.sh full"
    echo ""
    echo "🌟 Ready to test your prediction market!"
    
else
    echo "❌ Deployment failed. Check deploy.log for details."
    cat deploy.log
    exit 1
fi 