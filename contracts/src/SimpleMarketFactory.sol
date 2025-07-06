// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./SimplePredictionMarket.sol";

/**
 * @title SimpleMarketFactory
 * @dev Factory for creating SimplePredictionMarket instances
 */
contract SimpleMarketFactory {
    address public immutable usdc;
    
    address[] public markets;
    mapping(address => bool) public isMarket;
    
    event MarketCreated(
        address indexed market,
        string question,
        address indexed creator,
        uint256 timestamp
    );
    
    constructor(address _usdc) {
        usdc = _usdc;
    }
    
    /**
     * @dev Create a new prediction market
     */
    function createMarket(string memory question) external returns (address) {
        require(bytes(question).length > 0, "Question cannot be empty");
        
        // Deploy new market
        SimplePredictionMarket market = new SimplePredictionMarket(usdc, question);
        
        // Transfer ownership to creator
        market.transferOwnership(msg.sender);
        
        // Track market
        markets.push(address(market));
        isMarket[address(market)] = true;
        
        emit MarketCreated(address(market), question, msg.sender, block.timestamp);
        
        return address(market);
    }
    
    /**
     * @dev Get total number of markets
     */
    function getMarketCount() external view returns (uint256) {
        return markets.length;
    }
    
    /**
     * @dev Get market by index
     */
    function getMarket(uint256 index) external view returns (address) {
        require(index < markets.length, "Index out of bounds");
        return markets[index];
    }
    
    /**
     * @dev Get all markets
     */
    function getAllMarkets() external view returns (address[] memory) {
        return markets;
    }
    
    /**
     * @dev Check if address is a market created by this factory
     */
    function isValidMarket(address market) external view returns (bool) {
        return isMarket[market];
    }
} 