// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";

contract SimpleTest is Test {
    
    function testBasic() public {
        assertTrue(true);
    }
    
    function testMath() public {
        assertEq(uint256(2 + 2), uint256(4));
    }
} 