// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

contract DecodeVAATest is Test {
    function testDecodeAttackVAA() public pure {
        // bytes32 = 64 hex chars
        bytes32 tokenAddr = hex"0000000000000000000000004644bbcfd26a79a79254af30ed8ab80658a73b32";
        bytes32 toAddr = hex"000000000000000000000000b13a503da5f368e48577c87b5d5aec73d08f812e";
        
        bytes memory payload = abi.encodePacked(
            uint256(1000000000000000),
            tokenAddr,
            uint16(23),
            toAddr,
            uint16(4),
            uint8(6)
        );

        uint256 amount;
        bytes32 tokenAddress;
        uint16 tokenChain;
        bytes32 toAddress;
        uint16 toChain;
        uint8 tokenDecimals;

        assembly {
            let ptr := add(payload, 32)
            amount := mload(ptr)
            tokenAddress := mload(add(ptr, 32))
            tokenChain := shr(240, mload(add(ptr, 64)))
            toAddress := mload(add(ptr, 66))
            toChain := shr(240, mload(add(ptr, 98)))
            tokenDecimals := shr(248, mload(add(ptr, 100)))
        }

        console.log("========== Decoded Payload ==========");
        console.log("Amount (raw):", amount);
        console.log("Amount (tokens):", amount / 1e6);
        console.log("Token Chain:", tokenChain);
        console.log("To Chain:", toChain);
        console.log("Token Decimals:", tokenDecimals);
        console.log("To Address:");
        console.logBytes32(toAddress);

        address hackerAddress = address(uint160(uint256(toAddress)));
        console.log("Hacker Address:", hackerAddress);
    }
}