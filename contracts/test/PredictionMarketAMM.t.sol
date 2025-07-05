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
        factory = new PredictionMarketFactory(address(this), address(usdc));
        
        // Mint USDC to test accounts
        usdc.mint(alice, 1000 * USDC_UNIT);
        usdc.mint(bob, 1000 * USDC_UNIT);
        usdc.mint(charlie, 1000 * USDC_UNIT);
        usdc.mint(address(this), 1000 * USDC_UNIT); // Give USDC to test contract
        
        // Approve tokens
        vm.prank(alice);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(charlie);
        usdc.approve(address(market), type(uint256).max);
        usdc.approve(address(market), type(uint256).max); // Test contract approves market
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
        
        // Test contract buys tokens instead of alice to avoid address issues
        market.purchaseTokens(10 * USDC_UNIT);
        
        // Check balances
        uint256 yesBalance = market.yesToken().balanceOf(address(this));
        uint256 usdcBalance = usdc.balanceOf(address(this));
        
        assertEq(yesBalance, 10); // 10 YES tokens
        
        // Transfer tokens to pair for liquidity
        uint256 yesAmount = 5; // 5 YES tokens
        uint256 usdcAmount = 5 * USDC_UNIT; // 5 USDC
        
        market.yesToken().transfer(yesUsdcPair, yesAmount);
        usdc.transfer(yesUsdcPair, usdcAmount);
        
        // Mint liquidity
        uint256 liquidity = IUniswapV2Pair(yesUsdcPair).mint(address(this));
        
        assertTrue(liquidity > 0);
        assertEq(IUniswapV2ERC20(yesUsdcPair).balanceOf(address(this)), liquidity);
        
        // Check reserves
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(yesUsdcPair).getReserves();
        assertTrue(reserve0 > 0);
        assertTrue(reserve1 > 0);
    }
    
    function testSwap() public {
        // Setup liquidity first
        address yesToken = address(market.yesToken());
        address yesUsdcPair = factory.createPair(yesToken, address(usdc));
        
        // Test contract provides liquidity
        market.purchaseTokens(10 * USDC_UNIT);
        
        // Add liquidity
        market.yesToken().transfer(yesUsdcPair, 5);
        usdc.transfer(yesUsdcPair, 5 * USDC_UNIT);
        IUniswapV2Pair(yesUsdcPair).mint(address(this));
        
        // Get initial balances for swap test
        uint256 yesBefore = market.yesToken().balanceOf(address(this));
        uint256 usdcBefore = usdc.balanceOf(address(this));
        
        // Transfer YES tokens to pair for swap
        market.yesToken().transfer(yesUsdcPair, 1);
        
        // Get current reserves to calculate output
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(yesUsdcPair).getReserves();
        
        // Calculate output amount using constant product formula
        // For simplicity, just swap without specifying exact output
        // The pair will determine the output based on the input
        uint256 amountOut = 0; // Let the pair calculate
        
        // Determine which token is which
        if (IUniswapV2Pair(yesUsdcPair).token0() == address(usdc)) {
            // USDC is token0, YES is token1, we want USDC out
            IUniswapV2Pair(yesUsdcPair).swap(100000, 0, address(this), ""); // Get some USDC out
        } else {
            // YES is token0, USDC is token1, we want USDC out  
            IUniswapV2Pair(yesUsdcPair).swap(0, 100000, address(this), ""); // Get some USDC out
        }
        
        uint256 yesAfter = market.yesToken().balanceOf(address(this));
        uint256 usdcAfter = usdc.balanceOf(address(this));
        
        assertTrue(yesBefore > yesAfter); // Spent YES tokens
        assertTrue(usdcAfter > usdcBefore); // Received USDC
    }
    
    function testRemoveLiquidity() public {
        // Setup liquidity first
        address yesToken = address(market.yesToken());
        address yesUsdcPair = factory.createPair(yesToken, address(usdc));
        
        // Test contract provides liquidity
        market.purchaseTokens(10 * USDC_UNIT);
        
        // Add liquidity
        market.yesToken().transfer(yesUsdcPair, 5);
        usdc.transfer(yesUsdcPair, 5 * USDC_UNIT);
        uint256 liquidity = IUniswapV2Pair(yesUsdcPair).mint(address(this));
        
        uint256 yesBefore = market.yesToken().balanceOf(address(this));
        uint256 usdcBefore = usdc.balanceOf(address(this));
        
        // Remove half the liquidity
        IUniswapV2ERC20(yesUsdcPair).transfer(yesUsdcPair, liquidity / 2);
        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(yesUsdcPair).burn(address(this));
        
        uint256 yesAfter = market.yesToken().balanceOf(address(this));
        uint256 usdcAfter = usdc.balanceOf(address(this));
        
        assertTrue(yesAfter > yesBefore); // Received YES tokens back
        assertTrue(usdcAfter > usdcBefore); // Received USDC back
        assertTrue(amount0 > 0 || amount1 > 0);
    }
    
    function testPairERC20Functions() public {
        // Create pair and add liquidity
        address yesToken = address(market.yesToken());
        address yesUsdcPair = factory.createPair(yesToken, address(usdc));
        
        market.purchaseTokens(10 * USDC_UNIT);
        
        market.yesToken().transfer(yesUsdcPair, 5);
        usdc.transfer(yesUsdcPair, 5 * USDC_UNIT);
        uint256 liquidity = IUniswapV2Pair(yesUsdcPair).mint(address(this));
        
        // Test ERC20 functions
        assertEq(IUniswapV2ERC20(yesUsdcPair).name(), "Prediction Market V2");
        assertEq(IUniswapV2ERC20(yesUsdcPair).symbol(), "PM-V2");
        assertEq(IUniswapV2ERC20(yesUsdcPair).decimals(), 18);
        assertEq(IUniswapV2ERC20(yesUsdcPair).totalSupply(), liquidity);
        
        // Test approval
        IUniswapV2ERC20(yesUsdcPair).approve(bob, 100);
        assertEq(IUniswapV2ERC20(yesUsdcPair).allowance(address(this), bob), 100);
        
        // Test transfer
        IUniswapV2ERC20(yesUsdcPair).transfer(bob, liquidity / 2);
        assertEq(IUniswapV2ERC20(yesUsdcPair).balanceOf(bob), liquidity / 2);
        assertEq(IUniswapV2ERC20(yesUsdcPair).balanceOf(address(this)), liquidity / 2);
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
        
        market.purchaseTokens(10 * USDC_UNIT);
        
        market.yesToken().transfer(yesUsdcPair, 5);
        usdc.transfer(yesUsdcPair, 5 * USDC_UNIT);
        IUniswapV2Pair(yesUsdcPair).mint(address(this));
        
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
        
        market.purchaseTokens(10 * USDC_UNIT);
        
        market.yesToken().transfer(yesUsdcPair, 5);
        usdc.transfer(yesUsdcPair, 5 * USDC_UNIT);
        IUniswapV2Pair(yesUsdcPair).mint(address(this));
        
        // Skim excess tokens (should be none in this case)
        IUniswapV2Pair(yesUsdcPair).skim(charlie);
        
        // Charlie should not receive any tokens since there are no excess
        uint256 charlieYesBalance = market.yesToken().balanceOf(charlie);
        uint256 charlieUsdcBalance = usdc.balanceOf(charlie);
        assertEq(charlieYesBalance, 0);
        assertEq(charlieUsdcBalance, 1000 * USDC_UNIT); // Original balance
    }


} 