// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract KudiWallet{

    error InvalidAddress();
    error BalanceNotSufficient();
    error Transactionfailed();

    address owner;

    constructor(address _owner) {
        owner = _owner;
    }

    receive() external payable {}
    
    function balance(address _token) public view returns (uint256) {
        if (_token == address(0)) {
            return address(this).balance;
        }

        return IERC20(_token).balanceOf(address(this));
    }

    function approve( address _token,address _recipient, uint amount) public returns (bool) {
        
        if (_token == address(0) || _recipient == address(0)) {
            revert InvalidAddress();
        }
        
        return IERC20(_token).approve(_recipient, amount);
    }

    function withdrawToken(
        address _token,
        address _to,
        uint256 _amount
    ) public returns (bool) {
        if (_token == address(0)) revert InvalidAddress();

        if(IERC20(_token).balanceOf(address(this)) < _amount) revert BalanceNotSufficient();

        bool success = IERC20(_token).transfer(_to, _amount);

        if (!success)
            revert Transactionfailed();

        return success;
    }

    function withdrawNativeToken(
        address _to,
        uint _amount
    ) public {
        if(_to == address(0)) revert InvalidAddress();

        if(address(this).balance < _amount) revert BalanceNotSufficient();

        (bool success, ) = _to.call{value: _amount}("");

        if(!success) revert Transactionfailed();
    }
}