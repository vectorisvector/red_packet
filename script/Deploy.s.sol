// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/RedPacket.sol";

contract DeployScript is Script {
    function run() external {
        // 开始使用私钥签名
        vm.startBroadcast();

        // 部署合约
        RedPacket redPacket = new RedPacket();

        console2.log("RedPacket deployed at:", address(redPacket));

        vm.stopBroadcast();
    }
}
