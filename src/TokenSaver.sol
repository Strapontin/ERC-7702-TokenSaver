// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenSaver {
    // Purposes: have a list of tokens to track.
    // These tracked tokens should not see the balance of this address below the min amount.

    struct TokenTracked {
        address token; // If == address(0), then this represents native token
        uint256 minAmount; // If == uint.max, then we should check that the amount does not decrease
    }

    struct Call {
        address to;
        uint256 value;
        bytes data;
    }

    TokenTracked[] tokenTracked;

    modifier onlyOwner() {
        require(msg.sender == address(this), "Not account onlyOwner");
        _;
    }

    error BalanceBelowMinimum(address token, uint256 minAmount, uint256 actualAmount);

    /**
     * @notice Adds or updates a token to be tracked with a specified minimum amount.
     * @dev If the token already exists in the tracking list, its minimum amount is updated.
     * @param _token The address of the token to track. Use address(0) for native token.
     * @param _minAmount The minimum amount of the token to maintain.
     */
    function addOrUpdateTokenTracked(address _token, uint256 _minAmount) external onlyOwner {
        // Update the token if found
        for (uint256 i = 0; i < tokenTracked.length; i++) {
            if (tokenTracked[i].token == _token) {
                tokenTracked[i].minAmount = _minAmount;
                return;
            }
        }

        tokenTracked.push(TokenTracked({token: _token, minAmount: _minAmount}));
    }

    /**
     * @notice Removes a token from the tracking list.
     * @param _token The address of the token to remove. Use address(0) for native token.
     */
    function removeToken(address _token) external onlyOwner {
        uint256 listLength = tokenTracked.length;

        for (uint256 i = 0; i < listLength; i++) {
            if (tokenTracked[i].token == _token) {
                tokenTracked[i] = tokenTracked[listLength - 1];
                tokenTracked.pop();
                return;
            }
        }
    }

    /**
     * @notice Executes a series of calls and ensures token balances are maintained.
     * @dev Reverts if any token balance falls below the specified minimum amount.
     * @param calls An array of Call structs containing the details of each call to execute.
     */
    function execute(Call[] calldata calls) external onlyOwner {
        TokenTracked[] memory _tokenTracked = new TokenTracked[](tokenTracked.length);

        // Checks the value of tokens with minAmount == uint.max
        for (uint256 i = 0; i < tokenTracked.length; i++) {
            _tokenTracked[i] = tokenTracked[i];

            if (tokenTracked[i].minAmount == type(uint256).max) {
                _tokenTracked[i].minAmount = _getTokenValue(_tokenTracked[i].token);
            }
        }

        // Execute calls
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success,) = calls[i].to.call{value: calls[i].value}(calls[i].data);
                (success, "Call reverted");
        }

        // Revert if balances are not as expected
        for (uint256 i = 0; i < _tokenTracked.length; i++) {
            uint256 value = _getTokenValue(_tokenTracked[i].token);

            if (value < _tokenTracked[i].minAmount) {
                revert BalanceBelowMinimum(_tokenTracked[i].token, tokenTracked[i].minAmount, value);
            }
        }
    }

    /**
     * @notice Retrieves the balance of a specific token for this contract.
     * @param tokenAddress The address of the token. Use address(0) for native token.
     * @return The balance of the specified token.
     */
    function _getTokenValue(address tokenAddress) private view returns (uint256) {
        if (tokenAddress == address(0)) { 
            return address(this).balance;
        }

        return IERC20(tokenAddress).balanceOf(address(this));
    }
}
