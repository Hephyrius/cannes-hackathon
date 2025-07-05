// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SimplePredictionMarket} from "../src/SimplePredictionMarket.sol";
import {SimpleMarketFactory} from "../src/SimpleMarketFactory.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000 * 10**6);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract SimpleTest is Test {
    SimplePredictionMarket market;
    SimpleMarketFactory factory;
    MockUSDC usdc;
    
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    
    function setUp() public {
        usdc = new MockUSDC();
        factory = new SimpleMarketFactory(address(usdc));
        market = SimplePredictionMarket(factory.createMarket("Will ETH reach $5000?"));
        
        // Give users USDC and approve spending
        usdc.mint(user1, 10000 * 10**6);
        usdc.mint(user2, 10000 * 10**6);
        usdc.mint(user3, 10000 * 10**6);
        
        vm.prank(user1);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(user2);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(user3);
        usdc.approve(address(market), type(uint256).max);
    }
    
    function test_MarketCreation() public {
        assertEq(market.question(), "Will ETH reach $5000?");
        assertEq(uint256(market.currentPhase()), uint256(SimplePredictionMarket.Phase.SEEDING));
        assertEq(market.totalLPContributions(), 0);
    }
    
    function test_SeedingPhase() public {
        vm.prank(user1);
        market.seedLiquidity(1000 * 10**6);
        
        assertEq(market.lpContributions(user1), 1000 * 10**6);
        assertEq(market.totalLPContributions(), 1000 * 10**6);
        
        vm.prank(user2);
        market.seedLiquidity(500 * 10**6);
        
        assertEq(market.totalLPContributions(), 1500 * 10**6);
    }
    
    function test_VotingPhase() public {
        // Seed liquidity
        vm.prank(user1);
        market.seedLiquidity(1000 * 10**6);
        vm.prank(user2);
        market.seedLiquidity(500 * 10**6);
        
        // Fast forward to voting
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        
        assertEq(uint256(market.currentPhase()), uint256(SimplePredictionMarket.Phase.VOTING));
        
        // Propose and vote on criteria
        vm.prank(user1);
        market.proposeCriteria("CoinGecko price on Dec 31, 2024");
        
        vm.prank(user2);
        market.proposeCriteria("Binance price on Dec 31, 2024");
        
        vm.prank(user1);
        market.voteOnCriteria("CoinGecko price on Dec 31, 2024");
        
        vm.prank(user2);
        market.voteOnCriteria("Binance price on Dec 31, 2024");
        
        // Check votes
        assertEq(market.getCriteriaVotes("CoinGecko price on Dec 31, 2024"), 1000 * 10**6);
        assertEq(market.getCriteriaVotes("Binance price on Dec 31, 2024"), 500 * 10**6);
    }
    
    function test_TradingPhase() public {
        // Complete seeding and voting
        vm.prank(user1);
        market.seedLiquidity(1000 * 10**6);
        
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        
        vm.prank(user1);
        market.proposeCriteria("Test criteria");
        vm.prank(user1);
        market.voteOnCriteria("Test criteria");
        
        // Start trading
        vm.warp(block.timestamp + 1 hours + 1);
        market.startTrading();
        
        assertEq(uint256(market.currentPhase()), uint256(SimplePredictionMarket.Phase.TRADING));
        assertEq(market.resolutionCriteria(), "Test criteria");
        
        // Test trading
        uint256 initialYesBalance = market.yesToken().balanceOf(user3);
        
        vm.prank(user3);
        market.buyYes(100 * 10**6);
        
        assertGt(market.yesToken().balanceOf(user3), initialYesBalance);
        
        // Test NO token trading
        uint256 initialNoBalance = market.noToken().balanceOf(user3);
        
        vm.prank(user3);
        market.buyNo(100 * 10**6);
        
        assertGt(market.noToken().balanceOf(user3), initialNoBalance);
    }
    
    function test_TokenPrices() public {
        // Setup to trading phase
        vm.prank(user1);
        market.seedLiquidity(1000 * 10**6);
        
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        
        vm.prank(user1);
        market.proposeCriteria("Test criteria");
        vm.prank(user1);
        market.voteOnCriteria("Test criteria");
        
        vm.warp(block.timestamp + 1 hours + 1);
        market.startTrading();
        
        // Check initial prices
        (uint256 yesPrice, uint256 noPrice) = market.getTokenPrices();
        assertEq(yesPrice, noPrice);
        
        // Buy YES tokens and check price change
        vm.prank(user3);
        market.buyYes(100 * 10**6);
        
        (uint256 newYesPrice, uint256 newNoPrice) = market.getTokenPrices();
        assertGt(newYesPrice, yesPrice);
        assertLt(newNoPrice, noPrice);
    }
    
    function test_FactoryFunctionality() public {
        assertEq(factory.getMarketCount(), 1);
        assertEq(factory.getMarket(0), address(market));
        assertTrue(factory.isValidMarket(address(market)));
        
        address market2 = factory.createMarket("Will Bitcoin reach $100k?");
        assertEq(factory.getMarketCount(), 2);
        assertTrue(factory.isValidMarket(market2));
    }
    
    function test_SeedingErrors() public {
        vm.prank(user1);
        vm.expectRevert("Amount must be greater than 0");
        market.seedLiquidity(0);
        
        vm.prank(user2);
        usdc.approve(address(market), 0);
        vm.expectRevert();
        market.seedLiquidity(100 * 10**6);
        
        vm.prank(user1);
        market.seedLiquidity(1000 * 10**6);
        
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        
        vm.prank(user2);
        vm.expectRevert("Not in seeding phase");
        market.seedLiquidity(100 * 10**6);
    }
    
    function test_VotingErrors() public {
        vm.warp(block.timestamp + 2 hours + 1);
        vm.expectRevert("No liquidity seeded");
        market.startVoting();
        
        vm.prank(user1);
        market.seedLiquidity(1000 * 10**6);
        
        vm.expectRevert("Seeding period not ended");
        market.startVoting();
        
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        
        vm.prank(user3);
        vm.expectRevert("Not an LP");
        market.proposeCriteria("Invalid criteria");
        
        vm.prank(user1);
        vm.expectRevert("Criteria cannot be empty");
        market.proposeCriteria("");
        
        vm.prank(user1);
        market.proposeCriteria("First criteria");
        vm.prank(user1);
        vm.expectRevert("Already proposed");
        market.proposeCriteria("Second criteria");
        
        vm.prank(user3);
        vm.expectRevert("Not an LP");
        market.voteOnCriteria("First criteria");
        
        vm.prank(user1);
        market.voteOnCriteria("First criteria");
        vm.prank(user1);
        vm.expectRevert("Already voted");
        market.voteOnCriteria("First criteria");
    }
    
    function test_TradingErrors() public {
        vm.prank(user1);
        vm.expectRevert("Not in trading phase");
        market.buyYes(100 * 10**6);
        
        vm.prank(user1);
        market.seedLiquidity(1000 * 10**6);
        
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        
        vm.prank(user1);
        market.proposeCriteria("Test criteria");
        vm.prank(user1);
        market.voteOnCriteria("Test criteria");
        
        vm.warp(block.timestamp + 1 hours + 1);
        market.startTrading();
        
        vm.prank(user3);
        vm.expectRevert("Amount must be greater than 0");
        market.buyYes(0);
        
        vm.prank(user3);
        vm.expectRevert("Amount must be greater than 0");
        market.buyNo(0);
        
        vm.prank(user2);
        usdc.approve(address(market), 0);
        vm.expectRevert();
        market.buyYes(100 * 10**6);
    }
    
    function test_PhaseTransitionErrors() public {
        vm.prank(user1);
        market.seedLiquidity(1000 * 10**6);
        
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        
        vm.expectRevert("Voting period not ended");
        market.startTrading();
        
        vm.warp(block.timestamp + 1 hours + 1);
        vm.expectRevert("No criteria selected");
        market.startTrading();
    }
    
    function test_MultipleLP() public {
        vm.prank(user1);
        market.seedLiquidity(1000 * 10**6);
        
        vm.prank(user2);
        market.seedLiquidity(500 * 10**6);
        
        vm.prank(user3);
        market.seedLiquidity(300 * 10**6);
        
        assertEq(market.totalLPContributions(), 1800 * 10**6);
        
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        
        vm.prank(user1);
        market.proposeCriteria("Criteria A");
        vm.prank(user2);
        market.proposeCriteria("Criteria B");
        vm.prank(user3);
        market.proposeCriteria("Criteria C");
        
        vm.prank(user1);
        market.voteOnCriteria("Criteria A");
        vm.prank(user2);
        market.voteOnCriteria("Criteria B");
        vm.prank(user3);
        market.voteOnCriteria("Criteria A");
        
        assertEq(market.getCriteriaVotes("Criteria A"), 1300 * 10**6);
        assertEq(market.getCriteriaVotes("Criteria B"), 500 * 10**6);
        assertEq(market.getCriteriaVotes("Criteria C"), 0);
        
        vm.warp(block.timestamp + 1 hours + 1);
        market.startTrading();
        
        assertEq(market.resolutionCriteria(), "Criteria A");
    }
    
    function test_GetAmountOut() public {
        uint256 amountOut = market.getAmountOut(100 * 10**6, 1000 * 10**6, 1000 * 10**6);
        assertGt(amountOut, 0);
        assertLt(amountOut, 100 * 10**6);
        
        uint256 amountOut2 = market.getAmountOut(100 * 10**6, 2000 * 10**6, 1000 * 10**6);
        assertLt(amountOut2, amountOut);
        
        vm.expectRevert("Amount in must be greater than 0");
        market.getAmountOut(0, 1000 * 10**6, 1000 * 10**6);
        
        vm.expectRevert("Insufficient reserves");
        market.getAmountOut(100 * 10**6, 0, 1000 * 10**6);
        
        vm.expectRevert("Insufficient reserves");
        market.getAmountOut(100 * 10**6, 1000 * 10**6, 0);
    }
    
    function test_FactoryEdgeCases() public {
        vm.expectRevert("Question cannot be empty");
        factory.createMarket("");
        
        vm.expectRevert("Index out of bounds");
        factory.getMarket(999);
        
        assertFalse(factory.isValidMarket(address(0x999)));
        
        address[] memory allMarkets = factory.getAllMarkets();
        assertEq(allMarkets.length, 1);
        assertEq(allMarkets[0], address(market));
    }
} 