// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ERC20Token is ERC20, ERC20Permit {
    constructor(address mintTo, uint256 amount) ERC20("MyToken", "MTK") ERC20Permit("MyToken") {
        _mint(mintTo, amount);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
