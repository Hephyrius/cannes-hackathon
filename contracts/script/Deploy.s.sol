// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SimplePredictionMarket} from "../src/SimplePredictionMarket.sol";
import {SimpleMarketFactory} from "../src/SimpleMarketFactory.sol";

/**
 * @title Deploy Script for SimplePredictionMarket
 * @dev Deploys the complete prediction market system
 */
contract DeployScript is Script {
    // Deployment addresses (will be set during deployment)
    address public deployedUSDC;
    address public deployedFactory;
    address public deployedSampleMarket;
    
    // Sample market parameters
    string constant SAMPLE_QUESTION = "Will ETH reach $5000 by end of 2024?";
    
    function run() external {
        // Start broadcasting transactions
        vm.startBroadcast();
        
        console.log("=== DEPLOYING SIMPLE PREDICTION MARKET SYSTEM ===");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);
        console.log("");
        
        // 1. Deploy Mock USDC (for testing)
        console.log("1. Deploying Mock USDC...");
        MockUSDC usdc = new MockUSDC();
        deployedUSDC = address(usdc);
        console.log("   Mock USDC deployed at:", deployedUSDC);
        console.log("   Initial supply:", usdc.totalSupply() / 1e6, "USDC");
        console.log("");
        
        // 2. Deploy Factory
        console.log("2. Deploying SimpleMarketFactory...");
        SimpleMarketFactory factory = new SimpleMarketFactory(deployedUSDC);
        deployedFactory = address(factory);
        console.log("   Factory deployed at:", deployedFactory);
        console.log("   USDC token:", factory.usdc());
        console.log("");
        
        // 3. Create Sample Market
        console.log("3. Creating sample market...");
        address sampleMarket = factory.createMarket(SAMPLE_QUESTION);
        deployedSampleMarket = sampleMarket;
        console.log("   Sample market created at:", deployedSampleMarket);
        console.log("   Question:", SAMPLE_QUESTION);
        console.log("   Market count:", factory.getMarketCount());
        console.log("");
        
        // 4. Verify Deployment
        console.log("4. Verifying deployment...");
        _verifyDeployment(factory, SimplePredictionMarket(sampleMarket));
        
        vm.stopBroadcast();
        
        // 5. Print Summary
        _printDeploymentSummary();
        
        // 6. Print Usage Instructions
        _printUsageInstructions();
    }
    
    /**
     * @dev Verify that all contracts are deployed correctly
     */
    function _verifyDeployment(
        SimpleMarketFactory factory,
        SimplePredictionMarket market
    ) internal view {
        // Verify factory
        require(address(factory.usdc()) == deployedUSDC, "Factory USDC mismatch");
        require(factory.getMarketCount() == 1, "Factory market count mismatch");
        require(factory.isValidMarket(deployedSampleMarket), "Sample market not valid");
        
        // Verify market
        require(
            keccak256(abi.encodePacked(market.question())) == 
            keccak256(abi.encodePacked(SAMPLE_QUESTION)), 
            "Market question mismatch"
        );
        require(
            uint256(market.currentPhase()) == uint256(SimplePredictionMarket.Phase.SEEDING), 
            "Market not in seeding phase"
        );
        require(market.totalLPContributions() == 0, "Market should have no contributions");
        
        // Verify tokens exist
        require(address(market.yesToken()) != address(0), "YES token not deployed");
        require(address(market.noToken()) != address(0), "NO token not deployed");
        
        console.log("   All contracts verified successfully!");
        console.log("   Factory functionality working");
        console.log("   Sample market in correct state");
        console.log("   YES/NO tokens deployed");
    }
    
    /**
     * @dev Print deployment summary
     */
    function _printDeploymentSummary() internal view {
        console.log("");
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("Mock USDC:           ", deployedUSDC);
        console.log("Market Factory:      ", deployedFactory);
        console.log("Sample Market:       ", deployedSampleMarket);
        console.log("YES Token:           ", address(SimplePredictionMarket(deployedSampleMarket).yesToken()));
        console.log("NO Token:            ", address(SimplePredictionMarket(deployedSampleMarket).noToken()));
        console.log("Market Question:     ", SAMPLE_QUESTION);
        console.log("Current Phase:       SEEDING");
        console.log("");
    }
    
    /**
     * @dev Print usage instructions
     */
    function _printUsageInstructions() internal view {
        console.log("=== USAGE INSTRUCTIONS ===");
        console.log("");
        console.log("PHASE 1: SEEDING (2 hours)");
        console.log("   - LPs call seedLiquidity(amount) with USDC");
        console.log("   - Equal YES/NO tokens minted to market");
        console.log("   - Contributions tracked for voting weights");
        console.log("");
        console.log("PHASE 2: VOTING (1 hour)");
        console.log("   - Anyone can call startVoting() after 2 hours");
        console.log("   - LPs call proposeCriteria(string) to suggest resolution criteria");
        console.log("   - LPs call voteOnCriteria(string) to vote (weighted by contribution)");
        console.log("");
        console.log("PHASE 3: TRADING");
        console.log("   - Anyone can call startTrading() after voting ends");
        console.log("   - Users call buyYes(usdcAmount) or buyNo(usdcAmount) to trade");
        console.log("   - AMM uses constant product formula for pricing");
        console.log("");
        console.log("DEMO READY!");
        console.log("   Factory Address:  ", deployedFactory);
        console.log("   Sample Market:    ", deployedSampleMarket);
        console.log("   Mock USDC:        ", deployedUSDC);
        console.log("");
    }
}

/**
 * @title MockUSDC
 * @dev Mock USDC token for testing
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        // Mint 1M USDC to deployer
        _mint(msg.sender, 1_000_000 * 1e6);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    // Faucet function for testing
    function faucet(address to, uint256 amount) external {
        _mint(to, amount);
    }
} 