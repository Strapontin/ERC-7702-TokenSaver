// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MaliciousContract {
    function claim() external payable {
        // In the simulation, the malicious contract would have the following line added to it,
        //  masking the vulnerability.

        /**
         * payable(msg.sender).call{value: msg.value}("");
         */
    }
}
