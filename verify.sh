#!/bin/bash

# 合约地址
CONTRACT_ADDRESS="0x118a5F97bBf753ba56516592194B3c1Ae3701E81"

# 验证合约
forge verify-contract \
    --rpc-url "https://explorer.monad-devnet.devnet101.com/api/eth-rpc" \
    --verifier blockscout \
    --verifier-url "https://explorer.monad-devnet.devnet101.com/api/" \
    $CONTRACT_ADDRESS \
    src/RedPacket.sol:RedPacket 