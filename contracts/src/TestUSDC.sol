// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TestUSDC
 * @dev Test USDC token with 18 decimals for hackathon testing
 */
contract TestUSDC is ERC20, Ownable {
    constructor() ERC20("Test USDC", "USDC") {
        // Mint 10 million test USDC tokens (with 18 decimals)
        _mint(msg.sender, 10_000_000 * 10**18);
    }
    
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
    
    /**
     * @dev Mint tokens to any address for testing purposes
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    /**
     * @dev Faucet function - anyone can get 1000 test USDC for testing
     */
    function faucet() external {
        require(balanceOf(msg.sender) < 10000 * 10**18, "Already have enough tokens");
        _mint(msg.sender, 1000 * 10**18); // 1000 test USDC
    }
    
    /**
     * @dev Owner can mint large amounts for initial distribution
     */
    function ownerMint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev Get test tokens (alias for faucet)
     */
    function getTestTokens() external {
        faucet();
    }
} 