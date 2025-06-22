// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Kudifi} from "../src/kudifi.sol";
import {console2} from "forge-std/console2.sol";
import {KudiWallet} from "../src/kudiwallet.sol";

contract KudiTest is Test{
    Kudifi kudi;
    KudiWallet kwallett;

    function setUp() public {
        kwallett = new KudiWallet(msg.sender);
        kudi = new Kudifi();
    }

    function testCreateNewWallet() public{
        string memory number = "233208880995";
        address wallet = kudi.newKudiWallet(number);

        string memory number2 = "233541411718";
        address wallet2 = kudi.newKudiWallet(number2);

        assertTrue(wallet2 != address(0));
        assertTrue(wallet != address(0));

        console2.log("new address: ", wallet);
        console2.log("second wallet: ", wallet2);

    }

    function testRevertDuplicateWallet() public{
        // same numbers
        string memory number1 = "233592766862";
        string memory number2 = "233592766862";

        address wallet1 = kudi.newKudiWallet(number1);

        vm.expectRevert();
         address wallet2 = kudi.newKudiWallet(number2);

        console2.log(wallet1, "<- wallet 1");
        console2.log(wallet2, "<- wallet 2");

        assertTrue(wallet1 != address(0));
        assertTrue(wallet2 == address(0));
    }

    function testAddressOfNum() public {
        // address not in the system
        address wallet = kudi.addressOfPhonenumber("233592766862");
        console2.log("wallet: ", wallet);

        assertTrue(wallet != address(0));

        //address already in the system
        address wallet2 = kudi.addressOfPhonenumber("233592766862");
        console2.log("wallet2: ", wallet2);

        assertTrue(wallet == wallet2);
    }

    function testBalance() public {
        // address(0) to represent native eth
        address wallet = kudi.addressOfPhonenumber("233592766862");
        deal(wallet, 1555e7);
        address token = address(0);
        uint256 amount = kudi.balanceOf("233592766862", token);
        console2.log("amount is: ", amount);
    }

}