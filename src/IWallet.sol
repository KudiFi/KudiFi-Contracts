// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface IWallet {

    function withdrawToken(
        address _token,
        address _to,
        uint256 _amount
    ) external returns (bool);

    function balance(address _token) external view returns (uint256);

    function approve(
        address _token,
        address _recipient,
        uint amount
    ) external returns (bool);

    function approve(
        string calldata phonenumberOrUUID,
        string calldata recipientPhonenumberOrUUID,
        address token,
        uint amount
    ) external returns (bool);
}