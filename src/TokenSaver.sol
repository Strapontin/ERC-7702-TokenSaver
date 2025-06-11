// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TokenSaver is ReentrancyGuard {
    // Purposes: have a list of tokens to track.
    // These tracked tokens should not see the balance of this address below the min amount.

    struct TokenTracked {
        address token; // If == address(0), then this represents native token
        uint256 minAmount; // If == uint.max, then we should check that the amount does not decrease
    }

    struct AllowancesTracked {
        address token;
        address spender;
        uint256 amount;
    }

    struct Call {
        address to;
        uint256 value;
        bytes data;
    }

    bytes4 public constant APPROVE_SELECTOR = IERC20.approve.selector;
    bytes4 public constant PERMIT_SELECTOR = ERC20Permit.permit.selector;

    TokenTracked[] public tokensTracked;
    bool revertOnPermit;

    modifier onlyEOA() {
        if (msg.sender != address(this)) {
            revert NotSmartWalletEOA(msg.sender, address(this));
        }
        _;
    }

    error BalanceBelowMinimum(address token, uint256 minAmount, uint256 actualAmount);
    error AllowanceAboveBeforeTransaction(address token, address spender, uint256 amountBefore, uint256 amountAfter);
    error NotSmartWalletEOA(address sender, address eoa);
    error CallUnsuccessful(uint256 callIndex);
    error PermitIsNotAuthorized();

    /**
     * @notice Adds or updates a token to be tracked with a specified minimum amount.
     * @dev If the token already exists in the tracking list, its minimum amount is updated.
     * @param _token The address of the token to track. Use address(0) for native token.
     * @param _minAmount The minimum amount of the token to maintain. Use `type(uint256).max` if you expect the value to NEVER decrease.
     */
    function addOrUpdateTokenTracked(address _token, uint256 _minAmount) external onlyEOA nonReentrant {
        // Update the token if found
        for (uint256 i = 0; i < tokensTracked.length; i++) {
            if (tokensTracked[i].token == _token) {
                tokensTracked[i].minAmount = _minAmount;
                return;
            }
        }

        tokensTracked.push(TokenTracked({token: _token, minAmount: _minAmount}));
    }

    /**
     * @notice Removes a token from the tracking list.
     * @param _token The address of the token to remove. Use address(0) for native token.
     */
    function removeToken(address _token) external onlyEOA nonReentrant {
        uint256 listLength = tokensTracked.length;

        for (uint256 i = 0; i < listLength; i++) {
            if (tokensTracked[i].token == _token) {
                tokensTracked[i] = tokensTracked[listLength - 1];
                tokensTracked.pop();
                return;
            }
        }
    }

    /**
     * @notice Removes all tracked tokens.
     * @dev Useful for clearing token tracking state when migrating from a previous smart wallet
     */
    function deleteAllTokenTracked() external onlyEOA nonReentrant {
        delete tokensTracked;
    }

    /**
     * @notice Sets the value of the variable `revertOnPermit`. When set to true, any function
     * selector that matches the permit selector when calling `execute` will revert.
     * @param value The value to set the variable `revertOnPermit` to.
     */
    function setRevertOnPermit(bool value) external onlyEOA nonReentrant {
        revertOnPermit = value;
    }

    /**
     * @notice Executes a series of calls and ensures token balances are maintained.
     * @dev Reverts if any token balance falls below the specified minimum amount.
     * @param calls An array of Call structs containing the details of each call to execute.
     */
    function execute(Call[] calldata calls) external onlyEOA nonReentrant {
        TokenTracked[] memory _tokenTracked = new TokenTracked[](tokensTracked.length);
        AllowancesTracked[] memory _allowanceTracked = new AllowancesTracked[](tokensTracked.length);
        uint256 allowanceLength;

        // Checks the value of tokens with minAmount == uint.max
        for (uint256 i = 0; i < tokensTracked.length; i++) {
            _tokenTracked[i] = tokensTracked[i];

            if (tokensTracked[i].minAmount == type(uint256).max) {
                _tokenTracked[i].minAmount = _getTokenValue(_tokenTracked[i].token);
            }
        }

        // Execute calls
        for (uint256 i = 0; i < calls.length; i++) {
            // If the call is `ERC20::approve()`, save its data
            bytes calldata data = calls[i].data;
            bytes4 selector;
            assembly {
                selector := calldataload(data.offset)
            }
            // If we are trying to call `approve` for a tracked token, we save the previous value for comparison
            if (selector == APPROVE_SELECTOR && _isTokenTracked(calls[i].to)) {
                (address spender,) = abi.decode(data[4:], (address, uint256));

                if (!_isTokenAllowanceAlreadyTracked(_allowanceTracked, calls[i].to, spender, allowanceLength)) {
                    _allowanceTracked[allowanceLength].token = calls[i].to;
                    _allowanceTracked[allowanceLength].spender = spender;
                    _allowanceTracked[allowanceLength].amount =
                        IERC20(_allowanceTracked[i].token).allowance(address(this), _allowanceTracked[i].spender);

                    allowanceLength++;
                }
            }

            // If we are trying to call `permit` for a tracked token and `revertOnPermit` is set to true
            if (selector == PERMIT_SELECTOR && _isTokenTracked(calls[i].to) && revertOnPermit) {
                revert PermitIsNotAuthorized();
            }

            // Call execution
            (bool success,) = calls[i].to.call{value: calls[i].value}(data);
            if (!success) revert CallUnsuccessful(i);
        }

        // Revert if balances are lower than expected
        for (uint256 i = 0; i < _tokenTracked.length; i++) {
            uint256 value = _getTokenValue(_tokenTracked[i].token);

            if (value < _tokenTracked[i].minAmount) {
                revert BalanceBelowMinimum(_tokenTracked[i].token, tokensTracked[i].minAmount, value);
            }
        }

        // Revert if allowances are higher than expected
        for (uint256 i = 0; i < allowanceLength; i++) {
            uint256 newAllowance =
                IERC20(_allowanceTracked[i].token).allowance(address(this), _allowanceTracked[i].spender);

            if (newAllowance > _allowanceTracked[i].amount) {
                revert AllowanceAboveBeforeTransaction(
                    _allowanceTracked[i].token, _allowanceTracked[i].spender, _allowanceTracked[i].amount, newAllowance
                );
            }
        }
    }

    /**
     * @notice Checks if a specific token is being tracked.
     * @param token The address of the token to check.
     * @return bool Returns `true` if the token is being tracked, otherwise `false`.
     */
    function _isTokenTracked(address token) private view returns (bool) {
        for (uint256 i = 0; i < tokensTracked.length; i++) {
            if (tokensTracked[i].token == token) return true;
        }
        return false;
    }

    /**
     * @dev Checks if a specific token allowance is already being tracked.
     * @param _allowanceTracked An array of `AllowancesTracked` structs representing the tracked allowances.
     * @param token The address of the token to check.
     * @param spender The address of the spender to check.
     * @param allowanceLength The number of tracked allowances in the `_allowanceTracked` array.
     * @return bool Returns `true` if the token allowance is already being tracked, otherwise `false`.
     */
    function _isTokenAllowanceAlreadyTracked(
        AllowancesTracked[] memory _allowanceTracked,
        address token,
        address spender,
        uint256 allowanceLength
    ) private pure returns (bool) {
        for (uint256 i = 0; i < allowanceLength; i++) {
            if (_allowanceTracked[i].token == token && _allowanceTracked[i].spender == spender) return true;
        }
        return false;
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
