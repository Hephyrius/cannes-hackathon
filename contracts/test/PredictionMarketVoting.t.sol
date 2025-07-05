// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/PredictionMarketVoting.sol";
import "../src/PredictionMarket.sol";
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

contract MockUniswapV2ERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000e18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PredictionMarketVotingTest is Test {
    PredictionMarketVoting public voting;
    PredictionMarket public market;
    MockUSDC public usdc;
    MockUniswapV2ERC20 public yesLP;
    MockUniswapV2ERC20 public noLP;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    
    function setUp() public {
        usdc = new MockUSDC();
        yesLP = new MockUniswapV2ERC20("YES LP", "YESLP");
        noLP = new MockUniswapV2ERC20("NO LP", "NOLP");
        
        market = new PredictionMarket(
            address(usdc),
            "Will Bitcoin reach $100k by 2024?",
            block.timestamp + 30 days
        );
        
        voting = new PredictionMarketVoting();
        
        usdc.mint(alice, 50000e6);
        usdc.mint(bob, 30000e6);
        usdc.mint(charlie, 20000e6);
        usdc.mint(owner, 100000e6);
        
        yesLP.mint(alice, 1000e18);
        yesLP.mint(bob, 800e18);
        noLP.mint(alice, 500e18);
        noLP.mint(bob, 600e18);
    }
    
    function testConstructor() public view {
        assertEq(voting.VOTING_DURATION(), 24 hours);
        assertEq(voting.WITHDRAWAL_DURATION(), 12 hours);
    }
    
    function testRegisterLPPower() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        assertEq(voting.lpPower(address(market), alice), 1500e18); // 1000 + 500
    }
    
    function testRegisterLPPowerNoTokens() public {
        vm.prank(charlie);
        vm.expectRevert("No LP tokens");
        voting.registerLPPower(
            address(market),
            charlie,
            address(yesLP),
            address(noLP)
        );
    }
    
    function testRegisterLPPowerMultipleUsers() public {
        vm.startPrank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        vm.stopPrank();
        
        vm.startPrank(bob);
        voting.registerLPPower(
            address(market),
            bob,
            address(yesLP),
            address(noLP)
        );
        vm.stopPrank();
        
        assertEq(voting.lpPower(address(market), alice), 1500e18);
        assertEq(voting.lpPower(address(market), bob), 1400e18); // 800 + 600
        
        (
            , , uint256 totalVotingPower, , , , ,
        ) = voting.getVotingSession(address(market));
        
        assertEq(totalVotingPower, 2900e18); // 1500 + 1400
    }
    
    function testStartVoting() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        (
            uint256 startTime,
            uint256 endTime,
            uint256 totalVotingPower,
            , , , ,
        ) = voting.getVotingSession(address(market));
        
        assertGt(startTime, 0);
        assertEq(endTime, startTime + 24 hours);
        assertEq(totalVotingPower, 1500e18);
    }
    
    function testStartVotingNoPower() public {
        vm.prank(owner);
        vm.expectRevert("No voting power registered");
        voting.startVoting(address(market));
    }
    
    function testStartVotingAlreadyStarted() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(owner);
        vm.expectRevert("Voting already started");
        voting.startVoting(address(market));
    }
    
    function testVote() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
        
        (
            , , , uint256 yesVotes, uint256 noVotes, uint256 powerVotes, ,
        ) = voting.getVotingSession(address(market));
        
        assertEq(yesVotes, 1500e18);
        assertEq(noVotes, 0);
        assertEq(powerVotes, 0);
    }
    
    function testVoteNo() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.NO);
        
        (
            , , , uint256 yesVotes, uint256 noVotes, uint256 powerVotes, ,
        ) = voting.getVotingSession(address(market));
        
        assertEq(yesVotes, 0);
        assertEq(noVotes, 1500e18);
        assertEq(powerVotes, 0);
    }
    
    function testVotePower() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.POWER);
        
        (
            , , , uint256 yesVotes, uint256 noVotes, uint256 powerVotes, ,
        ) = voting.getVotingSession(address(market));
        
        assertEq(yesVotes, 0);
        assertEq(noVotes, 0);
        assertEq(powerVotes, 1500e18);
    }
    
    function testVoteNotStarted() public {
        vm.prank(alice);
        vm.expectRevert("Voting not started");
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
    }
    
    function testVoteNoPower() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(charlie);
        vm.expectRevert("No voting power");
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
    }
    
    function testVoteTwice() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.startPrank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
        vm.expectRevert("Already voted");
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.NO);
        vm.stopPrank();
    }
    
    function testVoteAfterDeadline() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(alice);
        vm.expectRevert("Voting ended");
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
    }
    
    function testResolveVoting() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        voting.resolveVoting(address(market));
        
        (
            , , , , , , bool resolved, PredictionMarketVoting.VoteChoice result
        ) = voting.getVotingSession(address(market));
        
        assertTrue(resolved);
        assertEq(uint256(result), uint256(PredictionMarketVoting.VoteChoice.YES));
    }
    
    function testResolveVotingNotStarted() public {
        vm.expectRevert("Voting not started");
        voting.resolveVoting(address(market));
    }
    
    function testResolveVotingStillActive() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.expectRevert("Voting still active");
        voting.resolveVoting(address(market));
    }
    
    function testResolveVotingAlreadyResolved() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        voting.resolveVoting(address(market));
        
        vm.expectRevert("Already resolved");
        voting.resolveVoting(address(market));
    }
    
    function testResolveVotingTie() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(bob);
        voting.registerLPPower(
            address(market),
            bob,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
        
        vm.prank(bob);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.NO);
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        voting.resolveVoting(address(market));
        
        (
            , , , , , , bool resolved, PredictionMarketVoting.VoteChoice result
        ) = voting.getVotingSession(address(market));
        
        assertTrue(resolved);
        assertEq(uint256(result), uint256(PredictionMarketVoting.VoteChoice.YES)); // Tie goes to YES
    }
    
    function testCanWithdraw() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.NO);
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        voting.resolveVoting(address(market));
        
        // Alice voted NO but result was YES, so she can withdraw
        assertTrue(voting.canWithdraw(address(market), alice));
    }
    
    function testCanWithdrawNotResolved() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.expectRevert("Voting not resolved");
        voting.canWithdraw(address(market), alice);
    }
    
    function testCanWithdrawPeriodEnded() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.NO);
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        voting.resolveVoting(address(market));
        
        vm.warp(block.timestamp + 12 hours + 1);
        
        vm.expectRevert("Withdrawal period ended");
        voting.canWithdraw(address(market), alice);
    }
    
    function testCanWithdrawNoVote() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        voting.resolveVoting(address(market));
        
        // Alice didn't vote, so she can't withdraw
        assertFalse(voting.canWithdraw(address(market), alice));
    }
    
    function testCanWithdrawVotedWithResult() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.prank(owner);
        voting.resolveVoting(address(market));
        
        // Alice voted YES and result was YES, so she can't withdraw
        assertFalse(voting.canWithdraw(address(market), alice));
    }
    
    function testGetVotingSession() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        (
            uint256 startTime,
            uint256 endTime,
            uint256 totalVotingPower,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 powerVotes,
            bool resolved,
            PredictionMarketVoting.VoteChoice result
        ) = voting.getVotingSession(address(market));
        
        assertGt(startTime, 0);
        assertEq(endTime, startTime + 24 hours);
        assertEq(totalVotingPower, 1500e18);
        assertEq(yesVotes, 0);
        assertEq(noVotes, 0);
        assertEq(powerVotes, 0);
        assertFalse(resolved);
        assertEq(uint256(result), 0);
    }
    
    function testGetLPVote() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
        
        (
            PredictionMarketVoting.VoteChoice choice,
            uint256 weight,
            uint256 timestamp,
            bool hasVoted
        ) = voting.getLPVote(address(market), alice);
        
        assertEq(uint256(choice), uint256(PredictionMarketVoting.VoteChoice.YES));
        assertEq(weight, 1500e18);
        assertGt(timestamp, 0);
        assertTrue(hasVoted);
    }
    
    function testGetLPVoteNoVote() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        (
            PredictionMarketVoting.VoteChoice choice,
            uint256 weight,
            uint256 timestamp,
            bool hasVoted
        ) = voting.getLPVote(address(market), alice);
        
        assertEq(uint256(choice), 0);
        assertEq(weight, 0);
        assertEq(timestamp, 0);
        assertFalse(hasVoted);
    }
    
    function testFuzzRegisterLPPower(uint256 yesAmount, uint256 noAmount) public {
        vm.assume(yesAmount > 0 && yesAmount <= 10000e18);
        vm.assume(noAmount > 0 && noAmount <= 10000e18);
        
        yesLP.mint(alice, yesAmount);
        noLP.mint(alice, noAmount);
        
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        assertEq(voting.lpPower(address(market), alice), yesAmount + noAmount);
    }
    
    function testFuzzVote(PredictionMarketVoting.VoteChoice choice) public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), choice);
        
        (
            , , , uint256 yesVotes, uint256 noVotes, uint256 powerVotes, ,
        ) = voting.getVotingSession(address(market));
        
        if (choice == PredictionMarketVoting.VoteChoice.YES) {
            assertEq(yesVotes, 1500e18);
            assertEq(noVotes, 0);
            assertEq(powerVotes, 0);
        } else if (choice == PredictionMarketVoting.VoteChoice.NO) {
            assertEq(yesVotes, 0);
            assertEq(noVotes, 1500e18);
            assertEq(powerVotes, 0);
        } else {
            assertEq(yesVotes, 0);
            assertEq(noVotes, 0);
            assertEq(powerVotes, 1500e18);
        }
    }
    
    function testInvariantVotingPower() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(bob);
        voting.registerLPPower(
            address(market),
            bob,
            address(yesLP),
            address(noLP)
        );
        
        (
            , , uint256 totalVotingPower, , , , ,
        ) = voting.getVotingSession(address(market));
        
        assertEq(totalVotingPower, 2900e18); // 1500 + 1400
    }
    
    function testEventEmission() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketVoting.LPPowerRegistered(address(market), alice, 1500e18);
        
        vm.prank(bob);
        voting.registerLPPower(
            address(market),
            bob,
            address(yesLP),
            address(noLP)
        );
    }
    
    function testVotingStartedEvent() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketVoting.VotingStarted(address(market), 0, 0);
        
        vm.prank(owner);
        voting.startVoting(address(market));
    }
    
    function testVoteCastEvent() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketVoting.VoteCast(address(market), alice, PredictionMarketVoting.VoteChoice.YES, 1500e18);
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
    }
    
    function testVotingResolvedEvent() public {
        vm.prank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
        
        vm.warp(block.timestamp + 24 hours + 1);
        
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketVoting.VotingResolved(address(market), PredictionMarketVoting.VoteChoice.YES);
        
        vm.prank(owner);
        voting.resolveVoting(address(market));
    }
    
    function testMultipleUsersVoting() public {
        vm.startPrank(alice);
        voting.registerLPPower(
            address(market),
            alice,
            address(yesLP),
            address(noLP)
        );
        vm.stopPrank();
        
        vm.startPrank(bob);
        voting.registerLPPower(
            address(market),
            bob,
            address(yesLP),
            address(noLP)
        );
        vm.stopPrank();
        
        vm.prank(owner);
        voting.startVoting(address(market));
        
        vm.prank(alice);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.YES);
        
        vm.prank(bob);
        voting.vote(address(market), PredictionMarketVoting.VoteChoice.NO);
        
        (
            , , , uint256 yesVotes, uint256 noVotes, uint256 powerVotes, ,
        ) = voting.getVotingSession(address(market));
        
        assertEq(yesVotes, 1500e18);
        assertEq(noVotes, 1400e18);
        assertEq(powerVotes, 0);
    }
} 