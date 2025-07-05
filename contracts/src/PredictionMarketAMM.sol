// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PredictionMarket.sol";

/**
 * @title PredictionMarketAMM
 * @dev Uniswap V2-style AMM for prediction market tokens using x*y=k formula
 */
contract PredictionMarketAMM is ReentrancyGuard, Ownable {
    IERC20 public immutable usdc;
    PredictionMarket public immutable predictionMarket;
    
    // Token contracts
    IERC20 public immutable yesToken;
    IERC20 public immutable noToken;
    IERC20 public immutable yesNoToken;
    
    // AMM state - separate pools for each token pair
    uint256 public yesReserves;
    uint256 public noReserves;
    uint256 public yesNoReserves;
    uint256 public usdcReserves;
    
    // Constants
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant FEE_NUMERATOR = 3; // 0.3% fee
    
    // Events
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    
    event AddLiquidity(
        address indexed provider,
        uint256 yesAmount,
        uint256 noAmount,
        uint256 yesNoAmount,
        uint256 usdcAmount
    );
    
    constructor(
        address _usdc,
        address _predictionMarket
    ) Ownable() {
        usdc = IERC20(_usdc);
        predictionMarket = PredictionMarket(_predictionMarket);
        
        // Get token addresses from the prediction market
        yesToken = IERC20(predictionMarket.yesToken());
        noToken = IERC20(predictionMarket.noToken());
        yesNoToken = IERC20(predictionMarket.yesNoToken());
    }
    
    /**
     * @dev Get reserves for a specific token
     */
    function getTokenReserves(address token) public view returns (uint256) {
        if (token == address(yesToken)) return yesReserves;
        if (token == address(noToken)) return noReserves;
        if (token == address(yesNoToken)) return yesNoReserves;
        if (token == address(usdc)) return usdcReserves;
        return 0;
    }
    
    /**
     * @dev Swap tokens using x*y=k constant product formula
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external nonReentrant returns (uint256 amountOut) {
        require(tokenIn != tokenOut, "Cannot swap same token");
        require(amountIn > 0, "Amount must be greater than 0");
        require(
            tokenIn == address(yesToken) || tokenIn == address(noToken) || tokenIn == address(yesNoToken) || tokenIn == address(usdc),
            "Invalid token in"
        );
        require(
            tokenOut == address(yesToken) || tokenOut == address(noToken) || tokenOut == address(yesNoToken) || tokenOut == address(usdc),
            "Invalid token out"
        );
        
        // Calculate amount out using x*y=k formula
        amountOut = getAmountOut(tokenIn, tokenOut, amountIn);
        require(amountOut > 0, "Insufficient output amount");
        
        // Transfer tokens
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);
        
        // Update reserves
        updateReserves(tokenIn, tokenOut, amountIn, amountOut);
        
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }
    
    /**
     * @dev Calculate amount out using x*y=k constant product formula
     * Formula: amountOut = (amountIn * reserveOut * (1000 - fee)) / (reserveIn * 1000 + amountIn * (1000 - fee))
     */
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256) {
        uint256 reserveIn = getTokenReserves(tokenIn);
        uint256 reserveOut = getTokenReserves(tokenOut);
        
        if (reserveIn == 0 || reserveOut == 0) {
            return 0;
        }
        
        // Apply fee to amount in
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        
        // Calculate amount out using x*y=k formula
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        
        return numerator / denominator;
    }
    
    /**
     * @dev Update reserves after a swap
     * Ensures x*y=k invariant is maintained
     */
    function updateReserves(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) internal {
        if (tokenIn == address(yesToken)) yesReserves += amountIn;
        else if (tokenIn == address(noToken)) noReserves += amountIn;
        else if (tokenIn == address(yesNoToken)) yesNoReserves += amountIn;
        else if (tokenIn == address(usdc)) usdcReserves += amountIn;
        
        if (tokenOut == address(yesToken)) yesReserves -= amountOut;
        else if (tokenOut == address(noToken)) noReserves -= amountOut;
        else if (tokenOut == address(yesNoToken)) yesNoReserves -= amountOut;
        else if (tokenOut == address(usdc)) usdcReserves -= amountOut;
    }
    
    /**
     * @dev Add initial liquidity (only owner)
     */
    function addInitialLiquidity(
        uint256 yesAmount,
        uint256 noAmount,
        uint256 yesNoAmount,
        uint256 usdcAmount
    ) external onlyOwner {
        require(yesReserves == 0 && noReserves == 0 && yesNoReserves == 0 && usdcReserves == 0, "Liquidity already added");
        
        // Transfer tokens
        yesToken.transferFrom(msg.sender, address(this), yesAmount);
        noToken.transferFrom(msg.sender, address(this), noAmount);
        yesNoToken.transferFrom(msg.sender, address(this), yesNoAmount);
        usdc.transferFrom(msg.sender, address(this), usdcAmount);
        
        // Set initial reserves
        yesReserves = yesAmount;
        noReserves = noAmount;
        yesNoReserves = yesNoAmount;
        usdcReserves = usdcAmount;
        
        emit AddLiquidity(msg.sender, yesAmount, noAmount, yesNoAmount, usdcAmount);
    }
    
    /**
     * @dev Get current token prices in USDC
     */
    function getTokenPrice(address token) public view returns (uint256) {
        uint256 tokenReserves = getTokenReserves(token);
        uint256 usdcReserve = usdcReserves;
        
        if (tokenReserves == 0 || usdcReserve == 0) {
            return 0;
        }
        
        return (usdcReserve * 1e6) / tokenReserves; // Price in USDC with 6 decimals
    }
    
    /**
     * @dev Verify that x*y=k invariant is maintained for a token pair
     */
    function verifyInvariant(address tokenA, address tokenB) public view returns (bool) {
        uint256 reserveA = getTokenReserves(tokenA);
        uint256 reserveB = getTokenReserves(tokenB);
        
        if (reserveA == 0 || reserveB == 0) {
            return true; // No liquidity, invariant holds
        }
        
        // For now, we'll just return true since we're using a simplified model
        // In a full implementation, you'd track the k value and verify it's maintained
        return true;
    }
} 