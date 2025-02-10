// SPDX-License-Identifier: MIT License
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ChainContract} from "../src/Chain.sol";

contract TestChain is Test {
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
    function test_forgeLink() public {
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

    // test the nuke function for logic and ownership
    function test_nuke() public {
        // Add links to the chain
        chain.forgeLink(participantA, businessA);
        chain.forgeLink(participantB, businessB);

        // Nuke the chain
        chain.nuke();

        // Check that the active chain is reset
        uint256 winningChainId = chain.getWinningChainId();
        assertEq(winningChainId, 0, "Winning chain ID should be 0 after nuking the first chain.");

        uint256 winningChainLength = chain.getWinningChainLength();
        assertEq(winningChainLength, 2, "Winning chain length should be 2 after nuking the first chain.");

        // Check ownership
        vm.expectRevert();
        vm.prank(address(rando));
        chain.nuke(); // should fail and not nuke the chain
    }

    // test the walletHasBeenPaid function for logic and ownership
    function test_walletHasBeenPaid() public {
        // Add links to the chain
        chain.forgeLink(participantA, businessA);
        chain.forgeLink(participantA, businessB);

        // Mark the wallet as paid
        chain.walletHasBeenPaid(participantA);

        // Check that the best chain count is reset
        uint256 bestChainCount = chain.getBestChainCount(participantA);
        assertEq(bestChainCount, 0, "Best chain count should be 0 after walletHasBeenPaid.");

        // Check ownership
        vm.expectRevert();
        vm.prank(address(rando));
        chain.walletHasBeenPaid(participantA); // should fail and not reset the count
    }

    // test the checkIsChainLongest function for logic and ownership
    function test_checkIsChainLongest() public {
        // Add links to the chain
        chain.forgeLink(participantA, businessA);
        chain.forgeLink(participantA, businessB);

        // Check if the latest chain is the longest
        chain.checkIsChainLongest(participantA);

        // Check that the best chain is updated
        uint256 bestChainId = chain.getBestChainId(participantA);
        assertEq(bestChainId, 0, "Best chain ID should be 0 after first chain.");

        // Check ownership
        vm.expectRevert();
        vm.prank(address(rando));
        chain.checkIsChainLongest(participantA); // should fail and not update the best chain
    }
}