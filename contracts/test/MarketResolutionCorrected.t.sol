// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/MarketResolution.sol";
import "../src/PredictionMarket.sol";
import "../src/OutcomeFunding.sol";
import "../src/PredictionMarketNFT.sol";
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

contract MarketResolutionCorrectedTest is Test {
    MarketResolution public resolution;
    PredictionMarket public market;
    OutcomeFunding public funding;
    PredictionMarketNFT public nft;
    MockUSDC public usdc;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public oracle1 = address(0x4);
    address public oracle2 = address(0x5);
    
    uint256 public constant RESOLUTION_BOND = 100e6;
    uint256 public constant VOTING_PERIOD = 2 days;
    
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
        
        nft = new PredictionMarketNFT("Prediction Market NFTs", "PMNFT", "https://example.com/images/");
        
        resolution = new MarketResolution(
            address(usdc),
            address(nft)
        );
        
        resolution.transferOwnership(owner);
        
        usdc.mint(alice, 50000e6);
        usdc.mint(bob, 30000e6);
        usdc.mint(oracle1, 100000e6);
        usdc.mint(oracle2, 100000e6);
        usdc.mint(owner, 100000e6);
    }
    
    function testConstructor() public view {
        assertEq(address(resolution.usdc()), address(usdc));
        assertEq(address(resolution.nftContract()), address(nft));
        assertEq(resolution.owner(), owner);
    }
    
    function testAddOracle() public {
        vm.prank(owner);
        resolution.addOracle(oracle1, 100, "Oracle 1");
        
        (
            uint256 weight,
            bool active,
            uint256 correctResolutions,
            uint256 totalResolutions,
            string memory name
        ) = resolution.getOracle(oracle1);
        
        assertEq(weight, 100);
        assertTrue(active);
        assertEq(correctResolutions, 0);
        assertEq(totalResolutions, 0);
        assertEq(name, "Oracle 1");
    }
    
    function testAddOracleOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        resolution.addOracle(oracle1, 100, "Oracle 1");
    }
    
    function testAddOracleInvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid oracle address");
        resolution.addOracle(address(0), 100, "Oracle 1");
    }
    
    function testAddOracleInvalidWeight() public {
        vm.prank(owner);
        vm.expectRevert("Weight must be greater than 0");
        resolution.addOracle(oracle1, 0, "Oracle 1");
    }
    
    function testUpdateOracle() public {
        vm.prank(owner);
        resolution.addOracle(oracle1, 100, "Oracle 1");
        
        vm.prank(owner);
        resolution.updateOracle(oracle1, 200, false);
        
        (
            uint256 weight,
            bool active,
            , , ,
        ) = resolution.getOracle(oracle1);
        
        assertEq(weight, 200);
        assertFalse(active);
    }
    
    function testUpdateOracleOnlyOwner() public {
        vm.prank(owner);
        resolution.addOracle(oracle1, 100, "Oracle 1");
        
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        resolution.updateOracle(oracle1, 200, false);
    }
    
    function testUpdateOracleNotExists() public {
        vm.prank(owner);
        vm.expectRevert("Oracle does not exist");
        resolution.updateOracle(oracle1, 200, false);
    }
    
    function testAuthorizeMarket() public {
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        
        // Note: authorizedMarkets is private, so we test through requestResolution
    }
    
    function testAuthorizeMarketOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        resolution.authorizeMarket(address(market));
    }
    
    function testLinkFundingContract() public {
        vm.prank(owner);
        resolution.linkFundingContract(address(market), address(funding));
        
        address[] memory contracts = resolution.getFundingContracts(address(market));
        assertEq(contracts.length, 1);
        assertEq(contracts[0], address(funding));
    }
    
    function testLinkFundingContractOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        resolution.linkFundingContract(address(market), address(funding));
    }
    
    function testRequestResolution() public {
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        uint256 requestId = resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin reached $100k"
        );
        vm.stopPrank();
        
        assertEq(requestId, 1);
        
        (
            address marketAddr,
            address requester,
            PredictionMarket.Outcome outcome,
            string memory evidence,
            uint256 timestamp,
            uint256 votingDeadline,
            bool resolved,
            uint256 votesFor,
            uint256 votesAgainst
        ) = resolution.getResolutionRequest(requestId);
        
        assertEq(marketAddr, address(market));
        assertEq(requester, alice);
        assertEq(uint256(outcome), uint256(PredictionMarket.Outcome.YES));
        assertEq(evidence, "Bitcoin reached $100k");
        assertEq(resolved, false);
        assertEq(votesFor, 0);
        assertEq(votesAgainst, 0);
    }
    
    function testRequestResolutionNotAuthorized() public {
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        vm.expectRevert("Market not authorized");
        resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test"
        );
        vm.stopPrank();
    }
    
    function testRequestResolutionAlreadyResolved() public {
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        
        vm.warp(block.timestamp + 30 days + 1);
        market.resolveMarket(PredictionMarket.Outcome.YES);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        vm.expectRevert("Market already resolved");
        resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test"
        );
        vm.stopPrank();
    }
    
    function testRequestResolutionTimeNotReached() public {
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        vm.expectRevert("Resolution time not reached");
        resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test"
        );
        vm.stopPrank();
    }
    
    function testVoteOnResolution() public {
        // Setup
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        resolution.addOracle(oracle1, 100, "Oracle 1");
        resolution.addOracle(oracle2, 150, "Oracle 2");
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        uint256 requestId = resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test"
        );
        vm.stopPrank();
        
        // Vote
        vm.prank(oracle1);
        resolution.voteOnResolution(requestId, true);
        
        vm.prank(oracle2);
        resolution.voteOnResolution(requestId, false);
        
        (
            , , , , , , , uint256 votesFor, uint256 votesAgainst
        ) = resolution.getResolutionRequest(requestId);
        
        assertEq(votesFor, 100);
        assertEq(votesAgainst, 150);
    }
    
    function testVoteOnResolutionNotOracle() public {
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        uint256 requestId = resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test"
        );
        vm.stopPrank();
        
        vm.prank(alice);
        vm.expectRevert("Not an active oracle");
        resolution.voteOnResolution(requestId, true);
    }
    
    function testVoteOnResolutionRequestNotExists() public {
        vm.prank(owner);
        resolution.addOracle(oracle1, 100, "Oracle 1");
        
        vm.prank(oracle1);
        vm.expectRevert("Request does not exist");
        resolution.voteOnResolution(999, true);
    }
    
    function testVoteOnResolutionVotingEnded() public {
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        resolution.addOracle(oracle1, 100, "Oracle 1");
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        uint256 requestId = resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test"
        );
        vm.stopPrank();
        
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        
        vm.prank(oracle1);
        vm.expectRevert("Voting period ended");
        resolution.voteOnResolution(requestId, true);
    }
    
    function testVoteOnResolutionAlreadyVoted() public {
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        resolution.addOracle(oracle1, 100, "Oracle 1");
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        uint256 requestId = resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test"
        );
        vm.stopPrank();
        
        vm.prank(oracle1);
        resolution.voteOnResolution(requestId, true);
        
        vm.prank(oracle1);
        vm.expectRevert("Already voted");
        resolution.voteOnResolution(requestId, false);
    }
    
    function testExecuteResolutionApproved() public {
        // Setup
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        resolution.addOracle(oracle1, 100, "Oracle 1");
        resolution.addOracle(oracle2, 50, "Oracle 2");
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        uint256 requestId = resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test"
        );
        vm.stopPrank();
        
        vm.prank(oracle1);
        resolution.voteOnResolution(requestId, true);
        
        vm.prank(oracle2);
        resolution.voteOnResolution(requestId, false);
        
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        resolution.executeResolution(requestId);
        
        // Alice should get bond back
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore + RESOLUTION_BOND);
        
        // Market should be resolved
        assertTrue(market.isResolved());
        assertEq(uint256(market.outcome()), uint256(PredictionMarket.Outcome.YES));
        
        (
            , , , , , , bool resolved, ,
        ) = resolution.getResolutionRequest(requestId);
        assertTrue(resolved);
    }
    
    function testExecuteResolutionRejected() public {
        // Setup
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        resolution.addOracle(oracle1, 50, "Oracle 1");
        resolution.addOracle(oracle2, 100, "Oracle 2");
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        uint256 requestId = resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test"
        );
        vm.stopPrank();
        
        vm.prank(oracle1);
        resolution.voteOnResolution(requestId, true);
        
        vm.prank(oracle2);
        resolution.voteOnResolution(requestId, false);
        
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        resolution.executeResolution(requestId);
        
        // Alice should not get bond back
        assertEq(usdc.balanceOf(alice), aliceBalanceBefore);
        
        // Market should not be resolved
        assertFalse(market.isResolved());
        
        (
            , , , , , , bool resolved, ,
        ) = resolution.getResolutionRequest(requestId);
        assertTrue(resolved);
    }
    
    function testExecuteResolutionStillActive() public {
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        resolution.addOracle(oracle1, 100, "Oracle 1");
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        uint256 requestId = resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test"
        );
        vm.stopPrank();
        
        vm.expectRevert("Voting still active");
        resolution.executeResolution(requestId);
    }
    
    function testExecuteResolutionNotExists() public {
        vm.expectRevert("Request does not exist");
        resolution.executeResolution(999);
    }
    
    function testExecuteResolutionAlreadyResolved() public {
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        resolution.addOracle(oracle1, 100, "Oracle 1");
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        uint256 requestId = resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test"
        );
        vm.stopPrank();
        
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        
        resolution.executeResolution(requestId);
        
        vm.expectRevert("Already resolved");
        resolution.executeResolution(requestId);
    }
    
    function testDistributeRevenue() public {
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        resolution.linkFundingContract(address(market), address(funding));
        
        vm.startPrank(owner);
        usdc.approve(address(resolution), 5000e6);
        resolution.distributeRevenue(
            address(market),
            address(funding),
            5000e6,
            "IP Rights"
        );
        vm.stopPrank();
        
        // Check that revenue was added to funding contract
        (, , , , , uint256 totalRevenue, ) = funding.getFundingRoundInfo();
        assertEq(totalRevenue, 5000e6);
    }
    
    function testDistributeRevenueOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        resolution.distributeRevenue(
            address(market),
            address(funding),
            1000e6,
            "Test"
        );
    }
    
    function testDistributeRevenueZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert("Amount must be greater than 0");
        resolution.distributeRevenue(
            address(market),
            address(funding),
            0,
            "Test"
        );
    }
    
    function testGetOracleAccuracy() public {
        vm.prank(owner);
        resolution.addOracle(oracle1, 100, "Oracle 1");
        
        assertEq(resolution.getOracleAccuracy(oracle1), 0);
        
        // After some resolutions, accuracy should be calculated
        // This would require setting up a full resolution cycle
    }
    
    function testSetMinimumVotingPeriod() public {
        vm.prank(owner);
        resolution.setMinimumVotingPeriod(5 days);
        
        assertEq(resolution.minimumVotingPeriod(), 5 days);
    }
    
    function testSetMinimumVotingPeriodOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        resolution.setMinimumVotingPeriod(5 days);
    }
    
    function testSetResolutionBond() public {
        vm.prank(owner);
        resolution.setResolutionBond(200e6);
        
        assertEq(resolution.resolutionBond(), 200e6);
    }
    
    function testSetResolutionBondOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        resolution.setResolutionBond(200e6);
    }
    
    function testWithdrawBonds() public {
        // Setup a failed resolution to accumulate bonds
        vm.prank(owner);
        resolution.authorizeMarket(address(market));
        resolution.addOracle(oracle1, 100, "Oracle 1");
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.startPrank(alice);
        usdc.approve(address(resolution), RESOLUTION_BOND);
        uint256 requestId = resolution.requestResolution(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test"
        );
        vm.stopPrank();
        
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        resolution.executeResolution(requestId); // This will fail, bond stays
        
        uint256 ownerBalanceBefore = usdc.balanceOf(owner);
        
        vm.prank(owner);
        resolution.withdrawBonds(RESOLUTION_BOND);
        
        assertEq(usdc.balanceOf(owner), ownerBalanceBefore + RESOLUTION_BOND);
    }
    
    function testWithdrawBondsOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        resolution.withdrawBonds(1000e6);
    }
    
    function testWithdrawBondsInsufficientBalance() public {
        vm.prank(owner);
        vm.expectRevert("Insufficient balance");
        resolution.withdrawBonds(1000000e6);
    }
} 