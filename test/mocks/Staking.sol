// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Staking {
    function deposit(address token, uint256 amount) external {
        ERC20(token).transferFrom(msg.sender, address(this), amount);
    }
}