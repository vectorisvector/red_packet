#!/bin/bash

# 加载环境变量
source .env

# 运行部署脚本
forge script script/Deploy.s.sol:DeployScript \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --force \
    -vvvv
