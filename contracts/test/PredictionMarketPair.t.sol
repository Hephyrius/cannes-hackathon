// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/PredictionMarketPair.sol";
import "../src/PredictionMarket.sol";
import "../src/YesNoToken.sol";
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

contract PredictionMarketPairTest is Test {
    PredictionMarketPair public pair;
    PredictionMarket public market;
    YesNoToken public yesToken;
    YesNoToken public noToken;
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
        
        yesToken = new YesNoToken("Bitcoin YES", "BTCY", address(market));
        noToken = new YesNoToken("Bitcoin NO", "BTCN", address(market));
        
        pair = new PredictionMarketPair(
            address(yesToken),
            address(noToken),
            address(usdc)
        );
        
        pair.transferOwnership(owner);
        
        usdc.mint(alice, 50000e6);
        usdc.mint(bob, 30000e6);
        usdc.mint(charlie, 20000e6);
        usdc.mint(owner, 100000e6);
        
        yesToken.mint(alice, 10000e18);
        yesToken.mint(bob, 8000e18);
        noToken.mint(alice, 10000e18);
        noToken.mint(bob, 8000e18);
    }
    
    function testConstructor() public view {
        assertEq(address(pair.yesToken()), address(yesToken));
        assertEq(address(pair.noToken()), address(noToken));
        assertEq(address(pair.usdc()), address(usdc));
        assertEq(pair.owner(), owner);
    }
    
    function testAddLiquidity() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        uint256 liquidity = pair.addLiquidity(1000e18, 1000e18, 2000e6);
        vm.stopPrank();
        
        assertGt(liquidity, 0);
        assertEq(pair.balanceOf(alice), liquidity);
    }
    
    function testAddLiquidityOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
    }
    
    function testAddLiquidityInsufficientAllowance() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 500e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        vm.expectRevert("ERC20: insufficient allowance");
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        vm.stopPrank();
    }
    
    function testRemoveLiquidity() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        uint256 liquidity = pair.addLiquidity(1000e18, 1000e18, 2000e6);
        
        pair.approve(address(pair), liquidity);
        (uint256 yesAmount, uint256 noAmount, uint256 usdcAmount) = pair.removeLiquidity(liquidity);
        vm.stopPrank();
        
        assertGt(yesAmount, 0);
        assertGt(noAmount, 0);
        assertGt(usdcAmount, 0);
    }
    
    function testRemoveLiquidityInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        pair.removeLiquidity(1000e18);
    }
    
    function testSwapYesForUSDC() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        
        yesToken.approve(address(pair), 500e18);
        uint256 usdcReceived = pair.swapYesForUSDC(500e18);
        vm.stopPrank();
        
        assertGt(usdcReceived, 0);
    }
    
    function testSwapNoForUSDC() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        
        noToken.approve(address(pair), 500e18);
        uint256 usdcReceived = pair.swapNoForUSDC(500e18);
        vm.stopPrank();
        
        assertGt(usdcReceived, 0);
    }
    
    function testSwapUSDCForYes() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        
        usdc.approve(address(pair), 500e6);
        uint256 yesReceived = pair.swapUSDCForYes(500e6);
        vm.stopPrank();
        
        assertGt(yesReceived, 0);
    }
    
    function testSwapUSDCForNo() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        
        usdc.approve(address(pair), 500e6);
        uint256 noReceived = pair.swapUSDCForNo(500e6);
        vm.stopPrank();
        
        assertGt(noReceived, 0);
    }
    
    function testGetReserves() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        vm.stopPrank();
        
        (uint256 yesReserve, uint256 noReserve, uint256 usdcReserve) = pair.getReserves();
        
        assertEq(yesReserve, 1000e18);
        assertEq(noReserve, 1000e18);
        assertEq(usdcReserve, 2000e6);
    }
    
    function testGetQuote() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        vm.stopPrank();
        
        uint256 quote = pair.getQuote(100e18, address(yesToken), address(usdc));
        assertGt(quote, 0);
    }
    
    function testGetQuoteInvalidToken() public {
        vm.expectRevert("Invalid token");
        pair.getQuote(100e18, address(0x999), address(usdc));
    }
    
    function testSetFee() public {
        vm.prank(owner);
        pair.setFee(300); // 3%
        
        assertEq(pair.fee(), 300);
    }
    
    function testSetFeeOnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        pair.setFee(300);
    }
    
    function testSetFeeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert("Fee too high");
        pair.setFee(10000); // 100%
    }
    
    function testSetFeeTooLow() public {
        vm.prank(owner);
        vm.expectRevert("Fee too low");
        pair.setFee(0);
    }
    
    function testSwapInsufficientLiquidity() public {
        vm.prank(alice);
        yesToken.approve(address(pair), 1000e18);
        vm.expectRevert("Insufficient liquidity");
        pair.swapYesForUSDC(1000e18);
    }
    
    function testSwapZeroAmount() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        
        yesToken.approve(address(pair), 0);
        vm.expectRevert("Amount must be greater than 0");
        pair.swapYesForUSDC(0);
        vm.stopPrank();
    }
    
    function testRemoveLiquidityZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert("Amount must be greater than 0");
        pair.removeLiquidity(0);
    }
    
    function testAddLiquidityZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert("Amount must be greater than 0");
        pair.addLiquidity(0, 1000e18, 2000e6);
    }
    
    function testFuzzAddLiquidity(uint256 yesAmount, uint256 noAmount, uint256 usdcAmount) public {
        vm.assume(yesAmount > 0 && yesAmount <= 10000e18);
        vm.assume(noAmount > 0 && noAmount <= 10000e18);
        vm.assume(usdcAmount > 0 && usdcAmount <= 20000e6);
        
        vm.startPrank(alice);
        yesToken.approve(address(pair), yesAmount);
        noToken.approve(address(pair), noAmount);
        usdc.approve(address(pair), usdcAmount);
        
        uint256 liquidity = pair.addLiquidity(yesAmount, noAmount, usdcAmount);
        vm.stopPrank();
        
        assertGt(liquidity, 0);
    }
    
    function testFuzzSwap(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000e18);
        
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        
        yesToken.approve(address(pair), amount);
        uint256 usdcReceived = pair.swapYesForUSDC(amount);
        vm.stopPrank();
        
        assertGt(usdcReceived, 0);
    }
    
    function testInvariantReserves() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        uint256 liquidity = pair.addLiquidity(1000e18, 1000e18, 2000e6);
        
        (uint256 yesReserve, uint256 noReserve, uint256 usdcReserve) = pair.getReserves();
        
        // After adding liquidity, reserves should match
        assertEq(yesReserve, 1000e18);
        assertEq(noReserve, 1000e18);
        assertEq(usdcReserve, 2000e6);
        
        // Remove liquidity
        pair.approve(address(pair), liquidity);
        pair.removeLiquidity(liquidity);
        
        (yesReserve, noReserve, usdcReserve) = pair.getReserves();
        
        // After removing all liquidity, reserves should be 0
        assertEq(yesReserve, 0);
        assertEq(noReserve, 0);
        assertEq(usdcReserve, 0);
        vm.stopPrank();
    }
    
    function testEventEmission() public {
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketPair.LiquidityAdded(alice, 1000e18, 1000e18, 2000e6, 0);
        
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        vm.stopPrank();
    }
    
    function testSwapEventEmission() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        
        yesToken.approve(address(pair), 100e18);
        
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketPair.Swap(alice, address(yesToken), address(usdc), 100e18, 0);
        
        pair.swapYesForUSDC(100e18);
        vm.stopPrank();
    }
    
    function testLiquidityRemovedEvent() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        uint256 liquidity = pair.addLiquidity(1000e18, 1000e18, 2000e6);
        
        pair.approve(address(pair), liquidity);
        
        vm.expectEmit(true, true, false, true);
        emit PredictionMarketPair.LiquidityRemoved(alice, 0, 0, 0, liquidity);
        
        pair.removeLiquidity(liquidity);
        vm.stopPrank();
    }
    
    function testFeeCalculation() public {
        vm.prank(owner);
        pair.setFee(500); // 5%
        
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        
        yesToken.approve(address(pair), 100e18);
        uint256 usdcReceived = pair.swapYesForUSDC(100e18);
        vm.stopPrank();
        
        // With 5% fee, the received amount should be less than without fee
        assertGt(usdcReceived, 0);
    }
    
    function testMultipleSwaps() public {
        vm.startPrank(alice);
        yesToken.approve(address(pair), 1000e18);
        noToken.approve(address(pair), 1000e18);
        usdc.approve(address(pair), 2000e6);
        
        pair.addLiquidity(1000e18, 1000e18, 2000e6);
        
        yesToken.approve(address(pair), 100e18);
        uint256 usdcReceived1 = pair.swapYesForUSDC(100e18);
        
        usdc.approve(address(pair), 100e6);
        uint256 yesReceived = pair.swapUSDCForYes(100e6);
        
        noToken.approve(address(pair), 100e18);
        uint256 usdcReceived2 = pair.swapNoForUSDC(100e18);
        vm.stopPrank();
        
        assertGt(usdcReceived1, 0);
        assertGt(yesReceived, 0);
        assertGt(usdcReceived2, 0);
    }
} 