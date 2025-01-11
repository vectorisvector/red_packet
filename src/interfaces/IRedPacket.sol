// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRedPacket {
    enum PacketType {
        ETH,
        ERC20,
        ERC721
    }

    struct PacketView {
        bytes32 packetId;
        address creator;
        uint256 totalAmount;
        uint256 remainingAmount;
        uint256 count;
        uint256 remaining;
        uint256 expireTime;
        bool isRandom;
        string coverURI;
        address token;
        PacketType packetType;
        uint256[] nftIds;
    }

    function initialize(address owner) external;

    function createETHPacket(
        uint256 count,
        uint256 expireTime,
        bool isRandom,
        string memory coverURI
    ) external payable returns (bytes32);

    function createERC20Packet(
        uint256 count,
        uint256 expireTime,
        bool isRandom,
        string memory coverURI,
        address token,
        uint256 amount
    ) external returns (bytes32);

    function createERC721Packet(
        uint256 count,
        uint256 expireTime,
        string memory coverURI,
        address token,
        uint256[] memory tokenIds
    ) external returns (bytes32);

    function claimPacket(
        bytes32 packetId
    ) external returns (bytes32, uint256, uint256);

    function refund(bytes32 packetId) external returns (bytes32, uint256);
}
