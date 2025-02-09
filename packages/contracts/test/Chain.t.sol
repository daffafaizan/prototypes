// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ChainContract} from "../src/Chain.sol";

contract ChainTest is Test {
    // create test Chain and dummy wallets to set transactions
    ChainContract public chain;
    saddress participantA;
    saddress participantB;
    saddress businessA;
    saddress businessB;
    saddress rando;

    // set up new chain object as well as the dummy addresses we will be using
    // owner address is address(this)
    function setUp() public {
        chain = new ChainContract();
        participantA = saddress(0x111);
        participantB = saddress(0x222);
        businessA = saddress(0x100);
        businessB = saddress(0x200);
        rando = saddress(0x999);
        //print list of addresses for visibility
        console.log(address(this));
        console.log(address(participantA));
        console.log(address(participantB));
        console.log(address(businessA));
        console.log(address(businessB));
        console.log(address(rando));
    }

    // test our getter functions for logic and ownership
    function test_getters() public {
        // chain length getter
        chain.getWinningChainLength(); //should pass
        vm.expectRevert();
        vm.prank(address(rando));
        chain.getWinningChainLength(); // should fail
        // user best chain getter
        chain.getBestChainId(participantA); // should pass
        vm.expectRevert();
        vm.prank(address(rando));
        chain.getBestChainId(participantA); // should fail
    }

    //test the update function for logic and ownership
    function test_update() public {
        chain.forgeLink(participantA, businessA); // should pass and set new mapping entries
        chain.forgeLink(participantA, businessB); // should pass and set new business mapping entry
        chain.forgeLink(participantB, businessA); // should pass and set new participant mapping entry
        chain.forgeLink(participantB, businessB); // should pass and not set new mapping entries
        //check ownership
        vm.expectRevert();
        vm.prank(address(rando));
        chain.forgeLink(participantA, businessA); // should fail and not update the chain

        console.log(chain.getWinningChainLength());
        console.log(chain.getBestChainId(participantA));
        console.log(chain.getBestChainId(businessB));
        console.log(chain.getBestChainId(saddress(0x555)));
    }
}