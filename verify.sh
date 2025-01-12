#!/bin/bash

# 加载环境变量
source .env

# 验证实现合约
forge verify-contract \
    --rpc-url "https://explorer.monad-devnet.devnet101.com/api/eth-rpc" \
    --verifier blockscout \
    --verifier-url "https://explorer.monad-devnet.devnet101.com/api/" \
    $IMPLEMENTATION_ADDRESS \
    src/RedPacketImpl.sol:RedPacketImpl 

# 生成构造函数参数
INIT_DATA=$(cast calldata "initialize(address)" $ADMIN_ADDRESS)

# 验证代理合约
forge verify-contract \
    --rpc-url "https://explorer.monad-devnet.devnet101.com/api/eth-rpc" \
    --verifier blockscout \
    --verifier-url "https://explorer.monad-devnet.devnet101.com/api/" \
    $PROXY_ADDRESS \
    src/RedPacketProxy.sol:RedPacketProxy \
    --constructor-args $(cast abi-encode "constructor(address,bytes)" $IMPLEMENTATION_ADDRESS $INIT_DATA) 