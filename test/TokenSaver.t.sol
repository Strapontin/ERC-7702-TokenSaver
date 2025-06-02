// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {TokenSaver} from "../src/TokenSaver.sol";

import {ERC20, ERC20Token} from "./mocks/ERC20Token.sol";

contract TokenSaverTest is Test {
    // Alice's address and private key (EOA with no initial contract code).
    address alice;
    uint256 alicePK;
    address bob;

    ERC20Token DAI;
    ERC20Token WETH;

    // The contract that Alice will delegate execution to.
    TokenSaver public tokenSaver;

    function setUp() public {
        (alice, alicePK) = makeAddrAndKey("alice");
        bob = makeAddr("bob");

        tokenSaver = new TokenSaver();

        DAI = new ERC20Token(alice, 100e18);
        WETH = new ERC20Token(alice, 100e18);
    }

    function test_SimpleTransfer() public {
        vm.signAndAttachDelegation(address(tokenSaver), alicePK);
        vm.startPrank(alice);

        // Add DAI token to the list of tracked tokens
        TokenSaver(alice).addOrUpdateTokenTracked(address(DAI), 100e18);

        TokenSaver.Call[] memory calls = new TokenSaver.Call[](1);
        calls[0] = TokenSaver.Call({to: address(DAI), value: 0, data: abi.encodeCall(ERC20.transfer, (bob, 1))});

        // Execute the transfer. It fails since alice's balance is now under the minimum amount she requested
        vm.expectRevert(
            abi.encodeWithSelector(TokenSaver.BalanceBelowMinimum.selector, address(DAI), 100e18, 100e18 - 1)
        );
        TokenSaver(alice).execute(calls);

        vm.stopPrank();
    }

    function test_setUintMaxShouldAllowToReceiveTokenButNotLoosingAny() public {
        vm.signAndAttachDelegation(address(tokenSaver), alicePK);
        vm.startPrank(alice);

        // Add DAI token to the list of tracked tokens
        TokenSaver(alice).addOrUpdateTokenTracked(address(DAI), type(uint256).max);

        TokenSaver.Call[] memory calls = new TokenSaver.Call[](1);
        calls[0] = TokenSaver.Call({to: address(DAI), value: 0, data: abi.encodeCall(ERC20.transfer, (bob, 1))});

        // Execute the transfer. It fails since alice's balance is now under the minimum amount she requested
        vm.expectRevert(
            abi.encodeWithSelector(TokenSaver.BalanceBelowMinimum.selector, address(DAI), type(uint256).max, 100e18 - 1)
        );
        TokenSaver(alice).execute(calls);

        calls[0] = TokenSaver.Call({to: address(DAI), value: 0, data: abi.encodeCall(ERC20Token.mint, (alice, 1e18))});

        TokenSaver(alice).execute(calls);

        assertEq(DAI.balanceOf(alice), 101e18);

        vm.stopPrank();
    }

    function test_usingNativeToken() public {
        vm.deal(alice, 2 ether);
        vm.signAndAttachDelegation(address(tokenSaver), alicePK);
        vm.startPrank(alice);

        // Address(0) is native token
        TokenSaver(alice).addOrUpdateTokenTracked(address(0), 1 ether);

        TokenSaver.Call[] memory calls = new TokenSaver.Call[](1);
        calls[0] = TokenSaver.Call({to: address(bob), value: 1 ether, data: ""});

        TokenSaver(alice).execute(calls);

        assertEq(alice.balance, 1 ether);
        assertEq(bob.balance, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(TokenSaver.BalanceBelowMinimum.selector, 0, 1 ether, 0));
        TokenSaver(alice).execute(calls);

        vm.stopPrank();
    }
}
