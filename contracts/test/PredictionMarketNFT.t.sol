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
        
        market = new PredictionMarket(
            address(usdc),
            "Will Bitcoin reach $100k by 2024?",
            block.timestamp + 30 days
        );
        
        nft = new PredictionMarketNFT(
            address(market),
            "Prediction Market NFT",
            "PMNFT"
        );
        
        nft.transferOwnership(owner);
        
        usdc.mint(alice, 50000e6);
        usdc.mint(bob, 30000e6);
        usdc.mint(charlie, 20000e6);
        usdc.mint(owner, 100000e6);
    }
    
    function testConstructor() public view {
        assertEq(nft.name(), "Prediction Market NFT");
        assertEq(nft.symbol(), "PMNFT");
        assertEq(address(nft.market()), address(market));
        assertEq(nft.owner(), owner);
    }
    
    function testMintNFT() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice, "Test NFT", "Description");
        
        assertEq(tokenId, 1);
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.tokenURI(tokenId), "Test NFT");
        assertEq(nft.tokenDescription(tokenId), "Description");
    }
    
    function testMintNFTOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        nft.mint(bob, "Test NFT", "Description");
    }
    
    function testMintMultipleNFTs() public {
        vm.startPrank(owner);
        
        uint256 tokenId1 = nft.mint(alice, "NFT 1", "Description 1");
        uint256 tokenId2 = nft.mint(bob, "NFT 2", "Description 2");
        uint256 tokenId3 = nft.mint(charlie, "NFT 3", "Description 3");
        
        vm.stopPrank();
        
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(tokenId3, 3);
        
        assertEq(nft.ownerOf(tokenId1), alice);
        assertEq(nft.ownerOf(tokenId2), bob);
        assertEq(nft.ownerOf(tokenId3), charlie);
    }
    
    function testTransferNFT() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice, "Test NFT", "Description");
        
        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);
        
        assertEq(nft.ownerOf(tokenId), bob);
    }
    
    function testApproveAndTransfer() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice, "Test NFT", "Description");
        
        vm.prank(alice);
        nft.approve(bob, tokenId);
        
        vm.prank(bob);
        nft.transferFrom(alice, charlie, tokenId);
        
        assertEq(nft.ownerOf(tokenId), charlie);
    }
    
    function testSetApprovalForAll() public {
        vm.startPrank(owner);
        uint256 tokenId1 = nft.mint(alice, "NFT 1", "Description 1");
        uint256 tokenId2 = nft.mint(alice, "NFT 2", "Description 2");
        vm.stopPrank();
        
        vm.prank(alice);
        nft.setApprovalForAll(bob, true);
        
        vm.prank(bob);
        nft.transferFrom(alice, charlie, tokenId1);
        nft.transferFrom(alice, charlie, tokenId2);
        
        assertEq(nft.ownerOf(tokenId1), charlie);
        assertEq(nft.ownerOf(tokenId2), charlie);
    }
    
    function testBurnNFT() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice, "Test NFT", "Description");
        
        vm.prank(owner);
        nft.burn(tokenId);
        
        vm.expectRevert("ERC721: invalid token ID");
        nft.ownerOf(tokenId);
    }
    
    function testBurnNFTOnlyOwner() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice, "Test NFT", "Description");
        
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        nft.burn(tokenId);
    }
    
    function testBurnNonExistentNFT() public {
        vm.prank(owner);
        vm.expectRevert("ERC721: invalid token ID");
        nft.burn(999);
    }
    
    function testGetTokensByOwner() public {
        vm.startPrank(owner);
        nft.mint(alice, "NFT 1", "Description 1");
        nft.mint(alice, "NFT 2", "Description 2");
        nft.mint(bob, "NFT 3", "Description 3");
        nft.mint(alice, "NFT 4", "Description 4");
        vm.stopPrank();
        
        uint256[] memory aliceTokens = nft.getTokensByOwner(alice);
        uint256[] memory bobTokens = nft.getTokensByOwner(bob);
        uint256[] memory charlieTokens = nft.getTokensByOwner(charlie);
        
        assertEq(aliceTokens.length, 3);
        assertEq(bobTokens.length, 1);
        assertEq(charlieTokens.length, 0);
        
        assertEq(aliceTokens[0], 1);
        assertEq(aliceTokens[1], 2);
        assertEq(aliceTokens[2], 4);
        assertEq(bobTokens[0], 3);
    }
    
    function testGetAllTokens() public {
        vm.startPrank(owner);
        nft.mint(alice, "NFT 1", "Description 1");
        nft.mint(bob, "NFT 2", "Description 2");
        nft.mint(charlie, "NFT 3", "Description 3");
        vm.stopPrank();
        
        uint256[] memory allTokens = nft.getAllTokens();
        
        assertEq(allTokens.length, 3);
        assertEq(allTokens[0], 1);
        assertEq(allTokens[1], 2);
        assertEq(allTokens[2], 3);
    }
    
    function testGetTokenInfo() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice, "Test NFT", "Test Description");
        
        (
            address tokenOwner,
            string memory tokenURI,
            string memory description,
            uint256 mintTime
        ) = nft.getTokenInfo(tokenId);
        
        assertEq(tokenOwner, alice);
        assertEq(tokenURI, "Test NFT");
        assertEq(description, "Test Description");
        assertGt(mintTime, 0);
    }
    
    function testGetTokenInfoNonExistent() public {
        vm.expectRevert("ERC721: invalid token ID");
        nft.getTokenInfo(999);
    }
    
    function testTotalSupply() public {
        assertEq(nft.totalSupply(), 0);
        
        vm.startPrank(owner);
        nft.mint(alice, "NFT 1", "Description 1");
        assertEq(nft.totalSupply(), 1);
        
        nft.mint(bob, "NFT 2", "Description 2");
        assertEq(nft.totalSupply(), 2);
        
        nft.mint(charlie, "NFT 3", "Description 3");
        assertEq(nft.totalSupply(), 3);
        vm.stopPrank();
    }
    
    function testTokenByIndex() public {
        vm.startPrank(owner);
        nft.mint(alice, "NFT 1", "Description 1");
        nft.mint(bob, "NFT 2", "Description 2");
        nft.mint(charlie, "NFT 3", "Description 3");
        vm.stopPrank();
        
        assertEq(nft.tokenByIndex(0), 1);
        assertEq(nft.tokenByIndex(1), 2);
        assertEq(nft.tokenByIndex(2), 3);
    }
    
    function testTokenByIndexOutOfBounds() public {
        vm.expectRevert("ERC721Enumerable: global index out of bounds");
        nft.tokenByIndex(0);
    }
    
    function testTokenOfOwnerByIndex() public {
        vm.startPrank(owner);
        nft.mint(alice, "NFT 1", "Description 1");
        nft.mint(alice, "NFT 2", "Description 2");
        nft.mint(bob, "NFT 3", "Description 3");
        vm.stopPrank();
        
        assertEq(nft.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(nft.tokenOfOwnerByIndex(alice, 1), 2);
        assertEq(nft.tokenOfOwnerByIndex(bob, 0), 3);
    }
    
    function testTokenOfOwnerByIndexOutOfBounds() public {
        vm.expectRevert("ERC721Enumerable: owner index out of bounds");
        nft.tokenOfOwnerByIndex(alice, 0);
    }
    
    function testBalanceOf() public {
        assertEq(nft.balanceOf(alice), 0);
        
        vm.startPrank(owner);
        nft.mint(alice, "NFT 1", "Description 1");
        assertEq(nft.balanceOf(alice), 1);
        
        nft.mint(alice, "NFT 2", "Description 2");
        assertEq(nft.balanceOf(alice), 2);
        vm.stopPrank();
    }
    
    function testIsApprovedForAll() public {
        vm.prank(alice);
        nft.setApprovalForAll(bob, true);
        
        assertTrue(nft.isApprovedForAll(alice, bob));
        assertFalse(nft.isApprovedForAll(alice, charlie));
    }
    
    function testGetApproved() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice, "Test NFT", "Description");
        
        vm.prank(alice);
        nft.approve(bob, tokenId);
        
        assertEq(nft.getApproved(tokenId), bob);
    }
    
    function testGetApprovedNonExistent() public {
        vm.expectRevert("ERC721: invalid token ID");
        nft.getApproved(999);
    }
    
    function testTransferToZeroAddress() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice, "Test NFT", "Description");
        
        vm.prank(alice);
        vm.expectRevert("ERC721: transfer to the zero address");
        nft.transferFrom(alice, address(0), tokenId);
    }
    
    function testTransferFromZeroAddress() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice, "Test NFT", "Description");
        
        vm.expectRevert("ERC721: transfer from the zero address");
        nft.transferFrom(address(0), bob, tokenId);
    }
    
    function testTransferUnauthorized() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice, "Test NFT", "Description");
        
        vm.prank(bob);
        vm.expectRevert("ERC721: caller is not token owner or approved");
        nft.transferFrom(alice, charlie, tokenId);
    }
    
    function testMintToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("ERC721: mint to the zero address");
        nft.mint(address(0), "Test NFT", "Description");
    }
    
    function testFuzzMintNFT(string memory uri, string memory description) public {
        vm.assume(bytes(uri).length > 0 && bytes(uri).length <= 100);
        vm.assume(bytes(description).length <= 200);
        
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice, uri, description);
        
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.tokenURI(tokenId), uri);
        assertEq(nft.tokenDescription(tokenId), description);
    }
    
    function testInvariantTotalSupply() public {
        uint256 initialSupply = nft.totalSupply();
        
        vm.prank(owner);
        nft.mint(alice, "Test NFT", "Description");
        
        assertEq(nft.totalSupply(), initialSupply + 1);
        
        vm.prank(owner);
        nft.burn(1);
        
        assertEq(nft.totalSupply(), initialSupply);
    }
    
    function testInvariantBalanceOf() public {
        uint256 initialBalance = nft.balanceOf(alice);
        
        vm.prank(owner);
        nft.mint(alice, "Test NFT", "Description");
        
        assertEq(nft.balanceOf(alice), initialBalance + 1);
        
        vm.prank(owner);
        nft.burn(1);
        
        assertEq(nft.balanceOf(alice), initialBalance);
    }
    
    function testEventEmission() public {
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketNFT.NFTMinted(1, alice, "Test NFT", "Description");
        
        vm.prank(owner);
        nft.mint(alice, "Test NFT", "Description");
    }
    
    function testBurnEventEmission() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice, "Test NFT", "Description");
        
        vm.expectEmit(true, true, false, false);
        emit PredictionMarketNFT.NFTBurned(tokenId, alice);
        
        vm.prank(owner);
        nft.burn(tokenId);
    }
} 