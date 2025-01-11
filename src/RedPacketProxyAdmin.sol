// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract RedPacketProxyAdmin is ProxyAdmin {
    event ProxyDeployed(address proxy, address implementation);

    // 构造函数, 设置初始所有者
    constructor(address initialOwner) ProxyAdmin(initialOwner) {}

    function deployProxy(
        address implementation, // 实现合约地址
        bytes memory initData // 初始化数据
    ) external onlyOwner returns (address) {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            implementation,
            address(this),
            initData
        );

        emit ProxyDeployed(address(proxy), implementation);
        return address(proxy);
    }
}
