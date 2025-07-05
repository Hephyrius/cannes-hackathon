// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/StagedPredictionMarket.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000e6);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract StagedPredictionMarketTest is Test {
    StagedPredictionMarket public market;
    MockUSDC public usdc;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    
    function setUp() public {
        usdc = new MockUSDC();
        
        market = new StagedPredictionMarket(
            address(usdc),
            "Will Bitcoin reach $100k by 2024?",
            block.timestamp + 30 days
        );
        
        market.transferOwnership(owner);
        
        usdc.mint(alice, 50000e6);
        usdc.mint(bob, 30000e6);
        usdc.mint(charlie, 20000e6);
        usdc.mint(owner, 100000e6);
    }
    
    function testConstructor() public view {
        assertEq(market.question(), "Will Bitcoin reach $100k by 2024?");
        assertEq(market.deadline(), block.timestamp + 30 days);
        assertEq(market.owner(), owner);
        assertEq(uint256(market.currentStage()), uint256(StagedPredictionMarket.Stage.CREATION));
    }
    
    function testAdvanceToTrading() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        assertEq(uint256(market.currentStage()), uint256(StagedPredictionMarket.Stage.TRADING));
    }
    
    function testAdvanceToTradingOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        market.advanceToTrading();
    }
    
    function testAdvanceToTradingWrongStage() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.expectRevert("Invalid stage transition");
        market.advanceToTrading();
    }
    
    function testAdvanceToResolution() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.prank(owner);
        market.advanceToResolution();
        
        assertEq(uint256(market.currentStage()), uint256(StagedPredictionMarket.Stage.RESOLUTION));
    }
    
    function testAdvanceToResolutionOnlyOwner() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        market.advanceToResolution();
    }
    
    function testAdvanceToResolutionWrongStage() public {
        vm.prank(owner);
        vm.expectRevert("Invalid stage transition");
        market.advanceToResolution();
    }
    
    function testAdvanceToClosed() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.prank(owner);
        market.advanceToResolution();
        
        vm.prank(owner);
        market.advanceToClosed();
        
        assertEq(uint256(market.currentStage()), uint256(StagedPredictionMarket.Stage.CLOSED));
    }
    
    function testAdvanceToClosedOnlyOwner() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.prank(owner);
        market.advanceToResolution();
        
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        market.advanceToClosed();
    }
    
    function testAdvanceToClosedWrongStage() public {
        vm.prank(owner);
        vm.expectRevert("Invalid stage transition");
        market.advanceToClosed();
    }
    
    function testBuyYesTokens() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        uint256 tokensReceived = market.buyYesTokens(1000e6);
        vm.stopPrank();
        
        assertGt(tokensReceived, 0);
        assertEq(market.yesToken().balanceOf(alice), tokensReceived);
    }
    
    function testBuyYesTokensWrongStage() public {
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        vm.expectRevert("Market not in trading stage");
        market.buyYesTokens(1000e6);
        vm.stopPrank();
    }
    
    function testBuyNoTokens() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        uint256 tokensReceived = market.buyNoTokens(1000e6);
        vm.stopPrank();
        
        assertGt(tokensReceived, 0);
        assertEq(market.noToken().balanceOf(alice), tokensReceived);
    }
    
    function testBuyNoTokensWrongStage() public {
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        vm.expectRevert("Market not in trading stage");
        market.buyNoTokens(1000e6);
        vm.stopPrank();
    }
    
    function testSellYesTokens() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        uint256 tokensReceived = market.buyYesTokens(1000e6);
        
        market.yesToken().approve(address(market), tokensReceived);
        uint256 usdcReceived = market.sellYesTokens(tokensReceived);
        vm.stopPrank();
        
        assertGt(usdcReceived, 0);
    }
    
    function testSellNoTokens() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        uint256 tokensReceived = market.buyNoTokens(1000e6);
        
        market.noToken().approve(address(market), tokensReceived);
        uint256 usdcReceived = market.sellNoTokens(tokensReceived);
        vm.stopPrank();
        
        assertGt(usdcReceived, 0);
    }
    
    function testResolveMarket() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.prank(owner);
        market.advanceToResolution();
        
        vm.prank(owner);
        market.resolveMarket(StagedPredictionMarket.Outcome.YES);
        
        assertEq(uint256(market.outcome()), uint256(StagedPredictionMarket.Outcome.YES));
        assertTrue(market.isResolved());
    }
    
    function testResolveMarketOnlyOwner() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.prank(owner);
        market.advanceToResolution();
        
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        market.resolveMarket(StagedPredictionMarket.Outcome.YES);
    }
    
    function testResolveMarketWrongStage() public {
        vm.prank(owner);
        vm.expectRevert("Market not in resolution stage");
        market.resolveMarket(StagedPredictionMarket.Outcome.YES);
    }
    
    function testResolveMarketAlreadyResolved() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.prank(owner);
        market.advanceToResolution();
        
        vm.prank(owner);
        market.resolveMarket(StagedPredictionMarket.Outcome.YES);
        
        vm.expectRevert("Market already resolved");
        market.resolveMarket(StagedPredictionMarket.Outcome.NO);
    }
    
    function testRedeemWinningTokens() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        uint256 yesTokens = market.buyYesTokens(1000e6);
        vm.stopPrank();
        
        vm.prank(owner);
        market.advanceToResolution();
        
        vm.prank(owner);
        market.resolveMarket(StagedPredictionMarket.Outcome.YES);
        
        vm.startPrank(alice);
        market.yesToken().approve(address(market), yesTokens);
        uint256 usdcReceived = market.redeemWinningTokens(yesTokens);
        vm.stopPrank();
        
        assertGt(usdcReceived, 0);
    }
    
    function testRedeemWinningTokensWrongStage() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        uint256 yesTokens = market.buyYesTokens(1000e6);
        vm.stopPrank();
        
        vm.startPrank(alice);
        market.yesToken().approve(address(market), yesTokens);
        vm.expectRevert("Market not resolved");
        market.redeemWinningTokens(yesTokens);
        vm.stopPrank();
    }
    
    function testRedeemLosingTokens() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        uint256 noTokens = market.buyNoTokens(1000e6);
        vm.stopPrank();
        
        vm.prank(owner);
        market.advanceToResolution();
        
        vm.prank(owner);
        market.resolveMarket(StagedPredictionMarket.Outcome.YES);
        
        vm.startPrank(alice);
        market.noToken().approve(address(market), noTokens);
        vm.expectRevert("Cannot redeem losing tokens");
        market.redeemWinningTokens(noTokens);
        vm.stopPrank();
    }
    
    function testGetMarketInfo() public {
        (
            string memory question,
            uint256 deadline,
            StagedPredictionMarket.Stage stage,
            StagedPredictionMarket.Outcome outcome,
            bool resolved
        ) = market.getMarketInfo();
        
        assertEq(question, "Will Bitcoin reach $100k by 2024?");
        assertEq(deadline, block.timestamp + 30 days);
        assertEq(uint256(stage), uint256(StagedPredictionMarket.Stage.CREATION));
        assertEq(uint256(outcome), uint256(StagedPredictionMarket.Outcome.NONE));
        assertFalse(resolved);
    }
    
    function testGetTokenPrices() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        market.buyYesTokens(1000e6);
        vm.stopPrank();
        
        (uint256 yesPrice, uint256 noPrice) = market.getTokenPrices();
        
        assertGt(yesPrice, 0);
        assertGt(noPrice, 0);
    }
    
    function testGetTokenPricesWrongStage() public {
        vm.expectRevert("Market not in trading stage");
        market.getTokenPrices();
    }
    
    function testFuzzBuyTokens(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 10000e6);
        
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), amount);
        uint256 tokensReceived = market.buyYesTokens(amount);
        vm.stopPrank();
        
        assertGt(tokensReceived, 0);
    }
    
    function testFuzzSellTokens(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000e6);
        
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 2000e6);
        uint256 tokensReceived = market.buyYesTokens(2000e6);
        
        market.yesToken().approve(address(market), tokensReceived);
        uint256 usdcReceived = market.sellYesTokens(amount);
        vm.stopPrank();
        
        assertGt(usdcReceived, 0);
    }
    
    function testInvariantStageProgression() public {
        assertEq(uint256(market.currentStage()), uint256(StagedPredictionMarket.Stage.CREATION));
        
        vm.prank(owner);
        market.advanceToTrading();
        assertEq(uint256(market.currentStage()), uint256(StagedPredictionMarket.Stage.TRADING));
        
        vm.prank(owner);
        market.advanceToResolution();
        assertEq(uint256(market.currentStage()), uint256(StagedPredictionMarket.Stage.RESOLUTION));
        
        vm.prank(owner);
        market.advanceToClosed();
        assertEq(uint256(market.currentStage()), uint256(StagedPredictionMarket.Stage.CLOSED));
    }
    
    function testEventEmission() public {
        vm.expectEmit(true, true, false, true);
        emit StagedPredictionMarket.StageAdvanced(StagedPredictionMarket.Stage.TRADING);
        
        vm.prank(owner);
        market.advanceToTrading();
    }
    
    function testResolveEventEmission() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.prank(owner);
        market.advanceToResolution();
        
        vm.expectEmit(true, true, false, true);
        emit StagedPredictionMarket.MarketResolved(StagedPredictionMarket.Outcome.YES);
        
        vm.prank(owner);
        market.resolveMarket(StagedPredictionMarket.Outcome.YES);
    }
    
    function testBuyTokensEventEmission() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.expectEmit(true, true, false, true);
        emit StagedPredictionMarket.TokensBought(alice, StagedPredictionMarket.Outcome.YES, 1000e6, 0);
        
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        market.buyYesTokens(1000e6);
        vm.stopPrank();
    }
    
    function testSellTokensEventEmission() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        uint256 tokensReceived = market.buyYesTokens(1000e6);
        
        market.yesToken().approve(address(market), tokensReceived);
        
        vm.expectEmit(true, true, false, true);
        emit StagedPredictionMarket.TokensSold(alice, StagedPredictionMarket.Outcome.YES, tokensReceived, 0);
        
        market.sellYesTokens(tokensReceived);
        vm.stopPrank();
    }
    
    function testRedeemEventEmission() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        uint256 yesTokens = market.buyYesTokens(1000e6);
        vm.stopPrank();
        
        vm.prank(owner);
        market.advanceToResolution();
        
        vm.prank(owner);
        market.resolveMarket(StagedPredictionMarket.Outcome.YES);
        
        vm.startPrank(alice);
        market.yesToken().approve(address(market), yesTokens);
        
        vm.expectEmit(true, true, false, true);
        emit StagedPredictionMarket.TokensRedeemed(alice, StagedPredictionMarket.Outcome.YES, yesTokens, 0);
        
        market.redeemWinningTokens(yesTokens);
        vm.stopPrank();
    }
    
    function testMultipleUsersTrading() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 1000e6);
        uint256 aliceYesTokens = market.buyYesTokens(1000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.approve(address(market), 1000e6);
        uint256 bobNoTokens = market.buyNoTokens(1000e6);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        usdc.approve(address(market), 1000e6);
        uint256 charlieYesTokens = market.buyYesTokens(1000e6);
        vm.stopPrank();
        
        assertGt(aliceYesTokens, 0);
        assertGt(bobNoTokens, 0);
        assertGt(charlieYesTokens, 0);
        
        assertEq(market.yesToken().balanceOf(alice), aliceYesTokens);
        assertEq(market.noToken().balanceOf(bob), bobNoTokens);
        assertEq(market.yesToken().balanceOf(charlie), charlieYesTokens);
    }
    
    function testPriceImpact() public {
        vm.prank(owner);
        market.advanceToTrading();
        
        vm.startPrank(alice);
        usdc.approve(address(market), 10000e6);
        
        uint256 firstBuy = market.buyYesTokens(1000e6);
        uint256 secondBuy = market.buyYesTokens(1000e6);
        uint256 thirdBuy = market.buyYesTokens(1000e6);
        vm.stopPrank();
        
        // Price should increase with each buy
        assertGt(firstBuy, secondBuy);
        assertGt(secondBuy, thirdBuy);
    }
} 