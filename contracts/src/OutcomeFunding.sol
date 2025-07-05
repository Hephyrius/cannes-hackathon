// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./PredictionMarket.sol";

/**
 * @title OutcomeFunding
 * @dev Allows people to fund specific market outcomes and share in revenue generated
 */
contract OutcomeFunding is ERC20, Ownable, ReentrancyGuard {
    IERC20 public immutable usdc;
    PredictionMarket public immutable market;
    PredictionMarket.Outcome public immutable targetOutcome;
    
    struct FundingRound {
        uint256 target;           // Target funding amount
        uint256 raised;           // Amount raised so far
        uint256 deadline;         // Funding deadline
        bool active;              // Is funding round active
        bool successful;          // Did it reach target
        uint256 totalRevenue;     // Total revenue collected
        uint256 totalDistributed; // Total revenue distributed
    }
    
    struct Proposal {
        uint256 id;
        string title;
        string description;
        uint256 requestedAmount;
        address proposer;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votingDeadline;
        bool executed;
        bool approved;
        ProposalType proposalType;
        bytes executionData;
    }
    
    enum ProposalType {
        MARKETING,
        LOBBYING,
        RESEARCH,
        MEDIA_PRODUCTION,
        LEGAL_ACTION,
        INFRASTRUCTURE,
        PARTNERSHIPS,
        OTHER
    }
    
    struct RevenueStream {
        uint256 id;
        string source;           // e.g., "IP Rights", "Media Rights", "Sponsorship"
        uint256 amount;
        uint256 timestamp;
        bool distributed;
        string description;
    }
    
    FundingRound public fundingRound;
    
    mapping(uint256 => Proposal) public proposals;
    mapping(address => mapping(uint256 => bool)) public hasVoted;
    mapping(uint256 => RevenueStream) public revenueStreams;
    mapping(address => uint256) public lastClaimedRevenue;
    
    uint256 public nextProposalId = 1;
    uint256 public nextRevenueId = 1;
    uint256 public minimumVotingPeriod = 3 days;
    uint256 public proposalThreshold = 1000e18; // Need 1000 tokens to propose
    
    event FundingRoundStarted(uint256 target, uint256 deadline);
    event FundingReceived(address indexed funder, uint256 amount, uint256 tokensIssued);
    event FundingRoundCompleted(bool successful, uint256 totalRaised);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event ProposalVoted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, bool approved);
    event RevenueReceived(uint256 indexed revenueId, string source, uint256 amount);
    event RevenueDistributed(address indexed recipient, uint256 amount);
    event FundsSpent(uint256 indexed proposalId, uint256 amount, string purpose);
    
    modifier onlyDuringFunding() {
        require(fundingRound.active && block.timestamp <= fundingRound.deadline, "Funding period ended");
        _;
    }
    
    modifier onlyAfterFunding() {
        require(!fundingRound.active || block.timestamp > fundingRound.deadline, "Funding still active");
        _;
    }
    
    constructor(
        address _usdc,
        address _market,
        PredictionMarket.Outcome _targetOutcome,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable() {
        usdc = IERC20(_usdc);
        market = PredictionMarket(_market);
        targetOutcome = _targetOutcome;
        _transferOwnership(msg.sender);
    }
    
    /**
     * @dev Start a funding round
     */
    function startFundingRound(uint256 _target, uint256 _duration) external onlyOwner {
        require(!fundingRound.active, "Funding round already active");
        require(_target > 0, "Target must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        
        fundingRound = FundingRound({
            target: _target,
            raised: 0,
            deadline: block.timestamp + _duration,
            active: true,
            successful: false,
            totalRevenue: 0,
            totalDistributed: 0
        });
        
        emit FundingRoundStarted(_target, block.timestamp + _duration);
    }
    
    /**
     * @dev Fund the outcome (receive tokens in return)
     */
    function fund(uint256 amount) external onlyDuringFunding nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        
        // Transfer USDC from funder
        usdc.transferFrom(msg.sender, address(this), amount);
        
        // Calculate tokens to issue (1:1 ratio with USDC)
        uint256 tokensToIssue = amount;
        
        // Mint tokens to funder
        _mint(msg.sender, tokensToIssue);
        
        // Update funding round
        fundingRound.raised += amount;
        
        emit FundingReceived(msg.sender, amount, tokensToIssue);
        
        // Check if target reached
        if (fundingRound.raised >= fundingRound.target) {
            _completeFundingRound(true);
        }
    }
    
    /**
     * @dev Complete funding round
     */
    function completeFundingRound() external {
        require(fundingRound.active, "No active funding round");
        require(block.timestamp > fundingRound.deadline, "Funding period not ended");
        
        bool successful = fundingRound.raised >= fundingRound.target;
        _completeFundingRound(successful);
    }
    
    function _completeFundingRound(bool successful) internal {
        fundingRound.active = false;
        fundingRound.successful = successful;
        
        emit FundingRoundCompleted(successful, fundingRound.raised);
    }
    
    /**
     * @dev Create a proposal for spending funds
     */
    function createProposal(
        string memory title,
        string memory description,
        uint256 requestedAmount,
        ProposalType proposalType,
        bytes memory executionData
    ) external onlyAfterFunding returns (uint256) {
        require(balanceOf(msg.sender) >= proposalThreshold, "Insufficient tokens to propose");
        require(requestedAmount > 0, "Requested amount must be greater than 0");
        require(requestedAmount <= usdc.balanceOf(address(this)), "Insufficient contract balance");
        
        uint256 proposalId = nextProposalId++;
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            title: title,
            description: description,
            requestedAmount: requestedAmount,
            proposer: msg.sender,
            votesFor: 0,
            votesAgainst: 0,
            votingDeadline: block.timestamp + minimumVotingPeriod,
            executed: false,
            approved: false,
            proposalType: proposalType,
            executionData: executionData
        });
        
        emit ProposalCreated(proposalId, msg.sender, title);
        return proposalId;
    }
    
    /**
     * @dev Vote on a proposal
     */
    function vote(uint256 proposalId, bool support) external {
        require(proposals[proposalId].id != 0, "Proposal does not exist");
        require(block.timestamp <= proposals[proposalId].votingDeadline, "Voting period ended");
        require(!hasVoted[msg.sender][proposalId], "Already voted");
        require(balanceOf(msg.sender) > 0, "No voting power");
        
        uint256 votingPower = balanceOf(msg.sender);
        hasVoted[msg.sender][proposalId] = true;
        
        if (support) {
            proposals[proposalId].votesFor += votingPower;
        } else {
            proposals[proposalId].votesAgainst += votingPower;
        }
        
        emit ProposalVoted(proposalId, msg.sender, support, votingPower);
    }
    
    /**
     * @dev Execute a proposal
     */
    function executeProposal(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp > proposal.votingDeadline, "Voting still active");
        require(!proposal.executed, "Proposal already executed");
        
        bool approved = proposal.votesFor > proposal.votesAgainst;
        proposal.executed = true;
        proposal.approved = approved;
        
        if (approved) {
            // Transfer funds to proposer for execution
            usdc.transfer(proposal.proposer, proposal.requestedAmount);
            emit FundsSpent(proposalId, proposal.requestedAmount, proposal.title);
        }
        
        emit ProposalExecuted(proposalId, approved);
    }
    
    /**
     * @dev Add revenue stream (only owner)
     */
    function addRevenue(
        string memory source,
        uint256 amount,
        string memory description
    ) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        
        // Transfer revenue to contract
        usdc.transferFrom(msg.sender, address(this), amount);
        
        uint256 revenueId = nextRevenueId++;
        
        revenueStreams[revenueId] = RevenueStream({
            id: revenueId,
            source: source,
            amount: amount,
            timestamp: block.timestamp,
            distributed: false,
            description: description
        });
        
        fundingRound.totalRevenue += amount;
        
        emit RevenueReceived(revenueId, source, amount);
    }
    
    /**
     * @dev Claim revenue share
     */
    function claimRevenue() external nonReentrant {
        require(balanceOf(msg.sender) > 0, "No tokens held");
        require(fundingRound.totalRevenue > fundingRound.totalDistributed, "No revenue to distribute");
        
        uint256 userShare = balanceOf(msg.sender);
        uint256 totalSupply = totalSupply();
        uint256 undistributedRevenue = fundingRound.totalRevenue - fundingRound.totalDistributed;
        
        // Calculate user's share of undistributed revenue
        uint256 userRevenue = (undistributedRevenue * userShare) / totalSupply;
        
        if (userRevenue > 0) {
            fundingRound.totalDistributed += userRevenue;
            usdc.transfer(msg.sender, userRevenue);
            emit RevenueDistributed(msg.sender, userRevenue);
        }
    }
    
    /**
     * @dev Get pending revenue for user
     */
    function getPendingRevenue(address user) external view returns (uint256) {
        if (balanceOf(user) == 0) return 0;
        if (fundingRound.totalRevenue <= fundingRound.totalDistributed) return 0;
        
        uint256 userShare = balanceOf(user);
        uint256 totalSupply = totalSupply();
        uint256 undistributedRevenue = fundingRound.totalRevenue - fundingRound.totalDistributed;
        
        return (undistributedRevenue * userShare) / totalSupply;
    }
    
    /**
     * @dev Get funding round info
     */
    function getFundingRoundInfo() external view returns (
        uint256 target,
        uint256 raised,
        uint256 deadline,
        bool active,
        bool successful,
        uint256 totalRevenue,
        uint256 totalDistributed
    ) {
        return (
            fundingRound.target,
            fundingRound.raised,
            fundingRound.deadline,
            fundingRound.active,
            fundingRound.successful,
            fundingRound.totalRevenue,
            fundingRound.totalDistributed
        );
    }
    
    /**
     * @dev Get proposal info
     */
    function getProposal(uint256 proposalId) external view returns (
        string memory title,
        string memory description,
        uint256 requestedAmount,
        address proposer,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 votingDeadline,
        bool executed,
        bool approved,
        ProposalType proposalType
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.title,
            proposal.description,
            proposal.requestedAmount,
            proposal.proposer,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.votingDeadline,
            proposal.executed,
            proposal.approved,
            proposal.proposalType
        );
    }
    
    /**
     * @dev Check if market outcome matches target
     */
    function isTargetOutcomeAchieved() external view returns (bool) {
        if (!market.isResolved()) return false;
        return market.outcome() == targetOutcome;
    }
    
    /**
     * @dev Emergency withdraw (if funding round fails)
     */
    function emergencyWithdraw() external nonReentrant {
        require(!fundingRound.successful, "Funding round was successful");
        require(!fundingRound.active, "Funding round still active");
        require(balanceOf(msg.sender) > 0, "No tokens to redeem");
        
        uint256 userTokens = balanceOf(msg.sender);
        uint256 refundAmount = (fundingRound.raised * userTokens) / totalSupply();
        
        _burn(msg.sender, userTokens);
        usdc.transfer(msg.sender, refundAmount);
    }
    
    /**
     * @dev Set minimum voting period (only owner)
     */
    function setMinimumVotingPeriod(uint256 _period) external onlyOwner {
        minimumVotingPeriod = _period;
    }
    
    /**
     * @dev Set proposal threshold (only owner)
     */
    function setProposalThreshold(uint256 _threshold) external onlyOwner {
        proposalThreshold = _threshold;
    }
} 