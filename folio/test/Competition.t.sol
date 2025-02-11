// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Competition} from "../src/Competition.sol";
import {ChainTracker} from "../src/ChainTracker.sol";
import {IStoreFront} from "../src/IStoreFront.sol";
import {MockStore} from "./utils/MockStore.sol";

contract TestCompetition is Test {
    address managerAddress;
    address charityAddress = address(0x2);
    address participantAddress = address(0x4);
    MockStore store;
    ChainTracker chain;

    Competition public competition;

    function setUp() public {
        store = new MockStore();
        competition = new Competition(charityAddress);
        competition.businessApprovalProcess(address(store));
        competition.startCompetition();
        chain = ChainTracker(competition.getChainTrackerAddress());
        managerAddress = competition.getManagerAddress();
    }

    // Test that only the manager can start the competition
    function testOnlyManagerCanStartCompetition() public {
        address nonManager = address(0x5);
        vm.prank(nonManager);
        vm.expectRevert("The competition manager must call this.");
        competition.startCompetition();
    }

    // Test that only approved businesses can participate
    function testOnlyApprovedBusinessesCanParticipate() public {
        address unapprovedBusiness = address(0x6);
        vm.prank(participantAddress);
        vm.expectRevert("This business is not approved.");
        competition.makeCompTransaction(sbool(true), unapprovedBusiness, suint(1));
    }

    // Test that a participant can make a transaction with an approved business
    function testMakeCompTransaction() public {
        vm.prank(participantAddress);
        // Initializes 40 ether to participant wallet address
        vm.deal(participantAddress, 40 ether);
        competition.makeCompTransaction{value: 10 ether}(sbool(true), address(store), suint(1));

        // Verify that the chain has been updated
        vm.prank(address(competition));
        uint256 bestChainId = chain.getBestChainId(saddress(participantAddress));
        assertEq(bestChainId, 0, "Best chain ID should be 0 after first transaction.");
    }

    // Test that the competition can be ended after the duration has passed
    function testEndCompetition() public {
        // Initializes 40 ether to participant wallet address
        vm.deal(participantAddress, 40 ether);

        // Make a transaction to trigger the end of the competition
        vm.prank(participantAddress);
        competition.makeCompTransaction{value: 10 ether}(sbool(true), address(store), suint(1));

        // Fast-forward time to the end of the competition
        vm.warp(block.timestamp + competition.duration());

        // End the competition
        vm.prank(managerAddress);
        competition.endCompetition();

        // Verify that the competition has ended
        assertEq(uint256(competition.competition()), 2, "Competition should be in POST phase.");
    }
}