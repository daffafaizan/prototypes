// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Competition} from "../src/Competition.sol";

contract CompetitionScript is Script {
    Competition public competition;

    function run() public {
        address charityAddress = address(0x2);
        uint256 deployerPrivateKey = vm.envUint("PRIVKEY");

        vm.startBroadcast(deployerPrivateKey);
        competition = new Competition(charityAddress);
        vm.stopBroadcast();
    }
}
