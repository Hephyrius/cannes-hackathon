// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/SimplePredictionMarket.sol";
import "../src/SimpleMarketFactory.sol";

contract BaseDeployScript is Script {
    // Base USDC address (6 decimals)
    address constant BASE_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    
    function run() external {
        vm.startBroadcast();
        
        console.log("=== DEPLOYING TO BASE NETWORK ===");
        console.log("Deployer:", msg.sender);
        console.log("Balance:", msg.sender.balance / 1e18, "ETH");
        console.log("USDC Address:", BASE_USDC);
        console.log("");
        
        // Deploy Factory
        console.log("Deploying Market Factory...");
        SimpleMarketFactory factory = new SimpleMarketFactory(BASE_USDC);
        console.log("Factory deployed at:", address(factory));
        console.log("");
        
        // Create sample market for hackathon demo
        console.log("Creating hackathon demo market...");
        address market = factory.createMarket("Will Bitcoin reach $100,000 by end of 2024?");
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
        console.log("Seeding duration: 2 hours");
        console.log("Voting duration: 1 hour");
        console.log("Minimum seed amount: 0.000001 USDC (1 wei)");
        console.log("Minimum trade amount: 0.000001 USDC (1 wei)");
        console.log("");
        
        vm.stopBroadcast();
        
        console.log("=== BASE DEPLOYMENT SUMMARY ===");
        console.log("Network:       Base");
        console.log("USDC:          ", BASE_USDC);
        console.log("Factory:       ", address(factory));
        console.log("Demo Market:   ", market);
        console.log("YES Token:     ", address(marketContract.yesToken()));
        console.log("NO Token:      ", address(marketContract.noToken()));
        console.log("");
        console.log("Ready for hackathon demo! 🚀");
        console.log("");
        console.log("=== NEXT STEPS ===");
        console.log("1. Add Base network to your wallet:");
        console.log("   - Network: Base");
        console.log("   - RPC: https://mainnet.base.org");
        console.log("   - Chain ID: 8453");
        console.log("2. Get Base ETH for gas fees");
        console.log("3. Get USDC on Base from bridge or exchange");
        console.log("4. Interact with contracts using the addresses above");
    }
} 