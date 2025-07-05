// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/OutcomeFundingFactory.sol";
import "../src/PredictionMarket.sol";
import "../src/MarketResolution.sol";
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
    MarketResolution public resolution;
    MockUSDC public usdc;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    
    function setUp() public {
        usdc = new MockUSDC();
        resolution = new MarketResolution(address(usdc), address(0));
        
        factory = new OutcomeFundingFactory(address(usdc));
        factory.transferOwnership(owner);
        
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
        assertEq(address(factory.usdc()), address(usdc));
        assertEq(factory.owner(), owner);
        assertEq(factory.creationFee(), 50e6);
        assertEq(factory.platformFeeRate(), 250);
    }
    
    function testSetResolutionContract() public {
        vm.prank(owner);
        factory.setResolutionContract(address(resolution));
        
        assertEq(address(factory.resolutionContract()), address(resolution));
    }
    
    function testSetResolutionContractOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setResolutionContract(address(resolution));
    }
    
    function testCreateFundingContract() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        address fundingAddress = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k YES Fund",
            "Description",
            "Bitcoin $100k YES Fund",
            "BTC100Y"
        );
        vm.stopPrank();
        
        assertTrue(fundingAddress != address(0));
        
        OutcomeFunding funding = OutcomeFunding(fundingAddress);
        assertEq(funding.name(), "Bitcoin $100k YES Fund");
        assertEq(funding.symbol(), "BTC100Y");
        assertEq(address(funding.usdc()), address(usdc));
        assertEq(address(funding.market()), address(market));
        assertEq(uint256(funding.targetOutcome()), uint256(PredictionMarket.Outcome.YES));
    }
    
    function testCreateFundingContractInvalidMarket() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        vm.expectRevert("Invalid market address");
        factory.createFundingContract(
            address(0),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k YES Fund",
            "Description",
            "Bitcoin $100k YES Fund",
            "BTC100Y"
        );
        vm.stopPrank();
    }
    
    function testCreateFundingContractEmptyTitle() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        vm.expectRevert("Title required");
        factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "",
            "Description",
            "Bitcoin $100k YES Fund",
            "BTC100Y"
        );
        vm.stopPrank();
    }
    
    function testCreateFundingContractEmptyTokenName() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        vm.expectRevert("Token name required");
        factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k YES Fund",
            "Description",
            "",
            "BTC100Y"
        );
        vm.stopPrank();
    }
    
    function testCreateFundingContractEmptyTokenSymbol() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        vm.expectRevert("Token symbol required");
        factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k YES Fund",
            "Description",
            "Bitcoin $100k YES Fund",
            ""
        );
        vm.stopPrank();
    }
    
    function testCreateMultipleFundingContracts() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 100e6);
        
        PredictionMarket.Outcome[] memory outcomes = new PredictionMarket.Outcome[](2);
        string[] memory titles = new string[](2);
        string[] memory descriptions = new string[](2);
        string[] memory tokenNames = new string[](2);
        string[] memory tokenSymbols = new string[](2);
        
        outcomes[0] = PredictionMarket.Outcome.YES;
        outcomes[1] = PredictionMarket.Outcome.NO;
        titles[0] = "Bitcoin $100k YES Fund";
        titles[1] = "Bitcoin $100k NO Fund";
        descriptions[0] = "Description 1";
        descriptions[1] = "Description 2";
        tokenNames[0] = "Bitcoin $100k YES Fund";
        tokenNames[1] = "Bitcoin $100k NO Fund";
        tokenSymbols[0] = "BTC100Y";
        tokenSymbols[1] = "BTC100N";
        
        address[] memory fundingAddresses = factory.createMultipleFundingContracts(
            address(market),
            outcomes,
            titles,
            descriptions,
            tokenNames,
            tokenSymbols
        );
        vm.stopPrank();
        
        assertEq(fundingAddresses.length, 2);
        assertTrue(fundingAddresses[0] != address(0));
        assertTrue(fundingAddresses[1] != address(0));
        assertTrue(fundingAddresses[0] != fundingAddresses[1]);
    }
    
    function testCreateMultipleFundingContractsArrayMismatch() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 100e6);
        
        PredictionMarket.Outcome[] memory outcomes = new PredictionMarket.Outcome[](2);
        string[] memory titles = new string[](1);
        string[] memory descriptions = new string[](2);
        string[] memory tokenNames = new string[](2);
        string[] memory tokenSymbols = new string[](2);
        
        outcomes[0] = PredictionMarket.Outcome.YES;
        outcomes[1] = PredictionMarket.Outcome.NO;
        titles[0] = "Bitcoin $100k YES Fund";
        descriptions[0] = "Description 1";
        descriptions[1] = "Description 2";
        tokenNames[0] = "Bitcoin $100k YES Fund";
        tokenNames[1] = "Bitcoin $100k NO Fund";
        tokenSymbols[0] = "BTC100Y";
        tokenSymbols[1] = "BTC100N";
        
        vm.expectRevert("Array length mismatch");
        factory.createMultipleFundingContracts(
            address(market),
            outcomes,
            titles,
            descriptions,
            tokenNames,
            tokenSymbols
        );
        vm.stopPrank();
    }
    
    function testUpdateFundingContractStatus() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        address fundingAddress = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k YES Fund",
            "Description",
            "Bitcoin $100k YES Fund",
            "BTC100Y"
        );
        vm.stopPrank();
        
        vm.prank(owner);
        factory.updateFundingContractStatus(fundingAddress, false);
        
        (
            , , , , bool active, ,
        ) = factory.getFundingContractInfo(fundingAddress);
        
        assertFalse(active);
    }
    
    function testUpdateFundingContractStatusOnlyOwner() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        address fundingAddress = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k YES Fund",
            "Description",
            "Bitcoin $100k YES Fund",
            "BTC100Y"
        );
        vm.stopPrank();
        
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.updateFundingContractStatus(fundingAddress, false);
    }
    
    function testUpdateFundingContractStatusNotFound() public {
        vm.prank(owner);
        vm.expectRevert("Funding contract not found");
        factory.updateFundingContractStatus(address(0x999), false);
    }
    
    function testGetFundingContractsForMarket() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 100e6);
        
        address funding1 = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Fund 1",
            "Description 1",
            "Fund 1",
            "FUND1"
        );
        
        address funding2 = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.NO,
            "Fund 2",
            "Description 2",
            "Fund 2",
            "FUND2"
        );
        vm.stopPrank();
        
        address[] memory marketFundings = factory.getFundingContractsForMarket(address(market));
        
        assertEq(marketFundings.length, 2);
        assertEq(marketFundings[0], funding1);
        assertEq(marketFundings[1], funding2);
    }
    
    function testGetFundingContractsByCreator() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 100e6);
        
        address funding1 = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Fund 1",
            "Description 1",
            "Fund 1",
            "FUND1"
        );
        
        address funding2 = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.NO,
            "Fund 2",
            "Description 2",
            "Fund 2",
            "FUND2"
        );
        vm.stopPrank();
        
        address[] memory creatorFundings = factory.getFundingContractsByCreator(alice);
        
        assertEq(creatorFundings.length, 2);
        assertEq(creatorFundings[0], funding1);
        assertEq(creatorFundings[1], funding2);
    }
    
    function testGetAllFundingContracts() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 100e6);
        
        address funding1 = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Fund 1",
            "Description 1",
            "Fund 1",
            "FUND1"
        );
        
        address funding2 = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.NO,
            "Fund 2",
            "Description 2",
            "Fund 2",
            "FUND2"
        );
        vm.stopPrank();
        
        address[] memory allFundings = factory.getAllFundingContracts();
        
        assertEq(allFundings.length, 2);
        assertEq(allFundings[0], funding1);
        assertEq(allFundings[1], funding2);
    }
    
    function testGetFundingContractInfo() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        address fundingAddress = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Bitcoin $100k YES Fund",
            "Description",
            "Bitcoin $100k YES Fund",
            "BTC100Y"
        );
        vm.stopPrank();
        
        (
            address marketAddress,
            PredictionMarket.Outcome targetOutcome,
            uint256 createdAt,
            address creator,
            bool active,
            string memory title,
            string memory description
        ) = factory.getFundingContractInfo(fundingAddress);
        
        assertEq(marketAddress, address(market));
        assertEq(uint256(targetOutcome), uint256(PredictionMarket.Outcome.YES));
        assertGt(createdAt, 0);
        assertEq(creator, alice);
        assertTrue(active);
        assertEq(title, "Bitcoin $100k YES Fund");
        assertEq(description, "Description");
    }
    
    function testFuzzCreateFundingContract(string memory title, string memory description, string memory tokenName, string memory tokenSymbol) public {
        vm.assume(bytes(title).length > 0 && bytes(title).length <= 100);
        vm.assume(bytes(description).length <= 500);
        vm.assume(bytes(tokenName).length > 0 && bytes(tokenName).length <= 50);
        vm.assume(bytes(tokenSymbol).length > 0 && bytes(tokenSymbol).length <= 10);
        
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        address fundingAddress = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            title,
            description,
            tokenName,
            tokenSymbol
        );
        vm.stopPrank();
        
        assertTrue(fundingAddress != address(0));
        
        OutcomeFunding funding = OutcomeFunding(fundingAddress);
        assertEq(funding.name(), tokenName);
        assertEq(funding.symbol(), tokenSymbol);
    }
    
    function testInvariantFundingContractCount() public {
        uint256 initialCount = factory.getAllFundingContracts().length;
        
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test Fund",
            "Description",
            "Test Fund",
            "TEST"
        );
        vm.stopPrank();
        
        assertEq(factory.getAllFundingContracts().length, initialCount + 1);
    }
    
    function testEventEmission() public {
        vm.expectEmit(true, true, false, true);
        emit OutcomeFundingFactory.FundingContractCreated(
            address(0), // Will be set by the factory
            address(market),
            alice,
            PredictionMarket.Outcome.YES,
            "Test Fund"
        );
        
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test Fund",
            "Description",
            "Test Fund",
            "TEST"
        );
        vm.stopPrank();
    }
    
    function testStatusUpdateEventEmission() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        address fundingAddress = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test Fund",
            "Description",
            "Test Fund",
            "TEST"
        );
        vm.stopPrank();
        
        vm.expectEmit(true, true, false, true);
        emit OutcomeFundingFactory.FundingContractStatusUpdated(fundingAddress, false);
        
        vm.prank(owner);
        factory.updateFundingContractStatus(fundingAddress, false);
    }
    
    function testMultipleUsersCreatingFundings() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        address aliceFunding = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Alice Fund",
            "Description",
            "Alice Fund",
            "ALICE"
        );
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.approve(address(factory), 50e6);
        
        address bobFunding = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.NO,
            "Bob Fund",
            "Description",
            "Bob Fund",
            "BOB"
        );
        vm.stopPrank();
        
        vm.startPrank(charlie);
        usdc.approve(address(factory), 50e6);
        
        address charlieFunding = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Charlie Fund",
            "Description",
            "Charlie Fund",
            "CHARLIE"
        );
        vm.stopPrank();
        
        assertTrue(aliceFunding != address(0));
        assertTrue(bobFunding != address(0));
        assertTrue(charlieFunding != address(0));
        
        address[] memory allFundings = factory.getAllFundingContracts();
        assertEq(allFundings.length, 3);
        
        address[] memory aliceFundings = factory.getFundingContractsByCreator(alice);
        assertEq(aliceFundings.length, 1);
        assertEq(aliceFundings[0], aliceFunding);
        
        address[] memory bobFundings = factory.getFundingContractsByCreator(bob);
        assertEq(bobFundings.length, 1);
        assertEq(bobFundings[0], bobFunding);
        
        address[] memory charlieFundings = factory.getFundingContractsByCreator(charlie);
        assertEq(charlieFundings.length, 1);
        assertEq(charlieFundings[0], charlieFunding);
    }
} 