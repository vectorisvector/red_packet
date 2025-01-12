#!/bin/bash

# 加载环境变量
source .env

forge script script/Upgrade.s.sol:UpgradeScript \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --force \
    -vvvv
