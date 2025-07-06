// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SimplePredictionMarket} from "../src/SimplePredictionMarket.sol";
import {SimpleMarketFactory} from "../src/SimpleMarketFactory.sol";

contract SampleDeployScript is Script {
    address public factory;
    address public sampleMarket;
    address public usdc;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Chain:", block.chainid);
        
        // For testing, use a mock USDC address
        // In production, use real USDC: 0xA0b86a33E6441B8dB90D05AE3E8C6B174Ca8c8E
        usdc = address(0x1234567890123456789012345678901234567890); // Mock address
        
        // Deploy factory
        SimpleMarketFactory marketFactory = new SimpleMarketFactory(usdc);
        factory = address(marketFactory);
        console.log("Factory deployed at:", factory);
        
        // Create sample market
        sampleMarket = marketFactory.createMarket("Will ETH reach $5000 by end of 2024?");
        console.log("Sample market created at:", sampleMarket);
        
        vm.stopBroadcast();
        
        console.log("Deployment complete!");
        console.log("Factory:", factory);
        console.log("Sample Market:", sampleMarket);
    }
} 