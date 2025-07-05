// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/YesNoToken.sol";
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

contract YesNoTokenTest is Test {
    YesNoToken public token;
    PredictionMarket public market;
    MockUSDC public usdc;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public unauthorized = address(0x3);
    
    function setUp() public {
        usdc = new MockUSDC();
        
        // Create market which will deploy the tokens
        market = new PredictionMarket(
            address(usdc),
            "Test Market",
            block.timestamp + 30 days
        );
        
        // Get the YesNoToken from the market
        token = YesNoToken(address(market.yesNoToken()));
    }
    
    function testTokenDeployment() public {
        assertEq(token.name(), "YES-NO Token");
        assertEq(token.symbol(), "YESNO");
        assertEq(token.decimals(), 18);
        assertEq(token.predictionMarket(), address(market));
    }
    
    function testMintByPredictionMarket() public {
        uint256 initialBalance = token.balanceOf(alice);
        
        // Market can mint tokens
        vm.prank(address(market));
        token.mint(alice, 1000e18);
        
        assertEq(token.balanceOf(alice), initialBalance + 1000e18);
    }
    
    function testMintByUnauthorized() public {
        vm.prank(unauthorized);
        vm.expectRevert("Only prediction market can call");
        token.mint(alice, 1000e18);
    }
    
    function testBurnByPredictionMarket() public {
        // First mint some tokens
        vm.prank(address(market));
        token.mint(alice, 1000e18);
        
        uint256 initialBalance = token.balanceOf(alice);
        
        // Market can burn tokens
        vm.prank(address(market));
        token.burn(alice, 500e18);
        
        assertEq(token.balanceOf(alice), initialBalance - 500e18);
    }
    
    function testBurnByUnauthorized() public {
        // First mint some tokens
        vm.prank(address(market));
        token.mint(alice, 1000e18);
        
        vm.prank(unauthorized);
        vm.expectRevert("Only prediction market can call");
        token.burn(alice, 500e18);
    }
    
    function testBurnMoreThanBalance() public {
        // First mint some tokens
        vm.prank(address(market));
        token.mint(alice, 1000e18);
        
        vm.prank(address(market));
        vm.expectRevert(); // Should revert when trying to burn more than balance
        token.burn(alice, 1500e18);
    }
    
    function testTransfer() public {
        // First mint some tokens
        vm.prank(address(market));
        token.mint(alice, 1000e18);
        
        // Alice can transfer tokens
        vm.prank(alice);
        token.transfer(bob, 500e18);
        
        assertEq(token.balanceOf(alice), 500e18);
        assertEq(token.balanceOf(bob), 500e18);
    }
    
    function testTransferInsufficientBalance() public {
        // First mint some tokens
        vm.prank(address(market));
        token.mint(alice, 1000e18);
        
        vm.prank(alice);
        vm.expectRevert(); // Should revert when trying to transfer more than balance
        token.transfer(bob, 1500e18);
    }
    
    function testApproveAndTransferFrom() public {
        // First mint some tokens
        vm.prank(address(market));
        token.mint(alice, 1000e18);
        
        // Alice approves Bob to spend her tokens
        vm.prank(alice);
        token.approve(bob, 500e18);
        
        assertEq(token.allowance(alice, bob), 500e18);
        
        // Bob transfers from Alice
        vm.prank(bob);
        token.transferFrom(alice, bob, 300e18);
        
        assertEq(token.balanceOf(alice), 700e18);
        assertEq(token.balanceOf(bob), 300e18);
        assertEq(token.allowance(alice, bob), 200e18);
    }
    
    function testTransferFromInsufficientAllowance() public {
        // First mint some tokens
        vm.prank(address(market));
        token.mint(alice, 1000e18);
        
        // Alice approves Bob for less than he tries to transfer
        vm.prank(alice);
        token.approve(bob, 500e18);
        
        vm.prank(bob);
        vm.expectRevert(); // Should revert when trying to transfer more than allowance
        token.transferFrom(alice, bob, 600e18);
    }
    
    function testTransferFromInsufficientBalance() public {
        // First mint some tokens
        vm.prank(address(market));
        token.mint(alice, 1000e18);
        
        // Alice approves Bob for more than her balance
        vm.prank(alice);
        token.approve(bob, 1500e18);
        
        vm.prank(bob);
        vm.expectRevert(); // Should revert when trying to transfer more than balance
        token.transferFrom(alice, bob, 1500e18);
    }
    
    function testIncreaseAllowance() public {
        vm.prank(alice);
        token.increaseAllowance(bob, 1000e18);
        
        assertEq(token.allowance(alice, bob), 1000e18);
        
        vm.prank(alice);
        token.increaseAllowance(bob, 500e18);
        
        assertEq(token.allowance(alice, bob), 1500e18);
    }
    
    function testDecreaseAllowance() public {
        vm.prank(alice);
        token.approve(bob, 1000e18);
        
        vm.prank(alice);
        token.decreaseAllowance(bob, 300e18);
        
        assertEq(token.allowance(alice, bob), 700e18);
    }
    
    function testDecreaseAllowanceBelowZero() public {
        vm.prank(alice);
        token.approve(bob, 1000e18);
        
        vm.prank(alice);
        vm.expectRevert(); // Should revert when trying to decrease below zero
        token.decreaseAllowance(bob, 1500e18);
    }
    
    function testTotalSupply() public {
        assertEq(token.totalSupply(), 0);
        
        vm.prank(address(market));
        token.mint(alice, 1000e18);
        
        assertEq(token.totalSupply(), 1000e18);
        
        vm.prank(address(market));
        token.mint(bob, 500e18);
        
        assertEq(token.totalSupply(), 1500e18);
        
        vm.prank(address(market));
        token.burn(alice, 200e18);
        
        assertEq(token.totalSupply(), 1300e18);
    }
    
    function testZeroAddressTransfer() public {
        vm.prank(alice);
        vm.expectRevert(); // Should revert when transferring to zero address
        token.transfer(address(0), 100e18);
    }
    
    function testZeroAddressTransferFrom() public {
        // First mint some tokens
        vm.prank(address(market));
        token.mint(alice, 1000e18);
        
        vm.prank(alice);
        token.approve(bob, 500e18);
        
        vm.prank(bob);
        vm.expectRevert(); // Should revert when transferring to zero address
        token.transferFrom(alice, address(0), 100e18);
    }
} 