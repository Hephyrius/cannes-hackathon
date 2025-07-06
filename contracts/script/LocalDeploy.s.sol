// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/SimplePredictionMarket.sol";
import "../src/SimpleMarketFactory.sol";

contract LocalDeployScript is Script {
    function run() external {
        // Use default anvil account
        vm.startBroadcast();
        
        console.log("=== DEPLOYING TO LOCAL TESTNET ===");
        console.log("Deployer:", msg.sender);
        console.log("Balance:", msg.sender.balance / 1e18, "ETH");
        console.log("");
        
        // Deploy Mock USDC first (for local testing)
        console.log("Deploying Mock USDC...");
        MockUSDC usdc = new MockUSDC();
        console.log("Mock USDC deployed at:", address(usdc));
        console.log("Total supply:", usdc.totalSupply() / 1e6, "USDC");
        console.log("");
        
        // Deploy Factory
        console.log("Deploying Market Factory...");
        SimpleMarketFactory factory = new SimpleMarketFactory(address(usdc));
        console.log("Factory deployed at:", address(factory));
        console.log("");
        
        // Create sample market
        console.log("Creating sample market...");
        address market = factory.createMarket("Will ETH reach $5000 by end of 2024?");
        console.log("Sample market deployed at:", market);
        console.log("Market count:", factory.getMarketCount());
        console.log("");
        
        // Get market details
        SimplePredictionMarket marketContract = SimplePredictionMarket(market);
        console.log("Market question:", marketContract.question());
        console.log("Current phase:", uint256(marketContract.currentPhase()));
        console.log("YES token:", address(marketContract.yesToken()));
        console.log("NO token:", address(marketContract.noToken()));
        console.log("");
        
        vm.stopBroadcast();
        
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("Mock USDC:     ", address(usdc));
        console.log("Factory:       ", address(factory));
        console.log("Sample Market: ", market);
        console.log("YES Token:     ", address(marketContract.yesToken()));
        console.log("NO Token:      ", address(marketContract.noToken()));
        console.log("");
        console.log("Deployment successful!");
    }
}

contract MockUSDC {
    string public name = "Mock USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    uint256 public totalSupply = 1_000_000 * 1e6; // 1M USDC
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor() {
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
} 