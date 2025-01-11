// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/RedPacketImpl.sol";
import "../src/RedPacketProxy.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署实现合约
        RedPacketImpl implementation = new RedPacketImpl();

        // 2. 部署代理合约
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address)",
            msg.sender // 部署者作为合约 owner
        );
        RedPacketProxy proxy = new RedPacketProxy(
            address(implementation),
            initData
        );

        vm.stopBroadcast();

        console2.log("Implementation:", address(implementation));
        console2.log("Proxy:", address(proxy));
    }
}
