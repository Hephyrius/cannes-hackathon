// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/PredictionMarketFactory.sol";
import "../src/PredictionMarket.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PredictionMarketFactoryTest is Test {
    MockUSDC usdc;
    PredictionMarket market;
    PredictionMarketFactory factory;
    address alice = address(0x1);
    address bob = address(0x2);
    
    function setUp() public {
        usdc = new MockUSDC();
        market = new PredictionMarket(address(usdc), "Test Market", block.timestamp + 1 days);
        factory = new PredictionMarketFactory(address(this), address(usdc));
        
        // Mint USDC to test accounts
        usdc.mint(alice, 1000 * 1e6);
        usdc.mint(bob, 1000 * 1e6);
    }
    
    function testFactoryDeployment() public {
        assertEq(factory.feeToSetter(), address(this));
        assertEq(factory.allPairsLength(), 0);
    }
    
    function testCreatePair() public {
        address yesToken = address(market.yesToken());
        address noToken = address(market.noToken());
        
        // Create YES/USDC pair
        address pair = factory.createPair(yesToken, address(usdc));
        assertTrue(pair != address(0));
        assertEq(factory.getPair(yesToken, address(usdc)), pair);
        assertEq(factory.getPair(address(usdc), yesToken), pair);
        assertEq(factory.allPairsLength(), 1);
        assertEq(factory.allPairs(0), pair);
        
        // Create NO/USDC pair
        address pair2 = factory.createPair(noToken, address(usdc));
        assertTrue(pair2 != address(0));
        assertEq(factory.getPair(noToken, address(usdc)), pair2);
        assertEq(factory.allPairsLength(), 2);
    }
    
    function testCreatePairSameTokens() public {
        address yesToken = address(market.yesToken());
        
        // Should fail when creating pair with same tokens
        vm.expectRevert("PredictionMarketFactory: IDENTICAL_ADDRESSES");
        factory.createPair(yesToken, yesToken);
    }
    
    function testCreatePairZeroAddress() public {
        address yesToken = address(market.yesToken());
        
        // Should fail when creating pair with zero address
        vm.expectRevert("PredictionMarketFactory: ZERO_ADDRESS");
        factory.createPair(address(0), yesToken);
    }
    
    function testCreatePairAlreadyExists() public {
        address yesToken = address(market.yesToken());
        
        // Create pair first time
        factory.createPair(yesToken, address(usdc));
        
        // Should fail when creating same pair again
        vm.expectRevert("PredictionMarketFactory: PAIR_EXISTS");
        factory.createPair(yesToken, address(usdc));
    }
    
    function testFeeControls() public {
        // Test fee controls
        factory.setFeeTo(alice);
        assertEq(factory.feeTo(), alice);
        
        factory.setFeeToSetter(bob);
        assertEq(factory.feeToSetter(), bob);
        
        // Only fee setter can change fees
        vm.prank(alice);
        vm.expectRevert("PredictionMarketFactory: FORBIDDEN");
        factory.setFeeTo(bob);
    }
} 