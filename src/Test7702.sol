// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console2.sol";


contract A {
    uint256 public a;

    function setA(uint256 _a) public {
        a = _a;
    }
}

contract B {
    uint256 public _a;
    uint256 public b;

    function setB(uint256 _b) public {
        b = _b;
    }

    fallback() external {
        console2.log("This function does not exist");
    }
}
