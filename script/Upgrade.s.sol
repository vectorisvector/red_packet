// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {RedPacketImpl} from "../src/RedPacketImpl.sol";
import {RedPacketProxy} from "../src/RedPacketProxy.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 从 env 读取代理合约地址
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        // 1. 部署新的实现合约
        RedPacketImpl newImplementation = new RedPacketImpl();

        // 2. 升级代理合约指向新的实现
        RedPacketImpl proxy = RedPacketImpl(payable(proxyAddress));
        proxy.upgradeToAndCall(address(newImplementation), "");

        vm.stopBroadcast();
    }
}
