// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {TokenSaver} from "../src/TokenSaver.sol";

import {MaliciousContract} from "./mocks/MaliciousContract.sol";
import {Staking} from "./mocks/Staking.sol";
import {ERC20, ERC20Permit, ERC20Token} from "./mocks/ERC20Token.sol";

contract ExampleScenarios is Test {
    address bob;

    address candid;
    uint256 candidPK;

    ERC20Token DAI;
    ERC20Token WETH;

    Staking stakingContract;
    MaliciousContract maliciousContract;

    // The contract that Alice will delegate execution to.
    TokenSaver public tokenSaver;

    function setUp() public {
        bob = makeAddr("bob");
        (candid, candidPK) = makeAddrAndKey("candid");

        tokenSaver = new TokenSaver();

        DAI = new ERC20Token(candid, 100e18);
        WETH = new ERC20Token(candid, 100e18);

        stakingContract = new Staking();
        maliciousContract = new MaliciousContract();
    }

    /**
     * The following test shows how the hack that inspired me for this project could have been avoided.
     * You can read about it here: http://drops.scamsniffer.io/transaction-simulation-spoofing-a-new-threat-in-web3/
     */
    function test_preventsSpoofingAttack() public {
        (address victim, uint256 victimPK) = makeAddrAndKey("victim");

        uint256 victimsBalance = 143.45 ether;
        vm.deal(victim, victimsBalance);

        // Our user simulates their transaction off-chain, and it looks correct.
        // This is because maliciousContract sends back the ether given to it.

        /* Around here, the attacker alters the malicious contract in order for it to not return the ether send */

        // Our victim is *clever* and chooses to use TokenSaver to protect their funds
        vm.signAndAttachDelegation(address(tokenSaver), victimPK);
        vm.startPrank(victim);

        // They set their smart wallet to revert if it has less than 143.45 ether
        TokenSaver(victim).addOrUpdateTokenTracked(address(0), victimsBalance);

        TokenSaver.Call[] memory calls = new TokenSaver.Call[](1);

        // Calls the malicious contract with the balance amount as value
        calls[0] = TokenSaver.Call({
            to: address(maliciousContract),
            value: victimsBalance,
            data: abi.encodeCall(MaliciousContract.claim, ())
        });

        // The call should revert
        vm.expectRevert(abi.encodeWithSelector(TokenSaver.BalanceBelowMinimum.selector, address(0), victimsBalance, 0));
        TokenSaver(victim).execute(calls);

        // Hurray ! Funds are safe !
    }

    /**
     * Candid is naive.
     * Candid does not really verify what the calls in `execute` are, because he believes that TokenSaver
     * will protect him from all hacks. How could an attacker profit from this?
     */

    // 1. An attacker tries to add/update/remove tokens from TokenSaver
    // ✅ TokenSaver does not allow for reentrancy between functions
    function test_AddRemoveTokensRevert() public {
        vm.signAndAttachDelegation(address(tokenSaver), candidPK);
        vm.startPrank(candid);

        // A transaction to add or update tokens will revert
        TokenSaver.Call[] memory calls = new TokenSaver.Call[](1);
        calls[0] = TokenSaver.Call({
            to: address(candid),
            value: 0,
            data: abi.encodeCall(TokenSaver.addOrUpdateTokenTracked, (address(DAI), 0))
        });

        vm.expectRevert(abi.encodeWithSelector(TokenSaver.CallUnsuccessful.selector, 0));
        TokenSaver(candid).execute(calls);

        // A transaction to remove tokens will also revert
        calls[0] = TokenSaver.Call({
            to: address(candid),
            value: 0,
            data: abi.encodeCall(TokenSaver.removeToken, (address(DAI)))
        });

        vm.expectRevert(abi.encodeWithSelector(TokenSaver.CallUnsuccessful.selector, 0));
        TokenSaver(candid).execute(calls);
    }

    // 2. An attacker tries to set unlimited allowance to steal in a later transaction
    // ✅ TokenSaver protects from allowances set to a higher value than it was before tx
    // !Only works for tracked tokens!
    function test_increasedAllowanceShouldRevert() public {
        vm.signAndAttachDelegation(address(tokenSaver), candidPK);
        vm.startPrank(candid);

        // Candid has 10 DAI. He will deposit 1, so he expects to end up with 9 DAI
        TokenSaver(candid).addOrUpdateTokenTracked(address(DAI), 9 ether);

        // A transaction to approve works if it's the amount expected to spend
        TokenSaver.Call[] memory calls = new TokenSaver.Call[](2);
        calls[0] = TokenSaver.Call({
            to: address(DAI),
            value: 0,
            data: abi.encodeCall(ERC20.approve, (address(stakingContract), 1 ether))
        });
        calls[1] = TokenSaver.Call({
            to: address(stakingContract),
            value: 0,
            data: abi.encodeCall(Staking.deposit, (address(DAI), 1 ether))
        });

        TokenSaver(candid).execute(calls);

        // But a transaction to approve more than expected should fail
        calls = new TokenSaver.Call[](1);
        calls[0] =
            TokenSaver.Call({to: address(DAI), value: 0, data: abi.encodeCall(ERC20.approve, (address(bob), 1 ether))});

        vm.expectRevert(
            abi.encodeWithSelector(TokenSaver.AllowanceAboveBeforeTransaction.selector, address(DAI), bob, 0, 1 ether)
        );
        TokenSaver(candid).execute(calls);
    }

    // 3. An attacker tries to call permit
    // ✅ TokenSaver allows to automatically revert on permit calls, if the parameter is set
    // !Only works for tracked tokens!
    function test_permitShouldNotWorkIfUnauthorized() public {
        vm.signAndAttachDelegation(address(tokenSaver), candidPK);
        vm.startPrank(candid);

        TokenSaver(candid).addOrUpdateTokenTracked(address(DAI), 10 ether);
        TokenSaver(candid).setRevertOnPermit(true);

        // Generate permit signature
        uint256 deadline = block.timestamp + 1 weeks;
        (uint8 v, bytes32 r, bytes32 s) = _generatePermitSignature(deadline);

        TokenSaver.Call[] memory calls = new TokenSaver.Call[](2);
        calls[0] = TokenSaver.Call({
            to: address(DAI),
            value: 0,
            data: abi.encodeCall(ERC20Permit.permit, (candid, bob, 10 ether, deadline, v, r, s))
        });

        vm.expectRevert(TokenSaver.PermitIsNotAuthorized.selector);
        TokenSaver(candid).execute(calls);
    }

    // Generates Candid's permit signature
    function _generatePermitSignature(uint256 deadline) private view returns (uint8 v, bytes32 r, bytes32 s) {
        uint256 nonce = DAI.nonces(candid);

        // Create the permit hash according to EIP-2612
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                candid,
                bob,
                10 ether,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DAI.DOMAIN_SEPARATOR(), structHash));

        // Sign the digest with the private key
        (v, r, s) = vm.sign(candidPK, digest);
    }
}
