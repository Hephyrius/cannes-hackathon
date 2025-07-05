// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./interfaces/IUniswapV2Factory.sol";
import "./PredictionMarketPair.sol";
import "./PredictionMarket.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PredictionMarketFactory
 * @dev Factory for creating prediction market pairs, following Uniswap V2 pattern
 */
contract PredictionMarketFactory is IUniswapV2Factory {
    address public override feeTo;
    address public override feeToSetter;
    
    IERC20 public immutable usdc;
    address public stagedMarketManager;
    
    uint256 public constant SEED_REQUIREMENT = 10e6; // 10 USDC
    uint256 public constant TOKEN_MINT_AMOUNT = 5e6; // 5 USDC worth of tokens
    uint256 public constant LIQUIDITY_PER_PAIR = 25e5; // 2.5 USDC per pair
    
    // Mapping from token pair to pair address
    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;
    
    event MarketSeeded(address indexed market, address indexed seeder, uint256 amount);
    
    constructor(address _feeToSetter, address _usdc) {
        feeToSetter = _feeToSetter;
        usdc = IERC20(_usdc);
    }
    
    /**
     * @dev Set the staged market manager
     */
    function setStagedMarketManager(address _stagedMarketManager) external {
        require(msg.sender == feeToSetter, "FORBIDDEN");
        stagedMarketManager = _stagedMarketManager;
    }
    
    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }
    
    /**
     * @dev Create a pair for two tokens
     */
    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, "PredictionMarketFactory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "PredictionMarketFactory: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "PredictionMarketFactory: PAIR_EXISTS");
        
        // Create pair contract
        bytes memory bytecode = type(PredictionMarketPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        // Initialize the pair
        IUniswapV2Pair(pair).initialize(token0, token1);
        
        // Update mappings
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
    }
    
    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "PredictionMarketFactory: FORBIDDEN");
        feeTo = _feeTo;
    }
    
    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "PredictionMarketFactory: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
    
    /**
     * @dev Seed a prediction market with initial liquidity
     * Requires 10 USDC: 5 USDC for tokens, 2.5 USDC for each pair
     */
    function seedMarket(address market) external {
        require(stagedMarketManager != address(0), "Staged manager not set");
        
        // Transfer 10 USDC from user
        usdc.transferFrom(msg.sender, address(this), SEED_REQUIREMENT);
        
        // Get market contract
        PredictionMarket predMarket = PredictionMarket(market);
        
        // Use 5 USDC to purchase tokens (creates 5 YES, 5 NO, 5 POWER tokens)
        usdc.approve(market, TOKEN_MINT_AMOUNT);
        predMarket.purchaseTokens(TOKEN_MINT_AMOUNT);
        
        // Get token addresses
        address yesToken = address(predMarket.yesToken());
        address noToken = address(predMarket.noToken());
        
        // Create pairs if they don't exist
        address yesUsdcPair = getPair[yesToken][address(usdc)];
        if (yesUsdcPair == address(0)) {
            yesUsdcPair = this.createPair(yesToken, address(usdc));
        }
        
        address noUsdcPair = getPair[noToken][address(usdc)];
        if (noUsdcPair == address(0)) {
            noUsdcPair = this.createPair(noToken, address(usdc));
        }
        
        // Initialize staged market
        if (stagedMarketManager != address(0)) {
            // Transfer tokens to staged manager for seeding
            predMarket.yesToken().transfer(stagedMarketManager, 5);
            predMarket.noToken().transfer(stagedMarketManager, 5);
            usdc.transfer(stagedMarketManager, LIQUIDITY_PER_PAIR * 2); // 5 USDC total
            
            // Initialize market in staged manager
            // This will be called by the staged manager when ready
        }
        
        emit MarketSeeded(market, msg.sender, SEED_REQUIREMENT);
    }
} 