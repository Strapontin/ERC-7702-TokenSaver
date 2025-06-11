// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TokenSaver} from "src/TokenSaver.sol";

contract TokenSaverTestHelper is TokenSaver {
    function getTokensTrackedLength() external view returns (uint256) {
        return tokensTracked.length;
    }
}
