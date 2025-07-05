// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./PredictionMarket.sol";
import "./PredictionMarketNFT.sol";
import "./StagedPredictionMarket.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PredictionMarketNFTFactory
 * @dev Factory for creating prediction markets with corresponding NFTs
 */
contract PredictionMarketNFTFactory is Ownable {
    PredictionMarketNFT public immutable nftContract;
    StagedPredictionMarket public stagedMarketManager;
    IERC20 public immutable usdc;
    
    uint256 public marketCreationFee = 1e6; // 1 USDC
    
    struct MarketCreationParams {
        string question;
        string description;
        string imageUrl;
        uint256 resolutionTime;
        string category;
        string[] tags;
    }
    
    mapping(address => address[]) public creatorToMarkets;
    address[] public allMarkets;
    
    event MarketCreatedWithNFT(
        address indexed creator,
        address indexed marketContract,
        uint256 indexed nftTokenId,
        string question
    );
    
    constructor(
        address _usdc,
        string memory nftName,
        string memory nftSymbol,
        string memory baseImageUrl
    ) Ownable() {
        _transferOwnership(msg.sender);
        usdc = IERC20(_usdc);
        nftContract = new PredictionMarketNFT(nftName, nftSymbol, baseImageUrl);
    }
    
    /**
     * @dev Set staged market manager
     */
    function setStagedMarketManager(address _stagedMarketManager) external onlyOwner {
        stagedMarketManager = StagedPredictionMarket(_stagedMarketManager);
    }
    
    /**
     * @dev Set market creation fee
     */
    function setMarketCreationFee(uint256 _fee) external onlyOwner {
        marketCreationFee = _fee;
    }
    
    /**
     * @dev Create a new prediction market with NFT
     */
    function createMarketWithNFT(
        MarketCreationParams memory params
    ) external returns (address marketContract, uint256 nftTokenId) {
        return _createMarketWithNFTInternal(params);
    }
    
    /**
     * @dev Batch create multiple markets
     */
    function batchCreateMarkets(
        MarketCreationParams[] memory marketsParams
    ) external returns (address[] memory marketContracts, uint256[] memory nftTokenIds) {
        uint256 length = marketsParams.length;
        require(length > 0 && length <= 10, "Invalid batch size");
        
        marketContracts = new address[](length);
        nftTokenIds = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            (marketContracts[i], nftTokenIds[i]) = _createMarketWithNFTInternal(marketsParams[i]);
        }
        
        return (marketContracts, nftTokenIds);
    }
    
    /**
     * @dev Internal function to create market with NFT
     */
    function _createMarketWithNFTInternal(
        MarketCreationParams memory params
    ) internal returns (address marketContract, uint256 nftTokenId) {
        require(params.resolutionTime > block.timestamp, "Resolution time must be in future");
        require(bytes(params.question).length > 0, "Question cannot be empty");
        
        // Collect creation fee
        if (marketCreationFee > 0) {
            usdc.transferFrom(msg.sender, address(this), marketCreationFee);
        }
        
        // Create prediction market
        PredictionMarket market = new PredictionMarket(
            address(usdc),
            params.question,
            params.resolutionTime
        );
        
        marketContract = address(market);
        
        // Mint NFT for the market
        nftTokenId = nftContract.mintMarketNFT(
            msg.sender,
            params.question,
            params.description,
            params.imageUrl,
            marketContract,
            address(stagedMarketManager), // Resolution contract
            params.category,
            params.tags
        );
        
        // Link NFT to market
        market.linkNFT(address(nftContract), nftTokenId);
        
        // Transfer ownership of market to creator
        market.transferOwnership(msg.sender);
        
        // Track markets
        creatorToMarkets[msg.sender].push(marketContract);
        allMarkets.push(marketContract);
        
        emit MarketCreatedWithNFT(msg.sender, marketContract, nftTokenId, params.question);
        
        return (marketContract, nftTokenId);
    }
    
    /**
     * @dev Update market resolution and NFT
     */
    function updateMarketResolution(address marketContract) external {
        PredictionMarket market = PredictionMarket(marketContract);
        require(market.isResolved(), "Market not resolved");
        
        // Update NFT with resolution
        nftContract.updateResolution(marketContract);
    }
    
    /**
     * @dev Get markets created by address
     */
    function getMarketsByCreator(address creator) external view returns (address[] memory) {
        return creatorToMarkets[creator];
    }
    
    /**
     * @dev Get total number of markets
     */
    function getTotalMarkets() external view returns (uint256) {
        return allMarkets.length;
    }
    
    /**
     * @dev Get market at index
     */
    function getMarketAtIndex(uint256 index) external view returns (address) {
        require(index < allMarkets.length, "Index out of bounds");
        return allMarkets[index];
    }
    
    /**
     * @dev Get market info including NFT data
     */
    function getMarketInfo(address marketContract) external view returns (
        string memory question,
        uint256 resolutionTime,
        bool isResolved,
        PredictionMarket.Outcome outcome,
        uint256 nftTokenId,
        address nftOwner
    ) {
        PredictionMarket market = PredictionMarket(marketContract);
        
        question = market.question();
        resolutionTime = market.resolutionTime();
        isResolved = market.isResolved();
        
        if (isResolved) {
            outcome = market.outcome();
        }
        
        nftTokenId = market.nftTokenId();
        if (nftTokenId > 0) {
            nftOwner = nftContract.ownerOf(nftTokenId);
        }
        
        return (question, resolutionTime, isResolved, outcome, nftTokenId, nftOwner);
    }
    
    /**
     * @dev Withdraw collected fees (only owner)
     */
    function withdrawFees(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(amount <= usdc.balanceOf(address(this)), "Insufficient balance");
        usdc.transfer(to, amount);
    }
    
    /**
     * @dev Get contract balance
     */
    function getBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }
} 