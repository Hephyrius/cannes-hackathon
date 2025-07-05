// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/PredictionMarketNFT.sol";
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

contract PredictionMarketNFTTest is Test {
    PredictionMarketNFT public nft;
    PredictionMarket public market;
    MockUSDC public usdc;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public charlie = address(0x4);
    
    function setUp() public {
        usdc = new MockUSDC();
        
        nft = new PredictionMarketNFT(
            "Prediction Market NFT",
            "PMNFT",
            "https://example.com/images/"
        );
        
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
        assertEq(nft.name(), "Prediction Market NFT");
        assertEq(nft.symbol(), "PMNFT");
        assertEq(nft.marketToTokenId(address(market)), 0);
        assertEq(nft.owner(), owner);
    }
    
    function testMintMarketNFT() public {
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Bitcoin $100k Prediction",
            "Will Bitcoin reach $100k by 2024?",
            "https://example.com/btc.jpg",
            address(market),
            address(0),
            "Crypto",
            new string[](2)
        );
        
        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.marketToTokenId(address(market)), tokenId);
        
        (
            string memory title,
            string memory description,
            address marketContract,
            address resolutionContract,
            uint256 creationTime,
            bool isResolved,
            string memory category
        ) = nft.getMarketMetadata(tokenId);
        
        assertEq(title, "Bitcoin $100k Prediction");
        assertEq(description, "Will Bitcoin reach $100k by 2024?");
        assertEq(marketContract, address(market));
        assertEq(resolutionContract, address(0));
        assertGt(creationTime, 0);
        assertFalse(isResolved);
        assertEq(category, "Crypto");
    }
    
    function testMintMarketNFTOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        nft.mintMarketNFT(
            alice,
            "Test NFT",
            "Description",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
    }
    
    function testMintMarketNFTAlreadyExists() public {
        vm.startPrank(owner);
        nft.mintMarketNFT(
            alice,
            "Test NFT",
            "Description",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        vm.expectRevert("Market NFT already exists");
        nft.mintMarketNFT(
            bob,
            "Test NFT 2",
            "Description 2",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        vm.stopPrank();
    }
    
    function testMintMultipleMarketNFTs() public {
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Will Ethereum reach $10k by 2024?",
            block.timestamp + 30 days
        );
        
        vm.startPrank(owner);
        
        uint256 tokenId1 = nft.mintMarketNFT(
            alice,
            "Bitcoin $100k",
            "Description 1",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        uint256 tokenId2 = nft.mintMarketNFT(
            bob,
            "Ethereum $10k",
            "Description 2",
            "",
            address(market2),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        vm.stopPrank();
        
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        
        assertEq(nft.ownerOf(tokenId1), alice);
        assertEq(nft.ownerOf(tokenId2), bob);
        
        assertEq(nft.marketToTokenId(address(market)), tokenId1);
        assertEq(nft.marketToTokenId(address(market2)), tokenId2);
    }
    
    function testTransferMarketNFT() public {
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test NFT",
            "Description",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);
        
        assertEq(nft.ownerOf(tokenId), bob);
    }
    
    function testApproveAndTransfer() public {
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test NFT",
            "Description",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        vm.prank(alice);
        nft.approve(bob, tokenId);
        
        vm.prank(bob);
        nft.transferFrom(alice, charlie, tokenId);
        
        assertEq(nft.ownerOf(tokenId), charlie);
    }
    
    function testSetApprovalForAll() public {
        vm.startPrank(owner);
        uint256 tokenId1 = nft.mintMarketNFT(
            alice,
            "NFT 1",
            "Description 1",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Will Ethereum reach $10k by 2024?",
            block.timestamp + 30 days
        );
        
        uint256 tokenId2 = nft.mintMarketNFT(
            alice,
            "NFT 2",
            "Description 2",
            "",
            address(market2),
            address(0),
            "Crypto",
            new string[](0)
        );
        vm.stopPrank();
        
        vm.prank(alice);
        nft.setApprovalForAll(bob, true);
        
        vm.prank(bob);
        nft.transferFrom(alice, charlie, tokenId1);
        nft.transferFrom(alice, charlie, tokenId2);
        
        assertEq(nft.ownerOf(tokenId1), charlie);
        assertEq(nft.ownerOf(tokenId2), charlie);
    }
    
    function testGetMarketResolution() public {
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test NFT",
            "Description",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        string memory resolution = nft.getMarketResolution(tokenId);
        assertEq(resolution, "Unresolved");
    }
    
    function testGetMarketStatus() public {
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test NFT",
            "Description",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        string memory status = nft.getMarketStatus(tokenId);
        assertEq(status, "Active");
    }
    
    function testGetMarketStatusExpired() public {
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test NFT",
            "Description",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        vm.warp(block.timestamp + 31 days);
        
        string memory status = nft.getMarketStatus(tokenId);
        assertEq(status, "Expired");
    }
    
    function testUpdateResolution() public {
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test NFT",
            "Description",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.prank(owner);
        market.resolveMarket(PredictionMarket.Outcome.YES);
        
        vm.prank(owner);
        nft.updateResolution(address(market));
        
        (
            , , , , , bool isResolved,
        ) = nft.getMarketMetadata(tokenId);
        
        assertTrue(isResolved);
        // Resolution time is updated internally
        
        string memory resolution = nft.getMarketResolution(tokenId);
        assertEq(resolution, "YES");
        
        string memory status = nft.getMarketStatus(tokenId);
        assertEq(status, "Resolved");
    }
    
    function testUpdateResolutionMarketNotResolved() public {
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test NFT",
            "Description",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        vm.prank(owner);
        vm.expectRevert("Market not resolved yet");
        nft.updateResolution(address(market));
    }
    
    function testUpdateResolutionNFTDoesNotExist() public {
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.prank(owner);
        market.resolveMarket(PredictionMarket.Outcome.YES);
        
        vm.prank(owner);
        vm.expectRevert("Market NFT does not exist");
        nft.updateResolution(address(market));
    }
    
    function testGetMarketResolutionNonExistent() public {
        vm.expectRevert("Token does not exist");
        nft.getMarketResolution(999);
    }
    
    function testGetMarketStatusNonExistent() public {
        vm.expectRevert("Token does not exist");
        nft.getMarketStatus(999);
    }
    
    function testFuzzMintMarketNFT(string memory title, string memory description, string memory category) public {
        vm.assume(bytes(title).length > 0 && bytes(title).length <= 100);
        vm.assume(bytes(description).length <= 500);
        vm.assume(bytes(category).length <= 50);
        
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            title,
            description,
            "",
            address(market),
            address(0),
            category,
            new string[](0)
        );
        
        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(tokenId), alice);
        
        (
            string memory mintedTitle,
            string memory mintedDescription,
            , , , , string memory mintedCategory
        ) = nft.getMarketMetadata(tokenId);
        
        assertEq(mintedTitle, title);
        assertEq(mintedDescription, description);
        assertEq(mintedCategory, category);
    }
    
    function testInvariantTokenIdIncrement() public {
        vm.startPrank(owner);
        
        uint256 tokenId1 = nft.mintMarketNFT(
            alice,
            "NFT 1",
            "Description 1",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Will Ethereum reach $10k by 2024?",
            block.timestamp + 30 days
        );
        
        uint256 tokenId2 = nft.mintMarketNFT(
            bob,
            "NFT 2",
            "Description 2",
            "",
            address(market2),
            address(0),
            "Crypto",
            new string[](0)
        );
        vm.stopPrank();
        
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
    }
    
    function testEventEmission() public {
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketNFT.MarketNFTMinted(1, address(market), "Test NFT", alice);
        
        vm.prank(owner);
        nft.mintMarketNFT(
            alice,
            "Test NFT",
            "Description",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
    }
    
    function testResolutionUpdateEventEmission() public {
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test NFT",
            "Description",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        vm.warp(block.timestamp + 30 days + 1);
        
        vm.prank(owner);
        market.resolveMarket(PredictionMarket.Outcome.YES);
        
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketNFT.MarketResolutionUpdated(tokenId, PredictionMarket.Outcome.YES, 0);
        
        vm.prank(owner);
        nft.updateResolution(address(market));
    }
    
    function testMultipleUsersOwningNFTs() public {
        vm.startPrank(owner);
        
        uint256 aliceToken = nft.mintMarketNFT(
            alice,
            "Alice NFT",
            "Description",
            "",
            address(market),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Will Ethereum reach $10k by 2024?",
            block.timestamp + 30 days
        );
        
        uint256 bobToken = nft.mintMarketNFT(
            bob,
            "Bob NFT",
            "Description",
            "",
            address(market2),
            address(0),
            "Crypto",
            new string[](0)
        );
        
        PredictionMarket market3 = new PredictionMarket(
            address(usdc),
            "Will Solana reach $500 by 2024?",
            block.timestamp + 30 days
        );
        
        uint256 charlieToken = nft.mintMarketNFT(
            charlie,
            "Charlie NFT",
            "Description",
            "",
            address(market3),
            address(0),
            "Crypto",
            new string[](0)
        );
        vm.stopPrank();
        
        assertEq(nft.ownerOf(aliceToken), alice);
        assertEq(nft.ownerOf(bobToken), bob);
        assertEq(nft.ownerOf(charlieToken), charlie);
        
        assertEq(nft.marketToTokenId(address(market)), aliceToken);
        assertEq(nft.marketToTokenId(address(market2)), bobToken);
        assertEq(nft.marketToTokenId(address(market3)), charlieToken);
    }
} 