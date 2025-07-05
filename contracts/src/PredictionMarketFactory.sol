// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./PredictionMarket.sol";

/**
 * @title PredictionMarketFactory
 * @dev Deploys PredictionMarket contracts and keeps track of all markets
 */
contract PredictionMarketFactory {
    address[] public allMarkets;
    event MarketCreated(address indexed market, string question, uint256 resolutionTime);

    /**
     * @dev Deploy a new prediction market
     * @param usdc Address of the USDC token
     * @param question The market question
     * @param resolutionTime The unix timestamp when the market can be resolved
     * @return market The address of the new PredictionMarket
     */
    function createMarket(
        address usdc,
        string calldata question,
        uint256 resolutionTime
    ) external returns (address market) {
        PredictionMarket newMarket = new PredictionMarket(usdc, question, resolutionTime);
        allMarkets.push(address(newMarket));
        emit MarketCreated(address(newMarket), question, resolutionTime);
        return address(newMarket);
    }

    /**
     * @dev Get the number of markets deployed
     */
    function numberOfMarkets() external view returns (uint256) {
        return allMarkets.length;
    }

    /**
     * @dev Get all market addresses
     */
    function getAllMarkets() external view returns (address[] memory) {
        return allMarkets;
    }
} 