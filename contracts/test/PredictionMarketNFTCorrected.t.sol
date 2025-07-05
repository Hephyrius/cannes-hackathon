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

contract PredictionMarketNFTCorrectedTest is Test {
    PredictionMarketNFT public nft;
    PredictionMarket public market;
    MockUSDC public usdc;
    
    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address public resolutionContract = address(0x4);
    
    string public constant BASE_IMAGE_URL = "https://example.com/images/";
    
    function setUp() public {
        usdc = new MockUSDC();
        
        market = new PredictionMarket(
            address(usdc),
            "Will Bitcoin reach $100k by 2024?",
            block.timestamp + 30 days
        );
        
        nft = new PredictionMarketNFT(
            "Prediction Market NFTs",
            "PMNFT",
            BASE_IMAGE_URL
        );
        
        nft.transferOwnership(owner);
    }
    
    function testConstructor() public view {
        assertEq(nft.name(), "Prediction Market NFTs");
        assertEq(nft.symbol(), "PMNFT");
        assertEq(nft.owner(), owner);
    }
    
    function testMintMarketNFT() public {
        string[] memory tags = new string[](2);
        tags[0] = "crypto";
        tags[1] = "bitcoin";
        
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Bitcoin $100k Prediction",
            "Will Bitcoin reach $100k by the end of 2024?",
            "https://example.com/bitcoin.jpg",
            address(market),
            resolutionContract,
            "Cryptocurrency",
            tags
        );
        
        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.marketToTokenId(address(market)), tokenId);
        
        // Check metadata using getMarketMetadata
        (
            string memory title,
            string memory description,
            address marketContract,
            address resContract,
            uint256 creationTime,
            bool isResolved,
            string memory category
        ) = nft.getMarketMetadata(tokenId);
        
        assertEq(title, "Bitcoin $100k Prediction");
        assertEq(description, "Will Bitcoin reach $100k by the end of 2024?");
        assertEq(marketContract, address(market));
        assertEq(resContract, resolutionContract);
        assertEq(creationTime, block.timestamp);
        assertFalse(isResolved);
        assertEq(category, "Cryptocurrency");
    }
    
    function testMintMarketNFTOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            new string[](0)
        );
    }
    
    function testMintMarketNFTAlreadyExists() public {
        string[] memory tags = new string[](0);
        
        vm.startPrank(owner);
        nft.mintMarketNFT(
            alice,
            "Test 1",
            "Description 1",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        vm.expectRevert("Market NFT already exists");
        nft.mintMarketNFT(
            bob,
            "Test 2",
            "Description 2",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        vm.stopPrank();
    }
    
    function testMintMarketNFTDefaultImageUrl() public {
        string[] memory tags = new string[](0);
        
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "", // Empty image URL
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        // We can't directly access the imageUrl from the struct, but we can check the tokenURI
        string memory uri = nft.tokenURI(tokenId);
        assertTrue(bytes(uri).length > 0);
    }
    
    function testUpdateResolution() public {
        string[] memory tags = new string[](0);
        vm.startPrank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        vm.stopPrank();
        // Warp to after resolution time
        vm.warp(block.timestamp + 31 days);
        // Resolve the market
        market.resolveMarket(PredictionMarket.Outcome.YES);
        nft.updateResolution(address(market));
        (
            , , , , , bool isResolved,
        ) = nft.getMarketMetadata(tokenId);
        assertTrue(isResolved);
    }
    
    function testUpdateResolutionNotExists() public {
        vm.expectRevert("Market NFT does not exist");
        nft.updateResolution(address(0x999));
    }
    
    function testUpdateResolutionNotResolved() public {
        string[] memory tags = new string[](0);
        
        vm.prank(owner);
        nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        vm.expectRevert("Market not resolved yet");
        nft.updateResolution(address(market));
    }
    
    function testUpdateResolutionAlreadyUpdated() public {
        string[] memory tags = new string[](0);
        vm.startPrank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        vm.stopPrank();
        // Warp to after resolution time
        vm.warp(block.timestamp + 31 days);
        // Resolve the market
        market.resolveMarket(PredictionMarket.Outcome.YES);
        nft.updateResolution(address(market));
        // Should not revert when called again
        nft.updateResolution(address(market));
        (
            , , , , , bool isResolved,
        ) = nft.getMarketMetadata(tokenId);
        assertTrue(isResolved);
    }
    
    function testGetMarketResolution() public {
        string[] memory tags = new string[](0);
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        // Before resolution
        assertEq(nft.getMarketResolution(tokenId), "Unresolved");
        // Warp to after resolution time
        vm.warp(block.timestamp + 31 days);
        // Resolve market
        market.resolveMarket(PredictionMarket.Outcome.YES);
        nft.updateResolution(address(market));
        assertEq(nft.getMarketResolution(tokenId), "YES");
        // Test other outcomes
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Test Market 2",
            block.timestamp + 30 days
        );
        vm.prank(owner);
        uint256 tokenId2 = nft.mintMarketNFT(
            alice,
            "Test 2",
            "Description",
            "",
            address(market2),
            resolutionContract,
            "Category",
            tags
        );
        vm.warp(block.timestamp + 31 days);
        market2.resolveMarket(PredictionMarket.Outcome.NO);
        nft.updateResolution(address(market2));
        assertEq(nft.getMarketResolution(tokenId2), "NO");
        // Test POWER outcome
        PredictionMarket market3 = new PredictionMarket(
            address(usdc),
            "Test Market 3",
            block.timestamp + 30 days
        );
        vm.prank(owner);
        uint256 tokenId3 = nft.mintMarketNFT(
            alice,
            "Test 3",
            "Description",
            "",
            address(market3),
            resolutionContract,
            "Category",
            tags
        );
        vm.warp(block.timestamp + 31 days);
        market3.resolveMarket(PredictionMarket.Outcome.POWER);
        nft.updateResolution(address(market3));
        assertEq(nft.getMarketResolution(tokenId3), "POWER");
    }
    
    function testGetMarketResolutionTokenNotExists() public {
        vm.expectRevert("Token does not exist");
        nft.getMarketResolution(999);
    }
    
    function testGetMarketStatus() public {
        string[] memory tags = new string[](0);
        
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        // Active status
        assertEq(nft.getMarketStatus(tokenId), "Active");
        
        // Expired status
        vm.warp(block.timestamp + 30 days + 1);
        assertEq(nft.getMarketStatus(tokenId), "Expired");
        
        // Resolved status
        market.resolveMarket(PredictionMarket.Outcome.YES);
        nft.updateResolution(address(market));
        assertEq(nft.getMarketStatus(tokenId), "Resolved");
    }
    
    function testGetMarketStatusTokenNotExists() public {
        vm.expectRevert("Token does not exist");
        nft.getMarketStatus(999);
    }
    
    function testGetMarketResolutionAndStatus() public {
        string[] memory tags = new string[](0);
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        (
            string memory resolution,
            string memory status,
            uint256 resolutionTime
        ) = nft.getMarketResolutionAndStatus(tokenId);
        assertEq(resolution, "Unresolved");
        assertEq(status, "Active");
        assertEq(resolutionTime, 0);
        // After resolution
        vm.warp(block.timestamp + 31 days);
        market.resolveMarket(PredictionMarket.Outcome.YES);
        nft.updateResolution(address(market));
        (
            resolution,
            status,
            resolutionTime
        ) = nft.getMarketResolutionAndStatus(tokenId);
        assertEq(resolution, "YES");
        assertEq(status, "Resolved");
        assertGt(resolutionTime, 0);
    }
    
    function testTokenURI() public {
        string[] memory tags = new string[](2);
        tags[0] = "crypto";
        tags[1] = "bitcoin";
        
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Bitcoin $100k Prediction",
            "Will Bitcoin reach $100k by the end of 2024?",
            "https://example.com/bitcoin.jpg",
            address(market),
            resolutionContract,
            "Cryptocurrency",
            tags
        );
        
        string memory uri = nft.tokenURI(tokenId);
        
        // Should be a valid JSON
        assertTrue(bytes(uri).length > 0);
        assertTrue(bytes(uri).length > 10);
    }
    
    function testTokenURIAfterResolution() public {
        string[] memory tags = new string[](0);
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        string memory uriBefore = nft.tokenURI(tokenId);
        // Warp to after resolution time
        vm.warp(block.timestamp + 31 days);
        // Resolve market
        market.resolveMarket(PredictionMarket.Outcome.YES);
        nft.updateResolution(address(market));
        string memory uriAfter = nft.tokenURI(tokenId);
        // URIs should be different after resolution
        assertTrue(keccak256(bytes(uriBefore)) != keccak256(bytes(uriAfter)));
    }
    
    function testTokenURITokenNotExists() public {
        vm.expectRevert("ERC721: invalid token ID");
        nft.tokenURI(999);
    }
    
    function testTransfer() public {
        string[] memory tags = new string[](0);
        
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);
        
        assertEq(nft.ownerOf(tokenId), bob);
    }
    
    function testApproveAndTransferFrom() public {
        string[] memory tags = new string[](0);
        
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        vm.prank(alice);
        nft.approve(bob, tokenId);
        
        vm.prank(bob);
        nft.transferFrom(alice, bob, tokenId);
        
        assertEq(nft.ownerOf(tokenId), bob);
    }
    
    function testSetApprovalForAll() public {
        string[] memory tags = new string[](0);
        
        vm.startPrank(owner);
        uint256 tokenId1 = nft.mintMarketNFT(
            alice,
            "Test 1",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Test Market 2",
            block.timestamp + 30 days
        );
        
        uint256 tokenId2 = nft.mintMarketNFT(
            alice,
            "Test 2",
            "Description",
            "",
            address(market2),
            resolutionContract,
            "Category",
            tags
        );
        vm.stopPrank();
        
        vm.prank(alice);
        nft.setApprovalForAll(bob, true);
        
        vm.prank(bob);
        nft.transferFrom(alice, bob, tokenId1);
        
        vm.prank(bob);
        nft.transferFrom(alice, bob, tokenId2);
        
        assertEq(nft.ownerOf(tokenId1), bob);
        assertEq(nft.ownerOf(tokenId2), bob);
    }
    
    function testGetMarketsByOwner() public {
        string[] memory tags = new string[](0);
        
        vm.startPrank(owner);
        nft.mintMarketNFT(
            alice,
            "Test 1",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        PredictionMarket market2 = new PredictionMarket(
            address(usdc),
            "Test Market 2",
            block.timestamp + 30 days
        );
        
        nft.mintMarketNFT(
            alice,
            "Test 2",
            "Description",
            "",
            address(market2),
            resolutionContract,
            "Category",
            tags
        );
        
        nft.mintMarketNFT(
            bob,
            "Test 3",
            "Description",
            "",
            address(0x5),
            resolutionContract,
            "Category",
            tags
        );
        vm.stopPrank();
        
        uint256[] memory aliceMarkets = nft.getMarketsByOwner(alice);
        assertEq(aliceMarkets.length, 2);
        assertEq(aliceMarkets[0], 1);
        assertEq(aliceMarkets[1], 2);
        
        uint256[] memory bobMarkets = nft.getMarketsByOwner(bob);
        assertEq(bobMarkets.length, 1);
        assertEq(bobMarkets[0], 3);
    }
    
    function testSetBaseImageUrl() public {
        vm.prank(owner);
        nft.setBaseImageUrl("https://newbase.com/images/");
        
        // Test by minting a new NFT with empty image URL
        string[] memory tags = new string[](0);
        
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "", // Empty image URL
            address(0x6),
            resolutionContract,
            "Category",
            tags
        );
        
        string memory uri = nft.tokenURI(tokenId);
        assertTrue(bytes(uri).length > 0);
    }
    
    function testSetBaseImageUrlOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        nft.setBaseImageUrl("https://newbase.com/images/");
    }
    
    function testUpdateMarketMetadata() public {
        string[] memory tags = new string[](0);
        
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Original Description",
            "https://original.com/image.jpg",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        vm.prank(owner);
        nft.updateMarketMetadata(tokenId, "Updated Description", "https://updated.com/image.jpg");
        
        (
            , string memory description, , , , ,
        ) = nft.getMarketMetadata(tokenId);
        
        assertEq(description, "Updated Description");
    }
    
    function testUpdateMarketMetadataNotAuthorized() public {
        string[] memory tags = new string[](0);
        
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        vm.prank(bob);
        vm.expectRevert("Not authorized");
        nft.updateMarketMetadata(tokenId, "Updated", "");
    }
    
    function testUpdateMarketMetadataTokenNotExists() public {
        vm.prank(owner);
        vm.expectRevert("Token does not exist");
        nft.updateMarketMetadata(999, "Updated", "");
    }
    
    function testBalanceOf() public {
        assertEq(nft.balanceOf(alice), 0);
        
        string[] memory tags = new string[](0);
        
        vm.prank(owner);
        nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        assertEq(nft.balanceOf(alice), 1);
    }
    
    function testOwnerOf() public {
        string[] memory tags = new string[](0);
        
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        assertEq(nft.ownerOf(tokenId), alice);
    }
    
    function testOwnerOfTokenNotExists() public {
        vm.expectRevert("ERC721: invalid token ID");
        nft.ownerOf(999);
    }
    
    function testGetApproved() public {
        string[] memory tags = new string[](0);
        
        vm.prank(owner);
        uint256 tokenId = nft.mintMarketNFT(
            alice,
            "Test",
            "Description",
            "",
            address(market),
            resolutionContract,
            "Category",
            tags
        );
        
        assertEq(nft.getApproved(tokenId), address(0));
        
        vm.prank(alice);
        nft.approve(bob, tokenId);
        
        assertEq(nft.getApproved(tokenId), bob);
    }
    
    function testIsApprovedForAll() public {
        assertFalse(nft.isApprovedForAll(alice, bob));
        
        vm.prank(alice);
        nft.setApprovalForAll(bob, true);
        
        assertTrue(nft.isApprovedForAll(alice, bob));
        
        vm.prank(alice);
        nft.setApprovalForAll(bob, false);
        
        assertFalse(nft.isApprovedForAll(alice, bob));
    }
    
    function testSupportsInterface() public view {
        // Test ERC721 interface
        assertTrue(nft.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(nft.supportsInterface(0x5b5e139f)); // ERC721Metadata
    }
} 