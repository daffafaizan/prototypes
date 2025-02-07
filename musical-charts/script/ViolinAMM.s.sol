// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ViolinAMM} from "../src/ViolinAMM.sol";
import {ViolinCoin} from "../src/ViolinCoin.sol";

contract ViolinAMMScript is Script {
    ViolinAMM public amm;
    ViolinCoin public baseAsset;
    ViolinCoin public quoteAsset;

    function setUp() public {
        address admin = address(0x14dC79964da2C08b23698B3D3cc7Ca32193d9955);
        baseAsset = new ViolinCoin(admin, "Base Asset", "BASE", 18);
        quoteAsset = new ViolinCoin(admin, "Quote Asset", "QUOTE", 18);
    }

    function run() public {
        vm.startBroadcast();
        address admin = address(0x14dC79964da2C08b23698B3D3cc7Ca32193d9955);
        amm = new ViolinAMM(baseAsset, quoteAsset, 1e18, 1e18, admin);
        vm.stopBroadcast();
    }
}
