// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

interface IPORT3 {
    function bridgeIn(bytes memory encodedVm) external;
    function tokenContracts(uint16 chainId) external view returns (bytes32);
    function balanceOf(address account) external view returns (uint256);
    function isTransferCompleted(bytes32 hash) external view returns (bool);
}

interface IWormhole {
    struct VM {
        uint8 version;
        uint32 timestamp;
        uint32 nonce;
        uint16 emitterChainId;
        bytes32 emitterAddress;
        uint64 sequence;
        uint8 consistencyLevel;
        bytes payload;
        uint32 guardianSetIndex;
        bytes signatures;
        bytes32 hash;
    }
    
    function parseAndVerifyVM(bytes calldata encodedVM) external view returns (VM memory vm, bool valid, string memory reason);
}


contract UseBridgeInScript is Script {
    function run() external {
        // 先拿一下主网上的合约
        address port3Address = 0xb4357054c3dA8D46eD642383F03139aC7f090343;

        // 从环境变量读取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Using VAA on BSC ===");
        console.log("PORT3 Contract:", port3Address);
        console.log("Caller:", deployer);
        console.log("");

        // 获取VAA
        bytes memory vaa = getVAA();

        console.log("VAA Length:", vaa.length, "bytes");
        
        // 解析VAA payload
        (uint8 payloadID, uint256 amount, bytes32 tokenAddress, uint16 tokenChain, bytes32 toAddress, uint16 toChain) = parseTransferPayload(vaa);
        console.log("=== VAA Payload Details ===");
        console.log("Payload ID:", payloadID);
        console.log("Amount:", amount);
        console.log("Token Address:");
        console.logBytes32(tokenAddress);
        console.log("Token Chain:", tokenChain);
        console.log("Recipient Address:");
        console.logBytes32(toAddress);
        console.log("Recipient Chain:", toChain);
        console.log("");

        // 检查当前注册的 emitter
        IPORT3 port3 = IPORT3(port3Address);
        bytes32 currentEmitter = port3.tokenContracts(23);
        console.log("Current registered emitter for Arbitrum (23):");
        console.logBytes32(currentEmitter);
        console.log("");

        // 解析VAA获取更多信息
        bytes32 vaaHash = keccak256(vaa);
        console.log("VAA Hash:");
        console.logBytes32(vaaHash);
        
        // 检查这个VAA是否已经被使用过
        try port3.isTransferCompleted(vaaHash) returns (bool completed) {
            console.log("Transfer already completed:", completed);
            if (completed) {
                console.log("WARNING: This VAA has already been used!");
                return;
            }
        } catch {
            console.log("Could not check if transfer is completed (method may not exist)");
        }
        console.log("");

        // 检查余额前
        uint256 balanceBefore = port3.balanceOf(deployer);
        console.log("Balance before:", balanceBefore);
        console.log("");
        
        // 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 传入VAA
        try port3.bridgeIn(vaa) {
            console.log("bridgeIn succeeded!");
        } catch Error(string memory reason) {
            console.log("bridgeIn failed:");
            console.log("Reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("bridgeIn failed with low-level error:");
            console.logBytes(lowLevelData);
        }

        
        vm.stopBroadcast();
        
        // 检查余额后
        uint256 balanceAfter = port3.balanceOf(deployer);
        console.log("Balance after:", balanceAfter);
        
        if (balanceAfter > balanceBefore) {
            console.log("Tokens minted:", balanceAfter - balanceBefore);
        }
    }


    function getVAA() internal pure returns (bytes memory) {
        // ✅ VAA from Wormholescan
        // Sequence: 8, Guardian Set: 4, Signatures: 13/19
        // Arbitrum (23) → BSC (4), Amount: 0.001 tokens
        // Timestamp: 2025-11-24T10:25:25Z
        return hex"01000000040d00dbcc365b40f2f4434b0d4d696ef6a63809f4c2ea541bef4193fa529c578d968d4684fb8ea97f7ad77d292ea90c161bcc39e3461c0d1dd172d8f86cf71a760ae1010259854e3de74e3337b3cbea254ded3d18cf955461406661ddcb33e7881b5450a828ba654152b66275637d8fa3625688159aaaaac7d9aa0186ed2cbee4ca6c64740003908b7e876d8faad0ab9e54e47af8e122b33dc8c9036893cca8fbc1c9fd51fef91fcc1f14deca8f87d6285778f1c81d9f3617411a0a93010b667ba2ab69c3bb9d00042367a0c759707a13d1928bc9e5057c928d14573d18902cd8e39d0b468f029f1b33dbbb76d05b57a4cdf3bc4c311e6b5a65629764a14679f8cc8f37504115f92d0005c94f1587e41ef7c9e15a4f0de453d1319774ab8748f1550d53b4dc4216804222498f762bd577ba0c742ce8f73ff13f3c2a1f24c5c384488fd4c8a63106b9934600063131e2ff5a922aeb94f11a8f4763074198f56c45f123fdbc0fa1106d92b6f181745fb7b389fe439e3b1b65c8f53eafb126622f2be28fec2fa637edf5afcbf4d20107dcf885bc2b8de61d6c84f9b695bfb6bd4c169653ef3e02b6b80bba17d0054e7414cdda031d7d083ee2953b7b988ebdc0ab9879c0ef88791446e2ae1840a0e54a010c9ad65068143decbaef34a4b42c3e8abac9811fc14f1c1c0fb71570489d5e0b045b95656f27fd6162786d79091a7b118b67fcee6de48180face393a09f5d06106010d9b5b36ae6bfb072e28e112975d142b16277bedacdd388fb7023132b316bd83037b3dd3b92a5e80fcebbe0e603917aa2f5a3a843bff17234270f0a274e7b8d729000ecd5e0c8d78a55bb696d2e079b1fe4a2c865cc34d61d3eafda73b8cbbc877d01b0abfc686daf4311ce05990546dbe338260f6fe6cb75991be5c1b512f46d9dc17000fc59eba20a72286cb9e8a816c04f854d597fab6171a167c08f5439658899d390e39c454effc89182d6bfd596199ffd5a018203a0e43b74244b516ab4a146f3cb300100e9edbd759d02c35b43abe73c3e8d335e135bbc8c566a8e2cfddce524bf4257e1c28ef04477efeed3f7e964085c682b7ad2a17d047709ff108706702fca66ba60011340a237fc080d50f68fc7e558415736396d50cb21b95990f0092d6a3626baa7d04d8a97ee2daedee14089ed4e48bafca730f0c5a7617eeec22b74bc11270dd6200692432950000000200170000000000000000000000004644bbcfd26a79a79254af30ed8ab80658a73b3200000000000000080f0100000000000000000000000000000000000000000000000000038d7ea4c680000000000000000000000000004644bbcfd26a79a79254af30ed8ab80658a73b32001700000000000000000000000000000000bb09009cdcd358d6c5ce6f56611577f100040000000000000000000000000000000000000000000000000000000000000000";
    }
    
    // 解析Token Transfer payload
    function parseTransferPayload(bytes memory vaa) internal pure returns (
        uint8 payloadID,
        uint256 amount,
        bytes32 tokenAddress,
        uint16 tokenChain,
        bytes32 to,
        uint16 toChain
    ) {
        // VAA结构: 签名 + body
        // 我们需要跳过签名部分，找到payload
        
        // 简单解析：找到payload部分（在固定位置之后）
        // 这里我们直接从已知的位置读取
        uint256 offset = vaa.length - 102; // payload在VAA末尾
        
        assembly {
            let payload := add(vaa, add(32, offset))
            payloadID := mload(add(payload, 1))
            amount := mload(add(payload, 33))
            tokenAddress := mload(add(payload, 65))
            tokenChain := mload(add(payload, 67))
            to := mload(add(payload, 99))
            toChain := mload(add(payload, 101))
        }
    }

}