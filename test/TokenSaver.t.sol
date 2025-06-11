// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console2} from "forge-std/Test.sol";
import {TokenSaver} from "../src/TokenSaver.sol";
import {TokenSaverTestHelper} from "./mocks/TokenSaverTestHelper.sol";
import {HelperFunction} from "./helpers/HelperFunction.sol";

import {ERC20, ERC20Permit, ERC20Token} from "./mocks/ERC20Token.sol";

contract TokenSaverTest is HelperFunction {
    // Alice's address and private key (EOA with no initial contract code).
    address alice;
    uint256 alicePK;
    address bob;

    ERC20Token DAI;
    ERC20Token WETH;

    // The contract that Alice will delegate execution to.
    TokenSaverTestHelper public tokenSaver;

    function setUp() public {
        (alice, alicePK) = makeAddrAndKey("alice");
        bob = makeAddr("bob");

        tokenSaver = new TokenSaverTestHelper();

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

    function test_updateExistingToken() public {
        vm.signAndAttachDelegation(address(tokenSaver), alicePK);
        vm.startPrank(alice);

        // First add the token with initial minimum
        TokenSaver(alice).addOrUpdateTokenTracked(address(DAI), 50e18);

        // Then update it with a new minimum
        TokenSaver(alice).addOrUpdateTokenTracked(address(DAI), 75e18);

        // Try to transfer more than allowed
        TokenSaver.Call[] memory calls = new TokenSaver.Call[](1);
        calls[0] = TokenSaver.Call({to: address(DAI), value: 0, data: abi.encodeCall(ERC20.transfer, (bob, 30e18))});

        // Should revert since balance would go below new minimum
        vm.expectRevert(abi.encodeWithSelector(TokenSaver.BalanceBelowMinimum.selector, address(DAI), 75e18, 70e18));
        TokenSaver(alice).execute(calls);

        vm.stopPrank();
    }

    function test_removeToken() public {
        vm.signAndAttachDelegation(address(tokenSaver), alicePK);
        vm.startPrank(alice);

        // Add a token, then remove it
        TokenSaver(alice).addOrUpdateTokenTracked(address(DAI), 50e18);
        TokenSaver(alice).removeToken(address(DAI));

        // Try to transfer everything
        TokenSaver.Call[] memory calls = new TokenSaver.Call[](1);
        calls[0] = TokenSaver.Call({
            to: address(DAI),
            value: 0,
            data: abi.encodeCall(ERC20.transfer, (bob, DAI.balanceOf(alice)))
        });

        TokenSaver(alice).execute(calls);

        assertEq(DAI.balanceOf(alice), 0);
    }

    function test_deleteAllTokensTracked() public {
        vm.signAndAttachDelegation(address(tokenSaver), alicePK);
        vm.startPrank(alice);

        // Add a token, then remove it
        TokenSaver(alice).addOrUpdateTokenTracked(address(DAI), 50e18);
        TokenSaver(alice).addOrUpdateTokenTracked(address(WETH), 50e18);
        TokenSaver(alice).deleteAllTokenTracked();

        assertEq(TokenSaverTestHelper(alice).getTokensTrackedLength(), 0);
    }

    function test_permitShouldFailIfRevertIsSet() public {
        vm.signAndAttachDelegation(address(tokenSaver), alicePK);
        vm.startPrank(alice);

        TokenSaver(alice).addOrUpdateTokenTracked(address(DAI), 50e18);

        // Generate permit signature
        uint256 deadline = block.timestamp + 1 weeks;
        (uint8 v, bytes32 r, bytes32 s) = generatePermitSignature(alicePK, DAI, alice, bob, 10 ether, deadline);

        TokenSaver.Call[] memory calls = new TokenSaver.Call[](2);
        calls[0] = TokenSaver.Call({
            to: address(DAI),
            value: 0,
            data: abi.encodeCall(ERC20Permit.permit, (alice, bob, 10 ether, deadline, v, r, s))
        });

        // permit should work if revert is not set
        TokenSaver(alice).execute(calls);

        // permit should not work if revert is set
        TokenSaver(alice).setRevertOnPermit(true);
        vm.expectRevert(TokenSaver.PermitIsNotAuthorized.selector);
        TokenSaver(alice).execute(calls);
    }
}
