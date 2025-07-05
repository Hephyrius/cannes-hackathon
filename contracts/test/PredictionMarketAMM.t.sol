// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/PredictionMarket.sol";
import "../src/PredictionMarketAMM.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PredictionMarketAMMTest is Test {
    MockUSDC usdc;
    PredictionMarket market;
    PredictionMarketAMM amm;
    address alice = address(0x1);
    address bob = address(0x2);
    uint256 constant USDC_UNIT = 1e6;
    
    function setUp() public {
        usdc = new MockUSDC();
        market = new PredictionMarket(address(usdc), "Test Market", block.timestamp + 1 days);
        amm = new PredictionMarketAMM(address(usdc), address(market));
        
        // Mint USDC to test accounts
        usdc.mint(alice, 100 * USDC_UNIT);
        usdc.mint(bob, 100 * USDC_UNIT);
        usdc.mint(address(this), 1000 * USDC_UNIT);
        
        // Approve tokens
        vm.prank(alice);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(market), type(uint256).max);
        usdc.approve(address(market), type(uint256).max);
        usdc.approve(address(amm), type(uint256).max);
    }
    
    function testAddInitialLiquidity() public {
        // Purchase tokens from market
        market.purchaseTokens(10 * USDC_UNIT);
        
        // Get token addresses
        address yesToken = address(market.yesToken());
        address noToken = address(market.noToken());
        address yesNoToken = address(market.yesNoToken());
        
        // Approve AMM to spend tokens
        market.yesToken().approve(address(amm), type(uint256).max);
        market.noToken().approve(address(amm), type(uint256).max);
        market.yesNoToken().approve(address(amm), type(uint256).max);
        
        // Add initial liquidity
        amm.addInitialLiquidity(5, 5, 5, 15 * USDC_UNIT);
        
        assertEq(amm.yesReserves(), 5);
        assertEq(amm.noReserves(), 5);
        assertEq(amm.yesNoReserves(), 5);
        assertEq(amm.usdcReserves(), 15 * USDC_UNIT);
    }
    
    function testTokenSwap() public {
        // Setup liquidity
        market.purchaseTokens(10 * USDC_UNIT);
        market.yesToken().approve(address(amm), type(uint256).max);
        market.noToken().approve(address(amm), type(uint256).max);
        market.yesNoToken().approve(address(amm), type(uint256).max);
        amm.addInitialLiquidity(5, 5, 5, 15 * USDC_UNIT);
        
        // Alice buys some tokens
        vm.prank(alice);
        market.purchaseTokens(5 * USDC_UNIT);
        
        // Alice swaps YES tokens for NO tokens
        vm.prank(alice);
        market.yesToken().approve(address(amm), type(uint256).max);
        market.noToken().approve(address(amm), type(uint256).max);
        
        uint256 yesBalanceBefore = market.yesToken().balanceOf(alice);
        uint256 noBalanceBefore = market.noToken().balanceOf(alice);
        
        vm.prank(alice);
        uint256 amountOut = amm.swap(address(market.yesToken()), address(market.noToken()), 2);
        
        uint256 yesBalanceAfter = market.yesToken().balanceOf(alice);
        uint256 noBalanceAfter = market.noToken().balanceOf(alice);
        
        assertEq(yesBalanceBefore - yesBalanceAfter, 2);
        assertEq(noBalanceAfter - noBalanceBefore, amountOut);
        assertTrue(amountOut > 0);
    }
    
    function testProbabilityConstraint() public {
        // Setup liquidity
        market.purchaseTokens(10 * USDC_UNIT);
        market.yesToken().approve(address(amm), type(uint256).max);
        market.noToken().approve(address(amm), type(uint256).max);
        market.yesNoToken().approve(address(amm), type(uint256).max);
        amm.addInitialLiquidity(5, 5, 5, 15 * USDC_UNIT);
        
        // Check initial probability
        uint256 initialProbability = amm.getTotalProbability();
        assertTrue(initialProbability <= 1e6, "Initial probability should be <= 100%");
        
        // Try to manipulate reserves to exceed 100% probability
        // This should fail due to the probability constraint
        vm.prank(alice);
        market.purchaseTokens(5 * USDC_UNIT);
        
        vm.prank(alice);
        market.yesToken().approve(address(amm), type(uint256).max);
        
        // Try to sell YES tokens for USDC in a way that would violate probability constraint
        // The AMM should prevent this
        vm.prank(alice);
        uint256 amountOut = amm.getAmountOut(address(market.yesToken()), address(usdc), 3);
        
        // Verify the swap doesn't violate probability constraint
        uint256 newProbability = amm.getTotalProbabilityAfterSwap(
            address(market.yesToken()), 
            address(usdc), 
            3, 
            amountOut
        );
        assertTrue(newProbability <= 1e6, "Probability constraint should not be violated");
    }
    
    function testNoArbitrageOpportunity() public {
        // Setup liquidity
        market.purchaseTokens(10 * USDC_UNIT);
        market.yesToken().approve(address(amm), type(uint256).max);
        market.noToken().approve(address(amm), type(uint256).max);
        market.yesNoToken().approve(address(amm), type(uint256).max);
        amm.addInitialLiquidity(5, 5, 5, 15 * USDC_UNIT);
        
        // Alice's initial USDC balance
        uint256 aliceInitialUSDC = usdc.balanceOf(alice);
        
        // Alice buys tokens from market (costs 1 USDC per set)
        vm.prank(alice);
        market.purchaseTokens(5 * USDC_UNIT);
        
        // Alice tries to sell tokens on AMM for more than 1 USDC
        vm.prank(alice);
        market.yesToken().approve(address(amm), type(uint256).max);
        
        uint256 amountOut = amm.getAmountOut(address(market.yesToken()), address(usdc), 5);
        
        // The amount out should be less than or equal to 5 USDC to prevent arbitrage
        assertTrue(amountOut <= 5 * USDC_UNIT, "Should not allow arbitrage");
        
        // Alice's final USDC balance should not be more than her initial balance
        vm.prank(alice);
        amm.swap(address(market.yesToken()), address(usdc), 5);
        
        uint256 aliceFinalUSDC = usdc.balanceOf(alice);
        assertTrue(aliceFinalUSDC <= aliceInitialUSDC, "No arbitrage should be possible");
    }
    
    function testGetTokenPrice() public {
        // Setup liquidity
        market.purchaseTokens(10 * USDC_UNIT);
        market.yesToken().approve(address(amm), type(uint256).max);
        market.noToken().approve(address(amm), type(uint256).max);
        market.yesNoToken().approve(address(amm), type(uint256).max);
        amm.addInitialLiquidity(5, 5, 5, 15 * USDC_UNIT);
        
        uint256 yesPrice = amm.getTokenPrice(address(market.yesToken()));
        uint256 noPrice = amm.getTokenPrice(address(market.noToken()));
        uint256 yesNoPrice = amm.getTokenPrice(address(market.yesNoToken()));
        
        assertTrue(yesPrice > 0, "YES token should have a price");
        assertTrue(noPrice > 0, "NO token should have a price");
        assertTrue(yesNoPrice > 0, "YES-NO token should have a price");
        
        uint256 totalProbability = yesPrice + noPrice + yesNoPrice;
        assertTrue(totalProbability <= 1e6, "Total probability should be <= 100%");
    }
} 