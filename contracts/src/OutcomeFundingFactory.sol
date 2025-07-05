// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./OutcomeFunding.sol";
import "./PredictionMarket.sol";
import "./MarketResolution.sol";

/**
 * @title OutcomeFundingFactory
 * @dev Factory for creating and managing outcome funding contracts
 */
contract OutcomeFundingFactory is Ownable {
    
    struct FundingInfo {
        address fundingContract;
        address market;
        PredictionMarket.Outcome targetOutcome;
        uint256 createdAt;
        address creator;
        bool active;
        string title;
        string description;
    }
    
    IERC20 public immutable usdc;
    MarketResolution public resolutionContract;
    
    mapping(address => FundingInfo) public fundingContracts;
    mapping(address => address[]) public marketToFundingContracts;
    mapping(address => address[]) public creatorToFundingContracts;
    
    address[] public allFundingContracts;
    
    uint256 public creationFee = 50e6; // 50 USDC to create funding contract
    uint256 public platformFeeRate = 250; // 2.5% (out of 10000)
    
    event FundingContractCreated(
        address indexed fundingContract,
        address indexed market,
        address indexed creator,
        PredictionMarket.Outcome targetOutcome,
        string title
    );
    
    event FundingContractStatusUpdated(address indexed fundingContract, bool active);
    
    constructor(address _usdc) Ownable() {
        usdc = IERC20(_usdc);
        _transferOwnership(msg.sender);
    }
    
    /**
     * @dev Set resolution contract
     */
    function setResolutionContract(address _resolutionContract) external onlyOwner {
        resolutionContract = MarketResolution(_resolutionContract);
    }
    
    /**
     * @dev Create funding contract for specific market outcome
     */
    function createFundingContract(
        address _market,
        PredictionMarket.Outcome _targetOutcome,
        string memory _title,
        string memory _description,
        string memory _tokenName,
        string memory _tokenSymbol
    ) external returns (address) {
        require(_market != address(0), "Invalid market address");
        require(bytes(_title).length > 0, "Title required");
        require(bytes(_tokenName).length > 0, "Token name required");
        require(bytes(_tokenSymbol).length > 0, "Token symbol required");
        
        // Collect creation fee
        usdc.transferFrom(msg.sender, address(this), creationFee);
        
        // Create funding contract
        OutcomeFunding fundingContract = new OutcomeFunding(
            address(usdc),
            _market,
            _targetOutcome,
            _tokenName,
            _tokenSymbol
        );
        
        address fundingAddress = address(fundingContract);
        
        // Store funding info
        fundingContracts[fundingAddress] = FundingInfo({
            fundingContract: fundingAddress,
            market: _market,
            targetOutcome: _targetOutcome,
            createdAt: block.timestamp,
            creator: msg.sender,
            active: true,
            title: _title,
            description: _description
        });
        
        // Add to mappings
        allFundingContracts.push(fundingAddress);
        marketToFundingContracts[_market].push(fundingAddress);
        creatorToFundingContracts[msg.sender].push(fundingAddress);
        
        // Link to resolution contract if available
        if (address(resolutionContract) != address(0)) {
            resolutionContract.linkFundingContract(_market, fundingAddress);
        }
        
        emit FundingContractCreated(
            fundingAddress,
            _market,
            msg.sender,
            _targetOutcome,
            _title
        );
        
        return fundingAddress;
    }
    
    /**
     * @dev Create multiple funding contracts for different outcomes
     */
    function createMultipleFundingContracts(
        address _market,
        PredictionMarket.Outcome[] memory _targetOutcomes,
        string[] memory _titles,
        string[] memory _descriptions,
        string[] memory _tokenNames,
        string[] memory _tokenSymbols
    ) external returns (address[] memory) {
        require(_targetOutcomes.length == _titles.length, "Array length mismatch");
        require(_targetOutcomes.length == _descriptions.length, "Array length mismatch");
        require(_targetOutcomes.length == _tokenNames.length, "Array length mismatch");
        require(_targetOutcomes.length == _tokenSymbols.length, "Array length mismatch");
        
        address[] memory fundingContracts = new address[](_targetOutcomes.length);
        
        for (uint256 i = 0; i < _targetOutcomes.length; i++) {
            fundingContracts[i] = createFundingContract(
                _market,
                _targetOutcomes[i],
                _titles[i],
                _descriptions[i],
                _tokenNames[i],
                _tokenSymbols[i]
            );
        }
        
        return fundingContracts;
    }
    
    /**
     * @dev Update funding contract status
     */
    function updateFundingContractStatus(address _fundingContract, bool _active) external onlyOwner {
        require(fundingContracts[_fundingContract].fundingContract != address(0), "Funding contract not found");
        
        fundingContracts[_fundingContract].active = _active;
        
        emit FundingContractStatusUpdated(_fundingContract, _active);
    }
    
    /**
     * @dev Get funding contracts for market
     */
    function getFundingContractsForMarket(address _market) external view returns (address[] memory) {
        return marketToFundingContracts[_market];
    }
    
    /**
     * @dev Get funding contracts by creator
     */
    function getFundingContractsByCreator(address _creator) external view returns (address[] memory) {
        return creatorToFundingContracts[_creator];
    }
    
    /**
     * @dev Get all funding contracts
     */
    function getAllFundingContracts() external view returns (address[] memory) {
        return allFundingContracts;
    }
    
    /**
     * @dev Get funding contract info
     */
    function getFundingContractInfo(address _fundingContract) external view returns (
        address market,
        PredictionMarket.Outcome targetOutcome,
        uint256 createdAt,
        address creator,
        bool active,
        string memory title,
        string memory description
    ) {
        FundingInfo storage info = fundingContracts[_fundingContract];
        return (
            info.market,
            info.targetOutcome,
            info.createdAt,
            info.creator,
            info.active,
            info.title,
            info.description
        );
    }
    
    /**
     * @dev Get funding contract stats
     */
    function getFundingContractStats(address _fundingContract) external view returns (
        uint256 totalRaised,
        uint256 totalRevenue,
        uint256 totalDistributed,
        uint256 tokenSupply,
        bool fundingActive,
        bool fundingSuccessful
    ) {
        OutcomeFunding funding = OutcomeFunding(_fundingContract);
        
        (
            ,
            totalRaised,
            ,
            fundingActive,
            fundingSuccessful,
            totalRevenue,
            totalDistributed
        ) = funding.getFundingRoundInfo();
        
        tokenSupply = funding.totalSupply();
        
        return (
            totalRaised,
            totalRevenue,
            totalDistributed,
            tokenSupply,
            fundingActive,
            fundingSuccessful
        );
    }
    
    /**
     * @dev Get active funding contracts for market
     */
    function getActiveFundingContractsForMarket(address _market) external view returns (address[] memory) {
        address[] memory allContracts = marketToFundingContracts[_market];
        uint256 activeCount = 0;
        
        // Count active contracts
        for (uint256 i = 0; i < allContracts.length; i++) {
            if (fundingContracts[allContracts[i]].active) {
                activeCount++;
            }
        }
        
        // Create array of active contracts
        address[] memory activeContracts = new address[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allContracts.length; i++) {
            if (fundingContracts[allContracts[i]].active) {
                activeContracts[index] = allContracts[i];
                index++;
            }
        }
        
        return activeContracts;
    }
    
    /**
     * @dev Get funding contracts by outcome
     */
    function getFundingContractsByOutcome(
        address _market,
        PredictionMarket.Outcome _outcome
    ) external view returns (address[] memory) {
        address[] memory allContracts = marketToFundingContracts[_market];
        uint256 matchingCount = 0;
        
        // Count matching contracts
        for (uint256 i = 0; i < allContracts.length; i++) {
            if (fundingContracts[allContracts[i]].targetOutcome == _outcome) {
                matchingCount++;
            }
        }
        
        // Create array of matching contracts
        address[] memory matchingContracts = new address[](matchingCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allContracts.length; i++) {
            if (fundingContracts[allContracts[i]].targetOutcome == _outcome) {
                matchingContracts[index] = allContracts[i];
                index++;
            }
        }
        
        return matchingContracts;
    }
    
    /**
     * @dev Set creation fee
     */
    function setCreationFee(uint256 _fee) external onlyOwner {
        creationFee = _fee;
    }
    
    /**
     * @dev Set platform fee rate
     */
    function setPlatformFeeRate(uint256 _rate) external onlyOwner {
        require(_rate <= 1000, "Fee rate too high"); // Max 10%
        platformFeeRate = _rate;
    }
    
    /**
     * @dev Withdraw fees
     */
    function withdrawFees(uint256 _amount) external onlyOwner {
        require(_amount <= usdc.balanceOf(address(this)), "Insufficient balance");
        usdc.transfer(msg.sender, _amount);
    }
    
    /**
     * @dev Get total funding contracts count
     */
    function getTotalFundingContractsCount() external view returns (uint256) {
        return allFundingContracts.length;
    }
    
    /**
     * @dev Get funding contracts with pagination
     */
    function getFundingContractsPaginated(
        uint256 _offset,
        uint256 _limit
    ) external view returns (address[] memory) {
        require(_offset < allFundingContracts.length, "Offset out of bounds");
        
        uint256 end = _offset + _limit;
        if (end > allFundingContracts.length) {
            end = allFundingContracts.length;
        }
        
        address[] memory result = new address[](end - _offset);
        for (uint256 i = _offset; i < end; i++) {
            result[i - _offset] = allFundingContracts[i];
        }
        
        return result;
    }
} 