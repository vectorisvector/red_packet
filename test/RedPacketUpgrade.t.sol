// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/RedPacketImpl.sol";
import "../src/RedPacketProxy.sol";
import "../src/interfaces/IRedPacket.sol";

contract RedPacketV2 is RedPacketImpl {
    function getPacketCount() external view returns (uint256) {
        return allPacketIds.length;
    }
}

contract RedPacketUpgradeTest is Test {
    RedPacketImpl public implementation;
    RedPacketV2 public implementationV2;
    RedPacketProxy public proxy;
    IRedPacket public redPacket;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        // 部署实现合约
        implementation = new RedPacketImpl();
        implementationV2 = new RedPacketV2();

        // 部署代理合约
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address)",
            alice // alice 作为合约 owner
        );
        proxy = new RedPacketProxy(address(implementation), initData);

        redPacket = IRedPacket(address(proxy));
    }

    function testUpgrade() public {
        // 创建红包
        vm.startPrank(alice);
        vm.deal(alice, 1 ether);
        bytes32 packetId = redPacket.createETHPacket{value: 1 ether}(
            2,
            block.timestamp + 1 hours,
            true,
            "ipfs://example"
        );

        // 升级到V2
        RedPacketImpl(address(proxy)).upgradeToAndCall(
            address(implementationV2),
            ""
        );
        vm.stopPrank();

        // 验证新功能
        assertEq(RedPacketV2(address(proxy)).getPacketCount(), 1);

        // 验证旧功能
        vm.startPrank(bob);
        redPacket.claimPacket(packetId);
        vm.stopPrank();
    }

    function testUpgradeFail() public {
        // 非 owner 不能升级
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                bob
            )
        );
        RedPacketImpl(address(proxy)).upgradeToAndCall(
            address(implementationV2),
            ""
        );
        vm.stopPrank();
    }
}
