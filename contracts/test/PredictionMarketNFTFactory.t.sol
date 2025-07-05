// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/PredictionMarketNFTFactory.sol";
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

contract PredictionMarketNFTFactoryTest is Test {
    PredictionMarketNFTFactory public factory;
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
        
        factory = new PredictionMarketNFTFactory();
        factory.transferOwnership(owner);
        
        usdc.mint(alice, 50000e6);
        usdc.mint(bob, 30000e6);
        usdc.mint(owner, 100000e6);
    }
    
    function testConstructor() public view {
        assertEq(factory.owner(), owner);
    }
    
    function testCreateNFT() public {
        vm.prank(owner);
        address nftAddress = factory.createNFT(
            address(market),
            "Bitcoin Market NFT",
            "BTCMNFT"
        );
        
        assertTrue(nftAddress != address(0));
        
        PredictionMarketNFT nft = PredictionMarketNFT(nftAddress);
        assertEq(nft.name(), "Bitcoin Market NFT");
        assertEq(nft.symbol(), "BTCMNFT");
        assertEq(address(nft.market()), address(market));
    }
    
    function testCreateNFTOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.createNFT(
            address(market),
            "Bitcoin Market NFT",
            "BTCMNFT"
        );
    }
    
    function testCreateMultipleNFTs() public {
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Will Ethereum reach $10k by 2024?",
            block.timestamp + 30 days
        );
        
        vm.startPrank(owner);
        
        address nft1 = factory.createNFT(
            address(market),
            "Bitcoin Market NFT",
            "BTCMNFT"
        );
        
        address nft2 = factory.createNFT(
            address(market2),
            "Ethereum Market NFT",
            "ETHMNFT"
        );
        
        vm.stopPrank();
        
        assertTrue(nft1 != address(0));
        assertTrue(nft2 != address(0));
        assertTrue(nft1 != nft2);
        
        PredictionMarketNFT nft1Contract = PredictionMarketNFT(nft1);
        PredictionMarketNFT nft2Contract = PredictionMarketNFT(nft2);
        
        assertEq(nft1Contract.name(), "Bitcoin Market NFT");
        assertEq(nft2Contract.name(), "Ethereum Market NFT");
        assertEq(address(nft1Contract.market()), address(market));
        assertEq(address(nft2Contract.market()), address(market2));
    }
    
    function testGetNFTCount() public {
        assertEq(factory.getNFTCount(), 0);
        
        vm.startPrank(owner);
        
        factory.createNFT(
            address(market),
            "NFT 1",
            "NFT1"
        );
        assertEq(factory.getNFTCount(), 1);
        
        factory.createNFT(
            address(market),
            "NFT 2",
            "NFT2"
        );
        assertEq(factory.getNFTCount(), 2);
        
        vm.stopPrank();
    }
    
    function testGetNFTByIndex() public {
        vm.startPrank(owner);
        
        address nft1 = factory.createNFT(
            address(market),
            "NFT 1",
            "NFT1"
        );
        
        address nft2 = factory.createNFT(
            address(market),
            "NFT 2",
            "NFT2"
        );
        
        address nft3 = factory.createNFT(
            address(market),
            "NFT 3",
            "NFT3"
        );
        
        vm.stopPrank();
        
        assertEq(factory.getNFTByIndex(0), nft1);
        assertEq(factory.getNFTByIndex(1), nft2);
        assertEq(factory.getNFTByIndex(2), nft3);
    }
    
    function testGetNFTByIndexOutOfBounds() public {
        vm.expectRevert("Index out of bounds");
        factory.getNFTByIndex(0);
    }
    
    function testGetNFTsByMarket() public {
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Will Ethereum reach $10k by 2024?",
            block.timestamp + 30 days
        );
        
        vm.startPrank(owner);
        
        address nft1 = factory.createNFT(
            address(market),
            "BTC NFT 1",
            "BTC1"
        );
        
        address nft2 = factory.createNFT(
            address(market),
            "BTC NFT 2",
            "BTC2"
        );
        
        address nft3 = factory.createNFT(
            address(market2),
            "ETH NFT 1",
            "ETH1"
        );
        
        vm.stopPrank();
        
        address[] memory btcNFTs = factory.getNFTsByMarket(address(market));
        address[] memory ethNFTs = factory.getNFTsByMarket(address(market2));
        
        assertEq(btcNFTs.length, 2);
        assertEq(ethNFTs.length, 1);
        
        assertEq(btcNFTs[0], nft1);
        assertEq(btcNFTs[1], nft2);
        assertEq(ethNFTs[0], nft3);
    }
    
    function testGetNFTsByMarketEmpty() public {
        address[] memory nfts = factory.getNFTsByMarket(address(market));
        assertEq(nfts.length, 0);
    }
    
    function testEventEmission() public {
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketNFTFactory.NFTCreated(
            address(0), // Will be set by the factory
            address(market),
            "Test NFT",
            "TEST"
        );
        
        vm.prank(owner);
        factory.createNFT(
            address(market),
            "Test NFT",
            "TEST"
        );
    }
    
    function testFuzzCreateNFT(string memory name, string memory symbol) public {
        vm.assume(bytes(name).length > 0 && bytes(name).length <= 50);
        vm.assume(bytes(symbol).length > 0 && bytes(symbol).length <= 10);
        
        vm.prank(owner);
        address nftAddress = factory.createNFT(
            address(market),
            name,
            symbol
        );
        
        assertTrue(nftAddress != address(0));
        
        PredictionMarketNFT nft = PredictionMarketNFT(nftAddress);
        assertEq(nft.name(), name);
        assertEq(nft.symbol(), symbol);
    }
    
    function testInvariantNFTCount() public {
        uint256 initialCount = factory.getNFTCount();
        
        vm.prank(owner);
        factory.createNFT(
            address(market),
            "Test NFT",
            "TEST"
        );
        
        assertEq(factory.getNFTCount(), initialCount + 1);
    }
    
    function testCreateNFTWithZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Market address cannot be zero");
        factory.createNFT(
            address(0),
            "Test NFT",
            "TEST"
        );
    }
    
    function testCreateNFTWithEmptyName() public {
        vm.prank(owner);
        vm.expectRevert("Name cannot be empty");
        factory.createNFT(
            address(market),
            "",
            "TEST"
        );
    }
    
    function testCreateNFTWithEmptySymbol() public {
        vm.prank(owner);
        vm.expectRevert("Symbol cannot be empty");
        factory.createNFT(
            address(market),
            "Test NFT",
            ""
        );
    }
    
    function testBatchCreateNFTs() public {
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Will Ethereum reach $10k by 2024?",
            block.timestamp + 30 days
        );
        
        PredictionMarket market3 = new PredictionMarket(
            address(usdc),
            "Will Solana reach $500 by 2024?",
            block.timestamp + 30 days
        );
        
        vm.startPrank(owner);
        
        address[] memory markets = new address[](3);
        string[] memory names = new string[](3);
        string[] memory symbols = new string[](3);
        
        markets[0] = address(market);
        markets[1] = address(market2);
        markets[2] = address(market3);
        
        names[0] = "Bitcoin NFT";
        names[1] = "Ethereum NFT";
        names[2] = "Solana NFT";
        
        symbols[0] = "BTCMNFT";
        symbols[1] = "ETHMNFT";
        symbols[2] = "SOLMNFT";
        
        address[] memory nftAddresses = factory.batchCreateNFTs(markets, names, symbols);
        
        vm.stopPrank();
        
        assertEq(nftAddresses.length, 3);
        assertTrue(nftAddresses[0] != address(0));
        assertTrue(nftAddresses[1] != address(0));
        assertTrue(nftAddresses[2] != address(0));
        
        PredictionMarketNFT nft1 = PredictionMarketNFT(nftAddresses[0]);
        PredictionMarketNFT nft2 = PredictionMarketNFT(nftAddresses[1]);
        PredictionMarketNFT nft3 = PredictionMarketNFT(nftAddresses[2]);
        
        assertEq(nft1.name(), "Bitcoin NFT");
        assertEq(nft2.name(), "Ethereum NFT");
        assertEq(nft3.name(), "Solana NFT");
        
        assertEq(address(nft1.market()), address(market));
        assertEq(address(nft2.market()), address(market2));
        assertEq(address(nft3.market()), address(market3));
    }
    
    function testBatchCreateNFTsOnlyOwner() public {
        address[] memory markets = new address[](1);
        string[] memory names = new string[](1);
        string[] memory symbols = new string[](1);
        
        markets[0] = address(market);
        names[0] = "Test NFT";
        symbols[0] = "TEST";
        
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.batchCreateNFTs(markets, names, symbols);
    }
    
    function testBatchCreateNFTsInvalidArrays() public {
        address[] memory markets = new address[](2);
        string[] memory names = new string[](1);
        string[] memory symbols = new string[](2);
        
        markets[0] = address(market);
        markets[1] = address(market);
        symbols[0] = "TEST1";
        symbols[1] = "TEST2";
        
        vm.prank(owner);
        vm.expectRevert("Arrays must have the same length");
        factory.batchCreateNFTs(markets, names, symbols);
    }
    
    function testBatchCreateNFTsEmptyArray() public {
        address[] memory markets = new address[](0);
        string[] memory names = new string[](0);
        string[] memory symbols = new string[](0);
        
        vm.prank(owner);
        vm.expectRevert("Arrays cannot be empty");
        factory.batchCreateNFTs(markets, names, symbols);
    }
    
    function testGetAllNFTs() public {
        vm.startPrank(owner);
        
        address nft1 = factory.createNFT(
            address(market),
            "NFT 1",
            "NFT1"
        );
        
        address nft2 = factory.createNFT(
            address(market),
            "NFT 2",
            "NFT2"
        );
        
        address nft3 = factory.createNFT(
            address(market),
            "NFT 3",
            "NFT3"
        );
        
        vm.stopPrank();
        
        address[] memory allNFTs = factory.getAllNFTs();
        
        assertEq(allNFTs.length, 3);
        assertEq(allNFTs[0], nft1);
        assertEq(allNFTs[1], nft2);
        assertEq(allNFTs[2], nft3);
    }
    
    function testGetAllNFTsEmpty() public {
        address[] memory allNFTs = factory.getAllNFTs();
        assertEq(allNFTs.length, 0);
    }
    
    function testNFTExists() public {
        vm.prank(owner);
        address nftAddress = factory.createNFT(
            address(market),
            "Test NFT",
            "TEST"
        );
        
        assertTrue(factory.nftExists(nftAddress));
        assertFalse(factory.nftExists(address(0x999)));
    }
    
    function testGetNFTsByMarketRange() public {
        vm.startPrank(owner);
        
        for (uint256 i = 0; i < 10; i++) {
            factory.createNFT(
                address(market),
                string(abi.encodePacked("NFT ", vm.toString(i))),
                string(abi.encodePacked("NFT", vm.toString(i)))
            );
        }
        
        vm.stopPrank();
        
        address[] memory nfts = factory.getNFTsByMarketRange(address(market), 0, 5);
        assertEq(nfts.length, 5);
        
        nfts = factory.getNFTsByMarketRange(address(market), 5, 10);
        assertEq(nfts.length, 5);
        
        nfts = factory.getNFTsByMarketRange(address(market), 0, 10);
        assertEq(nfts.length, 10);
    }
    
    function testGetNFTsByMarketRangeInvalid() public {
        vm.expectRevert("Invalid range");
        factory.getNFTsByMarketRange(address(market), 5, 3);
    }
    
    function testGetNFTsByMarketRangeOutOfBounds() public {
        vm.expectRevert("Range out of bounds");
        factory.getNFTsByMarketRange(address(market), 0, 5);
    }
} 