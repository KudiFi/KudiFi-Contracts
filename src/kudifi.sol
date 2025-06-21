// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {KudiWallet} from "./kudiwallet.sol";

contract Kudifi is Pausable, Ownable {

    error InvalidPhoneNumber();

    event KudiWalletCreated(address, string, uint256);

    address public caller;
    uint256 nonce;

    address[] public allWallets;
    KudiWallet kwallet;

    constructor() Ownable(msg.sender){}

    function newKudiWallet(string memory phoneNumber) external whenNotPaused returns (address wallet) {
        nonce = block.timestamp + 1;
        require(msg.sender == caller);
        if(bytes(phoneNumber).length < 12) revert InvalidPhoneNumber();
        bytes memory bytecode = abi.encode(address(kwallet));
        bytes32 salt = keccak256(abi.encodePacked(phoneNumber, nonce));

        assembly{
            wallet := create2(0, add(bytecode, 32), mload(bytecode), salt )
        }
        allWallets.push(wallet);

        emit KudiWalletCreated(wallet, phoneNumber, allWallets.length);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

}