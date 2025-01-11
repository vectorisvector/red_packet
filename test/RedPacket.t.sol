// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {RedPacket} from "../src/RedPacket.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockERC721} from "./mocks/MockERC721.sol";

contract RedPacketTest is Test {
    RedPacket public redPacket;
    MockERC20 public mockERC20;
    MockERC721 public mockERC721;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    function setUp() public {
        redPacket = new RedPacket();
        mockERC20 = new MockERC20();
        mockERC721 = new MockERC721();

        // 给测试账户一些 ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 1 ether);
        vm.deal(carol, 1 ether);

        // 给 alice 一些 ERC20 代币
        mockERC20.transfer(alice, 1000 * 10 ** 18);

        // 给 alice 铸造一些 NFT
        vm.startPrank(alice);
        for (uint i = 0; i < 10; i++) {
            mockERC721.mint(alice);
        }
        vm.stopPrank();
    }

    // ============ ETH 红包测试 ============
    function testCreateAndClaimETHPacket() public {
        // 创建 ETH 红包
        vm.startPrank(alice);
        uint256 amount = 1 ether;
        bytes32 packetId = redPacket.createETHPacket{value: amount}(
            2, // count
            block.timestamp + 1 hours,
            false, // 非随机
            "ipfs://example"
        );
        vm.stopPrank();

        // Bob 领取
        uint256 bobBalanceBefore = bob.balance;
        vm.prank(bob);
        redPacket.claimPacket(packetId);
        uint256 bobBalanceAfter = bob.balance;
        assertEq(bobBalanceAfter - bobBalanceBefore, 0.5 ether);

        // Carol 领取
        uint256 carolBalanceBefore = carol.balance;
        vm.prank(carol);
        redPacket.claimPacket(packetId);
        uint256 carolBalanceAfter = carol.balance;
        assertEq(carolBalanceAfter - carolBalanceBefore, 0.5 ether);
    }

    function testRandomETHPacket() public {
        // 创建随机 ETH 红包
        vm.startPrank(alice);
        uint256 amount = 1 ether;
        bytes32 packetId = redPacket.createETHPacket{value: amount}(
            3,
            block.timestamp + 1 hours,
            true, // 随机
            "ipfs://example"
        );
        vm.stopPrank();

        // Alice 领取 - 改变区块和时间
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);
        uint256 aliceBalanceBefore = alice.balance;
        vm.prank(alice);
        redPacket.claimPacket(packetId);
        uint256 aliceClaimed = alice.balance - aliceBalanceBefore;
        console2.log("Alice claimed:", aliceClaimed);
        console2.log(
            "Alice claimed percentage:",
            (aliceClaimed * 100) / amount,
            "%"
        );

        // Bob 领取 - 改变区块和时间
        vm.roll(block.number + 2);
        vm.warp(block.timestamp + 3);
        uint256 bobBalanceBefore = bob.balance;
        vm.prank(bob);
        redPacket.claimPacket(packetId);
        uint256 bobClaimed = bob.balance - bobBalanceBefore;
        console2.log("Bob claimed:", bobClaimed);
        console2.log(
            "Bob claimed percentage:",
            (bobClaimed * 100) / amount,
            "%"
        );

        // Carol 领取 - 改变区块和时间
        vm.roll(block.number + 3);
        vm.warp(block.timestamp + 5);
        uint256 carolBalanceBefore = carol.balance;
        vm.prank(carol);
        redPacket.claimPacket(packetId);
        uint256 carolClaimed = carol.balance - carolBalanceBefore;
        console2.log("Carol claimed:", carolClaimed);
        console2.log(
            "Carol claimed percentage:",
            (carolClaimed * 100) / amount,
            "%"
        );

        // 验证总和等于红包总额
        assertEq(aliceClaimed + bobClaimed + carolClaimed, amount);
    }

    // ============ ERC20 红包测试 ============
    function testCreateAndClaimERC20Packet() public {
        uint256 amount = 100 * 10 ** 18;

        // 授权并创建 ERC20 红包
        vm.startPrank(alice);
        mockERC20.approve(address(redPacket), amount);
        bytes32 packetId = redPacket.createERC20Packet(
            2,
            block.timestamp + 1 hours,
            false,
            "ipfs://example",
            address(mockERC20),
            amount
        );
        vm.stopPrank();

        // Bob 领取
        uint256 bobBalanceBefore = mockERC20.balanceOf(bob);
        vm.prank(bob);
        redPacket.claimPacket(packetId);
        uint256 bobBalanceAfter = mockERC20.balanceOf(bob);
        assertEq(bobBalanceAfter - bobBalanceBefore, amount / 2);

        // Carol 领取
        uint256 carolBalanceBefore = mockERC20.balanceOf(carol);
        vm.prank(carol);
        redPacket.claimPacket(packetId);
        uint256 carolBalanceAfter = mockERC20.balanceOf(carol);
        assertEq(carolBalanceAfter - carolBalanceBefore, amount / 2);
    }

    function testRandomERC20Packet() public {
        uint256 amount = 100 * 10 ** 18;

        // 授权并创建 ERC20 红包
        vm.startPrank(alice);
        mockERC20.approve(address(redPacket), amount);
        bytes32 packetId = redPacket.createERC20Packet(
            2,
            block.timestamp + 1 hours,
            true, // 随机模式
            "ipfs://example",
            address(mockERC20),
            amount
        );
        vm.stopPrank();

        // Bob 领取
        uint256 bobBalanceBefore = mockERC20.balanceOf(bob);
        vm.prank(bob);
        redPacket.claimPacket(packetId);
        uint256 bobClaimed = mockERC20.balanceOf(bob) - bobBalanceBefore;
        console2.log("Bob claimed ERC20:", bobClaimed);
        console2.log(
            "Bob claimed percentage:",
            (bobClaimed * 100) / amount,
            "%"
        );

        // Carol 领取
        uint256 carolBalanceBefore = mockERC20.balanceOf(carol);
        vm.prank(carol);
        redPacket.claimPacket(packetId);
        uint256 carolClaimed = mockERC20.balanceOf(carol) - carolBalanceBefore;
        console2.log("Carol claimed ERC20:", carolClaimed);
        console2.log(
            "Carol claimed percentage:",
            (carolClaimed * 100) / amount,
            "%"
        );

        // 验证
        assertEq(
            bobClaimed + carolClaimed,
            amount,
            "Total claimed should equal initial amount"
        );
        assertTrue(
            bobClaimed >= (amount * 10) / 100,
            "Bob should receive at least 10%"
        );
        assertTrue(
            carolClaimed >= (amount * 10) / 100,
            "Carol should receive at least 10%"
        );
    }

    // ============ ERC721 红包测试 ============
    function testCreateAndClaimERC721Packet() public {
        // 先铸造一些新的 NFT 给 alice
        vm.startPrank(alice);
        uint256[] memory tokenIds = new uint256[](3);
        for (uint i = 0; i < 3; i++) {
            tokenIds[i] = mockERC721.mint(alice);
        }

        // 授权并创建 NFT 红包
        mockERC721.setApprovalForAll(address(redPacket), true);
        bytes32 packetId = redPacket.createERC721Packet(
            2, // 红包数量
            block.timestamp + 1 hours,
            "ipfs://example",
            address(mockERC721),
            tokenIds
        );

        // 验证 NFT 已经转移到合约
        for (uint i = 0; i < 3; i++) {
            address currentOwner = mockERC721.ownerOf(tokenIds[i]);
            assertEq(
                currentOwner,
                address(redPacket),
                "NFT should be transferred to contract"
            );
        }
        vm.stopPrank();

        // Bob 领取
        vm.prank(bob);
        redPacket.claimPacket(packetId);

        // 验证 Bob 获得了一个 NFT
        uint256 bobNFTCount = 0;
        for (uint i = 0; i < 3; i++) {
            if (mockERC721.ownerOf(tokenIds[i]) == bob) {
                bobNFTCount++;
            }
        }
        assertEq(bobNFTCount, 1, "Bob should own exactly 1 NFT");

        // Carol 领取
        vm.prank(carol);
        redPacket.claimPacket(packetId);

        // 验证 Carol 获得了一个 NFT
        uint256 carolNFTCount = 0;
        for (uint i = 0; i < 3; i++) {
            if (mockERC721.ownerOf(tokenIds[i]) == carol) {
                carolNFTCount++;
            }
        }
        assertEq(carolNFTCount, 1, "Carol should own exactly 1 NFT");

        // 验证还有一个 NFT 在合约中
        uint256 contractNFTCount = 0;
        for (uint i = 0; i < 3; i++) {
            if (mockERC721.ownerOf(tokenIds[i]) == address(redPacket)) {
                contractNFTCount++;
            }
        }
        assertEq(contractNFTCount, 1, "Contract should own exactly 1 NFT");
    }

    // ============ 通用功能测试 ============
    function testCannotClaimTwice() public {
        vm.startPrank(alice);
        bytes32 packetId = redPacket.createETHPacket{value: 1 ether}(
            2,
            block.timestamp + 1 hours,
            false,
            "ipfs://example"
        );
        vm.stopPrank();

        vm.prank(bob);
        redPacket.claimPacket(packetId);

        vm.expectRevert("Already claimed");
        vm.prank(bob);
        redPacket.claimPacket(packetId);
    }

    function testExpiredPacket() public {
        vm.startPrank(alice);
        bytes32 packetId = redPacket.createETHPacket{value: 1 ether}(
            2,
            block.timestamp + 1 hours,
            false,
            "ipfs://example"
        );
        vm.stopPrank();

        // 时间快进到过期
        vm.warp(block.timestamp + 2 hours);

        vm.expectRevert("Packet expired");
        vm.prank(bob);
        redPacket.claimPacket(packetId);
    }

    function testRefund() public {
        // 创建红包
        vm.startPrank(alice);
        uint256 amount = 1 ether;
        bytes32 packetId = redPacket.createETHPacket{value: amount}(
            2,
            block.timestamp + 1 hours,
            false,
            "ipfs://example"
        );

        // 尝试提前退款
        vm.expectRevert("Not expired");
        redPacket.refund(packetId);

        // 时间快进到过期
        vm.warp(block.timestamp + 2 hours);

        uint256 balanceBefore = alice.balance;
        redPacket.refund(packetId);
        uint256 balanceAfter = alice.balance;

        // 验证退款金额
        assertEq(balanceAfter - balanceBefore, amount);
        vm.stopPrank();
    }

    function testRefundETH() public {
        // 创建 ETH 红包
        vm.startPrank(alice);
        uint256 amount = 1 ether;
        bytes32 packetId = redPacket.createETHPacket{value: amount}(
            2,
            block.timestamp + 1 hours,
            false,
            "ipfs://example"
        );

        // Bob 领取一个
        vm.stopPrank();
        vm.prank(bob);
        redPacket.claimPacket(packetId);

        // 快进时间
        vm.warp(block.timestamp + 2 hours);

        // Alice 退款
        vm.startPrank(alice);
        uint256 balanceBefore = alice.balance;
        redPacket.refund(packetId);
        uint256 refunded = alice.balance - balanceBefore;

        // 验证退款金额（应该是剩余的一半）
        assertEq(refunded, amount / 2, "Should refund remaining amount");
        vm.stopPrank();
    }

    function testRefundERC20() public {
        uint256 amount = 100 * 10 ** 18;

        // 创建 ERC20 红包
        vm.startPrank(alice);
        mockERC20.approve(address(redPacket), amount);
        bytes32 packetId = redPacket.createERC20Packet(
            2,
            block.timestamp + 1 hours,
            false,
            "ipfs://example",
            address(mockERC20),
            amount
        );

        // Bob 领取一个
        vm.stopPrank();
        vm.prank(bob);
        redPacket.claimPacket(packetId);
        uint256 bobAmount = mockERC20.balanceOf(bob);
        console2.log("Bob claimed:", bobAmount);

        // 快进时间
        vm.warp(block.timestamp + 2 hours);

        // Alice 退款
        vm.startPrank(alice);
        uint256 balanceBefore = mockERC20.balanceOf(alice);
        redPacket.refund(packetId);
        uint256 refunded = mockERC20.balanceOf(alice) - balanceBefore;
        console2.log("Refunded amount:", refunded);

        // 验证退款金额
        assertEq(
            bobAmount + refunded,
            amount,
            "Total distributed should equal initial amount"
        );
        vm.stopPrank();
    }

    function testRefundRandomERC20() public {
        uint256 amount = 100 * 10 ** 18;

        // 创建随机 ERC20 红包
        vm.startPrank(alice);
        mockERC20.approve(address(redPacket), amount);
        bytes32 packetId = redPacket.createERC20Packet(
            2,
            block.timestamp + 1 hours,
            true,
            "ipfs://example",
            address(mockERC20),
            amount
        );

        // Bob 领取一个
        vm.stopPrank();
        vm.prank(bob);
        redPacket.claimPacket(packetId);
        uint256 bobAmount = mockERC20.balanceOf(bob);
        console2.log("Bob claimed (random):", bobAmount);

        // 快进时间
        vm.warp(block.timestamp + 2 hours);

        // Alice 退款
        vm.startPrank(alice);
        uint256 balanceBefore = mockERC20.balanceOf(alice);
        redPacket.refund(packetId);
        uint256 refunded = mockERC20.balanceOf(alice) - balanceBefore;
        console2.log("Refunded amount (random):", refunded);

        // 验证退款金额
        assertEq(
            bobAmount + refunded,
            amount,
            "Total distributed should equal initial amount"
        );
        assertTrue(
            bobAmount >= (amount * 10) / 100,
            "Bob should receive at least 10%"
        );
        vm.stopPrank();
    }

    function testRefundERC721() public {
        // 铸造 NFTs
        vm.startPrank(alice);
        uint256[] memory tokenIds = new uint256[](3);
        for (uint i = 0; i < 3; i++) {
            tokenIds[i] = mockERC721.mint(alice);
        }

        // 创建 NFT 红包
        mockERC721.setApprovalForAll(address(redPacket), true);
        bytes32 packetId = redPacket.createERC721Packet(
            2,
            block.timestamp + 1 hours,
            "ipfs://example",
            address(mockERC721),
            tokenIds
        );

        // Bob 领取一个
        vm.stopPrank();
        vm.prank(bob);
        redPacket.claimPacket(packetId);

        // 快进时间
        vm.warp(block.timestamp + 2 hours);

        // 记录退款前的状态
        uint256 aliceNFTsBefore = 0;
        for (uint i = 0; i < 3; i++) {
            if (mockERC721.ownerOf(tokenIds[i]) == alice) {
                aliceNFTsBefore++;
            }
        }

        // Alice 退款
        vm.startPrank(alice);
        redPacket.refund(packetId);

        // 验证退款后的状态
        uint256 aliceNFTsAfter = 0;
        for (uint i = 0; i < 3; i++) {
            if (mockERC721.ownerOf(tokenIds[i]) == alice) {
                aliceNFTsAfter++;
            }
        }

        // Alice 应该收到 2 个 NFT（1 个未被领取 + 1 个多余的）
        assertEq(
            aliceNFTsAfter - aliceNFTsBefore,
            2,
            "Should refund remaining NFTs"
        );
        vm.stopPrank();
    }

    function testRefundFailures() public {
        // 创建 ETH 红包
        vm.startPrank(alice);
        bytes32 packetId = redPacket.createETHPacket{value: 1 ether}(
            2,
            block.timestamp + 1 hours,
            false,
            "ipfs://example"
        );
        vm.stopPrank();

        // 非创建者不能退款
        vm.prank(bob);
        vm.expectRevert("Not creator");
        redPacket.refund(packetId);

        // 未过期不能退款
        vm.prank(alice);
        vm.expectRevert("Not expired");
        redPacket.refund(packetId);

        // 领取完后不能退款
        vm.prank(bob);
        redPacket.claimPacket(packetId);
        vm.prank(carol);
        redPacket.claimPacket(packetId);

        vm.warp(block.timestamp + 2 hours);
        vm.prank(alice);
        vm.expectRevert("No remaining amount");
        redPacket.refund(packetId);
    }

    function testPacketInfo() public {
        // 创建 ETH 红包
        vm.startPrank(alice);
        uint256 amount = 1 ether;
        bytes32 packetId = redPacket.createETHPacket{value: amount}(
            3, // count
            block.timestamp + 1 hours,
            true, // 随机
            "ipfs://example"
        );
        vm.stopPrank();

        // 获取红包信息
        RedPacket.PacketView memory info = redPacket.getPacketInfo(packetId);

        // 验证红包信息
        assertEq(info.packetId, packetId);
        assertEq(info.creator, alice);
        assertEq(info.totalAmount, amount);
        assertEq(info.remainingAmount, amount);
        assertEq(info.count, 3);
        assertEq(info.remaining, 3);
        assertEq(info.expireTime, block.timestamp + 1 hours);
        assertTrue(info.isRandom);
        assertEq(info.coverURI, "ipfs://example");
        assertEq(info.token, address(0));
        assertEq(uint8(info.packetType), uint8(RedPacket.PacketType.ETH));
        assertEq(info.nftIds.length, 0);

        // Bob 领取红包
        vm.prank(bob);
        redPacket.claimPacket(packetId);

        // 再次获取红包信息
        info = redPacket.getPacketInfo(packetId);

        // 验证更新后的信息
        assertEq(info.remaining, 2);
        assertTrue(info.remainingAmount < amount);
    }

    function testUserPackets() public {
        // Alice 创建多个红包
        vm.startPrank(alice);
        bytes32[] memory packetIds = new bytes32[](3);

        for (uint i = 0; i < 3; i++) {
            packetIds[i] = redPacket.createETHPacket{value: 1 ether}(
                2, // 每个红包2份
                block.timestamp + 1 hours,
                true,
                "ipfs://example"
            );
        }
        vm.stopPrank();

        // 测试分页获取
        (bytes32[] memory result, uint256 total) = redPacket
            .getUserCreatedPackets(alice, 0, 2);
        assertEq(result.length, 2);
        assertEq(total, 3);
        assertEq(result[0], packetIds[0]);
        assertEq(result[1], packetIds[1]);

        // 测试第二页
        (result, total) = redPacket.getUserCreatedPackets(alice, 2, 2);
        assertEq(result.length, 1);
        assertEq(total, 3);
        assertEq(result[0], packetIds[2]);

        // Bob 和 Carol 各领取一个红包
        vm.prank(bob);
        redPacket.claimPacket(packetIds[0]);

        vm.prank(carol);
        redPacket.claimPacket(packetIds[1]);

        // 测试 Bob 的领取记录
        (result, total) = redPacket.getUserClaimedPackets(bob, 0, 10);
        assertEq(result.length, 1);
        assertEq(total, 1);
        assertEq(result[0], packetIds[0]);
    }

    function testPacketRange() public {
        // 测试设置无效范围
        vm.expectRevert("Invalid min percentage");
        redPacket.setPacketRange(0, 150);

        vm.expectRevert("Invalid min percentage");
        redPacket.setPacketRange(101, 150);

        vm.expectRevert("Invalid max percentage");
        redPacket.setPacketRange(50, 99);

        vm.expectRevert("Invalid max percentage");
        redPacket.setPacketRange(50, 201);

        // 设置有效范围
        redPacket.setPacketRange(50, 150);
        assertEq(redPacket.minPercentage(), 50);
        assertEq(redPacket.maxPercentage(), 150);

        // 创建随机红包并验证金额范围
        vm.startPrank(alice);
        uint256 amount = 100 ether;
        bytes32 packetId = redPacket.createETHPacket{value: amount}(
            2,
            block.timestamp + 1 hours,
            true,
            "ipfs://example"
        );
        vm.stopPrank();

        // Bob 领取
        uint256 bobBalanceBefore = bob.balance;
        vm.prank(bob);
        redPacket.claimPacket(packetId);
        uint256 bobClaimed = bob.balance - bobBalanceBefore;

        // 验证金额在设定范围内
        uint256 avgAmount = amount / 2;
        assertTrue(bobClaimed >= (avgAmount * 50) / 100, "Amount below min");
        assertTrue(bobClaimed <= (avgAmount * 150) / 100, "Amount above max");
    }

    function testGetPacketsInfo() public {
        // Alice 创建3个红包，确保每个红包的ID不同
        vm.startPrank(alice);
        bytes32[] memory packetIds = new bytes32[](3);

        // 通过改变时间戳来确保每个红包ID不同
        for (uint i = 0; i < 3; i++) {
            vm.warp(block.timestamp + i); // 每次增加时间戳
            packetIds[i] = redPacket.createETHPacket{value: 1 ether}(
                2,
                block.timestamp + 1 hours,
                true,
                "ipfs://example"
            );
        }
        vm.stopPrank();

        // 验证每个红包ID都不相同
        assertTrue(
            packetIds[0] != packetIds[1],
            "Packet IDs should be different"
        );
        assertTrue(
            packetIds[1] != packetIds[2],
            "Packet IDs should be different"
        );

        // 批量查询红包信息
        RedPacket.PacketView[] memory packets = redPacket.getPacketsInfo(
            packetIds
        );

        // 验证返回的红包数量
        assertEq(packets.length, 3);

        // 验证每个红包的信息
        for (uint i = 0; i < packets.length; i++) {
            assertEq(packets[i].packetId, packetIds[i]);
            assertEq(packets[i].creator, alice);
            assertEq(packets[i].totalAmount, 1 ether);
            assertEq(packets[i].remainingAmount, 1 ether);
            assertEq(packets[i].count, 2); // 2人红包
            assertEq(packets[i].remaining, 2); // 还剩2份
            assertTrue(packets[i].isRandom);
            assertEq(packets[i].coverURI, "ipfs://example");
            assertEq(packets[i].token, address(0));
            assertEq(
                uint8(packets[i].packetType),
                uint8(RedPacket.PacketType.ETH)
            );
        }

        // 测试超过10个红包的限制
        bytes32[] memory tooManyIds = new bytes32[](11);
        vm.expectRevert("Max 10 packets per query");
        redPacket.getPacketsInfo(tooManyIds);

        // Bob领取一个红包后再查询
        vm.prank(bob);
        redPacket.claimPacket(packetIds[0]);

        packets = redPacket.getPacketsInfo(packetIds);

        // 打印所有红包状态
        for (uint i = 0; i < packets.length; i++) {
            RedPacket.PacketView memory packet = packets[i];
            console2.log("Packet[", i, "] ID:", uint256(packet.packetId));
            console2.log(
                "  Remaining:",
                packet.remaining,
                "Amount:",
                packet.remainingAmount
            );
        }

        // 验证第一个红包（被领取）
        assertEq(
            packets[0].remaining,
            1,
            "First packet should have 1 remaining"
        );
        assertTrue(
            packets[0].remainingAmount < 1 ether,
            "First packet should have less than 1 ether"
        );

        // 验证第二个红包（未被领取）
        assertEq(
            packets[1].remaining,
            2,
            "Second packet should have 2 remaining"
        );
        assertEq(
            packets[1].remainingAmount,
            1 ether,
            "Second packet should have 1 ether"
        );
    }
}
