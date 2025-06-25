// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {KudiWallet} from "./kudiwallet.sol";
import {IWallet} from "./IWallet.sol";

contract Kudifi is Pausable, Ownable, EIP712 {

    error InvalidPhoneNumber();
    error TransactionFailed();
    error WalletAlreadyExists();

    event KudiWalletCreated(address, string, uint256);

    address public caller;

    address[] public allWallets;
    KudiWallet kwallet;

    struct Request {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
    }

    mapping(address => uint256) private _nonces;

    //Registry of all phone numbers to their valid wallets
    mapping(string => KudiWallet) private validWallets; 

    bytes32 private constant _TYPEHASH = keccak256(
            "Request(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)"
        );

    constructor() Ownable(msg.sender) EIP712("KudiFi", "V1"){}

    /**
     * Creates a new wallet address with user's provided phone number
     * @param phoneNumber phone number of user
     * @return wallet the wallet address created for user
     */
    function newKudiWallet(string memory phoneNumber) public whenNotPaused returns (address wallet) {
        if(bytes(phoneNumber).length < 12) revert InvalidPhoneNumber();
        bytes memory bytecode = abi.encode(address(kwallet));
        bytes32 salt = keccak256(abi.encodePacked(phoneNumber));

        assembly{
            wallet := create2(0, add(bytecode, 32), mload(bytecode), salt )
        }
        if (wallet == address(0)){
            revert WalletAlreadyExists();
        }
        allWallets.push(wallet);
        KudiWallet kwallet = new KudiWallet(wallet);
        validWallets[phoneNumber] = kwallet;

        emit KudiWalletCreated(wallet, phoneNumber, allWallets.length);
    }

    /**
     * Checks the wallets address of the valid phone number
     * if user does not have an address, it will create one
     * @param phoneNumber user's phone number
     * @return validWallet user's valid wallet address
     */
    function addressOfPhonenumber(string calldata phoneNumber) public  whenNotPaused returns (address validWallet) {
        KudiWallet vWallet = validWallets[phoneNumber];
        if (address(vWallet) == address(0)){ //This means user does not have a wallet with us yet so we have to create one?
            validWallet = newKudiWallet(phoneNumber);
        }
        return validWallet;
    }

    /**
     * Checks the balance of the provided phone number
     * @param phonenumber user's phone number
     * @param token address of token
     * @return amount of of tokens user has
     */
    function balanceOf(
        string calldata phonenumber,
        address token
    ) external onlyOwner returns (uint) {
        KudiWallet _wallet = validWallets[phonenumber];

        uint amount = _wallet.balance(token);

        return amount;
    }

    /**
     * Approves address
     */
    function approveAddress(
        string calldata phonenumber,
        address recipient,
        address token,
        uint amount
    ) external onlyOwner returns (bool) {
        address wallet = addressOfPhonenumber(phonenumber);
        KudiWallet _wallet = validWallets[phonenumber];

        return _wallet.approve(token, recipient, amount);
    }

    /**
     * Approves phone number
     */
    function approvePhonenumber(
        string calldata phonenumber,
        string calldata recipientPhonenumber,
        address token,
        uint amount
    )
        external onlyOwner returns (bool)
    {
        address wallet = addressOfPhonenumber(phonenumber);
        address recipient = addressOfPhonenumber(recipientPhonenumber);
        KudiWallet _wallet = validWallets[phonenumber];


        return _wallet.approve(token, recipient, amount);
    }


    /**
     * Sends tokens from one address to another
     * @param fromPhonenumber sender's phone number
     * @param toPhonenumber receiver's phone number
     * @param token address of token
     * @param amount amount of tokens to send
     */
    function safeTransferToAccount(string calldata fromPhonenumber, string calldata toPhonenumber, address token, uint256 amount)
        external onlyOwner whenNotPaused returns (bool)
    {
        address toWallet = addressOfPhonenumber(toPhonenumber);
        address fromWallet = addressOfPhonenumber(fromPhonenumber);

        // if (!_checkContract(toWallet)) {
        //     toWallet = ProxyFactory(factoryAddress).newWallet(
        //         toPhonenumber
        //     );
        // }
        KudiWallet _fromWallet = validWallets[fromPhonenumber];

        bool okay = _fromWallet.withdrawToken(
            token,
            toWallet,
            amount
        );

        if (!okay) revert TransactionFailed();

        return okay;
    }

    /**
     * transfers token to address
     * @param fromPhonenumber sender's phone number
     * @param _to receiver's address
     * @param token address of token
     * @param amount amount of tokens to send
     */
    function transferToAddress(
        string calldata fromPhonenumber,
        address _to,
        address token,
        uint256 amount
    )
        external onlyOwner whenNotPaused returns (bool)
    {
        address fromWallet = addressOfPhonenumber(fromPhonenumber);
        KudiWallet _fromWallet = validWallets[fromPhonenumber];

        bool okay = _fromWallet.withdrawToken(token, _to, amount);

        if (!okay) revert TransactionFailed();

        return okay;
    }

    function _verifySignature(
        Request memory req,
        bytes memory signature
    ) internal view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _TYPEHASH,
                    req.from,
                    req.to,
                    req.value,
                    req.gas,
                    req.nonce,
                    keccak256(req.data)
                )
            )
        );

        address signer = ECDSA.recover(digest, signature);

        return signer;
    }

    /**
     * Verifies the signature
     */
    function verify(
        Request memory _req,
        bytes memory _signature
    ) public view returns (bool) {
        address signer = _verifySignature(_req, _signature);

        if (_req.from != signer) return false;

        return true;
    }

    /**
     * Executes the request
     */
    function execute(
        Request memory _req,
        bytes memory _signature
    ) public payable returns (bool, bytes memory) {
        require(
            verify(_req, _signature),
            "PaysliceForwarder: signature does not match request"
        );

        _nonces[_req.from] = _req.nonce + 1;

        (bool success, bytes memory returndata) = _req.to.call{
            gas: _req.gas,
            value: _req.value
        }(abi.encodePacked(_req.data, _req.from));

        // Validate that the relayer has sent enough gas for the call.
        // See https://ronan.eth.limo/blog/ethereum-gas-dangers/
        if (gasleft() <= _req.gas / 63) {
            // We explicitly trigger invalid opcode to consume all gas and bubble-up the effects, since
            // neither revert or assert consume all gas since Solidity 0.8.0
            // https://docs.soliditylang.org/en/v0.8.0/control-structures.html#panic-via-assert-and-error-via-require
            /// @solidity memory-safe-assembly
            assembly {
                invalid()
            }
        }

        return (success, returndata);
    }

    function getNonce(address from) public view returns (uint256) {
        return _nonces[from];
    }


    /**
     * Pauses the contract
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * Unpause the contract
     */
    function unpause() public onlyOwner {
        _unpause();
    }

}