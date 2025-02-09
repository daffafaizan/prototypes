// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ChainContract} from "../src/Chain.sol";
import {CompManager} from "../src/CompManager.sol";
import {IStoreFront} from "../src/IStoreFront.sol";

contract TestChainAndCompManager is Test {
    address managerAddress = address(0x1);
    address charityAddress = address(0x2);
    address businessAddress = address(0x3);
    address participantAddress = address(0x4);

    CompManager public compManager;
    ChainContract public chain;

    function setUp() public {
        vm.prank(managerAddress);
        compManager = new CompManager(charityAddress);

        // Access the ChainContract instance deployed by CompManager
        chain = ChainContract(compManager.chainAddress());

        vm.prank(managerAddress);
        compManager.businessApprovalProcess(businessAddress);

        vm.prank(managerAddress);
        compManager.startCompetition();
    }

    function testOnlyManagerCanStartCompetition() public {
        address nonManager = address(0x5);
        vm.prank(nonManager);
        vm.expectRevert("The competition manager must call this.");
        compManager.startCompetition();
    }

    function testOnlyApprovedBusinessesCanParticipate() public {
        address unapprovedBusiness = address(0x6);
        vm.prank(participantAddress);
        vm.expectRevert("This business is not approved.");
        compManager.makeCompTransaction(sbool(true), unapprovedBusiness, suint(1));
    }

    function testForgeLink() public {
        // Simulate call from the manager of ChainContract
        vm.prank(address(compManager));
        chain.forgeLink(saddress(participantAddress), saddress(businessAddress));

        uint256 bestChainId = chain.getBestChainId(saddress(participantAddress));
        assertEq(bestChainId, 0, "Best chain ID should be 0 after first link.");
    }

    function testNukeChain() public {
        // Simulate call from the manager of ChainContract
        vm.prank(address(compManager));
        chain.forgeLink(saddress(participantAddress), saddress(businessAddress));

        vm.prank(address(compManager));
        chain.nuke();

        uint256 winningChainId = chain.getWinningChainId();
        assertEq(winningChainId, 0, "Winning chain ID should be 0 after nuking the first chain.");
    }

    function testPayout() public {
        // Simulate call from the manager of ChainContract
        vm.prank(address(compManager));
        chain.forgeLink(saddress(participantAddress), saddress(businessAddress));

        vm.prank(address(compManager));
        chain.nuke();

        vm.prank(participantAddress);
        compManager.payout();

        uint256 bestChainCount = chain.getBestChainCount(saddress(participantAddress));
        assertEq(bestChainCount, 0, "Best chain count should be 0 after payout.");
    }

    function testResetCompetition() public {
        // Simulate call from the manager of ChainContract
        vm.prank(address(compManager));
        chain.forgeLink(saddress(participantAddress), saddress(businessAddress));

        vm.prank(address(compManager));
        chain.nuke();

        vm.prank(participantAddress);
        compManager.payout();

        assertEq(uint256(compManager.competition()), 0, "Competition should be reset to PRE phase.");
    }
}