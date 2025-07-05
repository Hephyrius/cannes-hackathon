// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title YesNoToken
 * @dev ERC20 token representing the YES-NO outcome
 */
contract YesNoToken is ERC20 {
    address public predictionMarket;
    
    constructor() ERC20("YES-NO Token", "YESNO") {
        predictionMarket = msg.sender;
    }
    
    modifier onlyPredictionMarket() {
        require(msg.sender == predictionMarket, "Only prediction market can call");
        _;
    }
    
    function mint(address to, uint256 amount) external onlyPredictionMarket {
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external onlyPredictionMarket {
        _burn(from, amount);
    }
} 