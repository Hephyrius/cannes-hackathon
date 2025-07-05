// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/PredictionMarketNFTFactory.sol";
import "../src/PredictionMarket.sol";
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

contract PredictionMarketNFTFactoryTest is Test {
    PredictionMarketNFTFactory public factory;
    StagedPredictionMarket public stagedMarket;
    MockUSDC public usdc;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    
    function setUp() public {
        usdc = new MockUSDC();
        stagedMarket = new StagedPredictionMarket(
            address(0), // factory
            address(0), // voting
            address(usdc)
        );
        
        factory = new PredictionMarketNFTFactory(
            address(usdc),
            "Prediction Market NFT",
            "PMNFT",
            "https://example.com/images/"
        );
        factory.transferOwnership(owner);
        
        usdc.mint(alice, 50000e6);
        usdc.mint(bob, 30000e6);
        usdc.mint(charlie, 20000e6);
        usdc.mint(owner, 100000e6);
    }
    
    function testConstructor() public view {
        assertEq(factory.owner(), owner);
        assertEq(address(factory.usdc()), address(usdc));
        assertEq(factory.marketCreationFee(), 1e6);
        assertEq(factory.nftContract().name(), "Prediction Market NFT");
        assertEq(factory.nftContract().symbol(), "PMNFT");
    }
    
    function testSetStagedMarketManager() public {
        vm.prank(owner);
        factory.setStagedMarketManager(address(stagedMarket));
        
        assertEq(address(factory.stagedMarketManager()), address(stagedMarket));
    }
    
    function testSetStagedMarketManagerOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setStagedMarketManager(address(stagedMarket));
    }
    
    function testSetMarketCreationFee() public {
        vm.prank(owner);
        factory.setMarketCreationFee(2e6);
        
        assertEq(factory.marketCreationFee(), 2e6);
    }
    
    function testSetMarketCreationFeeOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setMarketCreationFee(2e6);
    }
    
    function testCreateMarketWithNFT() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 1e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory params = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Bitcoin reach $100k by 2024?",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        (address marketAddress, uint256 nftTokenId) = factory.createMarketWithNFT(params);
        vm.stopPrank();
        
        assertTrue(marketAddress != address(0));
        assertEq(nftTokenId, 1);
        
        PredictionMarket market = PredictionMarket(marketAddress);
        assertEq(market.question(), "Will Bitcoin reach $100k by 2024?");
        assertEq(market.resolutionTime(), block.timestamp + 30 days);
        assertEq(market.owner(), alice);
        
        PredictionMarketNFT nft = factory.nftContract();
        assertEq(nft.ownerOf(nftTokenId), alice);
        assertEq(nft.marketToTokenId(marketAddress), nftTokenId);
    }
    
    function testCreateMarketWithNFTInvalidResolutionTime() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 1e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory params = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Bitcoin reach $100k by 2024?",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp - 1, // Past time
            category: "Crypto",
            tags: new string[](0)
        });
        
        vm.expectRevert("Resolution time must be in future");
        factory.createMarketWithNFT(params);
        vm.stopPrank();
    }
    
    function testCreateMarketWithNFTEmptyQuestion() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 1e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory params = PredictionMarketNFTFactory.MarketCreationParams({
            question: "",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        vm.expectRevert("Question cannot be empty");
        factory.createMarketWithNFT(params);
        vm.stopPrank();
    }
    
    function testBatchCreateMarkets() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 3e6);
        
        PredictionMarketNFTFactory.MarketCreationParams[] memory params = new PredictionMarketNFTFactory.MarketCreationParams[](2);
        params[0] = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Bitcoin reach $100k by 2024?",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        params[1] = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Ethereum reach $10k by 2024?",
            description: "Ethereum price prediction",
            imageUrl: "https://example.com/eth.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        (address[] memory marketAddresses, uint256[] memory nftTokenIds) = factory.batchCreateMarkets(params);
        vm.stopPrank();
        
        assertEq(marketAddresses.length, 2);
        assertEq(nftTokenIds.length, 2);
        
        assertTrue(marketAddresses[0] != address(0));
        assertTrue(marketAddresses[1] != address(0));
        assertEq(nftTokenIds[0], 1);
        assertEq(nftTokenIds[1], 2);
    }
    
    function testBatchCreateMarketsInvalidSize() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 12e6);
        
        PredictionMarketNFTFactory.MarketCreationParams[] memory params = new PredictionMarketNFTFactory.MarketCreationParams[](11);
        for (uint256 i = 0; i < 11; i++) {
            params[i] = PredictionMarketNFTFactory.MarketCreationParams({
                question: string(abi.encodePacked("Question ", i.toString())),
                description: "Description",
                imageUrl: "",
                resolutionTime: block.timestamp + 30 days,
                category: "Crypto",
                tags: new string[](0)
            });
        }
        
        vm.expectRevert("Invalid batch size");
        factory.batchCreateMarkets(params);
        vm.stopPrank();
    }
    
    function testBatchCreateMarketsEmptyArray() public {
        vm.startPrank(alice);
        
        PredictionMarketNFTFactory.MarketCreationParams[] memory params = new PredictionMarketNFTFactory.MarketCreationParams[](0);
        
        vm.expectRevert("Invalid batch size");
        factory.batchCreateMarkets(params);
        vm.stopPrank();
    }
    
    function testUpdateMarketResolution() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 1e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory params = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Bitcoin reach $100k by 2024?",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        (address marketAddress, uint256 nftTokenId) = factory.createMarketWithNFT(params);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.prank(alice);
        PredictionMarket(marketAddress).resolveMarket(PredictionMarket.Outcome.YES);
        
        vm.prank(owner);
        factory.updateMarketResolution(marketAddress);
        
        PredictionMarketNFT nft = factory.nftContract();
        string memory resolution = nft.getMarketResolution(nftTokenId);
        assertEq(resolution, "YES");
    }
    
    function testUpdateMarketResolutionNotResolved() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 1e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory params = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Bitcoin reach $100k by 2024?",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        (address marketAddress, ) = factory.createMarketWithNFT(params);
        vm.stopPrank();
        
        vm.prank(owner);
        vm.expectRevert("Market not resolved");
        factory.updateMarketResolution(marketAddress);
    }
    
    function testGetMarketsByCreator() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 2e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory params1 = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Bitcoin reach $100k by 2024?",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        PredictionMarketNFTFactory.MarketCreationParams memory params2 = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Ethereum reach $10k by 2024?",
            description: "Ethereum price prediction",
            imageUrl: "https://example.com/eth.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        (address market1, ) = factory.createMarketWithNFT(params1);
        (address market2, ) = factory.createMarketWithNFT(params2);
        vm.stopPrank();
        
        address[] memory aliceMarkets = factory.getMarketsByCreator(alice);
        assertEq(aliceMarkets.length, 2);
        assertEq(aliceMarkets[0], market1);
        assertEq(aliceMarkets[1], market2);
    }
    
    function testGetTotalMarkets() public {
        assertEq(factory.getTotalMarkets(), 0);
        
        vm.startPrank(alice);
        usdc.approve(address(factory), 2e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory params = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Bitcoin reach $100k by 2024?",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        factory.createMarketWithNFT(params);
        assertEq(factory.getTotalMarkets(), 1);
        
        factory.createMarketWithNFT(params);
        assertEq(factory.getTotalMarkets(), 2);
        vm.stopPrank();
    }
    
    function testGetMarketAtIndex() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 2e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory params = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Bitcoin reach $100k by 2024?",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        (address market1, ) = factory.createMarketWithNFT(params);
        (address market2, ) = factory.createMarketWithNFT(params);
        vm.stopPrank();
        
        assertEq(factory.getMarketAtIndex(0), market1);
        assertEq(factory.getMarketAtIndex(1), market2);
    }
    
    function testGetMarketAtIndexOutOfBounds() public {
        vm.expectRevert("Index out of bounds");
        factory.getMarketAtIndex(0);
    }
    
    function testGetMarketInfo() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 1e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory params = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Bitcoin reach $100k by 2024?",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        (address marketAddress, uint256 nftTokenId) = factory.createMarketWithNFT(params);
        vm.stopPrank();
        
        (
            string memory question,
            uint256 resolutionTime,
            bool isResolved,
            PredictionMarket.Outcome outcome,
            uint256 returnedNftTokenId,
            address nftOwner
        ) = factory.getMarketInfo(marketAddress);
        
        assertEq(question, "Will Bitcoin reach $100k by 2024?");
        assertEq(resolutionTime, block.timestamp + 30 days);
        assertFalse(isResolved);
        assertEq(uint256(outcome), 0);
        assertEq(returnedNftTokenId, nftTokenId);
        assertEq(nftOwner, alice);
    }
    
    function testFuzzCreateMarketWithNFT(string memory question, string memory description, string memory category) public {
        vm.assume(bytes(question).length > 0 && bytes(question).length <= 200);
        vm.assume(bytes(description).length <= 500);
        vm.assume(bytes(category).length <= 50);
        
        vm.startPrank(alice);
        usdc.approve(address(factory), 1e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory params = PredictionMarketNFTFactory.MarketCreationParams({
            question: question,
            description: description,
            imageUrl: "",
            resolutionTime: block.timestamp + 30 days,
            category: category,
            tags: new string[](0)
        });
        
        (address marketAddress, uint256 nftTokenId) = factory.createMarketWithNFT(params);
        vm.stopPrank();
        
        assertTrue(marketAddress != address(0));
        assertEq(nftTokenId, 1);
        
        PredictionMarket market = PredictionMarket(marketAddress);
        assertEq(market.question(), question);
    }
    
    function testInvariantMarketCount() public {
        uint256 initialCount = factory.getTotalMarkets();
        
        vm.startPrank(alice);
        usdc.approve(address(factory), 1e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory params = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Bitcoin reach $100k by 2024?",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        factory.createMarketWithNFT(params);
        vm.stopPrank();
        
        assertEq(factory.getTotalMarkets(), initialCount + 1);
    }
    
    function testEventEmission() public {
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketNFTFactory.MarketCreatedWithNFT(
            alice,
            address(0), // Will be set by the factory
            1,
            "Will Bitcoin reach $100k by 2024?"
        );
        
        vm.startPrank(alice);
        usdc.approve(address(factory), 1e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory params = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Bitcoin reach $100k by 2024?",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        factory.createMarketWithNFT(params);
        vm.stopPrank();
    }
    
    function testMultipleUsersCreatingMarkets() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 1e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory aliceParams = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Bitcoin reach $100k by 2024?",
            description: "Bitcoin price prediction",
            imageUrl: "https://example.com/btc.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        (address aliceMarket, ) = factory.createMarketWithNFT(aliceParams);
        vm.stopPrank();
        
        vm.startPrank(bob);
        usdc.approve(address(factory), 1e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory bobParams = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Ethereum reach $10k by 2024?",
            description: "Ethereum price prediction",
            imageUrl: "https://example.com/eth.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        (address bobMarket, ) = factory.createMarketWithNFT(bobParams);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        usdc.approve(address(factory), 1e6);
        
        PredictionMarketNFTFactory.MarketCreationParams memory charlieParams = PredictionMarketNFTFactory.MarketCreationParams({
            question: "Will Solana reach $500 by 2024?",
            description: "Solana price prediction",
            imageUrl: "https://example.com/sol.jpg",
            resolutionTime: block.timestamp + 30 days,
            category: "Crypto",
            tags: new string[](0)
        });
        
        (address charlieMarket, ) = factory.createMarketWithNFT(charlieParams);
        vm.stopPrank();
        
        assertTrue(aliceMarket != address(0));
        assertTrue(bobMarket != address(0));
        assertTrue(charlieMarket != address(0));
        
        address[] memory aliceMarkets = factory.getMarketsByCreator(alice);
        address[] memory bobMarkets = factory.getMarketsByCreator(bob);
        address[] memory charlieMarkets = factory.getMarketsByCreator(charlie);
        
        assertEq(aliceMarkets.length, 1);
        assertEq(bobMarkets.length, 1);
        assertEq(charlieMarkets.length, 1);
        
        assertEq(aliceMarkets[0], aliceMarket);
        assertEq(bobMarkets[0], bobMarket);
        assertEq(charlieMarkets[0], charlieMarket);
        
        assertEq(factory.getTotalMarkets(), 3);
    }
} 