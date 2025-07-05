// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/StagedPredictionMarket.sol";
import "../src/PredictionMarket.sol";
import "../src/PredictionMarketFactory.sol";
import "../src/PredictionMarketVoting.sol";
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
    StagedPredictionMarket public stagedMarket;
    PredictionMarket public market;
    PredictionMarketFactory public factory;
    PredictionMarketVoting public voting;
    MockUSDC public usdc;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    
    function setUp() public {
        usdc = new MockUSDC();
        factory = new PredictionMarketFactory();
        voting = new PredictionMarketVoting();
        
        stagedMarket = new StagedPredictionMarket(
            address(factory),
            address(voting),
            address(usdc)
        );
        
        market = new PredictionMarket(
            address(usdc),
            "Will Bitcoin reach $100k by 2024?",
            block.timestamp + 30 days
        );
        
        usdc.mint(alice, 50000e6);
        usdc.mint(bob, 30000e6);
        usdc.mint(charlie, 20000e6);
        usdc.mint(owner, 100000e6);
    }
    
    function testConstructor() public view {
        assertEq(address(stagedMarket.factory()), address(factory));
        assertEq(address(stagedMarket.voting()), address(voting));
        assertEq(address(stagedMarket.usdc()), address(usdc));
        assertEq(stagedMarket.SEEDING_DURATION(), 48 hours);
        assertEq(stagedMarket.VOTING_DURATION(), 24 hours);
        assertEq(stagedMarket.WITHDRAWAL_DURATION(), 12 hours);
    }
    
    function testInitializeMarket() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        (
            StagedPredictionMarket.Stage currentStage,
            uint256 stageStartTime,
            uint256 timeInCurrentStage
        ) = stagedMarket.getMarketStage(address(market));
        
        assertEq(uint256(currentStage), uint256(StagedPredictionMarket.Stage.SEEDING));
        assertGt(stageStartTime, 0);
        assertGt(timeInCurrentStage, 0);
    }
    
    function testInitializeMarketAlreadyInitialized() public {
        vm.startPrank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.expectRevert("Already initialized");
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        vm.stopPrank();
    }
    
    function testSeedLiquidity() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.startPrank(alice);
        market.yesToken().approve(address(stagedMarket), 1000e18);
        market.noToken().approve(address(stagedMarket), 1000e18);
        usdc.approve(address(stagedMarket), 200e6);
        
        stagedMarket.seedLiquidity(address(market), 1000e18, 1000e18);
        vm.stopPrank();
    }
    
    function testSeedLiquidityNotInitialized() public {
        vm.startPrank(alice);
        vm.expectRevert("Market not initialized");
        stagedMarket.seedLiquidity(address(market), 1000e18, 1000e18);
        vm.stopPrank();
    }
    
    function testSeedLiquidityWrongStage() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
        
        vm.startPrank(alice);
        vm.expectRevert("Invalid stage");
        stagedMarket.seedLiquidity(address(market), 1000e18, 1000e18);
        vm.stopPrank();
    }
    
    function testStartVoting() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
        
        (
            StagedPredictionMarket.Stage currentStage,
            , 
        ) = stagedMarket.getMarketStage(address(market));
        
        assertEq(uint256(currentStage), uint256(StagedPredictionMarket.Stage.VOTING));
    }
    
    function testStartVotingNotInitialized() public {
        vm.prank(owner);
        vm.expectRevert("Market not initialized");
        stagedMarket.startVoting(address(market));
    }
    
    function testStartVotingWrongStage() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.prank(owner);
        vm.expectRevert("Invalid stage");
        stagedMarket.startVoting(address(market));
    }
    
    function testStartVotingSeedingNotEnded() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.prank(owner);
        vm.expectRevert("Seeding period not ended");
        stagedMarket.startVoting(address(market));
    }
    
    function testStartWithdrawal() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startWithdrawal(address(market));
        
        (
            StagedPredictionMarket.Stage currentStage,
            , 
        ) = stagedMarket.getMarketStage(address(market));
        
        assertEq(uint256(currentStage), uint256(StagedPredictionMarket.Stage.WITHDRAWAL));
    }
    
    function testStartWithdrawalNotInitialized() public {
        vm.prank(owner);
        vm.expectRevert("Market not initialized");
        stagedMarket.startWithdrawal(address(market));
    }
    
    function testStartWithdrawalWrongStage() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.prank(owner);
        vm.expectRevert("Invalid stage");
        stagedMarket.startWithdrawal(address(market));
    }
    
    function testStartWithdrawalVotingNotEnded() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
        
        vm.prank(owner);
        vm.expectRevert("Voting period not ended");
        stagedMarket.startWithdrawal(address(market));
    }
    
    function testStartTrading() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startWithdrawal(address(market));
        
        vm.warp(block.timestamp + 12 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startTrading(address(market));
        
        (
            StagedPredictionMarket.Stage currentStage,
            , 
        ) = stagedMarket.getMarketStage(address(market));
        
        assertEq(uint256(currentStage), uint256(StagedPredictionMarket.Stage.TRADING));
    }
    
    function testStartTradingNotInitialized() public {
        vm.prank(owner);
        vm.expectRevert("Market not initialized");
        stagedMarket.startTrading(address(market));
    }
    
    function testStartTradingWrongStage() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.prank(owner);
        vm.expectRevert("Invalid stage");
        stagedMarket.startTrading(address(market));
    }
    
    function testStartTradingWithdrawalNotEnded() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startWithdrawal(address(market));
        
        vm.prank(owner);
        vm.expectRevert("Withdrawal period not ended");
        stagedMarket.startTrading(address(market));
    }
    
    function testResolveMarket() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startWithdrawal(address(market));
        
        vm.warp(block.timestamp + 12 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startTrading(address(market));
        
        vm.prank(owner);
        stagedMarket.resolveMarket(address(market), PredictionMarket.Outcome.YES);
        
        (
            StagedPredictionMarket.Stage currentStage,
            , 
        ) = stagedMarket.getMarketStage(address(market));
        
        assertEq(uint256(currentStage), uint256(StagedPredictionMarket.Stage.RESOLVED));
    }
    
    function testResolveMarketNotInitialized() public {
        vm.prank(owner);
        vm.expectRevert("Market not initialized");
        stagedMarket.resolveMarket(address(market), PredictionMarket.Outcome.YES);
    }
    
    function testResolveMarketWrongStage() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.prank(owner);
        vm.expectRevert("Invalid stage");
        stagedMarket.resolveMarket(address(market), PredictionMarket.Outcome.YES);
    }
    
    function testIsTradingAllowed() public {
        assertFalse(stagedMarket.isTradingAllowed(address(market)));
        
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        assertFalse(stagedMarket.isTradingAllowed(address(market)));
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
        
        assertFalse(stagedMarket.isTradingAllowed(address(market)));
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startWithdrawal(address(market));
        
        assertFalse(stagedMarket.isTradingAllowed(address(market)));
        
        vm.warp(block.timestamp + 12 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startTrading(address(market));
        
        assertTrue(stagedMarket.isTradingAllowed(address(market)));
    }
    
    function testGetMarketStage() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        (
            StagedPredictionMarket.Stage currentStage,
            uint256 stageStartTime,
            uint256 timeInCurrentStage
        ) = stagedMarket.getMarketStage(address(market));
        
        assertEq(uint256(currentStage), uint256(StagedPredictionMarket.Stage.SEEDING));
        assertGt(stageStartTime, 0);
        assertGt(timeInCurrentStage, 0);
    }
    
    function testGetTimeRemainingInStage() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        uint256 timeRemaining = stagedMarket.getTimeRemainingInStage(address(market));
        assertGt(timeRemaining, 0);
        assertLe(timeRemaining, 48 hours);
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        timeRemaining = stagedMarket.getTimeRemainingInStage(address(market));
        assertEq(timeRemaining, 0);
    }
    
    function testGetTimeRemainingInStageVoting() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
        
        uint256 timeRemaining = stagedMarket.getTimeRemainingInStage(address(market));
        assertGt(timeRemaining, 0);
        assertLe(timeRemaining, 24 hours);
    }
    
    function testGetTimeRemainingInStageWithdrawal() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startWithdrawal(address(market));
        
        uint256 timeRemaining = stagedMarket.getTimeRemainingInStage(address(market));
        assertGt(timeRemaining, 0);
        assertLe(timeRemaining, 12 hours);
    }
    
    function testGetTimeRemainingInStageTrading() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startWithdrawal(address(market));
        
        vm.warp(block.timestamp + 12 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startTrading(address(market));
        
        uint256 timeRemaining = stagedMarket.getTimeRemainingInStage(address(market));
        assertEq(timeRemaining, 0);
    }
    
    function testFuzzSeedLiquidity(uint256 yesAmount, uint256 noAmount) public {
        vm.assume(yesAmount > 0 && yesAmount <= 10000e18);
        vm.assume(noAmount > 0 && noAmount <= 10000e18);
        
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.startPrank(alice);
        market.yesToken().approve(address(stagedMarket), yesAmount);
        market.noToken().approve(address(stagedMarket), noAmount);
        usdc.approve(address(stagedMarket), (yesAmount + noAmount) * 5e5 / 50);
        
        stagedMarket.seedLiquidity(address(market), yesAmount, noAmount);
        vm.stopPrank();
    }
    
    function testInvariantStageProgression() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        (
            StagedPredictionMarket.Stage currentStage,
            , 
        ) = stagedMarket.getMarketStage(address(market));
        assertEq(uint256(currentStage), uint256(StagedPredictionMarket.Stage.SEEDING));
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
        
        (currentStage, , ) = stagedMarket.getMarketStage(address(market));
        assertEq(uint256(currentStage), uint256(StagedPredictionMarket.Stage.VOTING));
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startWithdrawal(address(market));
        
        (currentStage, , ) = stagedMarket.getMarketStage(address(market));
        assertEq(uint256(currentStage), uint256(StagedPredictionMarket.Stage.WITHDRAWAL));
        
        vm.warp(block.timestamp + 12 hours + 1);
        
        vm.prank(owner);
        stagedMarket.startTrading(address(market));
        
        (currentStage, , ) = stagedMarket.getMarketStage(address(market));
        assertEq(uint256(currentStage), uint256(StagedPredictionMarket.Stage.TRADING));
        
        vm.prank(owner);
        stagedMarket.resolveMarket(address(market), PredictionMarket.Outcome.YES);
        
        (currentStage, , ) = stagedMarket.getMarketStage(address(market));
        assertEq(uint256(currentStage), uint256(StagedPredictionMarket.Stage.RESOLVED));
    }
    
    function testEventEmission() public {
        vm.expectEmit(true, true, false, true);
        emit StagedPredictionMarket.MarketInitialized(address(market), address(0), address(0));
        
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
    }
    
    function testStageChangedEvent() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.warp(block.timestamp + 48 hours + 1);
        
        vm.expectEmit(true, true, false, true);
        emit StagedPredictionMarket.StageChanged(address(market), StagedPredictionMarket.Stage.SEEDING, StagedPredictionMarket.Stage.VOTING);
        
        vm.prank(owner);
        stagedMarket.startVoting(address(market));
    }
    
    function testLiquiditySeededEvent() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.startPrank(alice);
        market.yesToken().approve(address(stagedMarket), 1000e18);
        market.noToken().approve(address(stagedMarket), 1000e18);
        usdc.approve(address(stagedMarket), 200e6);
        
        vm.expectEmit(true, true, false, true);
        emit StagedPredictionMarket.LiquiditySeeded(address(market), alice, 0);
        
        stagedMarket.seedLiquidity(address(market), 1000e18, 1000e18);
        vm.stopPrank();
    }
    
    function testMultipleUsersSeeding() public {
        vm.prank(owner);
        stagedMarket.initializeMarket(
            address(market),
            address(market.yesToken()),
            address(market.noToken())
        );
        
        vm.startPrank(alice);
        market.yesToken().approve(address(stagedMarket), 1000e18);
        market.noToken().approve(address(stagedMarket), 1000e18);
        usdc.approve(address(stagedMarket), 200e6);
        stagedMarket.seedLiquidity(address(market), 1000e18, 1000e18);
        vm.stopPrank();
        
        vm.startPrank(bob);
        market.yesToken().approve(address(stagedMarket), 800e18);
        market.noToken().approve(address(stagedMarket), 800e18);
        usdc.approve(address(stagedMarket), 160e6);
        stagedMarket.seedLiquidity(address(market), 800e18, 800e18);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        market.yesToken().approve(address(stagedMarket), 500e18);
        market.noToken().approve(address(stagedMarket), 500e18);
        usdc.approve(address(stagedMarket), 100e6);
        stagedMarket.seedLiquidity(address(market), 500e18, 500e18);
        vm.stopPrank();
    }
} 