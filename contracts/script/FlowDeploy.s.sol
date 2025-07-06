// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/SimplePredictionMarket.sol";
import "../src/SimpleMarketFactory.sol";

contract FlowDeployScript is Script {
    // Flow USDC address (6 decimals)
    address constant FLOW_USDC = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
    
    function run() external {
        vm.startBroadcast();
        
        console.log("=== DEPLOYING TO FLOW NETWORK ===");
        console.log("Deployer:", msg.sender);
        console.log("Balance:", msg.sender.balance / 1e18, "FLOW");
        console.log("USDC Address:", FLOW_USDC);
        console.log("");
        
        // Deploy Factory
        console.log("Deploying Market Factory...");
        SimpleMarketFactory factory = new SimpleMarketFactory(FLOW_USDC);
        console.log("Factory deployed at:", address(factory));
        console.log("");
        
        // Create sample market for hackathon demo
        console.log("Creating hackathon demo market...");
        address market = factory.createMarket("Will Flow reach $10 by end of 2024?");
        console.log("Demo market deployed at:", market);
        console.log("Market count:", factory.getMarketCount());
        console.log("");
        
        // Get market details
        SimplePredictionMarket marketContract = SimplePredictionMarket(market);
        console.log("Market question:", marketContract.question());
        console.log("Current phase:", uint256(marketContract.currentPhase()));
        console.log("YES token:", address(marketContract.yesToken()));
        console.log("NO token:", address(marketContract.noToken()));
        console.log("");
        
        // Display timing info
        console.log("=== TIMING INFO ===");
        console.log("Seeding duration: 1 minute");
        console.log("Voting duration: 1 minute");
        console.log("Minimum seed amount: 0.000001 USDC (1 wei)");
        console.log("Minimum trade amount: 0.000001 USDC (1 wei)");
        console.log("");
        
        vm.stopBroadcast();
        
        console.log("=== FLOW DEPLOYMENT SUMMARY ===");
        console.log("Network:       Flow EVM");
        console.log("USDC:          ", FLOW_USDC);
        console.log("Factory:       ", address(factory));
        console.log("Demo Market:   ", market);
        console.log("YES Token:     ", address(marketContract.yesToken()));
        console.log("NO Token:      ", address(marketContract.noToken()));
        console.log("");
        console.log("Ready for hackathon demo! 🚀");
        console.log("");
        console.log("=== NEXT STEPS ===");
        console.log("1. Add Flow network to your wallet:");
        console.log("   - Network: Flow EVM");
        console.log("   - RPC: https://mainnet.evm.nodes.onflow.org");
        console.log("   - Chain ID: 747");
        console.log("2. Get FLOW tokens for gas fees");
        console.log("3. Get USDC on Flow from bridge or exchange");
        console.log("4. Interact with contracts using the addresses above");
    }
} 