// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PredictionMarket.sol";
import "./PredictionMarketVoting.sol";
import "./PredictionMarketFactory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2ERC20.sol";

/**
 * @title StagedPredictionMarket
 * @dev Manages prediction markets with seeding, voting, withdrawal, and trading phases
 */
contract StagedPredictionMarket {
    enum Stage { SEEDING, VOTING, WITHDRAWAL, TRADING, RESOLVED }
    
    struct MarketInfo {
        PredictionMarket market;
        address yesUsdcPair;
        address noUsdcPair;
        Stage currentStage;
        uint256 stageStartTime;
        bool initialized;
    }
    
    mapping(address => MarketInfo) public markets;
    
    PredictionMarketFactory public immutable factory;
    PredictionMarketVoting public immutable voting;
    IERC20 public immutable usdc;
    
    uint256 public constant SEEDING_DURATION = 48 hours;
    uint256 public constant VOTING_DURATION = 24 hours;
    uint256 public constant WITHDRAWAL_DURATION = 12 hours;
    
    event MarketInitialized(address indexed market, address yesUsdcPair, address noUsdcPair);
    event StageChanged(address indexed market, Stage oldStage, Stage newStage);
    event LiquiditySeeded(address indexed market, address indexed seeder, uint256 amount);
    event LiquidityWithdrawn(address indexed market, address indexed withdrawer, uint256 amount);
    
    modifier onlyValidMarket(address market) {
        require(markets[market].initialized, "Market not initialized");
        _;
    }
    
    modifier onlyStage(address market, Stage stage) {
        require(markets[market].currentStage == stage, "Invalid stage");
        _;
    }
    
    constructor(
        address _factory,
        address _voting,
        address _usdc
    ) {
        factory = PredictionMarketFactory(_factory);
        voting = PredictionMarketVoting(_voting);
        usdc = IERC20(_usdc);
    }
    
    /**
     * @dev Initialize a new staged market
     */
    function initializeMarket(
        address market,
        address yesToken,
        address noToken
    ) external {
        require(!markets[market].initialized, "Already initialized");
        
        // Create trading pairs
        address yesUsdcPair = factory.createPair(yesToken, address(usdc));
        address noUsdcPair = factory.createPair(noToken, address(usdc));
        
        markets[market] = MarketInfo({
            market: PredictionMarket(market),
            yesUsdcPair: yesUsdcPair,
            noUsdcPair: noUsdcPair,
            currentStage: Stage.SEEDING,
            stageStartTime: block.timestamp,
            initialized: true
        });
        
        emit MarketInitialized(market, yesUsdcPair, noUsdcPair);
        emit StageChanged(market, Stage.SEEDING, Stage.SEEDING);
    }
    
    /**
     * @dev Seed liquidity during seeding phase
     */
    function seedLiquidity(address market, uint256 yesAmount, uint256 noAmount) 
        external 
        onlyValidMarket(market) 
        onlyStage(market, Stage.SEEDING) 
    {
        MarketInfo storage marketInfo = markets[market];
        
        // Transfer tokens from user
        PredictionMarket predMarket = marketInfo.market;
        predMarket.yesToken().transferFrom(msg.sender, marketInfo.yesUsdcPair, yesAmount);
        predMarket.noToken().transferFrom(msg.sender, marketInfo.noUsdcPair, noAmount);
        
        // Calculate required USDC (0.5 USDC per 5 tokens)
        uint256 yesUsdcAmount = (yesAmount * 5e5) / 50; // 0.5 USDC per 5 tokens
        uint256 noUsdcAmount = (noAmount * 5e5) / 50;
        
        usdc.transferFrom(msg.sender, marketInfo.yesUsdcPair, yesUsdcAmount);
        usdc.transferFrom(msg.sender, marketInfo.noUsdcPair, noUsdcAmount);
        
        // Mint LP tokens
        uint256 yesLiquidity = IUniswapV2Pair(marketInfo.yesUsdcPair).mint(msg.sender);
        uint256 noLiquidity = IUniswapV2Pair(marketInfo.noUsdcPair).mint(msg.sender);
        
        // Register LP power for voting
        voting.registerLPPower(market, msg.sender, marketInfo.yesUsdcPair, marketInfo.noUsdcPair);
        
        emit LiquiditySeeded(market, msg.sender, yesLiquidity + noLiquidity);
    }
    
    /**
     * @dev Transition to voting stage
     */
    function startVoting(address market) 
        external 
        onlyValidMarket(market) 
        onlyStage(market, Stage.SEEDING) 
    {
        require(
            block.timestamp >= markets[market].stageStartTime + SEEDING_DURATION,
            "Seeding period not ended"
        );
        
        MarketInfo storage marketInfo = markets[market];
        marketInfo.currentStage = Stage.VOTING;
        marketInfo.stageStartTime = block.timestamp;
        
        voting.startVoting(market);
        
        emit StageChanged(market, Stage.SEEDING, Stage.VOTING);
    }
    
    /**
     * @dev Transition to withdrawal stage
     */
    function startWithdrawal(address market) 
        external 
        onlyValidMarket(market) 
        onlyStage(market, Stage.VOTING) 
    {
        require(
            block.timestamp >= markets[market].stageStartTime + VOTING_DURATION,
            "Voting period not ended"
        );
        
        voting.resolveVoting(market);
        
        MarketInfo storage marketInfo = markets[market];
        marketInfo.currentStage = Stage.WITHDRAWAL;
        marketInfo.stageStartTime = block.timestamp;
        
        emit StageChanged(market, Stage.VOTING, Stage.WITHDRAWAL);
    }
    
    /**
     * @dev Withdraw liquidity during withdrawal phase (only if voted differently)
     */
    function withdrawLiquidity(address market) 
        external 
        onlyValidMarket(market) 
        onlyStage(market, Stage.WITHDRAWAL) 
    {
        require(voting.canWithdraw(market, msg.sender), "Cannot withdraw");
        
        MarketInfo storage marketInfo = markets[market];
        
        // Burn LP tokens and return underlying assets
        uint256 yesLPBalance = IUniswapV2ERC20(marketInfo.yesUsdcPair).balanceOf(msg.sender);
        uint256 noLPBalance = IUniswapV2ERC20(marketInfo.noUsdcPair).balanceOf(msg.sender);
        
        if (yesLPBalance > 0) {
            IUniswapV2ERC20(marketInfo.yesUsdcPair).transferFrom(msg.sender, marketInfo.yesUsdcPair, yesLPBalance);
            IUniswapV2Pair(marketInfo.yesUsdcPair).burn(msg.sender);
        }
        
        if (noLPBalance > 0) {
            IUniswapV2ERC20(marketInfo.noUsdcPair).transferFrom(msg.sender, marketInfo.noUsdcPair, noLPBalance);
            IUniswapV2Pair(marketInfo.noUsdcPair).burn(msg.sender);
        }
        
        emit LiquidityWithdrawn(market, msg.sender, yesLPBalance + noLPBalance);
    }
    
    /**
     * @dev Transition to trading stage
     */
    function startTrading(address market) 
        external 
        onlyValidMarket(market) 
        onlyStage(market, Stage.WITHDRAWAL) 
    {
        require(
            block.timestamp >= markets[market].stageStartTime + WITHDRAWAL_DURATION,
            "Withdrawal period not ended"
        );
        require(voting.canStartTrading(market), "Cannot start trading yet");
        
        MarketInfo storage marketInfo = markets[market];
        marketInfo.currentStage = Stage.TRADING;
        marketInfo.stageStartTime = block.timestamp;
        
        emit StageChanged(market, Stage.WITHDRAWAL, Stage.TRADING);
    }
    
    /**
     * @dev Resolve market (only during trading stage)
     */
    function resolveMarket(address market, PredictionMarket.Outcome outcome) 
        external 
        onlyValidMarket(market) 
        onlyStage(market, Stage.TRADING) 
    {
        MarketInfo storage marketInfo = markets[market];
        marketInfo.market.resolveMarket(outcome);
        marketInfo.currentStage = Stage.RESOLVED;
        
        emit StageChanged(market, Stage.TRADING, Stage.RESOLVED);
    }
    
    /**
     * @dev Check if trading is allowed
     */
    function isTradingAllowed(address market) external view returns (bool) {
        return markets[market].currentStage == Stage.TRADING;
    }
    
    /**
     * @dev Get market stage info
     */
    function getMarketStage(address market) external view returns (
        Stage currentStage,
        uint256 stageStartTime,
        uint256 timeInCurrentStage
    ) {
        MarketInfo storage marketInfo = markets[market];
        return (
            marketInfo.currentStage,
            marketInfo.stageStartTime,
            block.timestamp - marketInfo.stageStartTime
        );
    }
    
    /**
     * @dev Get time remaining in current stage
     */
    function getTimeRemainingInStage(address market) external view returns (uint256) {
        MarketInfo storage marketInfo = markets[market];
        uint256 stageDuration;
        
        if (marketInfo.currentStage == Stage.SEEDING) {
            stageDuration = SEEDING_DURATION;
        } else if (marketInfo.currentStage == Stage.VOTING) {
            stageDuration = VOTING_DURATION;
        } else if (marketInfo.currentStage == Stage.WITHDRAWAL) {
            stageDuration = WITHDRAWAL_DURATION;
        } else {
            return 0; // No time limit for trading/resolved
        }
        
        uint256 elapsed = block.timestamp - marketInfo.stageStartTime;
        return elapsed >= stageDuration ? 0 : stageDuration - elapsed;
    }
} 