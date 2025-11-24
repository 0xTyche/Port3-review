pragma solidity ^0.8.0;

import "forge-std/Script.sol";

interface IFakeToken {
    function sendMessageToWormhole(
        bytes memory payload,
        uint32 nonce,
        uint8 consistencyLevel
    ) external payable returns (uint64);
}

contract SendMessageScript is Script {
    IFakeToken public fakeToken = IFakeToken(0x4644BBcfd26a79A79254aF30ed8Ab80658a73B32);

    function run() external {
        // 从环境变量读取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 构造 payload - 完整的Wormhole Token Transfer格式
        bytes memory payload = abi.encodePacked(
            uint8(1),      // payloadID: Token Transfer
            uint256(1000000000000000),  // amount: 0.001 tokens (wei)
            bytes32(uint256(uint160(0x4644BBcfd26a79A79254aF30ed8Ab80658a73B32))),  // tokenAddress
            uint16(23),    // tokenChain: Arbitrum
            bytes32(uint256(uint160(0x00000000bb09009cDCD358d6c5CE6F56611577f1))),  // to: recipient address
            uint16(4),     // toChain: BSC
            uint256(0)     // fee: 0 (这是关键！之前是uint8(6)导致格式错误)
        );

        // 设置 gas price (必须在 startBroadcast 之前)
        vm.txGasPrice(0.1 gwei);
        
        // ✅ 只调用一次 startBroadcast
        vm.startBroadcast(deployerPrivateKey);
        
        // 直接调用,不需要 value
        uint64 sequence = fakeToken.sendMessageToWormhole(
            payload,
            2,
            15
        );
        
        console.log("Message sent with sequence:", sequence);
        
        vm.stopBroadcast();
    }
}