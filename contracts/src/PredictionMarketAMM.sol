// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PredictionMarket.sol";

/**
 * @title PredictionMarketAMM
 * @dev AMM for prediction market tokens with probability constraints
 */
contract PredictionMarketAMM is ReentrancyGuard, Ownable {
    IERC20 public immutable usdc;
    PredictionMarket public immutable predictionMarket;
    
    // Token contracts
    IERC20 public immutable yesToken;
    IERC20 public immutable noToken;
    IERC20 public immutable yesNoToken;
    
    // AMM state
    uint256 public yesReserves;
    uint256 public noReserves;
    uint256 public yesNoReserves;
    uint256 public usdcReserves;
    
    // Constants
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_PROBABILITY = 1e6; // 100% in USDC decimals
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
    
    event RemoveLiquidity(
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
     * @dev Calculate the price of a token based on reserves
     */
    function getTokenPrice(address token) public view returns (uint256) {
        uint256 totalValue = usdcReserves;
        uint256 tokenReserves = getTokenReserves(token);
        
        if (tokenReserves == 0 || totalValue == 0) {
            return 0;
        }
        
        return (tokenReserves * PRECISION) / totalValue;
    }
    
    /**
     * @dev Get reserves for a specific token
     */
    function getTokenReserves(address token) public view returns (uint256) {
        if (token == address(yesToken)) return yesReserves;
        if (token == address(noToken)) return noReserves;
        if (token == address(yesNoToken)) return yesNoReserves;
        return 0;
    }
    
    /**
     * @dev Calculate the total probability (sum of all token prices)
     */
    function getTotalProbability() public view returns (uint256) {
        uint256 yesPrice = getTokenPrice(address(yesToken));
        uint256 noPrice = getTokenPrice(address(noToken));
        uint256 yesNoPrice = getTokenPrice(address(yesNoToken));
        
        return yesPrice + noPrice + yesNoPrice;
    }
    
    /**
     * @dev Swap tokens using constant product formula with probability constraints
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
        
        // Calculate amount out
        amountOut = getAmountOut(tokenIn, tokenOut, amountIn);
        require(amountOut > 0, "Insufficient output amount");
        
        // Check probability constraint
        if (tokenOut == address(usdc)) {
            // Selling tokens for USDC - check if this would create arbitrage
            uint256 newTotalProbability = getTotalProbabilityAfterSwap(tokenIn, tokenOut, amountIn, amountOut);
            require(newTotalProbability <= MAX_PROBABILITY, "Probability constraint violated");
        }
        
        // Transfer tokens
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);
        
        // Update reserves
        updateReserves(tokenIn, tokenOut, amountIn, amountOut);
        
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }
    
    /**
     * @dev Calculate amount out for a swap
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
        
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_NUMERATOR);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        
        return numerator / denominator;
    }
    
    /**
     * @dev Calculate total probability after a swap
     */
    function getTotalProbabilityAfterSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) public view returns (uint256) {
        uint256 reserveIn = getTokenReserves(tokenIn);
        uint256 reserveOut = getTokenReserves(tokenOut);
        
        uint256 newReserveIn = reserveIn + amountIn;
        uint256 newReserveOut = reserveOut - amountOut;
        
        // Calculate new total value
        uint256 newTotalValue = usdcReserves;
        if (tokenIn == address(usdc)) {
            newTotalValue += amountIn;
        } else if (tokenOut == address(usdc)) {
            newTotalValue -= amountOut;
        }
        
        if (newTotalValue == 0) return 0;
        
        // Calculate new probabilities
        uint256 yesPrice = (yesReserves * PRECISION) / newTotalValue;
        uint256 noPrice = (noReserves * PRECISION) / newTotalValue;
        uint256 yesNoPrice = (yesNoReserves * PRECISION) / newTotalValue;
        
        // Adjust for the swapped tokens
        if (tokenIn == address(yesToken) || tokenOut == address(yesToken)) {
            yesPrice = (newReserveIn * PRECISION) / newTotalValue;
        }
        if (tokenIn == address(noToken) || tokenOut == address(noToken)) {
            noPrice = (newReserveIn * PRECISION) / newTotalValue;
        }
        if (tokenIn == address(yesNoToken) || tokenOut == address(yesNoToken)) {
            yesNoPrice = (newReserveIn * PRECISION) / newTotalValue;
        }
        
        return yesPrice + noPrice + yesNoPrice;
    }
    
    /**
     * @dev Update reserves after a swap
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
} 