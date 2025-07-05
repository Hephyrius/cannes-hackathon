// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/PredictionMarket.sol";
import "../src/YesNoToken.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PredictionMarketTest is Test {
    MockUSDC usdc;
    PredictionMarket market;
    YesNoToken yesNoToken;
    address alice = address(0x1);
    address bob = address(0x2);
    uint256 constant USDC_UNIT = 1e6;
    
    function setUp() public {
        usdc = new MockUSDC();
        market = new PredictionMarket(address(usdc), "Will it rain tomorrow?", block.timestamp + 1 days);
        usdc.mint(alice, 10 * USDC_UNIT);
        usdc.mint(bob, 10 * USDC_UNIT);
        vm.prank(alice);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(market), type(uint256).max);
        yesNoToken = YesNoToken(address(market.yesNoToken()));
    }

    function testPurchaseTokens() public {
        vm.prank(alice);
        market.purchaseTokens(USDC_UNIT);
        (uint256 yesBal, uint256 noBal, uint256 powerBal) = market.getUserBalances(alice);
        assertEq(yesBal, 1);
        assertEq(noBal, 1);
        assertEq(powerBal, 1);
        assertEq(usdc.balanceOf(address(market)), USDC_UNIT);
    }

    function testResolveAndRedeemYes() public {
        vm.prank(alice);
        market.purchaseTokens(USDC_UNIT);
        vm.warp(block.timestamp + 2 days);
        market.resolveMarket(PredictionMarket.Outcome.YES);
        vm.prank(alice);
        market.redeemWinningTokens(1);
        assertEq(usdc.balanceOf(alice), 10 * USDC_UNIT);
    }

    function testResolveAndRedeemNo() public {
        vm.prank(bob);
        market.purchaseTokens(2 * USDC_UNIT);
        vm.warp(block.timestamp + 2 days);
        market.resolveMarket(PredictionMarket.Outcome.NO);
        vm.prank(bob);
        market.redeemWinningTokens(2);
        assertEq(usdc.balanceOf(bob), 10 * USDC_UNIT);
    }

    function testResolveAndRedeemPower() public {
        vm.prank(alice);
        market.purchaseTokens(3 * USDC_UNIT);
        vm.warp(block.timestamp + 2 days);
        market.resolveMarket(PredictionMarket.Outcome.POWER);
        vm.prank(alice);
        market.redeemWinningTokens(3);
        assertEq(usdc.balanceOf(alice), 10 * USDC_UNIT);
    }

    function testOnlyWinningTokensCanBeRedeemed() public {
        vm.prank(alice);
        market.purchaseTokens(USDC_UNIT);
        vm.warp(block.timestamp + 2 days);
        market.resolveMarket(PredictionMarket.Outcome.NO);
        
        // Alice has YES, NO, and YES-NO tokens, but only NO is the winner
        // The redeemWinningTokens function automatically redeems the winning token type
        // So when NO is the winner, it will try to redeem NO tokens
        vm.prank(alice);
        market.redeemWinningTokens(1);
        
        // Verify Alice's NO tokens were burned but YES and YES-NO tokens remain
        (uint256 yesBal, uint256 noBal, uint256 yesNoBal) = market.getUserBalances(alice);
        assertEq(yesBal, 1); // YES tokens still there (losing outcome)
        assertEq(noBal, 0);  // NO tokens burned (winning outcome)
        assertEq(yesNoBal, 1); // YES-NO tokens still there (losing outcome)
        
        // Verify Alice received USDC for her winning tokens
        assertEq(usdc.balanceOf(alice), 10 * USDC_UNIT);
    }

    function testCannotRedeemWithoutWinningTokens() public {
        vm.prank(alice);
        market.purchaseTokens(USDC_UNIT);
        vm.warp(block.timestamp + 2 days);
        market.resolveMarket(PredictionMarket.Outcome.NO);
        
        // Alice redeems her NO tokens first
        vm.prank(alice);
        market.redeemWinningTokens(1);
        
        // Now Alice has no NO tokens left, so trying to redeem again should fail
        vm.prank(alice);
        vm.expectRevert("Insufficient NO tokens");
        market.redeemWinningTokens(1);
    }
} 