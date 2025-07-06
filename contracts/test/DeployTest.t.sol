// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SimplePredictionMarket} from "../src/SimplePredictionMarket.sol";
import {SimpleMarketFactory} from "../src/SimpleMarketFactory.sol";

contract DeployTest is Test {
    SimpleMarketFactory factory;
    SimplePredictionMarket market;
    MockUSDC usdc;
    
    address deployer = makeAddr("deployer");
    address lp1 = makeAddr("lp1");
    address lp2 = makeAddr("lp2");
    address trader = makeAddr("trader");
    
    function setUp() public {
        vm.startPrank(deployer);
        
        // Deploy Mock USDC
        usdc = new MockUSDC();
        console.log("Mock USDC deployed at:", address(usdc));
        
        // Deploy Factory
        factory = new SimpleMarketFactory(address(usdc));
        console.log("Factory deployed at:", address(factory));
        
        // Create market
        address marketAddress = factory.createMarket("Will ETH reach $5000 by end of 2024?");
        market = SimplePredictionMarket(marketAddress);
        console.log("Market deployed at:", address(market));
        
        vm.stopPrank();
        
        // Setup users with USDC
        usdc.mint(lp1, 10000 * 1e6);
        usdc.mint(lp2, 10000 * 1e6);
        usdc.mint(trader, 10000 * 1e6);
        
        // Approve spending
        vm.prank(lp1);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(lp2);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(trader);
        usdc.approve(address(market), type(uint256).max);
    }
    
    function test_DeploymentSuccess() public {
        // Verify factory deployment
        assertEq(address(factory.usdc()), address(usdc));
        assertEq(factory.getMarketCount(), 1);
        assertTrue(factory.isValidMarket(address(market)));
        
        // Verify market deployment
        assertEq(market.question(), "Will ETH reach $5000 by end of 2024?");
        assertEq(uint256(market.currentPhase()), uint256(SimplePredictionMarket.Phase.SEEDING));
        assertEq(market.totalLPContributions(), 0);
        
        // Verify tokens
        assertTrue(address(market.yesToken()) != address(0));
        assertTrue(address(market.noToken()) != address(0));
        
        console.log("All deployment verifications passed");
    }
    
    function test_CompleteWorkflow() public {
        console.log("=== TESTING COMPLETE PREDICTION MARKET WORKFLOW ===");
        
        // PHASE 1: SEEDING
        console.log("\n1. SEEDING PHASE");
        vm.prank(lp1);
        market.seedLiquidity(1000 * 1e6);
        console.log("   LP1 seeded 1000 USDC");
        
        vm.prank(lp2);
        market.seedLiquidity(500 * 1e6);
        console.log("   LP2 seeded 500 USDC");
        
        assertEq(market.totalLPContributions(), 1500 * 1e6);
        console.log("   Total seeded: 1500 USDC");
        
        // PHASE 2: VOTING
        console.log("\n2. VOTING PHASE");
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        console.log("   Voting started");
        
        vm.prank(lp1);
        market.proposeCriteria("CoinGecko price on Dec 31, 2024 at 11:59 PM UTC");
        console.log("   LP1 proposed CoinGecko criteria");
        
        vm.prank(lp2);
        market.proposeCriteria("Binance price on Dec 31, 2024 at market close");
        console.log("   LP2 proposed Binance criteria");
        
        vm.prank(lp1);
        market.voteOnCriteria("CoinGecko price on Dec 31, 2024 at 11:59 PM UTC");
        console.log("   LP1 voted for CoinGecko (1000 USDC weight)");
        
        vm.prank(lp2);
        market.voteOnCriteria("Binance price on Dec 31, 2024 at market close");
        console.log("   LP2 voted for Binance (500 USDC weight)");
        
        assertEq(market.getCriteriaVotes("CoinGecko price on Dec 31, 2024 at 11:59 PM UTC"), 1000 * 1e6);
        assertEq(market.getCriteriaVotes("Binance price on Dec 31, 2024 at market close"), 500 * 1e6);
        
        // PHASE 3: TRADING
        console.log("\n3. TRADING PHASE");
        vm.warp(block.timestamp + 1 hours + 1);
        market.startTrading();
        console.log("   Trading started");
        
        assertEq(market.resolutionCriteria(), "CoinGecko price on Dec 31, 2024 at 11:59 PM UTC");
        console.log("   Winning criteria: CoinGecko price on Dec 31, 2024 at 11:59 PM UTC");
        
        // Test trading
        uint256 initialYesBalance = market.yesToken().balanceOf(trader);
        
        vm.prank(trader);
        market.buyYes(100 * 1e6);
        console.log("   Trader bought YES tokens with 100 USDC");
        
        uint256 finalYesBalance = market.yesToken().balanceOf(trader);
        assertGt(finalYesBalance, initialYesBalance);
        console.log("   YES token balance increased");
        
        // Check price impact
        (uint256 yesPrice, uint256 noPrice) = market.getTokenPrices();
        console.log("   YES price:", yesPrice);
        console.log("   NO price:", noPrice);
        
        console.log("Complete workflow test passed!");
    }
    
    function test_MultipleMarkets() public {
        console.log("=== TESTING MULTIPLE MARKET CREATION ===");
        
        // Create additional markets
        vm.startPrank(deployer);
        
        address market2 = factory.createMarket("Will Bitcoin reach $100k by end of 2024?");
        console.log("Market 2 created:", market2);
        
        address market3 = factory.createMarket("Will SOL reach $500 by end of 2024?");
        console.log("Market 3 created:", market3);
        
        vm.stopPrank();
        
        // Verify factory state
        assertEq(factory.getMarketCount(), 3);
        assertTrue(factory.isValidMarket(market2));
        assertTrue(factory.isValidMarket(market3));
        
        address[] memory allMarkets = factory.getAllMarkets();
        assertEq(allMarkets.length, 3);
        assertEq(allMarkets[0], address(market));
        assertEq(allMarkets[1], market2);
        assertEq(allMarkets[2], market3);
        
        console.log("Multiple markets test passed!");
    }
    
    function test_GasOptimization() public {
        console.log("=== TESTING GAS USAGE ===");
        
        uint256 gasBefore = gasleft();
        
        // Test market creation gas
        vm.prank(deployer);
        address newMarket = factory.createMarket("Gas test market");
        uint256 marketCreationGas = gasBefore - gasleft();
        console.log("Market creation gas:", marketCreationGas);
        
        // Approve USDC spending for the new market
        vm.prank(lp1);
        usdc.approve(newMarket, type(uint256).max);
        
        // Test seeding gas
        gasBefore = gasleft();
        vm.prank(lp1);
        SimplePredictionMarket(newMarket).seedLiquidity(1000 * 1e6);
        uint256 seedingGas = gasBefore - gasleft();
        console.log("Seeding gas:", seedingGas);
        
        // All operations should be under reasonable gas limits
        assertLt(marketCreationGas, 3_000_000); // < 3M gas
        assertLt(seedingGas, 300_000); // < 300k gas
        
        console.log("Gas optimization test passed!");
    }
}

contract MockUSDC {
    string public name = "Mock USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    uint256 public totalSupply = 1_000_000 * 1e6;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor() {
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
} 