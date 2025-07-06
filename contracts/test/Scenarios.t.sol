// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SimplePredictionMarket} from "../src/SimplePredictionMarket.sol";
import {SimpleMarketFactory} from "../src/SimpleMarketFactory.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 10000000 * 10**6); // 10M USDC
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract ScenariosTest is Test {
    SimplePredictionMarket market;
    SimpleMarketFactory factory;
    MockUSDC usdc;
    
    // Participants
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address dave = makeAddr("dave");
    address eve = makeAddr("eve");
    
    function setUp() public {
        // Deploy contracts
        usdc = new MockUSDC();
        factory = new SimpleMarketFactory(address(usdc));
        
        // Give participants USDC
        usdc.mint(alice, 50000 * 10**6);    // 50k USDC
        usdc.mint(bob, 30000 * 10**6);      // 30k USDC
        usdc.mint(charlie, 20000 * 10**6);  // 20k USDC
        usdc.mint(dave, 10000 * 10**6);     // 10k USDC
        usdc.mint(eve, 5000 * 10**6);       // 5k USDC
        
        console.log("=== SETUP COMPLETE ===");
        console.log("Alice balance:", usdc.balanceOf(alice) / 10**6, "USDC");
        console.log("Bob balance:", usdc.balanceOf(bob) / 10**6, "USDC");
        console.log("Charlie balance:", usdc.balanceOf(charlie) / 10**6, "USDC");
        console.log("Dave balance:", usdc.balanceOf(dave) / 10**6, "USDC");
        console.log("Eve balance:", usdc.balanceOf(eve) / 10**6, "USDC");
    }
    
    function test_Scenario1_ETHPriceMarket() public {
        console.log("\n=== SCENARIO 1: ETH PRICE PREDICTION MARKET ===");
        
        // === MARKET CREATION ===
        market = SimplePredictionMarket(factory.createMarket("Will ETH reach $5000 by end of 2024?"));
        console.log("Market created:", address(market));
        console.log("Question:", market.question());
        console.log("Initial phase:", uint256(market.currentPhase()));
        
        // Approve USDC spending
        vm.prank(alice);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(charlie);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(dave);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(eve);
        usdc.approve(address(market), type(uint256).max);
        
        // === SEEDING PHASE ===
        console.log("\n--- SEEDING PHASE ---");
        
        // Alice seeds 10k USDC
        vm.prank(alice);
        market.seedLiquidity(10000 * 10**6);
        console.log("Alice seeded 10,000 USDC");
        
        // Bob seeds 5k USDC
        vm.prank(bob);
        market.seedLiquidity(5000 * 10**6);
        console.log("Bob seeded 5,000 USDC");
        
        // Charlie seeds 3k USDC
        vm.prank(charlie);
        market.seedLiquidity(3000 * 10**6);
        console.log("Charlie seeded 3,000 USDC");
        
        console.log("Total LP contributions:", market.totalLPContributions() / 10**6, "USDC");
        console.log("Alice contribution:", market.lpContributions(alice) / 10**6, "USDC");
        console.log("Bob contribution:", market.lpContributions(bob) / 10**6, "USDC");
        console.log("Charlie contribution:", market.lpContributions(charlie) / 10**6, "USDC");
        
        // === VOTING PHASE ===
        console.log("\n--- VOTING PHASE ---");
        
        // Fast forward to voting phase
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        console.log("Voting phase started");
        console.log("Current phase:", uint256(market.currentPhase()));
        
        // LPs propose resolution criteria
        vm.prank(alice);
        market.proposeCriteria("Official ETH price on CoinGecko at 11:59 PM UTC on Dec 31, 2024");
        console.log("Alice proposed: CoinGecko criteria");
        
        vm.prank(bob);
        market.proposeCriteria("ETH price on Binance at market close on Dec 31, 2024");
        console.log("Bob proposed: Binance criteria");
        
        vm.prank(charlie);
        market.proposeCriteria("Average ETH price across top 5 exchanges on Dec 31, 2024");
        console.log("Charlie proposed: Average price criteria");
        
        // LPs vote on criteria
        vm.prank(alice);
        market.voteOnCriteria("Official ETH price on CoinGecko at 11:59 PM UTC on Dec 31, 2024");
        console.log("Alice voted for CoinGecko criteria");
        
        vm.prank(bob);
        market.voteOnCriteria("ETH price on Binance at market close on Dec 31, 2024");
        console.log("Bob voted for Binance criteria");
        
        vm.prank(charlie);
        market.voteOnCriteria("Official ETH price on CoinGecko at 11:59 PM UTC on Dec 31, 2024");
        console.log("Charlie voted for CoinGecko criteria");
        
        // Check vote results
        console.log("\n--- VOTE RESULTS ---");
        console.log("CoinGecko criteria votes:", market.getCriteriaVotes("Official ETH price on CoinGecko at 11:59 PM UTC on Dec 31, 2024") / 10**6, "USDC weight");
        console.log("Binance criteria votes:", market.getCriteriaVotes("ETH price on Binance at market close on Dec 31, 2024") / 10**6, "USDC weight");
        console.log("Average price criteria votes:", market.getCriteriaVotes("Average ETH price across top 5 exchanges on Dec 31, 2024") / 10**6, "USDC weight");
        
        // === TRADING PHASE ===
        console.log("\n--- TRADING PHASE ---");
        
        // Fast forward to trading phase
        vm.warp(block.timestamp + 1 hours + 1);
        market.startTrading();
        console.log("Trading phase started");
        console.log("Current phase:", uint256(market.currentPhase()));
        console.log("Winning criteria:", market.resolutionCriteria());
        
        // Check initial AMM state
        console.log("\n--- INITIAL AMM STATE ---");
        console.log("YES reserves:", market.yesReserves() / 10**6, "tokens");
        console.log("NO reserves:", market.noReserves() / 10**6, "tokens");
        console.log("USDC reserves:", market.usdcReserves() / 10**6, "USDC");
        
        (uint256 yesPrice, uint256 noPrice) = market.getTokenPrices();
        console.log("YES price:", yesPrice, "USDC per token");
        console.log("NO price:", noPrice, "USDC per token");
        
        // === TRADING ACTIVITY ===
        console.log("\n--- TRADING ACTIVITY ---");
        
        // Dave buys YES tokens (bullish on ETH)
        vm.prank(dave);
        market.buyYes(2000 * 10**6);
        console.log("Dave bought YES tokens with 2,000 USDC");
        console.log("Dave's YES balance:", market.yesToken().balanceOf(dave) / 10**6, "tokens");
        
        // Eve buys NO tokens (bearish on ETH)
        vm.prank(eve);
        market.buyNo(1500 * 10**6);
        console.log("Eve bought NO tokens with 1,500 USDC");
        console.log("Eve's NO balance:", market.noToken().balanceOf(eve) / 10**6, "tokens");
        
        // Check updated prices
        (uint256 newYesPrice, uint256 newNoPrice) = market.getTokenPrices();
        console.log("\n--- UPDATED PRICES ---");
        console.log("YES price:", newYesPrice, "USDC per token");
        console.log("NO price:", newNoPrice, "USDC per token");
        
        // More trading activity
        vm.prank(bob);
        market.buyYes(1000 * 10**6);
        console.log("Bob bought YES tokens with 1,000 USDC");
        
        vm.prank(charlie);
        market.buyNo(800 * 10**6);
        console.log("Charlie bought NO tokens with 800 USDC");
        
        // Final state
        console.log("\n--- FINAL STATE ---");
        console.log("YES reserves:", market.yesReserves() / 10**6, "tokens");
        console.log("NO reserves:", market.noReserves() / 10**6, "tokens");
        console.log("USDC reserves:", market.usdcReserves() / 10**6, "USDC");
        
        (uint256 finalYesPrice, uint256 finalNoPrice) = market.getTokenPrices();
        console.log("Final YES price:", finalYesPrice, "USDC per token");
        console.log("Final NO price:", finalNoPrice, "USDC per token");
        
        // Show token balances
        console.log("\n--- TOKEN BALANCES ---");
        console.log("Dave's YES tokens:", market.yesToken().balanceOf(dave) / 10**6);
        console.log("Bob's YES tokens:", market.yesToken().balanceOf(bob) / 10**6);
        console.log("Eve's NO tokens:", market.noToken().balanceOf(eve) / 10**6);
        console.log("Charlie's NO tokens:", market.noToken().balanceOf(charlie) / 10**6);
        
        console.log("\n=== SCENARIO 1 COMPLETE ===");
    }
    
    function test_Scenario2_ElectionMarket() public {
        console.log("\n=== SCENARIO 2: ELECTION PREDICTION MARKET ===");
        
        // === MARKET CREATION ===
        market = SimplePredictionMarket(factory.createMarket("Will Democrats win the 2024 US Presidential Election?"));
        console.log("Market created:", address(market));
        console.log("Question:", market.question());
        
        // Setup approvals
        vm.prank(alice);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(charlie);
        usdc.approve(address(market), type(uint256).max);
        
        // === SEEDING PHASE ===
        console.log("\n--- SEEDING PHASE ---");
        
        vm.prank(alice);
        market.seedLiquidity(15000 * 10**6);
        console.log("Alice seeded 15,000 USDC");
        
        vm.prank(bob);
        market.seedLiquidity(8000 * 10**6);
        console.log("Bob seeded 8,000 USDC");
        
        vm.prank(charlie);
        market.seedLiquidity(7000 * 10**6);
        console.log("Charlie seeded 7,000 USDC");
        
        console.log("Total LP contributions:", market.totalLPContributions() / 10**6, "USDC");
        
        // === VOTING PHASE ===
        console.log("\n--- VOTING PHASE ---");
        
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        console.log("Voting phase started");
        
        // Multiple resolution criteria proposals
        vm.prank(alice);
        market.proposeCriteria("Official results certified by all 50 state governments");
        console.log("Alice proposed: State certification criteria");
        
        vm.prank(bob);
        market.proposeCriteria("Electoral College vote count on January 6, 2025");
        console.log("Bob proposed: Electoral College criteria");
        
        vm.prank(charlie);
        market.proposeCriteria("Associated Press election call on election night");
        console.log("Charlie proposed: AP call criteria");
        
        // Voting with different outcomes
        vm.prank(alice);
        market.voteOnCriteria("Official results certified by all 50 state governments");
        console.log("Alice voted for state certification");
        
        vm.prank(bob);
        market.voteOnCriteria("Official results certified by all 50 state governments");
        console.log("Bob voted for state certification");
        
        vm.prank(charlie);
        market.voteOnCriteria("Electoral College vote count on January 6, 2025");
        console.log("Charlie voted for Electoral College");
        
        // Check results
        console.log("\n--- VOTE RESULTS ---");
        console.log("State certification votes:", market.getCriteriaVotes("Official results certified by all 50 state governments") / 10**6, "USDC weight");
        console.log("Electoral College votes:", market.getCriteriaVotes("Electoral College vote count on January 6, 2025") / 10**6, "USDC weight");
        console.log("AP call votes:", market.getCriteriaVotes("Associated Press election call on election night") / 10**6, "USDC weight");
        
        // === TRADING PHASE ===
        console.log("\n--- TRADING PHASE ---");
        
        vm.warp(block.timestamp + 1 hours + 1);
        market.startTrading();
        console.log("Trading started");
        console.log("Winning criteria:", market.resolutionCriteria());
        
        // Setup more traders
        vm.prank(dave);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(eve);
        usdc.approve(address(market), type(uint256).max);
        
        // Political trading activity
        vm.prank(dave);
        market.buyYes(3000 * 10**6);
        console.log("Dave bought YES (Democrats) with 3,000 USDC");
        
        vm.prank(eve);
        market.buyNo(2500 * 10**6);
        console.log("Eve bought NO (Republicans) with 2,500 USDC");
        
        // Show final prices
        (uint256 finalYesPrice, uint256 finalNoPrice) = market.getTokenPrices();
        console.log("\n--- FINAL PRICES ---");
        console.log("Democrats (YES) price:", finalYesPrice, "USDC per token");
        console.log("Republicans (NO) price:", finalNoPrice, "USDC per token");
        
        console.log("\n=== SCENARIO 2 COMPLETE ===");
    }
    
    function test_Scenario3_SportsMarket() public {
        console.log("\n=== SCENARIO 3: SPORTS PREDICTION MARKET ===");
        
        // === MARKET CREATION ===
        market = SimplePredictionMarket(factory.createMarket("Will the Lakers win the 2024 NBA Championship?"));
        console.log("Market created:", address(market));
        console.log("Question:", market.question());
        
        // Setup participants
        vm.prank(alice);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(market), type(uint256).max);
        
        // === SEEDING PHASE ===
        console.log("\n--- SEEDING PHASE ---");
        
        vm.prank(alice);
        market.seedLiquidity(5000 * 10**6);
        console.log("Alice seeded 5,000 USDC");
        
        vm.prank(bob);
        market.seedLiquidity(5000 * 10**6);
        console.log("Bob seeded 5,000 USDC");
        
        // === VOTING PHASE ===
        console.log("\n--- VOTING PHASE ---");
        
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        
        // Sports-specific criteria
        vm.prank(alice);
        market.proposeCriteria("NBA official championship ceremony completion");
        console.log("Alice proposed: Official ceremony criteria");
        
        vm.prank(bob);
        market.proposeCriteria("ESPN championship announcement");
        console.log("Bob proposed: ESPN announcement criteria");
        
        // Equal weight voting
        vm.prank(alice);
        market.voteOnCriteria("NBA official championship ceremony completion");
        
        vm.prank(bob);
        market.voteOnCriteria("NBA official championship ceremony completion");
        
        console.log("Both voted for official ceremony criteria");
        
        // === TRADING PHASE ===
        console.log("\n--- TRADING PHASE ---");
        
        vm.warp(block.timestamp + 1 hours + 1);
        market.startTrading();
        console.log("Trading started");
        console.log("Winning criteria:", market.resolutionCriteria());
        
        // Setup more traders
        vm.prank(charlie);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(dave);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(eve);
        usdc.approve(address(market), type(uint256).max);
        
        // Sports betting activity
        vm.prank(charlie);
        market.buyYes(1000 * 10**6);
        console.log("Charlie bought YES (Lakers win) with 1,000 USDC");
        
        vm.prank(dave);
        market.buyNo(1200 * 10**6);
        console.log("Dave bought NO (Lakers lose) with 1,200 USDC");
        
        vm.prank(eve);
        market.buyYes(800 * 10**6);
        console.log("Eve bought YES (Lakers win) with 800 USDC");
        
        // Final state
        (uint256 finalYesPrice, uint256 finalNoPrice) = market.getTokenPrices();
        console.log("\n--- FINAL PRICES ---");
        console.log("Lakers win (YES) price:", finalYesPrice, "USDC per token");
        console.log("Lakers lose (NO) price:", finalNoPrice, "USDC per token");
        
        console.log("\n=== SCENARIO 3 COMPLETE ===");
    }
    
    function test_Scenario4_TechMarket() public {
        console.log("\n=== SCENARIO 4: TECH PREDICTION MARKET ===");
        
        // === MARKET CREATION ===
        market = SimplePredictionMarket(factory.createMarket("Will Apple release a VR headset in 2024?"));
        console.log("Market created:", address(market));
        console.log("Question:", market.question());
        
        // Single LP scenario
        vm.prank(alice);
        usdc.approve(address(market), type(uint256).max);
        
        // === SEEDING PHASE ===
        console.log("\n--- SEEDING PHASE ---");
        
        vm.prank(alice);
        market.seedLiquidity(20000 * 10**6);
        console.log("Alice seeded 20,000 USDC (single LP)");
        
        // === VOTING PHASE ===
        console.log("\n--- VOTING PHASE ---");
        
        vm.warp(block.timestamp + 2 hours + 1);
        market.startVoting();
        
        // Single LP gets to decide criteria
        vm.prank(alice);
        market.proposeCriteria("Official Apple press release or keynote announcement");
        console.log("Alice proposed: Official Apple announcement criteria");
        
        vm.prank(alice);
        market.voteOnCriteria("Official Apple press release or keynote announcement");
        console.log("Alice voted for her own criteria");
        
        // === TRADING PHASE ===
        console.log("\n--- TRADING PHASE ---");
        
        vm.warp(block.timestamp + 1 hours + 1);
        market.startTrading();
        console.log("Trading started");
        console.log("Winning criteria:", market.resolutionCriteria());
        
        // Setup traders
        vm.prank(bob);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(charlie);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(dave);
        usdc.approve(address(market), type(uint256).max);
        
        // Tech speculation
        vm.prank(bob);
        market.buyYes(5000 * 10**6);
        console.log("Bob bought YES (Apple VR) with 5,000 USDC");
        
        vm.prank(charlie);
        market.buyNo(3000 * 10**6);
        console.log("Charlie bought NO (no Apple VR) with 3,000 USDC");
        
        vm.prank(dave);
        market.buyYes(2000 * 10**6);
        console.log("Dave bought YES (Apple VR) with 2,000 USDC");
        
        // Final state
        (uint256 finalYesPrice, uint256 finalNoPrice) = market.getTokenPrices();
        console.log("\n--- FINAL PRICES ---");
        console.log("Apple VR (YES) price:", finalYesPrice, "USDC per token");
        console.log("No Apple VR (NO) price:", finalNoPrice, "USDC per token");
        
        console.log("\n=== SCENARIO 4 COMPLETE ===");
    }
} 