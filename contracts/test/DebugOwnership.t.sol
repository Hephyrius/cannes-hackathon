// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/OutcomeFundingFactory.sol";
import "../src/MarketResolution.sol";
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

contract DebugOwnershipTest is Test {
    OutcomeFundingFactory public factory;
    MarketResolution public resolution;
    PredictionMarket public market;
    MockUSDC public usdc;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    
    function setUp() public {
        // Deploy contracts - same as integration test
        usdc = new MockUSDC();
        factory = new OutcomeFundingFactory(address(usdc));
        resolution = new MarketResolution(address(usdc), address(0));
        
        // Create market
        market = new PredictionMarket(
            address(usdc),
            "Will Bitcoin reach $100k by 2024?",
            block.timestamp + 30 days
        );
        
        // Setup ownership - same as integration test
        factory.transferOwnership(owner);
        resolution.transferOwnership(owner);
        
        // Configure resolution system - same as integration test
        vm.startPrank(owner);
        factory.setResolutionContract(address(resolution));
        resolution.addOracle(alice, 100, "Test Oracle");
        resolution.authorizeMarket(address(market));
        vm.stopPrank();
        
        // Mint USDC to test accounts
        usdc.mint(alice, 50000e6);
        usdc.mint(owner, 100000e6);
    }
    
    function testOwnershipDebug() public {
        console.log("=== Testing Ownership Debug ===");
        
        // 1. Alice creates a funding contract
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        console.log("Alice address:", alice);
        console.log("Factory owner:", factory.owner());
        
        address fundingContract = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k Fund",
            "Fund to support Bitcoin reaching $100k",
            "BTC100Y",
            "BTC100Y"
        );
        vm.stopPrank();
        
        console.log("Funding contract created at:", fundingContract);
        
        // 2. Check ownership immediately
        OutcomeFunding funding = OutcomeFunding(fundingContract);
        address fundingOwner = funding.owner();
        
        console.log("Funding contract owner:", fundingOwner);
        console.log("Alice address:", alice);
        console.log("Are they equal?", fundingOwner == alice);
        
        // 3. Try to start funding round
        vm.prank(alice);
        try funding.startFundingRound(10000e6, 7 days) {
            console.log("SUCCESS: Alice can start funding round");
        } catch {
            console.log("FAILED: Alice cannot start funding round");
            console.log("Current owner:", funding.owner());
        }
    }
} 