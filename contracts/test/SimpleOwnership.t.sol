// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/OutcomeFundingFactory.sol";
import "../src/PredictionMarket.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000e6);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract SimpleOwnershipTest is Test {
    OutcomeFundingFactory public factory;
    PredictionMarket public market;
    MockUSDC public usdc;
    
    address public alice = address(0x2);
    
    function setUp() public {
        usdc = new MockUSDC();
        factory = new OutcomeFundingFactory(address(usdc));
        
        market = new PredictionMarket(
            address(usdc),
            "Test market",
            block.timestamp + 30 days
        );
        
        usdc.mint(alice, 10000e6);
    }
    
    function testOwnershipTransfer() public {
        vm.startPrank(alice);
        usdc.approve(address(factory), 50e6);
        
        address fundingContract = factory.createFundingContract(
            address(market),
            PredictionMarket.Outcome.YES,
            "Test Fund",
            "Description",
            "TEST",
            "TEST"
        );
        vm.stopPrank();
        
        // Check that Alice is the owner
        OutcomeFunding funding = OutcomeFunding(fundingContract);
        assertEq(funding.owner(), alice);
        
        // Alice should be able to start a funding round
        vm.prank(alice);
        funding.startFundingRound(1000e6, 7 days);
        
        // Check funding round started
        (uint256 target, , , bool active, , , ) = funding.getFundingRoundInfo();
        assertEq(target, 1000e6);
        assertTrue(active);
    }
} 