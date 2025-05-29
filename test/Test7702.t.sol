// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {A, B} from "../src/Test7702.sol";

contract Test7702Test is Test {
    // Alice's address and private key (EOA with no initial contract code).
    address payable ALICE_ADDRESS = payable(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    uint256 constant ALICE_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    // The contract that Alice will delegate execution to.
    A public contractA;
    B public contractB;

    function setUp() public {
        contractA = new A();
        contractB = new B();
    }

    function testMultipleSmartWallets() public {
        vm.signAndAttachDelegation(address(contractA), ALICE_PK);
        A(ALICE_ADDRESS).setA(1);
        vm.signAndAttachDelegation(address(contractB), ALICE_PK);
        B(ALICE_ADDRESS).setB(2);

        console2.log("_a:", B(ALICE_ADDRESS)._a());
        console2.log("b:", B(ALICE_ADDRESS).b());

        // OUTPUT:
        // _a: 1
        // b: 2

        // Conclusion: It's possible to create a new smart wallet while the previous wallet is still active.
        // Storage is NOT reset
    }

    // Test write to 1st contract after setting the 2nd
    function testMultipleSmartWalletsActive() public {
        vm.signAndAttachDelegation(address(contractA), ALICE_PK);
        vm.signAndAttachDelegation(address(contractB), ALICE_PK);
        A(ALICE_ADDRESS).setA(1);
        B(ALICE_ADDRESS).setB(2);

        console2.log("_a:", B(ALICE_ADDRESS)._a());
        console2.log("b:", B(ALICE_ADDRESS).b());

        // OUTPUT:
        // _a: 0
        // b: 2

        // Conclusion: Multiple contracts can't be active AT THE SAME TIME.
        // Setting a new smart wallet overwrites the function of the previous contract
    }

    // Set the first contract off, then retry to fetch the storage to see if it's still kept
    function testStorageIsKeptWhenSettingContractOff() public {
        vm.signAndAttachDelegation(address(contractA), ALICE_PK);
        A(ALICE_ADDRESS).setA(1);
        vm.signAndAttachDelegation(address(0), ALICE_PK);
        vm.signAndAttachDelegation(address(contractB), ALICE_PK);
        B(ALICE_ADDRESS).setB(2);

        console2.log("_a:", B(ALICE_ADDRESS)._a());
        console2.log("b:", B(ALICE_ADDRESS).b());

        // OUTPUT:
        // _a: 1
        // b: 2

        // Conclusion: Storage is kept even when we remove delegation before setting it to another contract
    }
}
