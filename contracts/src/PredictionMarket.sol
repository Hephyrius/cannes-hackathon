// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./YesNoToken.sol";

/**
 * @title PredictionMarket
 * @dev A prediction market where users can buy yes/no/power tokens for USDC
 * and redeem the winning tokens when the market resolves
 */
contract PredictionMarket is Ownable, ReentrancyGuard {
    IERC20 public immutable usdc;
    
    // Token contracts for yes, no, and power tokens
    YesToken public yesToken;
    NoToken public noToken;
    YesNoToken public yesNoToken;
    
    // Market state
    enum MarketState { OPEN, RESOLVED }
    enum Outcome { YES, NO, POWER }
    
    MarketState public marketState;
    Outcome public winningOutcome;
    
    // Market details
    string public question;
    uint256 public resolutionTime;
    uint256 public constant TOKEN_PRICE = 1e6; // 1 USDC (6 decimals)
    
    // Events
    event MarketCreated(string question, uint256 resolutionTime);
    event TokensPurchased(address buyer, uint256 yesAmount, uint256 noAmount, uint256 powerAmount);
    event MarketResolved(Outcome outcome);
    event TokensRedeemed(address redeemer, Outcome outcome, uint256 amount);
    
    constructor(
        address _usdc,
        string memory _question,
        uint256 _resolutionTime
    ) Ownable() {
        usdc = IERC20(_usdc);
        question = _question;
        resolutionTime = _resolutionTime;
        marketState = MarketState.OPEN;
        
        // Deploy token contracts
        yesToken = new YesToken();
        noToken = new NoToken();
        yesNoToken = new YesNoToken();
        
        emit MarketCreated(_question, _resolutionTime);
    }
    
    /**
     * @dev Purchase yes, no, and power tokens for USDC
     * @param usdcAmount Amount of USDC to spend (must be >= 1 USDC)
     */
    function purchaseTokens(uint256 usdcAmount) external nonReentrant {
        require(marketState == MarketState.OPEN, "Market is not open");
        require(usdcAmount >= TOKEN_PRICE, "Must spend at least 1 USDC");
        require(usdcAmount % TOKEN_PRICE == 0, "Amount must be multiple of 1 USDC");
        
        uint256 tokenAmount = usdcAmount / TOKEN_PRICE;
        
        // Transfer USDC from user to contract
        require(usdc.transferFrom(msg.sender, address(this), usdcAmount), "USDC transfer failed");
        
        // Mint tokens to user
        yesToken.mint(msg.sender, tokenAmount);
        noToken.mint(msg.sender, tokenAmount);
        yesNoToken.mint(msg.sender, tokenAmount);
        
        emit TokensPurchased(msg.sender, tokenAmount, tokenAmount, tokenAmount);
    }
    
    /**
     * @dev Resolve the market with the winning outcome (only owner)
     * @param _outcome The winning outcome
     */
    function resolveMarket(Outcome _outcome) external onlyOwner {
        require(marketState == MarketState.OPEN, "Market already resolved");
        require(block.timestamp >= resolutionTime, "Resolution time not reached");
        
        marketState = MarketState.RESOLVED;
        winningOutcome = _outcome;
        
        emit MarketResolved(_outcome);
    }
    
    /**
     * @dev Redeem winning tokens for USDC
     * @param amount Amount of winning tokens to redeem
     */
    function redeemWinningTokens(uint256 amount) external nonReentrant {
        require(marketState == MarketState.RESOLVED, "Market not resolved");
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 usdcAmount = amount * TOKEN_PRICE;
        
        if (winningOutcome == Outcome.YES) {
            require(yesToken.balanceOf(msg.sender) >= amount, "Insufficient YES tokens");
            yesToken.burn(msg.sender, amount);
        } else if (winningOutcome == Outcome.NO) {
            require(noToken.balanceOf(msg.sender) >= amount, "Insufficient NO tokens");
            noToken.burn(msg.sender, amount);
        } else if (winningOutcome == Outcome.POWER) {
            require(yesNoToken.balanceOf(msg.sender) >= amount, "Insufficient YES-NO tokens");
            yesNoToken.burn(msg.sender, amount);
        }
        
        // Transfer USDC to user
        require(usdc.transfer(msg.sender, usdcAmount), "USDC transfer failed");
        
        emit TokensRedeemed(msg.sender, winningOutcome, amount);
    }
    
    /**
     * @dev Get user's token balances
     * @param user Address to check balances for
     * @return yesBalance YES token balance
     * @return noBalance NO token balance
     * @return powerBalance POWER token balance
     */
    function getUserBalances(address user) external view returns (
        uint256 yesBalance,
        uint256 noBalance,
        uint256 powerBalance
    ) {
        yesBalance = yesToken.balanceOf(user);
        noBalance = noToken.balanceOf(user);
        powerBalance = yesNoToken.balanceOf(user);
    }
    
    /**
     * @dev Get contract's USDC balance
     */
    function getContractBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
}

/**
 * @title YesToken
 * @dev ERC20 token representing YES outcome
 */
contract YesToken is ERC20 {
    address public predictionMarket;
    
    constructor() ERC20("YES Token", "YES") {
        predictionMarket = msg.sender;
    }
    
    modifier onlyPredictionMarket() {
        require(msg.sender == predictionMarket, "Only prediction market can call");
        _;
    }
    
    function mint(address to, uint256 amount) external onlyPredictionMarket {
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external onlyPredictionMarket {
        _burn(from, amount);
    }
}

/**
 * @title NoToken
 * @dev ERC20 token representing NO outcome
 */
contract NoToken is ERC20 {
    address public predictionMarket;
    
    constructor() ERC20("NO Token", "NO") {
        predictionMarket = msg.sender;
    }
    
    modifier onlyPredictionMarket() {
        require(msg.sender == predictionMarket, "Only prediction market can call");
        _;
    }
    
    function mint(address to, uint256 amount) external onlyPredictionMarket {
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external onlyPredictionMarket {
        _burn(from, amount);
    }
} 