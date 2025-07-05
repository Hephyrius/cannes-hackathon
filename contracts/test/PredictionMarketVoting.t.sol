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

contract PredictionMarketVotingTest is Test {
    PredictionMarketVoting public voting;
    PredictionMarket public market;
    MockUSDC public usdc;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    
    function setUp() public {
        usdc = new MockUSDC();
        
        market = new PredictionMarket(
            address(usdc),
            "Will Bitcoin reach $100k by 2024?",
            block.timestamp + 30 days
        );
        
        voting = new PredictionMarketVoting(address(market));
        voting.transferOwnership(owner);
        
        usdc.mint(alice, 50000e6);
        usdc.mint(bob, 30000e6);
        usdc.mint(charlie, 20000e6);
        usdc.mint(owner, 100000e6);
    }
    
    function testConstructor() public view {
        assertEq(address(voting.market()), address(market));
        assertEq(voting.owner(), owner);
    }
    
    function testCreateProposal() public {
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        assertEq(proposalId, 1);
        
        (
            string memory title,
            string memory description,
            uint256 requestedAmount,
            address proposer,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 votingDeadline,
            bool executed,
            bool approved,
            PredictionMarketVoting.ProposalType proposalType
        ) = voting.getProposal(proposalId);
        
        assertEq(title, "Test Proposal");
        assertEq(description, "Test Description");
        assertEq(requestedAmount, 1000e6);
        assertEq(proposer, owner);
        assertEq(votesFor, 0);
        assertEq(votesAgainst, 0);
        assertFalse(executed);
        assertFalse(approved);
        assertEq(uint256(proposalType), uint256(PredictionMarketVoting.ProposalType.MARKETING));
    }
    
    function testCreateProposalOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
    }
    
    function testCreateProposalInvalidAmount() public {
        vm.prank(owner);
        vm.expectRevert("Requested amount must be greater than 0");
        voting.createProposal(
            "Test Proposal",
            "Test Description",
            0,
            PredictionMarketVoting.ProposalType.MARKETING
        );
    }
    
    function testCreateMultipleProposals() public {
        vm.startPrank(owner);
        
        uint256 proposal1 = voting.createProposal(
            "Proposal 1",
            "Description 1",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        uint256 proposal2 = voting.createProposal(
            "Proposal 2",
            "Description 2",
            2000e6,
            PredictionMarketVoting.ProposalType.RESEARCH
        );
        
        uint256 proposal3 = voting.createProposal(
            "Proposal 3",
            "Description 3",
            3000e6,
            PredictionMarketVoting.ProposalType.LOBBYING
        );
        
        vm.stopPrank();
        
        assertEq(proposal1, 1);
        assertEq(proposal2, 2);
        assertEq(proposal3, 3);
    }
    
    function testVoteOnProposal() public {
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        vm.prank(alice);
        voting.vote(proposalId, true);
        
        vm.prank(bob);
        voting.vote(proposalId, false);
        
        vm.prank(charlie);
        voting.vote(proposalId, true);
        
        (
            , , , , uint256 votesFor, uint256 votesAgainst, , , ,
        ) = voting.getProposal(proposalId);
        
        assertEq(votesFor, 2); // alice and charlie voted for
        assertEq(votesAgainst, 1); // bob voted against
    }
    
    function testVoteOnNonExistentProposal() public {
        vm.prank(alice);
        vm.expectRevert("Proposal does not exist");
        voting.vote(999, true);
    }
    
    function testVoteTwice() public {
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        vm.startPrank(alice);
        voting.vote(proposalId, true);
        vm.expectRevert("Already voted");
        voting.vote(proposalId, false);
        vm.stopPrank();
    }
    
    function testVoteAfterDeadline() public {
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        vm.warp(block.timestamp + 7 days + 1);
        
        vm.prank(alice);
        vm.expectRevert("Voting period ended");
        voting.vote(proposalId, true);
    }
    
    function testExecuteProposal() public {
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        vm.prank(alice);
        voting.vote(proposalId, true);
        
        vm.prank(bob);
        voting.vote(proposalId, true);
        
        vm.warp(block.timestamp + 7 days + 1);
        
        vm.prank(owner);
        voting.executeProposal(proposalId);
        
        (
            , , , , , , , bool executed, bool approved,
        ) = voting.getProposal(proposalId);
        
        assertTrue(executed);
        assertTrue(approved);
    }
    
    function testExecuteRejectedProposal() public {
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        vm.prank(alice);
        voting.vote(proposalId, false);
        
        vm.prank(bob);
        voting.vote(proposalId, false);
        
        vm.warp(block.timestamp + 7 days + 1);
        
        vm.prank(owner);
        voting.executeProposal(proposalId);
        
        (
            , , , , , , , bool executed, bool approved,
        ) = voting.getProposal(proposalId);
        
        assertTrue(executed);
        assertFalse(approved);
    }
    
    function testExecuteProposalVotingStillActive() public {
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        vm.expectRevert("Voting still active");
        voting.executeProposal(proposalId);
    }
    
    function testExecuteNonExistentProposal() public {
        vm.expectRevert("Proposal does not exist");
        voting.executeProposal(999);
    }
    
    function testExecuteProposalAlreadyExecuted() public {
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        vm.prank(alice);
        voting.vote(proposalId, true);
        
        vm.warp(block.timestamp + 7 days + 1);
        
        vm.prank(owner);
        voting.executeProposal(proposalId);
        
        vm.expectRevert("Proposal already executed");
        voting.executeProposal(proposalId);
    }
    
    function testGetProposalNonExistent() public {
        (
            string memory title,
            string memory description,
            uint256 requestedAmount,
            address proposer,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 votingDeadline,
            bool executed,
            bool approved,
            PredictionMarketVoting.ProposalType proposalType
        ) = voting.getProposal(999);
        
        assertEq(title, "");
        assertEq(description, "");
        assertEq(requestedAmount, 0);
        assertEq(proposer, address(0));
        assertEq(votesFor, 0);
        assertEq(votesAgainst, 0);
        assertEq(votingDeadline, 0);
        assertFalse(executed);
        assertFalse(approved);
        assertEq(uint256(proposalType), 0);
    }
    
    function testHasVoted() public {
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        assertFalse(voting.hasVoted(alice, proposalId));
        
        vm.prank(alice);
        voting.vote(proposalId, true);
        
        assertTrue(voting.hasVoted(alice, proposalId));
        assertFalse(voting.hasVoted(bob, proposalId));
    }
    
    function testGetProposalCount() public {
        assertEq(voting.getProposalCount(), 0);
        
        vm.startPrank(owner);
        voting.createProposal("Proposal 1", "Desc 1", 1000e6, PredictionMarketVoting.ProposalType.MARKETING);
        assertEq(voting.getProposalCount(), 1);
        
        voting.createProposal("Proposal 2", "Desc 2", 2000e6, PredictionMarketVoting.ProposalType.RESEARCH);
        assertEq(voting.getProposalCount(), 2);
        
        voting.createProposal("Proposal 3", "Desc 3", 3000e6, PredictionMarketVoting.ProposalType.LOBBYING);
        assertEq(voting.getProposalCount(), 3);
        vm.stopPrank();
    }
    
    function testSetVotingPeriod() public {
        vm.prank(owner);
        voting.setVotingPeriod(14 days);
        
        assertEq(voting.votingPeriod(), 14 days);
    }
    
    function testSetVotingPeriodOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        voting.setVotingPeriod(14 days);
    }
    
    function testSetVotingPeriodInvalid() public {
        vm.prank(owner);
        vm.expectRevert("Voting period must be greater than 0");
        voting.setVotingPeriod(0);
    }
    
    function testCreateProposalAllTypes() public {
        vm.startPrank(owner);
        
        voting.createProposal("Marketing", "Desc", 1000e6, PredictionMarketVoting.ProposalType.MARKETING);
        voting.createProposal("Research", "Desc", 1000e6, PredictionMarketVoting.ProposalType.RESEARCH);
        voting.createProposal("Lobbying", "Desc", 1000e6, PredictionMarketVoting.ProposalType.LOBBYING);
        voting.createProposal("Legal", "Desc", 1000e6, PredictionMarketVoting.ProposalType.LEGAL_ACTION);
        voting.createProposal("Infrastructure", "Desc", 1000e6, PredictionMarketVoting.ProposalType.INFRASTRUCTURE);
        voting.createProposal("Partnerships", "Desc", 1000e6, PredictionMarketVoting.ProposalType.PARTNERSHIPS);
        voting.createProposal("Other", "Desc", 1000e6, PredictionMarketVoting.ProposalType.OTHER);
        
        vm.stopPrank();
        
        assertEq(voting.getProposalCount(), 7);
    }
    
    function testFuzzCreateProposal(string memory title, string memory description, uint256 amount) public {
        vm.assume(bytes(title).length > 0 && bytes(title).length <= 100);
        vm.assume(bytes(description).length <= 500);
        vm.assume(amount > 0 && amount <= 1000000e6);
        
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            title,
            description,
            amount,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        assertEq(proposalId, 1);
        
        (
            string memory storedTitle,
            string memory storedDescription,
            uint256 storedAmount,
            , , , , , ,
        ) = voting.getProposal(proposalId);
        
        assertEq(storedTitle, title);
        assertEq(storedDescription, description);
        assertEq(storedAmount, amount);
    }
    
    function testFuzzVote(uint256 proposalId, bool support) public {
        vm.assume(proposalId > 0 && proposalId <= 10);
        
        // Create the proposal first
        vm.prank(owner);
        voting.createProposal("Test", "Desc", 1000e6, PredictionMarketVoting.ProposalType.MARKETING);
        
        vm.prank(alice);
        voting.vote(proposalId, support);
        
        assertTrue(voting.hasVoted(alice, proposalId));
    }
    
    function testInvariantProposalCount() public {
        uint256 initialCount = voting.getProposalCount();
        
        vm.prank(owner);
        voting.createProposal("Test", "Desc", 1000e6, PredictionMarketVoting.ProposalType.MARKETING);
        
        assertEq(voting.getProposalCount(), initialCount + 1);
    }
    
    function testEventEmission() public {
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketVoting.ProposalCreated(1, owner, "Test Proposal", 1000e6);
        
        vm.prank(owner);
        voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
    }
    
    function testVoteEventEmission() public {
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketVoting.ProposalVoted(proposalId, alice, true, 1);
        
        vm.prank(alice);
        voting.vote(proposalId, true);
    }
    
    function testExecuteEventEmission() public {
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        vm.prank(alice);
        voting.vote(proposalId, true);
        
        vm.warp(block.timestamp + 7 days + 1);
        
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketVoting.ProposalExecuted(proposalId, true);
        
        vm.prank(owner);
        voting.executeProposal(proposalId);
    }
    
    function testTieVote() public {
        vm.prank(owner);
        uint256 proposalId = voting.createProposal(
            "Test Proposal",
            "Test Description",
            1000e6,
            PredictionMarketVoting.ProposalType.MARKETING
        );
        
        vm.prank(alice);
        voting.vote(proposalId, true);
        
        vm.prank(bob);
        voting.vote(proposalId, false);
        
        vm.warp(block.timestamp + 7 days + 1);
        
        vm.prank(owner);
        voting.executeProposal(proposalId);
        
        (
            , , , , , , , bool executed, bool approved,
        ) = voting.getProposal(proposalId);
        
        assertTrue(executed);
        assertFalse(approved); // Tie goes to rejection
    }
    
    function testMultipleProposalsVoting() public {
        vm.startPrank(owner);
        uint256 proposal1 = voting.createProposal("Proposal 1", "Desc 1", 1000e6, PredictionMarketVoting.ProposalType.MARKETING);
        uint256 proposal2 = voting.createProposal("Proposal 2", "Desc 2", 2000e6, PredictionMarketVoting.ProposalType.RESEARCH);
        vm.stopPrank();
        
        vm.startPrank(alice);
        voting.vote(proposal1, true);
        voting.vote(proposal2, false);
        vm.stopPrank();
        
        vm.startPrank(bob);
        voting.vote(proposal1, false);
        voting.vote(proposal2, true);
        vm.stopPrank();
        
        assertTrue(voting.hasVoted(alice, proposal1));
        assertTrue(voting.hasVoted(alice, proposal2));
        assertTrue(voting.hasVoted(bob, proposal1));
        assertTrue(voting.hasVoted(bob, proposal2));
    }
} 