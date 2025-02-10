// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Competition} from "../src/Competition.sol";
import {ChainContract} from "../src/Chain.sol";
import {IStoreFront} from "../src/IStoreFront.sol";

contract TestCompetition is Test {
    address managerAddress = address(0x1);
    address charityAddress = address(0x2);
    address businessAddress = address(0x3);
    address participantAddress = address(0x4);

    Competition public competition;

    function setUp() public {
        competition = new Competition();
        competition.businessApprovalProcess(businessAddress);
        competition.selectCharity(charityAddress);
        competition.startCompetition();
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

    // // Test that a participant can make a transaction with an approved business
    // function testMakeCompTransaction() public {
    //     vm.prank(participantAddress);
    //     competition.makeCompTransaction{value: 1 ether}(sbool(true), businessAddress, suint(1));

    //     // Verify that the chain has been updated
    //     vm.prank(managerAddress);
    //     uint256 bestChainId = competition.chain.getBestChainId(saddress(participantAddress));
    //     assertEq(bestChainId, 0, "Best chain ID should be 0 after first transaction.");
    // }

    // // Test that the competition can be ended after the duration has passed
    // function testEndCompetition() public {
    //     // Fast-forward time to the end of the competition
    //     vm.warp(block.timestamp + competition.duration());

    //     // Make a transaction to trigger the end of the competition
    //     vm.prank(participantAddress);
    //     competition.makeCompTransaction{value: 1 ether}(sbool(true), businessAddress, suint(1));

    //     // Verify that the competition has ended
    //     console.log(uint256(competition.competition()));
    //     assertEq(uint256(competition.competition()), 2, "Competition should be in POST phase.");
    // }

    // // Test that participants can claim payouts after the competition ends
    // function testPayout() public {
    //     // Make a transaction to add a link to the chain
    //     vm.prank(participantAddress);
    //     competition.makeCompTransaction{value: 1 ether}(sbool(true), businessAddress, suint(1));

    //     // Fast-forward time to the end of the competition
    //     vm.warp(block.timestamp + competition.duration());

    //     // End the competition
    //     vm.prank(participantAddress);
    //     competition.makeCompTransaction{value: 1 ether}(sbool(true), businessAddress, suint(1));

    //     // Claim payout
    //     vm.prank(participantAddress);
    //     competition.payout();

    //     // Verify that the participant's best chain count has been reset
    //     uint256 bestChainCount = competition.chain.getBestChainCount(saddress(participantAddress));
    //     assertEq(bestChainCount, 0, "Best chain count should be 0 after payout.");
    // }

    // // Test that the competition can be reset after all payouts are claimed
    // function testResetCompetition() public {
    //     // Make a transaction to add a link to the chain
    //     vm.prank(participantAddress);
    //     competition.makeCompTransaction{value: 1 ether}(sbool(true), businessAddress, suint(1));

    //     // Fast-forward time to the end of the competition
    //     vm.warp(block.timestamp + competition.duration());

    //     // End the competition
    //     vm.prank(participantAddress);
    //     competition.makeCompTransaction{value: 1 ether}(sbool(true), businessAddress, suint(1));

    //     // Claim payout
    //     vm.prank(participantAddress);
    //     competition.payout();

    //     // Verify that the competition has been reset
    //     assertEq(uint256(competition.competition()), 0, "Competition should be reset to PRE phase.");
    // }
}