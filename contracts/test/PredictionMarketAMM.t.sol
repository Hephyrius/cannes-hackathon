// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/PredictionMarket.sol";
import "../src/PredictionMarketFactory.sol";
import "../src/PredictionMarketPair.sol";
import "../src/interfaces/IUniswapV2Pair.sol";
import "../src/interfaces/IUniswapV2ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PredictionMarketAMMTest is Test {
    MockUSDC usdc;
    PredictionMarket market;
    PredictionMarketFactory factory;
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);
    uint256 constant USDC_UNIT = 1e6;
    
    function setUp() public {
        usdc = new MockUSDC();
        market = new PredictionMarket(address(usdc), "Test Market", block.timestamp + 1 days);
        factory = new PredictionMarketFactory(address(this));
        
        // Mint USDC to test accounts
        usdc.mint(alice, 1000 * USDC_UNIT);
        usdc.mint(bob, 1000 * USDC_UNIT);
        usdc.mint(charlie, 1000 * USDC_UNIT);
        
        // Approve tokens
        vm.prank(alice);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(charlie);
        usdc.approve(address(market), type(uint256).max);
    }
    
    function testFactoryDeployment() public {
        assertEq(factory.feeToSetter(), address(this));
        assertEq(factory.allPairsLength(), 0);
    }
    
    function testCreatePair() public {
        address yesToken = address(market.yesToken());
        
        // Create YES/USDC pair
        address pair = factory.createPair(yesToken, address(usdc));
        assertTrue(pair != address(0));
        assertEq(factory.getPair(yesToken, address(usdc)), pair);
        assertEq(factory.getPair(address(usdc), yesToken), pair);
        assertEq(factory.allPairsLength(), 1);
        assertEq(factory.allPairs(0), pair);
        
        // Verify pair initialization
        IUniswapV2Pair pairContract = IUniswapV2Pair(pair);
        assertEq(pairContract.factory(), address(factory));
        // Note: token0 should be the lower address
        if (address(usdc) < yesToken) {
            assertEq(pairContract.token0(), address(usdc));
            assertEq(pairContract.token1(), yesToken);
        } else {
            assertEq(pairContract.token0(), yesToken);
            assertEq(pairContract.token1(), address(usdc));
        }
    }
    
    function testCreateAllPairs() public {
        address yesToken = address(market.yesToken());
        address noToken = address(market.noToken());
        address yesNoToken = address(market.yesNoToken());
        
        // Create all pairs
        address yesUsdcPair = factory.createPair(yesToken, address(usdc));
        address noUsdcPair = factory.createPair(noToken, address(usdc));
        address yesNoUsdcPair = factory.createPair(yesNoToken, address(usdc));
        
        assertEq(factory.allPairsLength(), 3);
        assertTrue(yesUsdcPair != address(0));
        assertTrue(noUsdcPair != address(0));
        assertTrue(yesNoUsdcPair != address(0));
    }
    
    function testAddLiquidity() public {
        // Create pair
        address yesToken = address(market.yesToken());
        address yesUsdcPair = factory.createPair(yesToken, address(usdc));
        
        // Alice buys tokens
        vm.prank(alice);
        market.purchaseTokens(10 * USDC_UNIT);
        
        // Check Alice's balances
        uint256 aliceYesBalance = market.yesToken().balanceOf(alice);
        uint256 aliceUsdcBalance = usdc.balanceOf(alice);
        
        assertEq(aliceYesBalance, 10); // 10 YES tokens
        assertEq(aliceUsdcBalance, 990 * USDC_UNIT); // 990 USDC remaining
        
        // Transfer tokens to pair for liquidity
        uint256 yesAmount = 5; // 5 YES tokens
        uint256 usdcAmount = 5 * USDC_UNIT; // 5 USDC
        
        vm.prank(alice);
        market.yesToken().transfer(yesUsdcPair, yesAmount);
        vm.prank(alice);
        usdc.transfer(yesUsdcPair, usdcAmount);
        
        // Mint liquidity
        vm.prank(alice);
        uint256 liquidity = IUniswapV2Pair(yesUsdcPair).mint(alice);
        
        assertTrue(liquidity > 0);
        assertEq(IUniswapV2ERC20(yesUsdcPair).balanceOf(alice), liquidity);
        
        // Check reserves
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(yesUsdcPair).getReserves();
        assertTrue(reserve0 > 0);
        assertTrue(reserve1 > 0);
    }
    
    function testSwap() public {
        // Setup liquidity first
        address yesToken = address(market.yesToken());
        address yesUsdcPair = factory.createPair(yesToken, address(usdc));
        
        // Alice provides liquidity
        vm.prank(alice);
        market.purchaseTokens(10 * USDC_UNIT);
        
        vm.prank(alice);
        market.yesToken().approve(yesUsdcPair, type(uint256).max);
        vm.prank(alice);
        usdc.approve(yesUsdcPair, type(uint256).max);
        
        // Add liquidity
        vm.prank(alice);
        market.yesToken().transfer(yesUsdcPair, 5);
        vm.prank(alice);
        usdc.transfer(yesUsdcPair, 5 * USDC_UNIT);
        vm.prank(alice);
        IUniswapV2Pair(yesUsdcPair).mint(alice);
        
        // Bob buys tokens and swaps
        vm.prank(bob);
        market.purchaseTokens(5 * USDC_UNIT);
        
        uint256 bobYesBefore = market.yesToken().balanceOf(bob);
        uint256 bobUsdcBefore = usdc.balanceOf(bob);
        
        // Bob transfers YES tokens to pair for swap
        vm.prank(bob);
        market.yesToken().transfer(yesUsdcPair, 1);
        
        // Bob swaps (gets USDC out)
        vm.prank(bob);
        IUniswapV2Pair(yesUsdcPair).swap(0, 1 * USDC_UNIT, bob, "");
        
        uint256 bobYesAfter = market.yesToken().balanceOf(bob);
        uint256 bobUsdcAfter = usdc.balanceOf(bob);
        
        assertTrue(bobYesBefore > bobYesAfter); // Bob spent YES tokens
        assertTrue(bobUsdcAfter > bobUsdcBefore); // Bob received USDC
    }
    
    function testRemoveLiquidity() public {
        // Setup liquidity first
        address yesToken = address(market.yesToken());
        address yesUsdcPair = factory.createPair(yesToken, address(usdc));
        
        // Alice provides liquidity
        vm.prank(alice);
        market.purchaseTokens(10 * USDC_UNIT);
        
        vm.prank(alice);
        market.yesToken().approve(yesUsdcPair, type(uint256).max);
        vm.prank(alice);
        usdc.approve(yesUsdcPair, type(uint256).max);
        
        // Add liquidity
        vm.prank(alice);
        market.yesToken().transfer(yesUsdcPair, 5);
        vm.prank(alice);
        usdc.transfer(yesUsdcPair, 5 * USDC_UNIT);
        vm.prank(alice);
        uint256 liquidity = IUniswapV2Pair(yesUsdcPair).mint(alice);
        
        uint256 aliceYesBefore = market.yesToken().balanceOf(alice);
        uint256 aliceUsdcBefore = usdc.balanceOf(alice);
        
        // Alice removes half her liquidity
        vm.prank(alice);
        IUniswapV2ERC20(yesUsdcPair).transfer(yesUsdcPair, liquidity / 2);
        vm.prank(alice);
        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(yesUsdcPair).burn(alice);
        
        uint256 aliceYesAfter = market.yesToken().balanceOf(alice);
        uint256 aliceUsdcAfter = usdc.balanceOf(alice);
        
        assertTrue(aliceYesAfter > aliceYesBefore); // Alice received YES tokens back
        assertTrue(aliceUsdcAfter > aliceUsdcBefore); // Alice received USDC back
        assertTrue(amount0 > 0 || amount1 > 0);
    }
    
    function testPairERC20Functions() public {
        // Create pair and add liquidity
        address yesToken = address(market.yesToken());
        address yesUsdcPair = factory.createPair(yesToken, address(usdc));
        
        vm.prank(alice);
        market.purchaseTokens(10 * USDC_UNIT);
        
        vm.prank(alice);
        market.yesToken().approve(yesUsdcPair, type(uint256).max);
        vm.prank(alice);
        usdc.approve(yesUsdcPair, type(uint256).max);
        
        vm.prank(alice);
        market.yesToken().transfer(yesUsdcPair, 5);
        vm.prank(alice);
        usdc.transfer(yesUsdcPair, 5 * USDC_UNIT);
        vm.prank(alice);
        uint256 liquidity = IUniswapV2Pair(yesUsdcPair).mint(alice);
        
        // Test ERC20 functions
        assertEq(IUniswapV2ERC20(yesUsdcPair).name(), "Prediction Market V2");
        assertEq(IUniswapV2ERC20(yesUsdcPair).symbol(), "PM-V2");
        assertEq(IUniswapV2ERC20(yesUsdcPair).decimals(), 18);
        assertEq(IUniswapV2ERC20(yesUsdcPair).totalSupply(), liquidity);
        
        // Test approval
        vm.prank(alice);
        IUniswapV2ERC20(yesUsdcPair).approve(bob, 100);
        assertEq(IUniswapV2ERC20(yesUsdcPair).allowance(alice, bob), 100);
        
        // Test transfer
        vm.prank(alice);
        IUniswapV2ERC20(yesUsdcPair).transfer(bob, liquidity / 2);
        assertEq(IUniswapV2ERC20(yesUsdcPair).balanceOf(bob), liquidity / 2);
        assertEq(IUniswapV2ERC20(yesUsdcPair).balanceOf(alice), liquidity / 2);
    }
    
    function testFactoryFeeControls() public {
        // Test fee controls
        factory.setFeeTo(charlie);
        assertEq(factory.feeTo(), charlie);
        
        factory.setFeeToSetter(bob);
        assertEq(factory.feeToSetter(), bob);
        
        // Only fee setter can change fees
        vm.prank(alice);
        vm.expectRevert("PredictionMarketFactory: FORBIDDEN");
        factory.setFeeTo(alice);
    }
    
    function testSync() public {
        // Create pair and add liquidity
        address yesToken = address(market.yesToken());
        address yesUsdcPair = factory.createPair(yesToken, address(usdc));
        
        vm.prank(alice);
        market.purchaseTokens(10 * USDC_UNIT);
        
        vm.prank(alice);
        market.yesToken().transfer(yesUsdcPair, 5);
        vm.prank(alice);
        usdc.transfer(yesUsdcPair, 5 * USDC_UNIT);
        vm.prank(alice);
        IUniswapV2Pair(yesUsdcPair).mint(alice);
        
        // Sync reserves
        IUniswapV2Pair(yesUsdcPair).sync();
        
        // Verify reserves are updated
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(yesUsdcPair).getReserves();
        assertTrue(reserve0 > 0);
        assertTrue(reserve1 > 0);
    }
    
    function testSkim() public {
        // Create pair and add liquidity
        address yesToken = address(market.yesToken());
        address yesUsdcPair = factory.createPair(yesToken, address(usdc));
        
        vm.prank(alice);
        market.purchaseTokens(10 * USDC_UNIT);
        
        vm.prank(alice);
        market.yesToken().transfer(yesUsdcPair, 5);
        vm.prank(alice);
        usdc.transfer(yesUsdcPair, 5 * USDC_UNIT);
        vm.prank(alice);
        IUniswapV2Pair(yesUsdcPair).mint(alice);
        
        // Skim excess tokens (should be none in this case)
        IUniswapV2Pair(yesUsdcPair).skim(charlie);
        
        // Charlie should not receive any tokens since there are no excess
        uint256 charlieYesBalance = market.yesToken().balanceOf(charlie);
        uint256 charlieUsdcBalance = usdc.balanceOf(charlie);
        assertEq(charlieYesBalance, 0);
        assertEq(charlieUsdcBalance, 1000 * USDC_UNIT); // Original balance
    }

    function testDebugBalances() public {
        // Create pair
        address yesToken = address(market.yesToken());
        address yesUsdcPair = factory.createPair(yesToken, address(usdc));
        
        // Check Alice's initial balance
        uint256 aliceUsdcInitial = usdc.balanceOf(alice);
        console.log("Alice initial USDC:", aliceUsdcInitial);
        
        // Alice buys tokens
        vm.prank(alice);
        market.purchaseTokens(10 * USDC_UNIT);
        
        // Check Alice's balances after purchase
        uint256 aliceYesBalance = market.yesToken().balanceOf(alice);
        uint256 aliceUsdcBalance = usdc.balanceOf(alice);
        
        console.log("Alice YES balance:", aliceYesBalance);
        console.log("Alice USDC balance after purchase:", aliceUsdcBalance);
        console.log("Expected USDC balance:", 990 * USDC_UNIT);
        
        assertEq(aliceYesBalance, 10); // 10 YES tokens
        assertEq(aliceUsdcBalance, 990 * USDC_UNIT); // 990 USDC remaining
    }
} 