// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20Token} from "../mocks/ERC20Token.sol";

contract HelperFunction is Test {
    // Generates a user's permit signature
    function generatePermitSignature(
        uint256 privateKey,
        ERC20Token token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline
    ) public view returns (uint8 v, bytes32 r, bytes32 s) {
        uint256 nonce = token.nonces(from);

        // Create the permit hash according to EIP-2612
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                from,
                to,
                amount,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));

        // Sign the digest with the private key
        (v, r, s) = vm.sign(privateKey, digest);
    }
}
