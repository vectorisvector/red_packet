// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RedPacket is Ownable, IERC721Receiver {
    using SafeERC20 for IERC20;

    enum PacketType {
        ETH,
        ERC20,
        ERC721
    }

    struct Packet {
        bytes32 packetId; // 红包ID
        address creator; // 红包创建者
        uint256 totalAmount; // 红包总金额(ETH/ERC20)或 NFT 数量(ERC721)
        uint256 remainingAmount; // 剩余金额(ETH/ERC20)或 剩余 NFT 数量(ERC721)
        uint256 count; // 红包个数
        uint256 remaining; // 剩余红包个数
        uint256 expireTime; // 过期时间
        bool isRandom; // 是否随机金额(仅用于 ETH/ERC20)
        string coverURI; // 红包封面媒体链接
        address token; // 代币地址(ETH 为 address(0))
        PacketType packetType; // 红包类型
        // mapping(uint256 => uint256) nftIds; // ERC721 代币 ID 列表
        uint256[] nftIds; // ERC721 代币 ID 列表
        mapping(address => bool) claimed; // 记录已领取地址
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

    // 红包ID => 红包信息
    mapping(bytes32 => Packet) public packets;

    event PacketCreated(
        bytes32 indexed packetId,
        address indexed creator,
        uint256 totalAmount,
        uint256 count,
        uint256 expireTime,
        bool isRandom,
        string coverURI,
        address indexed token,
        PacketType packetType
    );

    event PacketClaimed(
        bytes32 indexed packetId,
        address indexed claimer,
        uint256 amount,
        uint256 tokenId
    );

    event PacketRefunded(
        bytes32 indexed packetId,
        address indexed creator,
        uint256 amount
    );

    event EmergencyWithdraw(address indexed token, uint256 amount);

    event EmergencyWithdrawNFT(address indexed token, uint256[] tokenIds);

    event PacketRangeUpdated(uint256 minPercentage, uint256 maxPercentage);

    // 相对平均值的最小比例
    uint256 public minPercentage = 50;
    // 相对平均值的最大比例
    uint256 public maxPercentage = 150;

    // 记录所有红包ID
    bytes32[] public allPacketIds;

    // 用户创建的红包ID映射
    mapping(address => bytes32[]) public userCreatedPackets;

    // 用户领取的红包ID映射
    mapping(address => bytes32[]) public userClaimedPackets;

    // 构造函数
    constructor() Ownable(msg.sender) {}

    // ---------- Setter ----------

    // 创建 ETH 红包
    function createETHPacket(
        uint256 count,
        uint256 expireTime,
        bool isRandom,
        string memory coverURI
    ) external payable returns (bytes32 id) {
        require(msg.value > 0, "Amount must be greater than 0");

        return
            _createPacket(
                count,
                expireTime,
                isRandom,
                coverURI,
                address(0),
                msg.value,
                new uint256[](0),
                PacketType.ETH
            );
    }

    // 创建 ERC20 红包
    function createERC20Packet(
        uint256 count,
        uint256 expireTime,
        bool isRandom,
        string memory coverURI,
        address token,
        uint256 amount
    ) external returns (bytes32 id) {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        return
            _createPacket(
                count,
                expireTime,
                isRandom,
                coverURI,
                token,
                amount,
                new uint256[](0),
                PacketType.ERC20
            );
    }

    // 创建 ERC721 红包
    function createERC721Packet(
        uint256 count,
        uint256 expireTime,
        string memory coverURI,
        address token,
        uint256[] memory tokenIds
    ) external returns (bytes32 id) {
        require(token != address(0), "Invalid token address");
        require(tokenIds.length > 0, "No token IDs provided");
        require(tokenIds.length >= count, "Not enough NFTs for packet count");

        // 转移所有 NFT 到合约
        for (uint i = 0; i < tokenIds.length; i++) {
            IERC721(token).safeTransferFrom(
                msg.sender,
                address(this),
                tokenIds[i]
            );
        }

        return
            _createPacket(
                count,
                expireTime,
                true,
                coverURI,
                token,
                tokenIds.length,
                tokenIds,
                PacketType.ERC721
            );
    }

    // 内部创建红包函数
    function _createPacket(
        uint256 count,
        uint256 expireTime,
        bool isRandom,
        string memory coverURI,
        address token,
        uint256 totalAmount,
        uint256[] memory tokenIds,
        PacketType packetType
    ) internal returns (bytes32 id) {
        // 封面URI不能为空
        require(bytes(coverURI).length > 0, "Cover URI cannot be empty");
        // 封面URI不能超过500个字符
        require(bytes(coverURI).length <= 500, "Cover URI too long");
        // 过期时间必须大于当前时间
        require(expireTime > block.timestamp, "Invalid expire time");
        // 红包个数必须大于0
        require(count > 0, "Count must be greater than 0");

        // 生成红包ID
        bytes32 packetId = keccak256(
            abi.encodePacked(
                msg.sender,
                block.timestamp,
                count,
                block.number,
                tx.gasprice,
                address(this),
                allPacketIds.length
            )
        );

        // 检查红包ID是否已存在
        require(
            packets[packetId].creator == address(0),
            "Packet ID already exists"
        );

        Packet storage packet = packets[packetId];
        packet.creator = msg.sender;
        packet.totalAmount = totalAmount;
        packet.remainingAmount = totalAmount; // 初始剩余金额等于总金额
        packet.count = count;
        packet.remaining = count;
        packet.expireTime = expireTime;
        packet.isRandom = isRandom;
        packet.coverURI = coverURI;
        packet.token = token;
        packet.packetType = packetType;

        // 记录红包ID
        allPacketIds.push(packetId);
        // 记录用户创建的红包ID
        userCreatedPackets[msg.sender].push(packetId);

        // 如果是 ERC721, 存储代币 ID
        if (packetType == PacketType.ERC721) {
            for (uint256 i = 0; i < tokenIds.length; i++) {
                packet.nftIds.push(tokenIds[i]);
            }
        }

        // 发送红包创建事件
        emit PacketCreated(
            packetId,
            msg.sender,
            totalAmount,
            count,
            expireTime,
            isRandom,
            coverURI,
            token,
            packetType
        );

        // 返回红包ID
        return packetId;
    }

    // 领取红包
    function claimPacket(
        bytes32 packetId
    ) external returns (bytes32 id, uint256 amount, uint256 tokenId) {
        Packet storage packet = packets[packetId];
        require(packet.creator != address(0), "Packet not found");
        require(block.timestamp <= packet.expireTime, "Packet expired");
        require(packet.remaining > 0, "No remaining packets");
        require(!packet.claimed[msg.sender], "Already claimed");

        uint256 _amount;
        uint256 _tokenId;

        if (packet.packetType == PacketType.ETH) {
            // 领取 ETH 红包
            _amount = _getClaimAmount(packet);
            (bool success, ) = msg.sender.call{value: _amount}("");
            require(success, "ETH transfer failed");
        } else if (packet.packetType == PacketType.ERC20) {
            // 领取 ERC20 红包
            _amount = _getClaimAmount(packet);
            bool success = IERC20(packet.token).transfer(msg.sender, _amount);
            require(success, "ERC20 transfer failed");
        } else {
            // 领取 ERC721 红包
            _tokenId = _claimNFT(packet);
        }

        packet.claimed[msg.sender] = true;
        packet.remaining--;
        if (packet.packetType != PacketType.ERC721) {
            packet.remainingAmount -= _amount;
        } else {
            packet.remainingAmount -= 1;
        }

        // 记录用户领取
        userClaimedPackets[msg.sender].push(packetId);

        // 发送领取红包事件
        emit PacketClaimed(packetId, msg.sender, _amount, _tokenId);

        return (packetId, _amount, _tokenId);
    }

    // 领取 NFT 红包
    function _claimNFT(
        Packet storage packet
    ) internal returns (uint256 tokenId) {
        // 获取随机 NFT 索引
        uint256 index = _getRandomNFTIndex(packet);
        tokenId = packet.nftIds[index];

        // 将最后一个 NFT 移到当前位置
        if (index != packet.nftIds.length - 1) {
            packet.nftIds[index] = packet.nftIds[packet.nftIds.length - 1];
        }
        packet.nftIds.pop();

        // 转移 NFT
        IERC721(packet.token).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );

        return tokenId;
    }

    // 获取随机 NFT 索引
    function _getRandomNFTIndex(
        Packet storage packet
    ) internal view returns (uint256 index) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    msg.sender,
                    packet.remaining
                )
            )
        );

        return seed % packet.nftIds.length;
    }

    // 获取领取金额
    function _getClaimAmount(
        Packet storage packet
    ) internal view returns (uint256 amount) {
        if (packet.remaining == 1) {
            return packet.remainingAmount;
        }

        if (!packet.isRandom) {
            return packet.remainingAmount / packet.remaining;
        }

        return _getRandomAmount(packet.remainingAmount, packet.remaining);
    }

    // 计算随机金额
    function _getRandomAmount(
        uint256 totalAmount, // 剩余金额
        uint256 remaining // 剩余红包个数
    ) internal view returns (uint256 amount) {
        // 如果是最后一个，返回剩余全部
        if (remaining == 1) {
            return totalAmount;
        }

        // 确保至少有 1 wei 可分配
        require(totalAmount >= remaining, "Insufficient amount");

        // 计算每个红包的平均值
        uint256 avgAmount = totalAmount / remaining;

        // 确保后续红包至少能分到 1 wei
        uint256 maxSafeAmount = totalAmount - (remaining - 1);

        // 计算本次红包的范围
        uint256 minAmount = (avgAmount * minPercentage) / 100;
        uint256 maxAmount = (avgAmount * maxPercentage) / 100;

        // 确保最小值至少为 1
        if (minAmount == 0) {
            minAmount = 1;
        }

        // 确保最大值不超过安全值
        if (maxAmount > maxSafeAmount) {
            maxAmount = maxSafeAmount;
        }

        // 确保最大值大于最小值
        if (maxAmount <= minAmount) {
            return minAmount;
        }

        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    msg.sender,
                    remaining,
                    tx.gasprice,
                    blockhash(block.number - 1)
                )
            )
        );

        return minAmount + (seed % (maxAmount - minAmount + 1));
    }

    // 退款函数
    function refund(
        bytes32 packetId
    ) external returns (bytes32 id, uint256 amount) {
        Packet storage packet = packets[packetId];
        require(packet.creator == msg.sender, "Not creator");
        require(block.timestamp > packet.expireTime, "Not expired");
        require(packet.remaining > 0, "No remaining amount");

        uint256 remainingAmount;

        // 如果是 ERC721, 退还所有未领取的 NFT
        if (packet.packetType == PacketType.ERC721) {
            remainingAmount = packet.nftIds.length;
            // 退还所有未领取的 NFT
            for (uint i = 0; i < packet.nftIds.length; i++) {
                IERC721(packet.token).safeTransferFrom(
                    address(this),
                    msg.sender,
                    packet.nftIds[i]
                );
            }
        } else {
            // ETH 和 ERC20 的退款逻辑
            remainingAmount = packet.remainingAmount;
            // 先清零, 防止重入
            packet.remainingAmount = 0;
            packet.remaining = 0;

            if (packet.packetType == PacketType.ETH) {
                (bool success, ) = msg.sender.call{value: remainingAmount}("");
                require(success, "ETH transfer failed");
            } else {
                bool success = IERC20(packet.token).transfer(
                    msg.sender,
                    remainingAmount
                );
                require(success, "ERC20 transfer failed");
            }
        }

        // 发送退款事件
        emit PacketRefunded(packetId, msg.sender, remainingAmount);

        return (packetId, remainingAmount);
    }

    // 紧急取回 ETH
    function emergencyWithdrawETH()
        external
        onlyOwner
        returns (address tokenAddress, uint256 amount)
    {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "ETH transfer failed");

        // 发送紧急取回事件
        emit EmergencyWithdraw(address(0), balance);

        return (address(0), balance);
    }

    // 紧急取回 ERC20
    function emergencyWithdrawERC20(
        address token
    ) external onlyOwner returns (address tokenAddress, uint256 amount) {
        require(token != address(0), "Invalid token");
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");

        // 这里不再使用 SafeERC20, 而是直接调用 transfer
        bool success = IERC20(token).transfer(owner(), balance);
        require(success, "ERC20 transfer failed");

        // 发送紧急取回事件
        emit EmergencyWithdraw(token, balance);

        return (token, balance);
    }

    // 紧急取回 ERC721
    function emergencyWithdrawERC721(
        address token,
        uint256[] memory tokenIds
    ) external onlyOwner returns (address tokenAddress, uint256[] memory ids) {
        require(token != address(0), "Invalid token");
        require(tokenIds.length > 0, "No tokens to withdraw");

        for (uint i = 0; i < tokenIds.length; i++) {
            IERC721(token).safeTransferFrom(
                address(this),
                owner(),
                tokenIds[i]
            );
        }

        // 发送紧急取回事件
        emit EmergencyWithdrawNFT(token, tokenIds);

        return (token, tokenIds);
    }

    // 设置红包金额范围
    function setPacketRange(
        uint256 _minPercentage,
        uint256 _maxPercentage
    )
        external
        onlyOwner
        returns (uint256 newMinPercentage, uint256 newMaxPercentage)
    {
        // 最小值必须大于10且小于100
        require(
            _minPercentage > 10 && _minPercentage < 100,
            "Invalid min percentage"
        );
        // 最大值必须大于100且小于200
        require(
            _maxPercentage > 100 && _maxPercentage < 200,
            "Invalid max percentage"
        );
        // 确保最大值大于最小值
        require(_maxPercentage > _minPercentage, "Invalid range");

        minPercentage = _minPercentage;
        maxPercentage = _maxPercentage;

        // 发送红包范围更新事件
        emit PacketRangeUpdated(_minPercentage, _maxPercentage);

        return (_minPercentage, _maxPercentage);
    }

    // 实现 IERC721Receiver 接口
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // ---------- Getter ----------

    // 获取红包信息
    function getPacketInfo(
        bytes32 packetId
    ) external view returns (PacketView memory packetInfo) {
        Packet storage packet = packets[packetId];
        require(packet.creator != address(0), "Packet not exists");

        return
            PacketView(
                packetId,
                packet.creator,
                packet.totalAmount,
                packet.remainingAmount,
                packet.count,
                packet.remaining,
                packet.expireTime,
                packet.isRandom,
                packet.coverURI,
                packet.token,
                packet.packetType,
                packet.nftIds
            );
    }

    // 获取红包总数
    function getTotalPackets() external view returns (uint256 total) {
        return allPacketIds.length;
    }

    // 获取用户创建的红包数量
    function getUserCreatedPacketsCount(
        address user
    ) external view returns (uint256 total) {
        return userCreatedPackets[user].length;
    }

    // 获取用户领取的红包数量
    function getUserClaimedPacketsCount(
        address user
    ) external view returns (uint256 total) {
        return userClaimedPackets[user].length;
    }

    // 分页获取用户创建的红包列表
    function getUserCreatedPackets(
        address user,
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory packetIds, uint256 total) {
        require(limit <= 10, "Max 10 packets per query");

        bytes32[] storage userPackets = userCreatedPackets[user];
        uint256 end = offset + limit;
        if (end > userPackets.length) {
            end = userPackets.length;
        }
        if (offset >= end) {
            return (new bytes32[](0), userPackets.length);
        }

        bytes32[] memory result = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = userPackets[i];
        }

        return (result, userCreatedPackets[user].length);
    }

    // 分页获取用户领取的红包列表
    function getUserClaimedPackets(
        address user,
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory packetIds, uint256 total) {
        require(limit <= 10, "Max 10 packets per query");

        bytes32[] storage userPackets = userClaimedPackets[user];
        uint256 end = offset + limit;
        if (end > userPackets.length) {
            end = userPackets.length;
        }
        if (offset >= end) {
            return (new bytes32[](0), userPackets.length);
        }

        bytes32[] memory result = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = userPackets[i];
        }
        return (result, userClaimedPackets[user].length);
    }

    // 批量查询红包信息，限制每次最多10个
    function getPacketsInfo(
        bytes32[] calldata packetIds
    ) external view returns (PacketView[] memory packetInfos) {
        require(packetIds.length <= 10, "Max 10 packets per query");
        packetInfos = new PacketView[](packetIds.length);

        for (uint256 i = 0; i < packetIds.length; i++) {
            Packet storage packet = packets[packetIds[i]];

            // 检查红包是否存在
            require(packet.creator != address(0), "Packet not exists");

            packetInfos[i] = PacketView(
                packetIds[i],
                packet.creator,
                packet.totalAmount,
                packet.remainingAmount,
                packet.count,
                packet.remaining,
                packet.expireTime,
                packet.isRandom,
                packet.coverURI,
                packet.token,
                packet.packetType,
                packet.nftIds
            );
        }

        return packetInfos;
    }
}
