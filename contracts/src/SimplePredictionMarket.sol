// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title SimplePredictionMarket
 * @dev Simplified prediction market focusing on resolution criteria selection
 * Flow: Create → LP Seeding → Vote on Criteria → Trading Opens
 */
contract SimplePredictionMarket is Ownable, ReentrancyGuard {
    IERC20 public immutable usdc;
    
    // Simple YES/NO tokens
    YesToken public yesToken;
    NoToken public noToken;
    
    // Market phases
    enum Phase { SEEDING, VOTING, TRADING, ENDED }
    Phase public currentPhase;
    
    // Market details
    string public question;
    string public resolutionCriteria;
    uint256 public creationTime;
    
    // Seeding phase - LPs provide initial liquidity
    mapping(address => uint256) public lpContributions;
    uint256 public totalLPContributions;
    uint256 public constant SEEDING_DURATION = 2 hours; // Short for demo
    
    // Voting phase - LPs vote on resolution criteria
    mapping(address => string) public proposedCriteria;
    mapping(string => uint256) public criteriaVotes;
    mapping(address => bool) public hasVoted;
    string[] public criteriaOptions;
    uint256 public constant VOTING_DURATION = 1 hours; // Short for demo
    
    // AMM reserves for trading
    uint256 public yesReserves;
    uint256 public noReserves;
    uint256 public usdcReserves;
    
    // Events
    event MarketCreated(string question, uint256 timestamp);
    event PhaseChanged(Phase oldPhase, Phase newPhase, uint256 timestamp);
    event LiquiditySeeded(address indexed lp, uint256 amount);
    event CriteriaProposed(address indexed lp, string criteria);
    event CriteriaVoted(address indexed lp, string criteria, uint256 weight);
    event CriteriaSelected(string criteria);
    event TokensTraded(address indexed trader, bool buyingYes, uint256 amountIn, uint256 amountOut);
    
    constructor(
        address _usdc,
        string memory _question
    ) Ownable() {
        usdc = IERC20(_usdc);
        question = _question;
        creationTime = block.timestamp;
        currentPhase = Phase.SEEDING;
        
        // Deploy token contracts
        yesToken = new YesToken();
        noToken = new NoToken();
        
        emit MarketCreated(_question, block.timestamp);
    }
    
    /**
     * @dev LP provides initial liquidity during seeding phase
     */
    function seedLiquidity(uint256 amount) external nonReentrant {
        require(currentPhase == Phase.SEEDING, "Not in seeding phase");
        require(amount > 0, "Amount must be greater than 0");
        
        // Transfer USDC from LP
        usdc.transferFrom(msg.sender, address(this), amount);
        
        // Track LP contribution
        lpContributions[msg.sender] += amount;
        totalLPContributions += amount;
        
        // Mint 2x tokens to set initial price at $0.5 each
        // Price = (usdcReserves * 1e6) / tokenReserves
        // For $0.5 price: tokenReserves = 2 * usdcReserves
        uint256 tokenAmount = amount * 2;
        yesToken.mint(address(this), tokenAmount);
        noToken.mint(address(this), tokenAmount);
        
        emit LiquiditySeeded(msg.sender, amount);
    }
    
    /**
     * @dev Transition to voting phase
     */
    function startVoting() external {
        require(currentPhase == Phase.SEEDING, "Not in seeding phase");
        require(block.timestamp >= creationTime + SEEDING_DURATION, "Seeding period not ended");
        require(totalLPContributions > 0, "No liquidity seeded");
        
        currentPhase = Phase.VOTING;
        
        // Initialize AMM reserves
        yesReserves = yesToken.balanceOf(address(this));
        noReserves = noToken.balanceOf(address(this));
        usdcReserves = totalLPContributions;
        
        emit PhaseChanged(Phase.SEEDING, Phase.VOTING, block.timestamp);
    }
    
    /**
     * @dev LP proposes resolution criteria
     */
    function proposeCriteria(string memory criteria) external {
        require(currentPhase == Phase.VOTING, "Not in voting phase");
        require(lpContributions[msg.sender] > 0, "Not an LP");
        require(bytes(criteria).length > 0, "Criteria cannot be empty");
        require(bytes(proposedCriteria[msg.sender]).length == 0, "Already proposed");
        
        proposedCriteria[msg.sender] = criteria;
        criteriaOptions.push(criteria);
        
        emit CriteriaProposed(msg.sender, criteria);
    }
    
    /**
     * @dev LP votes on resolution criteria
     */
    function voteOnCriteria(string memory criteria) external {
        require(currentPhase == Phase.VOTING, "Not in voting phase");
        require(lpContributions[msg.sender] > 0, "Not an LP");
        require(!hasVoted[msg.sender], "Already voted");
        
        uint256 votingWeight = lpContributions[msg.sender];
        criteriaVotes[criteria] += votingWeight;
        hasVoted[msg.sender] = true;
        
        emit CriteriaVoted(msg.sender, criteria, votingWeight);
    }
    
    /**
     * @dev Transition to trading phase
     */
    function startTrading() external {
        require(currentPhase == Phase.VOTING, "Not in voting phase");
        require(block.timestamp >= creationTime + SEEDING_DURATION + VOTING_DURATION, "Voting period not ended");
        
        // Find winning criteria
        string memory winningCriteria = "";
        uint256 maxVotes = 0;
        
        for (uint256 i = 0; i < criteriaOptions.length; i++) {
            if (criteriaVotes[criteriaOptions[i]] > maxVotes) {
                maxVotes = criteriaVotes[criteriaOptions[i]];
                winningCriteria = criteriaOptions[i];
            }
        }
        
        require(bytes(winningCriteria).length > 0, "No criteria selected");
        
        resolutionCriteria = winningCriteria;
        currentPhase = Phase.TRADING;
        
        emit CriteriaSelected(winningCriteria);
        emit PhaseChanged(Phase.VOTING, Phase.TRADING, block.timestamp);
    }
    
    /**
     * @dev Simple AMM trading - buy YES tokens
     */
    function buyYes(uint256 usdcAmount) external nonReentrant {
        require(currentPhase == Phase.TRADING, "Not in trading phase");
        require(usdcAmount > 0, "Amount must be greater than 0");
        
        // Calculate YES tokens to receive using constant product formula
        uint256 yesAmount = getAmountOut(usdcAmount, usdcReserves, yesReserves);
        require(yesAmount > 0, "Insufficient output amount");
        
        // Transfer USDC and YES tokens
        usdc.transferFrom(msg.sender, address(this), usdcAmount);
        yesToken.transfer(msg.sender, yesAmount);
        
        // Update reserves
        usdcReserves += usdcAmount;
        yesReserves -= yesAmount;
        
        emit TokensTraded(msg.sender, true, usdcAmount, yesAmount);
    }
    
    /**
     * @dev Simple AMM trading - buy NO tokens
     */
    function buyNo(uint256 usdcAmount) external nonReentrant {
        require(currentPhase == Phase.TRADING, "Not in trading phase");
        require(usdcAmount > 0, "Amount must be greater than 0");
        
        // Calculate NO tokens to receive using constant product formula
        uint256 noAmount = getAmountOut(usdcAmount, usdcReserves, noReserves);
        require(noAmount > 0, "Insufficient output amount");
        
        // Transfer USDC and NO tokens
        usdc.transferFrom(msg.sender, address(this), usdcAmount);
        noToken.transfer(msg.sender, noAmount);
        
        // Update reserves
        usdcReserves += usdcAmount;
        noReserves -= noAmount;
        
        emit TokensTraded(msg.sender, false, usdcAmount, noAmount);
    }
    
    /**
     * @dev Calculate output amount using constant product formula
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
        public 
        pure 
        returns (uint256) 
    {
        require(amountIn > 0, "Amount in must be greater than 0");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient reserves");
        
        // Apply 0.3% fee
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        
        return numerator / denominator;
    }
    
    /**
     * @dev Get current token prices
     */
    function getTokenPrices() external view returns (uint256 yesPrice, uint256 noPrice) {
        if (usdcReserves == 0) return (0, 0);
        
        yesPrice = (usdcReserves * 1e6) / yesReserves;
        noPrice = (usdcReserves * 1e6) / noReserves;
    }
    
    /**
     * @dev Get all proposed criteria
     */
    function getAllCriteria() external view returns (string[] memory) {
        return criteriaOptions;
    }
    
    /**
     * @dev Get votes for specific criteria
     */
    function getCriteriaVotes(string memory criteria) external view returns (uint256) {
        return criteriaVotes[criteria];
    }
    
    /**
     * @dev Check if LP has voted
     */
    function hasLPVoted(address lp) external view returns (bool) {
        return hasVoted[lp];
    }
    
    /**
     * @dev Get LP contribution
     */
    function getLPContribution(address lp) external view returns (uint256) {
        return lpContributions[lp];
    }
}

/**
 * @title YesToken
 * @dev ERC20 token representing YES outcome
 */
contract YesToken is ERC20 {
    address public immutable market;
    
    constructor() ERC20("YES Token", "YES") {
        market = msg.sender;
    }
    
    function mint(address to, uint256 amount) external {
        require(msg.sender == market, "Only market can mint");
        _mint(to, amount);
    }
}

/**
 * @title NoToken
 * @dev ERC20 token representing NO outcome
 */
contract NoToken is ERC20 {
    address public immutable market;
    
    constructor() ERC20("NO Token", "NO") {
        market = msg.sender;
    }
    
    function mint(address to, uint256 amount) external {
        require(msg.sender == market, "Only market can mint");
        _mint(to, amount);
    }
} 