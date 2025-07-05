// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/OutcomeFundingFactory.sol";
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

contract OutcomeFundingFactoryTest is Test {
    OutcomeFundingFactory public factory;
    PredictionMarket public market;
    MockUSDC public usdc;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    
    function setUp() public {
        usdc = new MockUSDC();
        
        market = new PredictionMarket(
            address(usdc),
            "Will Bitcoin reach $100k by 2024?",
            block.timestamp + 30 days
        );
        
        factory = new OutcomeFundingFactory();
        factory.transferOwnership(owner);
        
        usdc.mint(alice, 50000e6);
        usdc.mint(bob, 30000e6);
        usdc.mint(owner, 100000e6);
    }
    
    function testConstructor() public view {
        assertEq(factory.owner(), owner);
    }
    
    function testCreateOutcomeFunding() public {
        vm.prank(owner);
        address fundingAddress = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k YES Fund",
            "BTC100Y"
        );
        
        assertTrue(fundingAddress != address(0));
        
        OutcomeFunding funding = OutcomeFunding(fundingAddress);
        assertEq(funding.name(), "Bitcoin $100k YES Fund");
        assertEq(funding.symbol(), "BTC100Y");
        assertEq(address(funding.usdc()), address(usdc));
        assertEq(address(funding.market()), address(market));
        assertEq(uint256(funding.targetOutcome()), uint256(PredictionMarket.Outcome.YES));
    }
    
    function testCreateOutcomeFundingOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k YES Fund",
            "BTC100Y"
        );
    }
    
    function testCreateMultipleOutcomeFundings() public {
        vm.startPrank(owner);
        
        address funding1 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k YES Fund",
            "BTC100Y"
        );
        
        address funding2 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.NO,
            "Bitcoin $100k NO Fund",
            "BTC100N"
        );
        
        vm.stopPrank();
        
        assertTrue(funding1 != address(0));
        assertTrue(funding2 != address(0));
        assertTrue(funding1 != funding2);
        
        OutcomeFunding yesFunding = OutcomeFunding(funding1);
        OutcomeFunding noFunding = OutcomeFunding(funding2);
        
        assertEq(yesFunding.name(), "Bitcoin $100k YES Fund");
        assertEq(noFunding.name(), "Bitcoin $100k NO Fund");
        assertEq(uint256(yesFunding.targetOutcome()), uint256(PredictionMarket.Outcome.YES));
        assertEq(uint256(noFunding.targetOutcome()), uint256(PredictionMarket.Outcome.NO));
    }
    
    function testCreateOutcomeFundingWithDifferentMarkets() public {
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Will Ethereum reach $10k by 2024?",
            block.timestamp + 30 days
        );
        
        vm.startPrank(owner);
        
        address funding1 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k YES Fund",
            "BTC100Y"
        );
        
        address funding2 = factory.createOutcomeFunding(
            address(usdc),
            address(market2),
            PredictionMarket.Outcome.YES,
            "Ethereum $10k YES Fund",
            "ETH10Y"
        );
        
        vm.stopPrank();
        
        OutcomeFunding btcFunding = OutcomeFunding(funding1);
        OutcomeFunding ethFunding = OutcomeFunding(funding2);
        
        assertEq(address(btcFunding.market()), address(market));
        assertEq(address(ethFunding.market()), address(market2));
    }
    
    function testCreateOutcomeFundingWithDifferentTokens() public {
        MockUSDC usdc2 = new MockUSDC();
        
        vm.startPrank(owner);
        
        address funding1 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "USDC Fund",
            "USDCY"
        );
        
        address funding2 = factory.createOutcomeFunding(
            address(usdc2),
            address(market),
            PredictionMarket.Outcome.YES,
            "USDC2 Fund",
            "USDC2Y"
        );
        
        vm.stopPrank();
        
        OutcomeFunding funding1Contract = OutcomeFunding(funding1);
        OutcomeFunding funding2Contract = OutcomeFunding(funding2);
        
        assertEq(address(funding1Contract.usdc()), address(usdc));
        assertEq(address(funding2Contract.usdc()), address(usdc2));
    }
    
    function testGetOutcomeFundingCount() public {
        assertEq(factory.getOutcomeFundingCount(), 0);
        
        vm.startPrank(owner);
        
        factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "Fund 1",
            "FUND1"
        );
        assertEq(factory.getOutcomeFundingCount(), 1);
        
        factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.NO,
            "Fund 2",
            "FUND2"
        );
        assertEq(factory.getOutcomeFundingCount(), 2);
        
        factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "Fund 3",
            "FUND3"
        );
        assertEq(factory.getOutcomeFundingCount(), 3);
        
        vm.stopPrank();
    }
    
    function testGetOutcomeFundingByIndex() public {
        vm.startPrank(owner);
        
        address funding1 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "Fund 1",
            "FUND1"
        );
        
        address funding2 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.NO,
            "Fund 2",
            "FUND2"
        );
        
        address funding3 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "Fund 3",
            "FUND3"
        );
        
        vm.stopPrank();
        
        assertEq(factory.getOutcomeFundingByIndex(0), funding1);
        assertEq(factory.getOutcomeFundingByIndex(1), funding2);
        assertEq(factory.getOutcomeFundingByIndex(2), funding3);
    }
    
    function testGetOutcomeFundingByIndexOutOfBounds() public {
        vm.expectRevert("Index out of bounds");
        factory.getOutcomeFundingByIndex(0);
    }
    
    function testGetOutcomeFundingsByMarket() public {
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Will Ethereum reach $10k by 2024?",
            block.timestamp + 30 days
        );
        
        vm.startPrank(owner);
        
        address funding1 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "BTC YES",
            "BTCY"
        );
        
        address funding2 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.NO,
            "BTC NO",
            "BTCN"
        );
        
        address funding3 = factory.createOutcomeFunding(
            address(usdc),
            address(market2),
            PredictionMarket.Outcome.YES,
            "ETH YES",
            "ETHY"
        );
        
        vm.stopPrank();
        
        address[] memory btcFundings = factory.getOutcomeFundingsByMarket(address(market));
        address[] memory ethFundings = factory.getOutcomeFundingsByMarket(address(market2));
        
        assertEq(btcFundings.length, 2);
        assertEq(ethFundings.length, 1);
        
        assertEq(btcFundings[0], funding1);
        assertEq(btcFundings[1], funding2);
        assertEq(ethFundings[0], funding3);
    }
    
    function testGetOutcomeFundingsByMarketEmpty() public {
        address[] memory fundings = factory.getOutcomeFundingsByMarket(address(market));
        assertEq(fundings.length, 0);
    }
    
    function testGetOutcomeFundingsByOutcome() public {
        vm.startPrank(owner);
        
        address funding1 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "YES Fund 1",
            "YES1"
        );
        
        address funding2 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.NO,
            "NO Fund 1",
            "NO1"
        );
        
        address funding3 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "YES Fund 2",
            "YES2"
        );
        
        vm.stopPrank();
        
        address[] memory yesFundings = factory.getOutcomeFundingsByOutcome(PredictionMarket.Outcome.YES);
        address[] memory noFundings = factory.getOutcomeFundingsByOutcome(PredictionMarket.Outcome.NO);
        
        assertEq(yesFundings.length, 2);
        assertEq(noFundings.length, 1);
        
        assertEq(yesFundings[0], funding1);
        assertEq(yesFundings[1], funding3);
        assertEq(noFundings[0], funding2);
    }
    
    function testGetOutcomeFundingsByOutcomeEmpty() public {
        address[] memory yesFundings = factory.getOutcomeFundingsByOutcome(PredictionMarket.Outcome.YES);
        address[] memory noFundings = factory.getOutcomeFundingsByOutcome(PredictionMarket.Outcome.NO);
        
        assertEq(yesFundings.length, 0);
        assertEq(noFundings.length, 0);
    }
    
    function testGetOutcomeFundingsByMarketAndOutcome() public {
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Will Ethereum reach $10k by 2024?",
            block.timestamp + 30 days
        );
        
        vm.startPrank(owner);
        
        address funding1 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "BTC YES",
            "BTCY"
        );
        
        address funding2 = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.NO,
            "BTC NO",
            "BTCN"
        );
        
        address funding3 = factory.createOutcomeFunding(
            address(usdc),
            address(market2),
            PredictionMarket.Outcome.YES,
            "ETH YES",
            "ETHY"
        );
        
        vm.stopPrank();
        
        address[] memory btcYesFundings = factory.getOutcomeFundingsByMarketAndOutcome(
            address(market),
            PredictionMarket.Outcome.YES
        );
        
        address[] memory btcNoFundings = factory.getOutcomeFundingsByMarketAndOutcome(
            address(market),
            PredictionMarket.Outcome.NO
        );
        
        address[] memory ethYesFundings = factory.getOutcomeFundingsByMarketAndOutcome(
            address(market2),
            PredictionMarket.Outcome.YES
        );
        
        assertEq(btcYesFundings.length, 1);
        assertEq(btcNoFundings.length, 1);
        assertEq(ethYesFundings.length, 1);
        
        assertEq(btcYesFundings[0], funding1);
        assertEq(btcNoFundings[0], funding2);
        assertEq(ethYesFundings[0], funding3);
    }
    
    function testGetOutcomeFundingsByMarketAndOutcomeEmpty() public {
        address[] memory fundings = factory.getOutcomeFundingsByMarketAndOutcome(
            address(market),
            PredictionMarket.Outcome.YES
        );
        assertEq(fundings.length, 0);
    }
    
    function testEventEmission() public {
        vm.expectEmit(true, true, false, true);
        emit OutcomeFundingFactory.OutcomeFundingCreated(
            address(0), // Will be set by the factory
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "Test Fund",
            "TEST"
        );
        
        vm.prank(owner);
        factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "Test Fund",
            "TEST"
        );
    }
    
    function testFuzzCreateOutcomeFunding(string memory name, string memory symbol) public {
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 50);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);
        
        vm.prank(owner);
        address fundingAddress = factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            name,
            symbol
        );
        
        assertTrue(fundingAddress != address(0));
        
        OutcomeFunding funding = OutcomeFunding(fundingAddress);
        assertEq(funding.name(), name);
        assertEq(funding.symbol(), symbol);
    }
    
    function testInvariantOutcomeFundingCount() public {
        // This invariant test ensures that the count is always accurate
        uint256 count = factory.getOutcomeFundingCount();
        
        // Create a new funding
        vm.prank(owner);
        factory.createOutcomeFunding(
            address(usdc),
            address(market),
            PredictionMarket.Outcome.YES,
            "Test Fund",
            "TEST"
        );
        
        assertEq(factory.getOutcomeFundingCount(), count + 1);
    }
} 