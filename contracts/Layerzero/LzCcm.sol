// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import { OApp, MessagingFee, Origin } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppCore.sol";


contract LzCcm is OApp {

    using OptionsBuilder for bytes; 
    event GreetingReceived(string greeting, uint32 senderChain, address sender);
    string public latestGreeting;

    constructor(address _endpoint) OApp(_endpoint, msg.sender){}

    function sendMessage(
        string memory message,
        uint32 destChainId
    ) external payable returns (MessagingReceipt memory receipt) {
        
        bytes memory payload = abi.encode(message, msg.sender);
        bytes memory options = OptionsBuilder.addExecutorLzReceiveOption(OptionsBuilder.newOptions(), 2_500_000, 0);
        
        MessagingFee memory ccmFees = _quote(destChainId, payload, options, false);
        if (msg.value < ccmFees.nativeFee) revert ("Insufficient fees");

        receipt = _lzSend(destChainId, payload, options, MessagingFee(msg.value, 0), payable(msg.sender));
    }

    function _payNative(uint256 _nativeFee) internal override returns (uint256) {
        if (msg.value < _nativeFee) revert NotEnoughNative(msg.value);
        return _nativeFee;
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32 /*_guid*/,
        bytes calldata payload,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        (bytes32 messageType, bytes memory _data) = abi.decode(payload, (bytes32, bytes));

        (string memory message, address sender) = abi.decode(_data, (string, address));

        latestGreeting = message;

        emit GreetingReceived(message, _origin.srcEid, sender);
       
    }

    function getCctxFees(
        uint32 eId,
        address sender,
        string memory message
    ) external view returns (uint256) {
        bytes memory payload = abi.encode(message, sender);
        bytes memory options = OptionsBuilder.addExecutorLzReceiveOption(OptionsBuilder.newOptions(), 2_500_000, 0);
        MessagingFee memory ccmFees = _quote(eId, payload, options, false);
        return ccmFees.nativeFee;
    }

}