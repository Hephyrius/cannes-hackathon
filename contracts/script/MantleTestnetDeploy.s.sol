// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/SimplePredictionMarket.sol";
import "../src/SimpleMarketFactory.sol";
import "../src/TestUSDC.sol";

contract MantleTestnetDeployScript is Script {
    function run() external {
        vm.startBroadcast();
        
        console.log("=== DEPLOYING TO MANTLE TESTNET ===");
        console.log("Deployer:", msg.sender);
        console.log("Balance:", msg.sender.balance / 1e18, "MNT");
        console.log("");
        
        // Deploy Test USDC first
        console.log("Deploying Test USDC (18 decimals)...");
        TestUSDC testUsdc = new TestUSDC();
        console.log("Test USDC deployed at:", address(testUsdc));
        console.log("Total supply:", testUsdc.totalSupply() / 1e18, "Test USDC");
        console.log("Decimals:", testUsdc.decimals());
        console.log("");
        
        // Deploy Factory
        console.log("Deploying Market Factory...");
        SimpleMarketFactory factory = new SimpleMarketFactory(address(testUsdc));
        console.log("Factory deployed at:", address(factory));
        console.log("");
        
        // Create sample market for hackathon demo
        console.log("Creating hackathon demo market...");
        address market = factory.createMarket("Will Mantle reach $5 by end of 2024?");
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
        console.log("Minimum seed amount: 0.000001 Test USDC");
        console.log("Minimum trade amount: 0.000001 Test USDC");
        console.log("");
        
        // Mint test tokens to deployer for distribution
        console.log("Minting additional test tokens...");
        testUsdc.ownerMint(msg.sender, 1_000_000 * 10**18); // 1M additional tokens
        console.log("Additional tokens minted for distribution");
        console.log("");
        
        vm.stopBroadcast();
        
        console.log("=== MANTLE TESTNET DEPLOYMENT SUMMARY ===");
        console.log("Network:       Mantle Testnet");
        console.log("Test USDC:     ", address(testUsdc));
        console.log("Factory:       ", address(factory));
        console.log("Demo Market:   ", market);
        console.log("YES Token:     ", address(marketContract.yesToken()));
        console.log("NO Token:      ", address(marketContract.noToken()));
        console.log("");
        console.log("Ready for hackathon demo! 🚀");
        console.log("");
        console.log("=== NEXT STEPS ===");
        console.log("1. Add Mantle testnet to your wallet:");
        console.log("   - Network: Mantle Testnet");
        console.log("   - RPC: https://rpc.testnet.mantle.xyz");
        console.log("   - Chain ID: 5001");
        console.log("2. Get testnet MNT from faucet");
        console.log("3. Use faucet() function to get test USDC:");
        console.log("   - Contract:", address(testUsdc));
        console.log("   - Function: faucet() gives 1000 test USDC");
        console.log("4. Start testing with demo market");
    }
} 