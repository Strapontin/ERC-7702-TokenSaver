> This code is un-audited and not suitable for production.

# Introduction

This project was inspired from this [spoofing attack](https://drops.scamsniffer.io/transaction-simulation-spoofing-a-new-threat-in-web3/).

In a world where transactions are subject to MEV, spoofing attacks, or other related thieve of funds scenarios, EOAs are not natively able to sign a transaction and **expect** the desired outcome to happen.

Since project tries to show how [EIP-7702](https://eips.ethereum.org/EIPS/eip-7702) can be used to fix such issue, where every transaction that would end with less funds than expected would revert, covering any loss.

# TokenSaver

## Tracking A Token

In order to add an ERC20 token (or native ether) to the list of funds you don't want to lose, you need to call `addOrUpdateTokenTracked` with the address of the corresponding token, and the minimum value you expect to have after your next call.

_Note: You can use `address(0)` for the token address if you want to track native tokens, and `type(uint256).max` for the minimum value if you expect it to NEVER decrease._

_Note: If the token is already in the list, the minimum amount will be updated with the new value_

**Example:** `myAddress.addOrUpdateTokenTracked(address(0), 100 ether)` will add the native token to the tracked tokens, and your balance must not drop below `100 ether`.

## Removing A Token

If you don't want to track a token anymore, you are advised to remove it from the list by calling `removeToken`.

_Note: This will NOT revert if the token is not in the list_

Alternatively, you can use `deleteAllTokenTracked` to clear the array. This is particulary useful when migrating from another smart wallet, where this storage was used by another array.

## Setting `revertOnPermit`

If you want to avoid the `permit` vulnerability, you can call `setRevertOnPermit(true)`. This will allow `execute` to revert everytime it encounters a call with a [`ERC20Permit::permit` selector](https://www.4byte.directory/signatures/?bytes4_signature=0xd505accf).

## Executing A Transaction

> **[!WARNING]** If you execute transactions without using `TokenSaver::execute`, your tracked tokens will not be verified! You must execute transaction through `TokenSaver::execute` if you want this contract to verify your tokens balance correctly.

Once you have set your tracked tokens correctly, you are ready to call the function `execute`, where your transactions will run safely.

You will need to encode a list of calls, and all of them will be executed in order.

Once these calls are made, the function verifies that:

1. Your balances for every token tracked did not fall below the expected amount.
2. Your allowances for every token tracked were not updated to a higher value than what they were at the beginning of the function call.
3. If the `revertOnPermit` variable is set to `true`, then the whole transaction will revert if it encounters a [`ERC20Permit::permit` selector](https://www.4byte.directory/signatures/?bytes4_signature=0xd505accf).

_Note: You cannot call other functions of `TokenSaver` during `execute` for security reasons_

## _But I need concrete code examples, show me real-world scenarios!_

For example use-cases, visit the [`ExampleScenarios` test file](./test/ExampleScenarios.t.sol).
