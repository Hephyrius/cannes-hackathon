// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SimplePredictionMarket} from "../src/SimplePredictionMarket.sol";
import {SimpleMarketFactory} from "../src/SimpleMarketFactory.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000 * 10**6);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract ScaleTest is Test {
    SimplePredictionMarket market;
    SimpleMarketFactory factory;
    MockUSDC usdc;
    
    // Scale test parameters
    uint256 constant NUM_LPS = 50;
    uint256 constant NUM_TRADERS = 100;
    
    address[] lps;
    address[] traders;
    
    // Metrics
    uint256 totalGasUsed;
    uint256 totalVolumeTraded;
    uint256 totalLiquiditySeeded;
    uint256 numTrades;
    
    function setUp() public {
        usdc = new MockUSDC();
        factory = new SimpleMarketFactory(address(usdc));
        market = SimplePredictionMarket(factory.createMarket("Will Bitcoin reach 100k USD by 2025?"));
        
        _createUsers();
        _setupBalances();
        
        console.log("Scale test setup complete");
        console.log("LPs:", NUM_LPS);
        console.log("Traders:", NUM_TRADERS);
    }
    
    function test_LargeScaleMarketOperations() public {
        console.log("=== LARGE SCALE MARKET TEST ===");
        
        // Phase 1: Mass liquidity seeding
        uint256 seedingGasStart = gasleft();
        for (uint256 i = 0; i < NUM_LPS; i++) {
            uint256 seedAmount = (1000 + (i * 100)) * 1e6; // 1k to 6k USDC
            
            vm.prank(lps[i]);
            market.seedLiquidity(seedAmount);
            
            totalLiquiditySeeded += seedAmount;
        }
        uint256 seedingGasUsed = seedingGasStart - gasleft();
        
        console.log("Phase 1 Complete - Seeding:");
        console.log("Total liquidity:", totalLiquiditySeeded / 1e6, "USDC");
        console.log("Gas for", NUM_LPS, "seeds:", seedingGasUsed);
        console.log("Avg gas per seed:", seedingGasUsed / NUM_LPS);
        
        // Phase 2: Voting
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        
        uint256 votingGasStart = gasleft();
        
        // First 10 LPs propose criteria
        for (uint256 i = 0; i < 10; i++) {
            string memory criteria = string(abi.encodePacked("Criteria ", vm.toString(i + 1)));
            vm.prank(lps[i]);
            market.proposeCriteria(criteria);
        }
        
        // All LPs vote
        for (uint256 i = 0; i < NUM_LPS; i++) {
            uint256 criteriaIndex = i % 10;
            string memory criteria = string(abi.encodePacked("Criteria ", vm.toString(criteriaIndex + 1)));
            vm.prank(lps[i]);
            market.voteOnCriteria(criteria);
        }
        
        uint256 votingGasUsed = votingGasStart - gasleft();
        
        console.log("Phase 2 Complete - Voting:");
        console.log("Proposals and votes:", NUM_LPS + 10);
        console.log("Voting gas used:", votingGasUsed);
        
        // Phase 3: Mass trading
        vm.warp(block.timestamp + 1 hours + 1);
        market.startTrading();
        
        uint256 tradingGasStart = gasleft();
        
        // Simulate trading waves
        for (uint256 wave = 0; wave < 5; wave++) {
            uint256 tradersThisWave = NUM_TRADERS / 5; // 20 traders per wave
            
            for (uint256 i = 0; i < tradersThisWave; i++) {
                uint256 traderIndex = (wave * tradersThisWave) + i;
                uint256 tradeAmount = (100 + (i * 50)) * 1e6; // 100-1k USDC trades
                
                bool buyYes = (traderIndex % 3) != 0; // 2/3 buy YES, 1/3 buy NO
                
                if (buyYes) {
                    vm.prank(traders[traderIndex]);
                    market.buyYes(tradeAmount);
                } else {
                    vm.prank(traders[traderIndex]);
                    market.buyNo(tradeAmount);
                }
                
                totalVolumeTraded += tradeAmount;
                numTrades++;
            }
            
            // Report wave progress
            (uint256 yesPrice, uint256 noPrice) = market.getTokenPrices();
            console.log("Wave completed:", wave + 1);
            console.log("YES price:", yesPrice);
            console.log("NO price:", noPrice);
        }
        
        uint256 tradingGasUsed = tradingGasStart - gasleft();
        
        console.log("Phase 3 Complete - Trading:");
        console.log("Total trades:", numTrades);
        console.log("Total volume:", totalVolumeTraded / 1e6, "USDC");
        console.log("Trading gas used:", tradingGasUsed);
        console.log("Avg gas per trade:", tradingGasUsed / numTrades);
        
        // Final metrics
        totalGasUsed = seedingGasUsed + votingGasUsed + tradingGasUsed;
        
        console.log("=== FINAL METRICS ===");
        console.log("Total participants:", NUM_LPS + NUM_TRADERS);
        console.log("Total transactions:", NUM_LPS + 10 + NUM_LPS + numTrades);
        console.log("Total gas consumed:", totalGasUsed);
        uint256 utilizationPercent = (totalVolumeTraded * 100) / totalLiquiditySeeded;
        console.log("Liquidity utilization %:", utilizationPercent);
        
        (uint256 finalYesPrice, uint256 finalNoPrice) = market.getTokenPrices();
        console.log("Final prices - YES:", finalYesPrice, "NO:", finalNoPrice);
        
        console.log("=== SCALE TEST SUCCESSFUL ===");
    }
    
    function test_MultipleMarketsScale() public {
        console.log("=== MULTIPLE MARKETS SCALE TEST ===");
        
        // Create 20 markets
        address[] memory markets = new address[](20);
        uint256 creationGasStart = gasleft();
        
        for (uint256 i = 0; i < 20; i++) {
            string memory question = string(abi.encodePacked("Market ", vm.toString(i + 1), " question"));
            markets[i] = factory.createMarket(question);
        }
        
        uint256 creationGasUsed = creationGasStart - gasleft();
        
        console.log("Created 20 markets");
        console.log("Creation gas:", creationGasUsed);
        console.log("Avg gas per market:", creationGasUsed / 20);
        
        // Seed each market with multiple LPs
        uint256 totalSeeded = 0;
        uint256 seedingGasStart = gasleft();
        
        for (uint256 marketIdx = 0; marketIdx < 20; marketIdx++) {
            SimplePredictionMarket targetMarket = SimplePredictionMarket(markets[marketIdx]);
            
            // 5 LPs per market
            for (uint256 lpIdx = 0; lpIdx < 5; lpIdx++) {
                uint256 lpIndex = (marketIdx * 5 + lpIdx) % NUM_LPS;
                uint256 seedAmount = 1000 * 1e6; // 1k USDC each
                
                vm.prank(lps[lpIndex]);
                usdc.approve(markets[marketIdx], type(uint256).max);
                
                vm.prank(lps[lpIndex]);
                targetMarket.seedLiquidity(seedAmount);
                
                totalSeeded += seedAmount;
            }
        }
        
        uint256 multiSeedingGasUsed = seedingGasStart - gasleft();
        
        console.log("Seeded all markets");
        console.log("Total seeded across markets:", totalSeeded / 1e6, "USDC");
        console.log("Multi-market seeding gas:", multiSeedingGasUsed);
        
        console.log("Factory total markets:", factory.getMarketCount());
        console.log("=== MULTI-MARKET TEST SUCCESSFUL ===");
    }
    
    function test_HighFrequencyTrading() public {
        console.log("=== HIGH FREQUENCY TRADING TEST ===");
        
        // Setup a market for high frequency trading
        vm.prank(lps[0]);
        market.seedLiquidity(50000 * 1e6); // Large liquidity pool
        
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        
        vm.prank(lps[0]);
        market.proposeCriteria("High frequency test criteria");
        
        vm.prank(lps[0]);
        market.voteOnCriteria("High frequency test criteria");
        
        vm.warp(block.timestamp + 1 hours + 1);
        market.startTrading();
        
        // Rapid trading simulation
        uint256 rapidTrades = 200;
        uint256 rapidGasStart = gasleft();
        
        for (uint256 i = 0; i < rapidTrades; i++) {
            uint256 traderIndex = i % NUM_TRADERS;
            uint256 tradeSize = 50 * 1e6; // Small 50 USDC trades
            
            if (i % 2 == 0) {
                vm.prank(traders[traderIndex]);
                market.buyYes(tradeSize);
            } else {
                vm.prank(traders[traderIndex]);
                market.buyNo(tradeSize);
            }
        }
        
        uint256 rapidGasUsed = rapidGasStart - gasleft();
        
        console.log("Rapid trades completed:", rapidTrades);
        console.log("Rapid trading gas:", rapidGasUsed);
        console.log("Gas per rapid trade:", rapidGasUsed / rapidTrades);
        
        (uint256 finalYes, uint256 finalNo) = market.getTokenPrices();
        console.log("Final prices after rapid trading - YES:", finalYes, "NO:", finalNo);
        
        console.log("=== HIGH FREQUENCY TEST SUCCESSFUL ===");
    }
    
    function _createUsers() internal {
        lps = new address[](NUM_LPS);
        traders = new address[](NUM_TRADERS);
        
        for (uint256 i = 0; i < NUM_LPS; i++) {
            lps[i] = makeAddr(string(abi.encodePacked("lp", vm.toString(i))));
        }
        
        for (uint256 i = 0; i < NUM_TRADERS; i++) {
            traders[i] = makeAddr(string(abi.encodePacked("trader", vm.toString(i))));
        }
    }
    
    function _setupBalances() internal {
        // Setup LP balances
        for (uint256 i = 0; i < NUM_LPS; i++) {
            uint256 balance = (10000 + (i * 500)) * 1e6; // 10k-35k USDC
            usdc.mint(lps[i], balance);
            
            vm.prank(lps[i]);
            usdc.approve(address(market), type(uint256).max);
        }
        
        // Setup trader balances
        for (uint256 i = 0; i < NUM_TRADERS; i++) {
            uint256 balance = (2000 + (i * 100)) * 1e6; // 2k-12k USDC
            usdc.mint(traders[i], balance);
            
            vm.prank(traders[i]);
            usdc.approve(address(market), type(uint256).max);
        }
    }
} 