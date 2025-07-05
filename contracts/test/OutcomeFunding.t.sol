// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/OutcomeFunding.sol";
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

contract OutcomeFundingTest is Test {
    OutcomeFunding public funding;
    PredictionMarket public market;
    MockUSDC public usdc;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    
    uint256 public constant FUNDING_TARGET = 10000e6;
    uint256 public constant FUNDING_DURATION = 7 days;
    
    function setUp() public {
        usdc = new MockUSDC();
        
        market = new PredictionMarket(
            address(usdc),
            "Will Bitcoin reach $100k by 2024?",
            block.timestamp + 30 days
        );
        
        funding = new OutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k YES Fund",
            "BTC100Y"
        );
        
        funding.transferOwnership(owner);
        
        usdc.mint(alice, 50000e6);
        usdc.mint(bob, 30000e6);
        usdc.mint(charlie, 20000e6);
        usdc.mint(owner, 100000e6);
    }
    
    function testConstructor() public {
        assertEq(funding.name(), "Bitcoin $100k YES Fund");
        assertEq(funding.symbol(), "BTC100Y");
        assertEq(address(funding.usdc()), address(usdc));
        assertEq(address(funding.market()), address(market));
        assertEq(uint256(funding.targetOutcome()), uint256(PredictionMarket.Outcome.YES));
        assertEq(funding.owner(), owner);
    }
    
    function testStartFundingRound() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        (
            uint256 target,
            uint256 raised,
            uint256 deadline,
            bool active,
            bool successful,
            ,
        ) = funding.getFundingRoundInfo();
        
        assertEq(target, FUNDING_TARGET);
        assertEq(raised, 0);
        assertEq(deadline, block.timestamp + FUNDING_DURATION);
        assertTrue(active);
        assertFalse(successful);
    }
    
    function testStartFundingRoundOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
    }
    
    function testStartFundingRoundAlreadyActive() public {
        vm.startPrank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.expectRevert("Funding round already active");
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        vm.stopPrank();
    }
    
    function testStartFundingRoundInvalidTarget() public {
        vm.prank(owner);
        vm.expectRevert("Target must be greater than 0");
        funding.startFundingRound(0, FUNDING_DURATION);
    }
    
    function testStartFundingRoundInvalidDuration() public {
        vm.prank(owner);
        vm.expectRevert("Duration must be greater than 0");
        funding.startFundingRound(FUNDING_TARGET, 0);
    }
    
    function testFund() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), 5000e6);
        funding.fund(5000e6);
        vm.stopPrank();
        
        assertEq(funding.balanceOf(alice), 5000e18);
        
        (, uint256 raised, , , , , ) = funding.getFundingRoundInfo();
        assertEq(raised, 5000e6);
    }
    
    function testFundMultipleUsers() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), 6000e6);
        funding.fund(6000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.approve(address(funding), 4000e6);
        funding.fund(4000e6);
        vm.stopPrank();
        
        assertEq(funding.balanceOf(alice), 6000e18);
        assertEq(funding.balanceOf(bob), 4000e18);
        assertEq(funding.totalSupply(), 10000e18);
        
        (, uint256 raised, , , , , ) = funding.getFundingRoundInfo();
        assertEq(raised, 10000e6);
    }
    
    function testFundTargetReached() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), FUNDING_TARGET);
        funding.fund(FUNDING_TARGET);
        vm.stopPrank();
        
        (, , , bool active, bool successful, , ) = funding.getFundingRoundInfo();
        assertFalse(active);
        assertTrue(successful);
    }
    
    function testFundAfterDeadline() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.warp(block.timestamp + FUNDING_DURATION + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), 1000e6);
        vm.expectRevert("Funding period ended");
        funding.fund(1000e6);
        vm.stopPrank();
    }
    
    function testFundZeroAmount() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), 1000e6);
        vm.expectRevert("Amount must be greater than 0");
        funding.fund(0);
        vm.stopPrank();
    }
    
    function testCompleteFundingRound() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.warp(block.timestamp + FUNDING_DURATION + 1);
        
        funding.completeFundingRound();
        
        (, , , bool active, bool successful, , ) = funding.getFundingRoundInfo();
        assertFalse(active);
        assertFalse(successful); // No funds raised
    }
    
    function testCompleteFundingRoundStillActive() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.expectRevert("Funding period not ended");
        funding.completeFundingRound();
    }
    
    function testCompleteFundingRoundNoActive() public {
        vm.expectRevert("No active funding round");
        funding.completeFundingRound();
    }
    
    function testCreateProposal() public {
        // Setup successful funding round
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), FUNDING_TARGET);
        funding.fund(FUNDING_TARGET);
        vm.stopPrank();
        
        vm.startPrank(alice);
        uint256 proposalId = funding.createProposal(
            "Marketing Campaign",
            "Launch social media campaign",
            2000e6,
            OutcomeFunding.ProposalType.MARKETING,
            ""
        );
        vm.stopPrank();
        
        assertEq(proposalId, 1);
        
        (
            string memory title,
            string memory description,
            uint256 requestedAmount,
            address proposer,
            , , , , ,
        ) = funding.getProposal(proposalId);
        
        assertEq(title, "Marketing Campaign");
        assertEq(description, "Launch social media campaign");
        assertEq(requestedAmount, 2000e6);
        assertEq(proposer, alice);
    }
    
    function testCreateProposalInsufficientTokens() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), 5000e6);
        funding.fund(5000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        vm.expectRevert("Insufficient tokens to propose");
        funding.createProposal(
            "Test Proposal",
            "Description",
            1000e6,
            OutcomeFunding.ProposalType.MARKETING,
            ""
        );
        vm.stopPrank();
    }
    
    function testCreateProposalDuringFunding() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), FUNDING_TARGET);
        funding.fund(FUNDING_TARGET);
        
        vm.expectRevert("Funding still active");
        funding.createProposal(
            "Test Proposal",
            "Description",
            1000e6,
            OutcomeFunding.ProposalType.MARKETING,
            ""
        );
        vm.stopPrank();
    }
    
    function testVoteOnProposal() public {
        // Setup
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), 6000e6);
        funding.fund(6000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.approve(address(funding), 4000e6);
        funding.fund(4000e6);
        vm.stopPrank();
        
        vm.startPrank(alice);
        uint256 proposalId = funding.createProposal(
            "Test Proposal",
            "Description",
            2000e6,
            OutcomeFunding.ProposalType.MARKETING,
            ""
        );
        vm.stopPrank();
        
        // Vote
        vm.prank(alice);
        funding.vote(proposalId, true);
        
        vm.prank(bob);
        funding.vote(proposalId, false);
        
        (, , , , uint256 votesFor, uint256 votesAgainst, , , , ) = funding.getProposal(proposalId);
        assertEq(votesFor, 6000e18);
        assertEq(votesAgainst, 4000e18);
    }
    
    function testVoteTwice() public {
        // Setup
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), FUNDING_TARGET);
        funding.fund(FUNDING_TARGET);
        
        uint256 proposalId = funding.createProposal(
            "Test Proposal",
            "Description",
            2000e6,
            OutcomeFunding.ProposalType.MARKETING,
            ""
        );
        
        funding.vote(proposalId, true);
        vm.expectRevert("Already voted");
        funding.vote(proposalId, false);
        vm.stopPrank();
    }
    
    function testVoteAfterDeadline() public {
        // Setup
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), FUNDING_TARGET);
        funding.fund(FUNDING_TARGET);
        
        uint256 proposalId = funding.createProposal(
            "Test Proposal",
            "Description",
            2000e6,
            OutcomeFunding.ProposalType.MARKETING,
            ""
        );
        vm.stopPrank();
        
        vm.warp(block.timestamp + 3 days + 1);
        
        vm.prank(alice);
        vm.expectRevert("Voting period ended");
        funding.vote(proposalId, true);
    }
    
    function testExecuteProposal() public {
        // Setup
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), 6000e6);
        funding.fund(6000e6);
        
        uint256 proposalId = funding.createProposal(
            "Test Proposal",
            "Description",
            2000e6,
            OutcomeFunding.ProposalType.MARKETING,
            ""
        );
        
        funding.vote(proposalId, true);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 3 days + 1);
        
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        funding.executeProposal(proposalId);
        
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + 2000e6);
        
        (, , , , , , , bool executed, bool approved, ) = funding.getProposal(proposalId);
        assertTrue(executed);
        assertTrue(approved);
    }
    
    function testExecuteRejectedProposal() public {
        // Setup
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), 4000e6);
        funding.fund(4000e6);
        
        uint256 proposalId = funding.createProposal(
            "Test Proposal",
            "Description",
            2000e6,
            OutcomeFunding.ProposalType.MARKETING,
            ""
        );
        
        funding.vote(proposalId, false);
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.approve(address(funding), 6000e6);
        funding.fund(6000e6);
        funding.vote(proposalId, true);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 3 days + 1);
        
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        funding.executeProposal(proposalId);
        
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore); // No funds transferred
        
        (, , , , , , , bool executed, bool approved, ) = funding.getProposal(proposalId);
        assertTrue(executed);
        assertFalse(approved);
    }
    
    function testAddRevenue() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), FUNDING_TARGET);
        funding.fund(FUNDING_TARGET);
        vm.stopPrank();
        
        vm.startPrank(owner);
        usdc.approve(address(funding), 5000e6);
        funding.addRevenue("IP Rights", 5000e6, "Revenue from IP licensing");
        vm.stopPrank();
        
        (, , , , , uint256 totalRevenue, ) = funding.getFundingRoundInfo();
        assertEq(totalRevenue, 5000e6);
    }
    
    function testAddRevenueOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        funding.addRevenue("IP Rights", 1000e6, "Description");
    }
    
    function testClaimRevenue() public {
        // Setup
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), 6000e6);
        funding.fund(6000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.approve(address(funding), 4000e6);
        funding.fund(4000e6);
        vm.stopPrank();
        
        vm.startPrank(owner);
        usdc.approve(address(funding), 5000e6);
        funding.addRevenue("IP Rights", 5000e6, "Revenue from IP licensing");
        vm.stopPrank();
        
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        uint256 bobBalanceBefore = usdc.balanceOf(bob);
        
        vm.prank(alice);
        funding.claimRevenue();
        
        vm.prank(bob);
        funding.claimRevenue();
        
        // Alice should get 60% of revenue
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + 3000e6);
        // Bob should get 40% of revenue
        assertEq(usdc.balanceOf(bob), bobBalanceBefore + 2000e6);
    }
    
    function testClaimRevenueNoTokens() public {
        vm.prank(alice);
        vm.expectRevert("No tokens held");
        funding.claimRevenue();
    }
    
    function testClaimRevenueNoRevenue() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), FUNDING_TARGET);
        funding.fund(FUNDING_TARGET);
        vm.stopPrank();
        
        vm.prank(alice);
        funding.claimRevenue(); // Should not revert but not transfer anything
    }
    
    function testGetPendingRevenue() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), 6000e6);
        funding.fund(6000e6);
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.approve(address(funding), 4000e6);
        funding.fund(4000e6);
        vm.stopPrank();
        
        vm.startPrank(owner);
        usdc.approve(address(funding), 5000e6);
        funding.addRevenue("IP Rights", 5000e6, "Revenue from IP licensing");
        vm.stopPrank();
        
        assertEq(funding.getPendingRevenue(alice), 3000e6);
        assertEq(funding.getPendingRevenue(bob), 2000e6);
        assertEq(funding.getPendingRevenue(charlie), 0);
    }
    
    function testEmergencyWithdraw() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), 5000e6);
        funding.fund(5000e6);
        vm.stopPrank();
        
        vm.warp(block.timestamp + FUNDING_DURATION + 1);
        funding.completeFundingRound();
        
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        
        vm.prank(alice);
        funding.emergencyWithdraw();
        
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + 5000e6);
        assertEq(funding.balanceOf(alice), 0);
    }
    
    function testEmergencyWithdrawSuccessful() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), FUNDING_TARGET);
        funding.fund(FUNDING_TARGET);
        vm.stopPrank();
        
        vm.prank(alice);
        vm.expectRevert("Funding round was successful");
        funding.emergencyWithdraw();
    }
    
    function testEmergencyWithdrawStillActive() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.startPrank(alice);
        usdc.approve(address(funding), 5000e6);
        funding.fund(5000e6);
        vm.stopPrank();
        
        vm.prank(alice);
        vm.expectRevert("Funding round still active");
        funding.emergencyWithdraw();
    }
    
    function testEmergencyWithdrawNoTokens() public {
        vm.prank(owner);
        funding.startFundingRound(FUNDING_TARGET, FUNDING_DURATION);
        
        vm.warp(block.timestamp + FUNDING_DURATION + 1);
        funding.completeFundingRound();
        
        vm.prank(alice);
        vm.expectRevert("No tokens to redeem");
        funding.emergencyWithdraw();
    }
    
    function testIsTargetOutcomeAchieved() public {
        assertFalse(funding.isTargetOutcomeAchieved());
        
        market.resolveMarket(PredictionMarket.Outcome.YES);
        
        assertTrue(funding.isTargetOutcomeAchieved());
    }
    
    function testIsTargetOutcomeNotAchieved() public {
        market.resolveMarket(PredictionMarket.Outcome.NO);
        
        assertFalse(funding.isTargetOutcomeAchieved());
    }
    
    function testSetMinimumVotingPeriod() public {
        vm.prank(owner);
        funding.setMinimumVotingPeriod(5 days);
        
        assertEq(funding.minimumVotingPeriod(), 5 days);
    }
    
    function testSetMinimumVotingPeriodOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        funding.setMinimumVotingPeriod(5 days);
    }
    
    function testSetProposalThreshold() public {
        vm.prank(owner);
        funding.setProposalThreshold(2000e18);
        
        assertEq(funding.proposalThreshold(), 2000e18);
    }
    
    function testSetProposalThresholdOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        funding.setProposalThreshold(2000e18);
    }
} 