// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/PredictionMarketFactory.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PredictionMarketFactoryTest is Test {
    MockUSDC usdc;
    PredictionMarketFactory factory;
    address alice = address(0x1);
    uint256 constant USDC_UNIT = 1e6;

    function setUp() public {
        usdc = new MockUSDC();
        factory = new PredictionMarketFactory();
    }

    function testCreateMarket() public {
        string memory question = "Is this a test?";
        uint256 resolutionTime = block.timestamp + 1 days;
        address market = factory.createMarket(address(usdc), question, resolutionTime);
        assertTrue(market != address(0));
        assertEq(factory.numberOfMarkets(), 1);
        address[] memory markets = factory.getAllMarkets();
        assertEq(markets.length, 1);
        assertEq(markets[0], market);
    }

    function testMultipleMarkets() public {
        for (uint256 i = 0; i < 3; i++) {
            string memory question = string(abi.encodePacked("Q", vm.toString(i)));
            uint256 resolutionTime = block.timestamp + (i + 1) * 1 days;
            factory.createMarket(address(usdc), question, resolutionTime);
        }
        assertEq(factory.numberOfMarkets(), 3);
        address[] memory markets = factory.getAllMarkets();
        assertEq(markets.length, 3);
    }

    function testMarketCreatedEvent() public {
        string memory question = "Event test?";
        uint256 resolutionTime = block.timestamp + 1 days;
        // Deploy and capture the market address
        vm.recordLogs();
        address market = factory.createMarket(address(usdc), question, resolutionTime);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool found = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics.length > 0 && entries[i].topics[0] == keccak256("MarketCreated(address,string,uint256)")) {
                address loggedMarket = address(uint160(uint256(entries[i].topics[1])));
                assertEq(loggedMarket, market);
                found = true;
            }
        }
        assertTrue(found, "MarketCreated event not found");
    }
} 