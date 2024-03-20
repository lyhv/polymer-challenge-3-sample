//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "../base/UniversalChanIbcApp.sol";

contract XSecretUC is UniversalChanIbcApp {
    constructor(address _middleware) UniversalChanIbcApp(_middleware) {}

    event MessageOnRecv(string message);
    event RequestSecretMessage(address indexed caller);
    string private constant SECRET_MESSAGE = "Polymer is not a bridge: ";
    string private constant LIMIT_MESSAGE =
        "Sorry, but the 500 limit has been reached, stay tuned for challenge 4";
    event LogQuery(address indexed caller, string query, uint64 counter);
    mapping(address => bool) addressMap;
    // application specific state
    uint64 public counter;

    // application specific logic
    function resetCounter() internal {
        counter = 0;
    }

    function increment() internal {
        counter++;
    }

    function getCounter() internal view returns (uint64) {
        return counter;
    }

    // IBC logic

    /**
     * @dev Sends a packet with the caller's address over the universal channel.
     * @param destPortAddr The address of the destination application.
     * @param channelId The ID of the channel to send the packet to.
     * @param timeoutSeconds The timeout in seconds (relative).
     */
    function sendUniversalPacket(
        address destPortAddr,
        bytes32 channelId,
        uint64 timeoutSeconds
    ) external {
        bytes memory payload = abi.encode(msg.sender, "crossChainQuery");

        uint64 timeoutTimestamp = uint64(
            (block.timestamp + timeoutSeconds) * 1000000000
        );

        IbcUniversalPacketSender(mw).sendUniversalPacket(
            channelId,
            IbcUtils.toBytes32(destPortAddr),
            payload,
            timeoutTimestamp
        );

        emit RequestSecretMessage(msg.sender);
    }

    function onRecvUniversalPacket(
        bytes32 channelId,
        UniversalPacket calldata packet
    ) external override onlyIbcMw returns (AckPacket memory ackPacket) {
        recvedPackets.push(UcPacketWithChannel(channelId, packet));
        uint64 _counter = getCounter();

        (address _caller, string memory _query) = abi.decode(
            packet.appData,
            (address, string)
        );

        require(!addressMap[_caller], "Address already queried");
        if (_counter >= 500) {
            return AckPacket(true, abi.encode(LIMIT_MESSAGE));
        }

        if (keccak256(bytes(_query)) == keccak256(bytes("crossChainQuery"))) {
            increment();
            addressMap[_caller] = true;
            uint64 newCounter = getCounter();
            emit LogQuery(_caller, _query, newCounter);

            string memory counterString = Strings.toString(newCounter);

            string memory _ackData = string(
                abi.encodePacked(SECRET_MESSAGE, counterString)
            );

            return AckPacket(true, abi.encode(_ackData));
        }
    }

    function onUniversalAcknowledgement(
        bytes32 channelId,
        UniversalPacket memory packet,
        AckPacket calldata ack
    ) external override onlyIbcMw {
        ackPackets.push(UcAckWithChannel(channelId, packet, ack));

        string memory _message = abi.decode(packet.appData, (string));
        emit MessageOnRecv(_message);
    }

    function onTimeoutUniversalPacket(
        bytes32,
        UniversalPacket calldata
    ) external view override onlyIbcMw {
        require(false, "This function should not be called");
    }
}
