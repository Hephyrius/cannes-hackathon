// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./PredictionMarket.sol";
import "./OutcomeFunding.sol";
import "./PredictionMarketNFT.sol";

/**
 * @title MarketResolution
 * @dev Handles market resolution with oracle integration and funding coordination
 */
contract MarketResolution is Ownable, ReentrancyGuard {
    
    struct ResolutionRequest {
        uint256 id;
        address market;
        address requester;
        PredictionMarket.Outcome proposedOutcome;
        string evidence;
        uint256 timestamp;
        uint256 votingDeadline;
        bool resolved;
        uint256 votesFor;
        uint256 votesAgainst;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voterWeights;
    }
    
    struct Oracle {
        address addr;
        uint256 weight;
        bool active;
        uint256 correctResolutions;
        uint256 totalResolutions;
        string name;
    }
    
    struct RevenueDistribution {
        address market;
        uint256 amount;
        string source;
        uint256 timestamp;
        bool distributed;
    }
    
    mapping(uint256 => ResolutionRequest) public resolutionRequests;
    mapping(address => Oracle) public oracles;
    mapping(address => address[]) public marketToFundingContracts;
    mapping(address => bool) public authorizedMarkets;
    mapping(uint256 => RevenueDistribution) public revenueDistributions;
    
    address[] public oracleList;
    uint256 public nextRequestId = 1;
    uint256 public nextRevenueId = 1;
    uint256 public minimumVotingPeriod = 2 days;
    uint256 public resolutionBond = 100e6; // 100 USDC bond to request resolution
    
    PredictionMarketNFT public nftContract;
    IERC20 public immutable usdc;
    
    event ResolutionRequested(
        uint256 indexed requestId,
        address indexed market,
        address indexed requester,
        PredictionMarket.Outcome proposedOutcome
    );
    
    event OracleVoted(
        uint256 indexed requestId,
        address indexed oracle,
        bool support,
        uint256 weight
    );
    
    event MarketResolved(
        address indexed market,
        PredictionMarket.Outcome outcome,
        uint256 requestId
    );
    
    event OracleAdded(address indexed oracle, uint256 weight, string name);
    event OracleUpdated(address indexed oracle, uint256 weight, bool active);
    event FundingContractLinked(address indexed market, address indexed fundingContract);
    event RevenueDistributed(address indexed market, uint256 amount, string source);
    
    modifier onlyOracle() {
        require(oracles[msg.sender].active, "Not an active oracle");
        _;
    }
    
    modifier onlyAuthorizedMarket() {
        require(authorizedMarkets[msg.sender], "Not authorized market");
        _;
    }
    
    constructor(address _usdc, address _nftContract) Ownable() {
        usdc = IERC20(_usdc);
        nftContract = PredictionMarketNFT(_nftContract);
        _transferOwnership(msg.sender);
    }
    
    /**
     * @dev Add oracle
     */
    function addOracle(
        address _oracle,
        uint256 _weight,
        string memory _name
    ) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle address");
        require(_weight > 0, "Weight must be greater than 0");
        
        if (!oracles[_oracle].active) {
            oracleList.push(_oracle);
        }
        
        oracles[_oracle] = Oracle({
            addr: _oracle,
            weight: _weight,
            active: true,
            correctResolutions: 0,
            totalResolutions: 0,
            name: _name
        });
        
        emit OracleAdded(_oracle, _weight, _name);
    }
    
    /**
     * @dev Update oracle
     */
    function updateOracle(
        address _oracle,
        uint256 _weight,
        bool _active
    ) external onlyOwner {
        require(oracles[_oracle].addr != address(0), "Oracle does not exist");
        
        oracles[_oracle].weight = _weight;
        oracles[_oracle].active = _active;
        
        emit OracleUpdated(_oracle, _weight, _active);
    }
    
    /**
     * @dev Authorize market
     */
    function authorizeMarket(address _market) external onlyOwner {
        authorizedMarkets[_market] = true;
    }
    
    /**
     * @dev Link funding contract to market
     */
    function linkFundingContract(
        address _market,
        address _fundingContract
    ) external onlyOwner {
        marketToFundingContracts[_market].push(_fundingContract);
        emit FundingContractLinked(_market, _fundingContract);
    }
    
    /**
     * @dev Request market resolution
     */
    function requestResolution(
        address _market,
        PredictionMarket.Outcome _proposedOutcome,
        string memory _evidence
    ) external nonReentrant returns (uint256) {
        require(authorizedMarkets[_market], "Market not authorized");
        
        PredictionMarket market = PredictionMarket(_market);
        require(!market.isResolved(), "Market already resolved");
        require(block.timestamp >= market.resolutionTime(), "Resolution time not reached");
        
        // Collect resolution bond
        usdc.transferFrom(msg.sender, address(this), resolutionBond);
        
        uint256 requestId = nextRequestId++;
        
        ResolutionRequest storage request = resolutionRequests[requestId];
        request.id = requestId;
        request.market = _market;
        request.requester = msg.sender;
        request.proposedOutcome = _proposedOutcome;
        request.evidence = _evidence;
        request.timestamp = block.timestamp;
        request.votingDeadline = block.timestamp + minimumVotingPeriod;
        request.resolved = false;
        request.votesFor = 0;
        request.votesAgainst = 0;
        
        emit ResolutionRequested(requestId, _market, msg.sender, _proposedOutcome);
        
        return requestId;
    }
    
    /**
     * @dev Oracle vote on resolution
     */
    function voteOnResolution(uint256 _requestId, bool _support) external onlyOracle {
        ResolutionRequest storage request = resolutionRequests[_requestId];
        require(request.id != 0, "Request does not exist");
        require(block.timestamp <= request.votingDeadline, "Voting period ended");
        require(!request.hasVoted[msg.sender], "Already voted");
        
        Oracle storage oracle = oracles[msg.sender];
        uint256 weight = oracle.weight;
        
        request.hasVoted[msg.sender] = true;
        request.voterWeights[msg.sender] = weight;
        
        if (_support) {
            request.votesFor += weight;
        } else {
            request.votesAgainst += weight;
        }
        
        emit OracleVoted(_requestId, msg.sender, _support, weight);
    }
    
    /**
     * @dev Execute resolution
     */
    function executeResolution(uint256 _requestId) external nonReentrant {
        ResolutionRequest storage request = resolutionRequests[_requestId];
        require(request.id != 0, "Request does not exist");
        require(block.timestamp > request.votingDeadline, "Voting still active");
        require(!request.resolved, "Already resolved");
        
        bool approved = request.votesFor > request.votesAgainst;
        request.resolved = true;
        
        if (approved) {
            // Resolve the market
            PredictionMarket market = PredictionMarket(request.market);
            market.resolveMarket(request.proposedOutcome);
            
            // Update NFT
            nftContract.updateResolution(request.market);
            
            // Update oracle statistics
            _updateOracleStats(_requestId, true);
            
            // Return bond to requester
            usdc.transfer(request.requester, resolutionBond);
            
            emit MarketResolved(request.market, request.proposedOutcome, _requestId);
            
            // Trigger revenue distribution if applicable
            _triggerRevenueDistribution(request.market, request.proposedOutcome);
            
        } else {
            // Update oracle statistics
            _updateOracleStats(_requestId, false);
            
            // Bond is forfeited (stays in contract)
        }
    }
    
    /**
     * @dev Update oracle statistics
     */
    function _updateOracleStats(uint256 _requestId, bool _correctResolution) internal {
        ResolutionRequest storage request = resolutionRequests[_requestId];
        
        for (uint256 i = 0; i < oracleList.length; i++) {
            address oracleAddr = oracleList[i];
            if (request.hasVoted[oracleAddr]) {
                Oracle storage oracle = oracles[oracleAddr];
                oracle.totalResolutions++;
                
                // Check if oracle voted correctly
                bool votedCorrectly = _correctResolution ? 
                    (request.voterWeights[oracleAddr] > 0) : 
                    (request.voterWeights[oracleAddr] == 0);
                
                if (votedCorrectly) {
                    oracle.correctResolutions++;
                }
            }
        }
    }
    
    /**
     * @dev Trigger revenue distribution to funding contracts
     */
    function _triggerRevenueDistribution(
        address _market,
        PredictionMarket.Outcome _outcome
    ) internal {
        address[] memory fundingContracts = marketToFundingContracts[_market];
        
        for (uint256 i = 0; i < fundingContracts.length; i++) {
            OutcomeFunding funding = OutcomeFunding(fundingContracts[i]);
            
            // Check if this funding contract's target outcome was achieved
            if (funding.targetOutcome() == _outcome) {
                // This funding contract's outcome was achieved
                // Revenue will be added through separate calls to distributeRevenue
            }
        }
    }
    
    /**
     * @dev Distribute revenue to funding contract
     */
    function distributeRevenue(
        address _market,
        address _fundingContract,
        uint256 _amount,
        string memory _source
    ) external onlyOwner nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= usdc.balanceOf(address(this)), "Insufficient balance");
        
        // Record distribution
        uint256 revenueId = nextRevenueId++;
        revenueDistributions[revenueId] = RevenueDistribution({
            market: _market,
            amount: _amount,
            source: _source,
            timestamp: block.timestamp,
            distributed: true
        });
        
        // Approve and let the funding contract pull the funds
        usdc.approve(_fundingContract, _amount);
        OutcomeFunding funding = OutcomeFunding(_fundingContract);
        funding.addRevenue(_source, _amount, "Market resolution revenue");
        
        emit RevenueDistributed(_market, _amount, _source);
    }
    
    /**
     * @dev Get resolution request info
     */
    function getResolutionRequest(uint256 _requestId) external view returns (
        address market,
        address requester,
        PredictionMarket.Outcome proposedOutcome,
        string memory evidence,
        uint256 timestamp,
        uint256 votingDeadline,
        bool resolved,
        uint256 votesFor,
        uint256 votesAgainst
    ) {
        ResolutionRequest storage request = resolutionRequests[_requestId];
        return (
            request.market,
            request.requester,
            request.proposedOutcome,
            request.evidence,
            request.timestamp,
            request.votingDeadline,
            request.resolved,
            request.votesFor,
            request.votesAgainst
        );
    }
    
    /**
     * @dev Get oracle info
     */
    function getOracle(address _oracle) external view returns (
        uint256 weight,
        bool active,
        uint256 correctResolutions,
        uint256 totalResolutions,
        string memory name
    ) {
        Oracle storage oracle = oracles[_oracle];
        return (
            oracle.weight,
            oracle.active,
            oracle.correctResolutions,
            oracle.totalResolutions,
            oracle.name
        );
    }
    
    /**
     * @dev Get funding contracts for market
     */
    function getFundingContracts(address _market) external view returns (address[] memory) {
        return marketToFundingContracts[_market];
    }
    
    /**
     * @dev Get oracle accuracy rate
     */
    function getOracleAccuracy(address _oracle) external view returns (uint256) {
        Oracle storage oracle = oracles[_oracle];
        if (oracle.totalResolutions == 0) return 0;
        return (oracle.correctResolutions * 100) / oracle.totalResolutions;
    }
    
    /**
     * @dev Set minimum voting period
     */
    function setMinimumVotingPeriod(uint256 _period) external onlyOwner {
        minimumVotingPeriod = _period;
    }
    
    /**
     * @dev Set resolution bond
     */
    function setResolutionBond(uint256 _bond) external onlyOwner {
        resolutionBond = _bond;
    }
    
    /**
     * @dev Withdraw accumulated bonds (only owner)
     */
    function withdrawBonds(uint256 _amount) external onlyOwner {
        require(_amount <= usdc.balanceOf(address(this)), "Insufficient balance");
        usdc.transfer(msg.sender, _amount);
    }
} 