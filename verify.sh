#!/bin/bash

# 加载环境变量
source .env

# 验证实现合约
forge verify-contract \
    --rpc-url "https://testnet-rpc.monad.xyz" \
    --verifier sourcify \
    --verifier-url "https://sourcify-api-monad.blockvision.org" \
    $IMPLEMENTATION_ADDRESS \
    src/RedPacketImpl.sol:RedPacketImpl 

# 生成构造函数参数
INIT_DATA=$(cast calldata "initialize(address)" $ADMIN_ADDRESS)

# 验证代理合约
forge verify-contract \
    --rpc-url "https://testnet-rpc.monad.xyz" \
    --verifier sourcify \
    --verifier-url "https://sourcify-api-monad.blockvision.org" \
    $PROXY_ADDRESS \
    src/RedPacketProxy.sol:RedPacketProxy \
    --constructor-args $(cast abi-encode "constructor(address,bytes)" $IMPLEMENTATION_ADDRESS $INIT_DATA) 