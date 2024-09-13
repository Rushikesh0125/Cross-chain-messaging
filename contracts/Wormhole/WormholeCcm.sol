// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WormholeCcm is IWormholeReceiver, Ownable {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    uint256 constant GAS_LIMIT = 50_000;
    uint16 public _srcChainId;

    IWormholeRelayer public immutable wormholeRelayer;

    string public latestGreeting;

    mapping(uint16 chainId => address peerContract) private peerContracts;

    constructor(address _wormholeRelayer, uint16 srcChainId) Ownable(msg.sender){
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        _srcChainId = srcChainId;
    }

    function quoteCrossChainGreeting(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );
    }

    function setPeer(uint16 chainId, address peerContract) public onlyOwner{
        require(peerContract != address(0));
        peerContracts[chainId] = peerContract;
    }

    function sendMessage(
        uint16 targetChain,
        address targetAddress,
        string memory greeting
    ) public payable {
        uint256 cost = quoteCrossChainGreeting(targetChain);
        require(msg.value == cost);
        require(peerContracts[targetChain] == targetAddress);
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(greeting, msg.sender), // payload
            0, // no receiver value needed since we're just passing a message
            GAS_LIMIT,
            targetChain,
            msg.sender
        );
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32 sender, // address that called 'sendPayloadToEvm' (HelloWormhole contract address)
        uint16 sourceChain,
        bytes32 // unique identifier of delivery
    ) public payable override {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");
        require(peerContracts[sourceChain] == address(uint160(uint256(sender))));

        // Parse the payload and do the corresponding actions!
        (string memory greeting, address senderAddress) = abi.decode(
            payload,
            (string, address)
        );
        latestGreeting = greeting;
        emit GreetingReceived(latestGreeting, sourceChain, senderAddress);
    }
}