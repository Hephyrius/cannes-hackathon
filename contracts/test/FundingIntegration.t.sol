// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/OutcomeFunding.sol";
import "../src/MarketResolution.sol";
import "../src/OutcomeFundingFactory.sol";
import "../src/PredictionMarket.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000e6); // 1M USDC
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract FundingIntegrationTest is Test {
    OutcomeFundingFactory public factory;
    MarketResolution public resolution;
    PredictionMarket public market;
    MockUSDC public usdc;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public oracle = address(0x4);
    
    function setUp() public {
        // Deploy contracts
        usdc = new MockUSDC();
        factory = new OutcomeFundingFactory(address(usdc));
        resolution = new MarketResolution(address(usdc), address(0)); // No NFT
        
        // Create market
        market = new PredictionMarket(
            address(usdc),
            "Will Bitcoin reach $100k by 2024?",
            block.timestamp + 30 days
        );
        
        // Setup ownership
        factory.transferOwnership(owner);
        resolution.transferOwnership(owner);
        
        // Configure resolution system
        vm.startPrank(owner);
        factory.setResolutionContract(address(resolution));
        resolution.addOracle(oracle, 100, "Test Oracle");
        resolution.authorizeMarket(address(market));
        vm.stopPrank();
        
        // Mint USDC to test accounts
        usdc.mint(alice, 50000e6);
        usdc.mint(bob, 30000e6);
        usdc.mint(owner, 100000e6);
    }
    
    function testFullFundingFlow() public {
        // 1. Alice creates a funding contract for YES outcome
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        address fundingContract = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k Fund",
            "Fund to support Bitcoin reaching $100k",
            "BTC100Y",
            "BTC100Y"
        );
        vm.stopPrank();
        
        // 2. Alice starts a funding round
        OutcomeFunding funding = OutcomeFunding(fundingContract);
        vm.prank(alice);
        funding.startFundingRound(10000e6, 7 days);
        
        // 3. Bob contributes to the funding
        vm.startPrank(bob);
        usdc.approve(address(funding), 5000e6);
        funding.fund(5000e6);
        vm.stopPrank();
        
        // 4. Alice also contributes
        vm.startPrank(alice);
        usdc.approve(address(funding), 5000e6);
        funding.fund(5000e6);
        vm.stopPrank();
        
        // Check funding status
        (
            uint256 target,
            uint256 raised,
            ,
            bool active,
            bool successful,
            ,
        ) = funding.getFundingRoundInfo();
        
        assertEq(target, 10000e6);
        assertEq(raised, 10000e6);
        assertFalse(active); // Should be completed
        assertTrue(successful);
        
        // Check token balances
        assertEq(funding.balanceOf(alice), 5000e18);
        assertEq(funding.balanceOf(bob), 5000e18);
        
        // 5. Alice creates a proposal
        vm.startPrank(alice);
        uint256 proposalId = funding.createProposal(
            "Marketing Campaign",
            "Launch Bitcoin awareness campaign",
            2000e6,
            OutcomeFunding.ProposalType.MARKETING,
            ""
        );
        vm.stopPrank();
        
        // 6. Both vote on the proposal
        vm.prank(alice);
        funding.vote(proposalId, true);
        
        vm.prank(bob);
        funding.vote(proposalId, true);
        
        // 7. Fast forward and execute proposal
        vm.warp(block.timestamp + 3 days + 1);
        
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        funding.executeProposal(proposalId);
        
        // Check Alice received the funds
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + 2000e6);
        
        // 8. Market resolution
        vm.warp(block.timestamp + 30 days + 1);
        
        // Request resolution
        vm.startPrank(alice);
        usdc.approve(address(resolution), 100e6);
        uint256 requestId = resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin reached $100k!"
        );
        vm.stopPrank();
        
        // Oracle votes
        vm.prank(oracle);
        resolution.voteOnResolution(requestId, true);
        
        // Execute resolution
        vm.warp(block.timestamp + 2 days + 1);
        resolution.executeResolution(requestId);
        
        // Check market resolved
        assertTrue(market.isResolved());
        assertEq(uint256(market.outcome()), uint256(PredictionMarket.Outcome.YES));
        
        // Check funding contract achieved target
        assertTrue(funding.isTargetOutcomeAchieved());
        
        // 9. Add revenue to funding contract
        vm.startPrank(owner);
        usdc.approve(address(funding), 3000e6);
        funding.addRevenue("IP Rights", 3000e6, "Revenue from IP licensing");
        vm.stopPrank();
        
        // 10. Users claim their revenue share
        uint256 aliceBalanceBeforeRevenue = usdc.balanceOf(alice);
        uint256 bobBalanceBeforeRevenue = usdc.balanceOf(bob);
        
        vm.prank(alice);
        funding.claimRevenue();
        
        vm.prank(bob);
        funding.claimRevenue();
        
        // Check revenue distribution (50/50 split)
        assertEq(usdc.balanceOf(alice), aliceBalanceBeforeRevenue + 1500e6);
        assertEq(usdc.balanceOf(bob), bobBalanceBeforeRevenue + 1500e6);
    }
    
    function testFactoryManagement() public {
        // Test factory functionality
        assertEq(factory.getTotalFundingContractsCount(), 0);
        
        // Create funding contract
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        address fundingContract = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test Fund",
            "Test Description",
            "TEST",
            "TEST"
        );
        vm.stopPrank();
        
        assertEq(factory.getTotalFundingContractsCount(), 1);
        
        // Check factory mappings
        address[] memory marketContracts = factory.getFundingContractsForMarket(address(market));
        assertEq(marketContracts.length, 1);
        assertEq(marketContracts[0], fundingContract);
        
        address[] memory creatorContracts = factory.getFundingContractsByCreator(alice);
        assertEq(creatorContracts.length, 1);
        assertEq(creatorContracts[0], fundingContract);
        
        // Test contract info
        (
            address marketAddr,
            PredictionMarket.Outcome targetOutcome,
            ,
            address creator,
            bool active,
            string memory title,
            string memory description
        ) = factory.getFundingContractInfo(fundingContract);
        
        assertEq(marketAddr, address(market));
        assertEq(uint256(targetOutcome), uint256(PredictionMarket.Outcome.YES));
        assertEq(creator, alice);
        assertTrue(active);
        assertEq(title, "Test Fund");
        assertEq(description, "Test Description");
    }
    
    function testResolutionSystem() public {
        // Test oracle management
        (uint256 weight, bool active, , , string memory name) = resolution.getOracle(oracle);
        assertEq(weight, 100);
        assertTrue(active);
        assertEq(name, "Test Oracle");
        
        // Test oracle accuracy (initially 0)
        assertEq(resolution.getOracleAccuracy(oracle), 0);
        
        // Test resolution request
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), 100e6);
        uint256 requestId = resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test evidence"
        );
        vm.stopPrank();
        
        // Check request details
        (
            address marketAddr,
            address requester,
            PredictionMarket.Outcome proposedOutcome,
            string memory evidence,
            ,
            ,
            bool resolved,
            ,
        ) = resolution.getResolutionRequest(requestId);
        
        assertEq(marketAddr, address(market));
        assertEq(requester, alice);
        assertEq(uint256(proposedOutcome), uint256(PredictionMarket.Outcome.YES));
        assertEq(evidence, "Test evidence");
        assertFalse(resolved);
    }
    
    function testUnsuccessfulFundingRoundWithEmergencyWithdraw() public {
        // Create funding contract
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        address fundingContract = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Failed Fund",
            "Description",
            "FAIL",
            "FAIL"
        );
        vm.stopPrank();
        
        // Start funding round
        OutcomeFunding funding = OutcomeFunding(fundingContract);
        vm.prank(alice);
        funding.startFundingRound(10000e6, 7 days);
        
        // Only partial funding
        vm.startPrank(alice);
        usdc.approve(address(funding), 3000e6);
        funding.fund(3000e6);
        vm.stopPrank();
        
        // Fast forward past deadline
        vm.warp(block.timestamp + 7 days + 1);
        
        // Complete funding round
        funding.completeFundingRound();
        
        // Check it failed
        (, , , bool active, bool successful, , ) = funding.getFundingRoundInfo();
        assertFalse(active);
        assertFalse(successful);
        
        // Test emergency withdraw
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        
        vm.prank(alice);
        funding.emergencyWithdraw();
        
        // Check Alice got refund
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + 3000e6);
        assertEq(funding.balanceOf(alice), 0);
    }
} 