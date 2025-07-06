// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/SimplePredictionMarket.sol";
import "../src/SimpleMarketFactory.sol";

contract FlowTestnetDeployScript is Script {
    // Flow USDF address (18 decimals)
    address constant FLOW_USDF = 0xd7d43ab7b365f0d0789aE83F4385fA710FfdC98F;
    
    function run() external {
        vm.startBroadcast();
        
        console.log("=== DEPLOYING TO FLOW TESTNET ===");
        console.log("Deployer:", msg.sender);
        console.log("Balance:", msg.sender.balance / 1e18, "FLOW");
        console.log("USDF Address:", FLOW_USDF);
        console.log("");
        
        // Deploy Factory
        console.log("Deploying Market Factory...");
        SimpleMarketFactory factory = new SimpleMarketFactory(FLOW_USDF);
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
        console.log("Minimum seed amount: 0.000001 USDF (18 decimals)");
        console.log("Minimum trade amount: 0.000001 USDF (18 decimals)");
        console.log("");
        
        vm.stopBroadcast();
        
        console.log("=== FLOW TESTNET DEPLOYMENT SUMMARY ===");
        console.log("Network:       Flow Testnet");
        console.log("USDF:          ", FLOW_USDF);
        console.log("Factory:       ", address(factory));
        console.log("Demo Market:   ", market);
        console.log("YES Token:     ", address(marketContract.yesToken()));
        console.log("NO Token:      ", address(marketContract.noToken()));
        console.log("");
        console.log("Ready for hackathon demo! 🚀");
        console.log("");
        console.log("=== NEXT STEPS ===");
        console.log("1. Add Flow testnet to your wallet:");
        console.log("   - Network: Flow Testnet");
        console.log("   - RPC: https://testnet.evm.nodes.onflow.org");
        console.log("   - Chain ID: 545");
        console.log("2. Get testnet FLOW tokens from faucet");
        console.log("3. Get USDF tokens for testing");
        console.log("4. Interact with contracts using the addresses above");
    }
} 