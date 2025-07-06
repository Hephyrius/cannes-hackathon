// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./DemoPredictionMarket.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DemoMarketFactory is Ownable {
    address public immutable usdc;
    address[] public markets;
    
    mapping(address => bool) public isMarket;
    
    event MarketCreated(address indexed market, string question, uint256 timestamp);
    
    constructor(address _usdc) {
        usdc = _usdc;
    }
    
    function createMarket(string memory question) external returns (address) {
        DemoPredictionMarket market = new DemoPredictionMarket(usdc, question);
        
        markets.push(address(market));
        isMarket[address(market)] = true;
        
        emit MarketCreated(address(market), question, block.timestamp);
        
        return address(market);
    }
    
    function getMarketCount() external view returns (uint256) {
        return markets.length;
    }
    
    function getMarket(uint256 index) external view returns (address) {
        require(index < markets.length, "Index out of bounds");
        return markets[index];
    }
    
    function getAllMarkets() external view returns (address[] memory) {
        return markets;
    }
} 