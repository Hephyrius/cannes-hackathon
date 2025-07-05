// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./interfaces/IUniswapV2Factory.sol";
import "./PredictionMarketPair.sol";

/**
 * @title PredictionMarketFactory
 * @dev Factory for creating prediction market pairs, following Uniswap V2 pattern
 */
contract PredictionMarketFactory is IUniswapV2Factory {
    address public override feeTo;
    address public override feeToSetter;
    
    // Mapping from token pair to pair address
    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;
    
    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }
    
    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }
    
    /**
     * @dev Create a pair for two tokens
     */
    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, "PredictionMarketFactory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "PredictionMarketFactory: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "PredictionMarketFactory: PAIR_EXISTS");
        
        // Create pair contract
        bytes memory bytecode = type(PredictionMarketPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        // Initialize the pair
        IUniswapV2Pair(pair).initialize(token0, token1);
        
        // Update mappings
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
    }
    
    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "PredictionMarketFactory: FORBIDDEN");
        feeTo = _feeTo;
    }
    
    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "PredictionMarketFactory: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
} 