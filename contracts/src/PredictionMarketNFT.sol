// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./PredictionMarket.sol";

/**
 * @title PredictionMarketNFT
 * @dev NFT representation of prediction markets with dynamic metadata
 */
contract PredictionMarketNFT is ERC721, ERC721URIStorage, Ownable {
    using Strings for uint256;
    using Strings for address;
    
    struct MarketMetadata {
        string title;
        string description;
        string imageUrl;
        address marketContract;
        address resolutionContract;
        uint256 creationTime;
        uint256 resolutionTime;
        bool isResolved;
        string category;
        string[] tags;
    }
    
    mapping(uint256 => MarketMetadata) public marketMetadata;
    mapping(address => uint256) public marketToTokenId;
    
    uint256 private _nextTokenId = 1;
    string private _baseImageUrl;
    
    event MarketNFTMinted(
        uint256 indexed tokenId, 
        address indexed marketContract, 
        string title, 
        address indexed owner
    );
    
    event MarketResolutionUpdated(
        uint256 indexed tokenId, 
        PredictionMarket.Outcome resolution,
        uint256 resolutionTime
    );
    
    constructor(
        string memory name,
        string memory symbol,
        string memory baseImageUrl
    ) ERC721(name, symbol) Ownable() {
        _baseImageUrl = baseImageUrl;
        _transferOwnership(msg.sender);
    }
    
    /**
     * @dev Mint NFT for a new prediction market
     */
    function mintMarketNFT(
        address to,
        string memory title,
        string memory description,
        string memory imageUrl,
        address marketContract,
        address resolutionContract,
        string memory category,
        string[] memory tags
    ) external returns (uint256) {
        require(marketToTokenId[marketContract] == 0, "Market NFT already exists");
        
        uint256 tokenId = _nextTokenId++;
        
        marketMetadata[tokenId] = MarketMetadata({
            title: title,
            description: description,
            imageUrl: bytes(imageUrl).length > 0 ? imageUrl : _baseImageUrl,
            marketContract: marketContract,
            resolutionContract: resolutionContract,
            creationTime: block.timestamp,
            resolutionTime: 0,
            isResolved: false,
            category: category,
            tags: tags
        });
        
        marketToTokenId[marketContract] = tokenId;
        
        _mint(to, tokenId);
        _setTokenURI(tokenId, _generateTokenURI(tokenId));
        
        emit MarketNFTMinted(tokenId, marketContract, title, to);
        
        return tokenId;
    }
    
    /**
     * @dev Update resolution status when market is resolved
     */
    function updateResolution(address marketContract) external {
        uint256 tokenId = marketToTokenId[marketContract];
        require(tokenId != 0, "Market NFT does not exist");
        
        PredictionMarket market = PredictionMarket(marketContract);
        require(market.isResolved(), "Market not resolved yet");
        
        MarketMetadata storage metadata = marketMetadata[tokenId];
        if (!metadata.isResolved) {
            metadata.isResolved = true;
            metadata.resolutionTime = block.timestamp;
            
            // Update token URI with new resolution status
            _setTokenURI(tokenId, _generateTokenURI(tokenId));
            
            emit MarketResolutionUpdated(tokenId, market.outcome(), block.timestamp);
        }
    }
    
    /**
     * @dev Get market resolution as a readable string
     */
    function getMarketResolution(uint256 tokenId) public view returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        MarketMetadata storage metadata = marketMetadata[tokenId];
        if (!metadata.isResolved) {
            return "Unresolved";
        }
        
        PredictionMarket market = PredictionMarket(metadata.marketContract);
        PredictionMarket.Outcome outcome = market.outcome();
        
        if (outcome == PredictionMarket.Outcome.YES) {
            return "YES";
        } else if (outcome == PredictionMarket.Outcome.NO) {
            return "NO";
        } else {
            return "POWER";
        }
    }
    
    /**
     * @dev Get market status
     */
    function getMarketStatus(uint256 tokenId) public view returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        MarketMetadata storage metadata = marketMetadata[tokenId];
        PredictionMarket market = PredictionMarket(metadata.marketContract);
        
        if (market.isResolved()) {
            return "Resolved";
        } else if (block.timestamp > market.resolutionTime()) {
            return "Expired";
        } else {
            return "Active";
        }
    }
    
    /**
     * @dev Generate dynamic token URI with market data
     */
    function _generateTokenURI(uint256 tokenId) internal view returns (string memory) {
        MarketMetadata storage metadata = marketMetadata[tokenId];
        
        string memory resolution = getMarketResolution(tokenId);
        string memory status = getMarketStatus(tokenId);
        
        // Create attributes array
        string memory attributes = string(abi.encodePacked(
            '[',
            '{"trait_type": "Status", "value": "', status, '"},',
            '{"trait_type": "Resolution", "value": "', resolution, '"},',
            '{"trait_type": "Category", "value": "', metadata.category, '"},',
            '{"trait_type": "Creation Time", "display_type": "date", "value": ', metadata.creationTime.toString(), '},',
            metadata.isResolved ? string(abi.encodePacked(
                '{"trait_type": "Resolution Time", "display_type": "date", "value": ', metadata.resolutionTime.toString(), '},'
            )) : '',
            '{"trait_type": "Market Contract", "value": "', metadata.marketContract.toHexString(), '"},',
            '{"trait_type": "Resolution Contract", "value": "', metadata.resolutionContract.toHexString(), '"}'
        ));
        
        // Add tags if they exist
        if (metadata.tags.length > 0) {
            attributes = string(abi.encodePacked(
                attributes,
                ',{"trait_type": "Tags", "value": "', _joinTags(metadata.tags), '"}'
            ));
        }
        
        attributes = string(abi.encodePacked(attributes, ']'));
        
        // Create JSON metadata
        string memory json = string(abi.encodePacked(
            '{',
            '"name": "', metadata.title, '",',
            '"description": "', metadata.description, '\\n\\nMarket Contract: ', metadata.marketContract.toHexString(), '\\nResolution Contract: ', metadata.resolutionContract.toHexString(), '\\nStatus: ', status, '\\nResolution: ', resolution, '",',
            '"image": "', metadata.imageUrl, '",',
            '"external_url": "https://prediction-market.example.com/market/', tokenId.toString(), '",',
            '"attributes": ', attributes,
            '}'
        ));
        
        return string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(json))
        ));
    }
    
    /**
     * @dev Join tags array into comma-separated string
     */
    function _joinTags(string[] memory tags) internal pure returns (string memory) {
        if (tags.length == 0) return "";
        
        string memory result = tags[0];
        for (uint256 i = 1; i < tags.length; i++) {
            result = string(abi.encodePacked(result, ", ", tags[i]));
        }
        return result;
    }
    
    /**
     * @dev Get complete market metadata
     */
    function getMarketMetadata(uint256 tokenId) external view returns (
        string memory title,
        string memory description,
        string memory imageUrl,
        address marketContract,
        address resolutionContract,
        uint256 creationTime,
        uint256 resolutionTime,
        bool isResolved,
        string memory category,
        string[] memory tags,
        string memory resolution,
        string memory status
    ) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        
        MarketMetadata storage metadata = marketMetadata[tokenId];
        
        return (
            metadata.title,
            metadata.description,
            metadata.imageUrl,
            metadata.marketContract,
            metadata.resolutionContract,
            metadata.creationTime,
            metadata.resolutionTime,
            metadata.isResolved,
            metadata.category,
            metadata.tags,
            getMarketResolution(tokenId),
            getMarketStatus(tokenId)
        );
    }
    
    /**
     * @dev Get all market NFTs owned by an address
     */
    function getMarketsByOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](balance);
        uint256 currentIndex = 0;
        
        for (uint256 i = 1; i < _nextTokenId; i++) {
            if (_ownerOf(i) == owner) {
                tokenIds[currentIndex] = i;
                currentIndex++;
            }
        }
        
        return tokenIds;
    }
    
    /**
     * @dev Update base image URL (only owner)
     */
    function setBaseImageUrl(string memory newBaseImageUrl) external onlyOwner {
        _baseImageUrl = newBaseImageUrl;
    }
    
    /**
     * @dev Update market metadata (only owner or market contract)
     */
    function updateMarketMetadata(
        uint256 tokenId,
        string memory newDescription,
        string memory newImageUrl
    ) external {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(
            msg.sender == owner() || msg.sender == marketMetadata[tokenId].marketContract,
            "Not authorized"
        );
        
        MarketMetadata storage metadata = marketMetadata[tokenId];
        if (bytes(newDescription).length > 0) {
            metadata.description = newDescription;
        }
        if (bytes(newImageUrl).length > 0) {
            metadata.imageUrl = newImageUrl;
        }
        
        _setTokenURI(tokenId, _generateTokenURI(tokenId));
    }
    
    // Override required functions
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
} 