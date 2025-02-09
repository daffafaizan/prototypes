// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.13;

// Solution to check if chain exists: https://ethereum.stackexchange.com/questions/13021/how-can-i-figure-out-if-a-certain-key-exists-in-a-mapping-struct-defined-inside

contract ChainContract {
    // sets of the contract and saves competition manager address
    address manager;

    constructor() {
        manager = msg.sender;
    }

    //modifier to determine if function call is coming from competition manager
    modifier isCompManager() {
        require(msg.sender == manager, "The competition manager must call this.");
        _;
    }

    // struct representing a pay-it-forward chain
    // we record who participated, how many times, and the total number of transactions
    struct Chain {
        suint chainId; // unique id for chain
        mapping(saddress => suint) links; // participant/business => # of times they paid into the chain
        suint uniqueBusinesses; // # of different businesses in the chain
        suint uniqueParticipants; // # of different participants in the chain
        suint chainLength; // total length of the chain
    }

    // struct representing the records of all nuked chains accumulated over the course of a competition
    // we keep track of the final score and length of the nuked chains, and the overall longest chain
    struct CompStats {
        mapping(suint => suint) chainFinalScores; // nuked chain's ID => that chain's final score
        mapping(suint => suint) chainFinalLengths; // nuked chain's ID => that chain's total length
        suint overallWinningChainId; // chainId of the overall winning chain
    }

    // struct representing the records of each participant and business specific chain details accumulated over the course of a competition
    // we record the last chain they paid into, the longest chain they paid into, and how many times they paid into the longest chain
    struct UserStats {
        mapping(saddress => suint) latestChain; // participant/business => latest chain's ID
        mapping(saddress => suint) bestChain; // participant/business => longest chain's ID
        mapping(saddress => suint) bestChainLinks; // participant/business => longest chain's # of links
    }

    Chain activeChain; // current running chain
    CompStats comp; // records of all comp global data
    UserStats user; // records all user specific data

    // adds a link to the active chain
    function forgeLink(saddress pAddr, saddress bAddr) public isCompManager {
        // check if participant is paying into the active chain for the first time
        // if so, update their personal stats and increment # of different people in the active chain
        if (user.latestChain[pAddr] != activeChain.chainId) {
            updateToCurrentChain(pAddr);
            activeChain.uniqueParticipants++;
        }
        activeChain.links[pAddr]++; // increment the participants # of links in active chain

        // check if business is being added to the active chain for the first time
        // if so, update their personal stats and increment # of different businesses in the active chain
        if (user.latestChain[bAddr] != activeChain.chainId) {
            updateToCurrentChain(bAddr);
            activeChain.uniqueBusinesses++;
        }
        activeChain.links[bAddr]++; // increment the businesses # of links in active chain
    }

    // helper function to reset the participant/business links and assign their latest chain to the active chain
    function updateToCurrentChain(saddress addr) internal {
        checkIsChainLongest(addr); // check if last chain is participant/business longest chain
        activeChain.links[addr] = suint(0);
        user.latestChain[addr] = activeChain.chainId;
    }

    // check if participant/business latest chains score is greater than their current highest chain score. If so, overwrite it
    function checkIsChainLongest(saddress addr) public {
        if (comp.chainFinalScores[user.latestChain[addr]] > comp.chainFinalScores[user.bestChain[addr]]) {
            user.bestChain[addr] = user.latestChain[addr]; // update the longest chain to the new longest chain
            user.bestChainLinks[addr] = activeChain.links[addr]; // update longest chain count to the new count
        }
    }

    // saves the necessary stats of the chain being nuked, updates the overall winning chain, and resets the active chain
    function nuke() public isCompManager {
        // save the final score and length of the nuked chain
        comp.chainFinalScores[activeChain.chainId] =
            calcChainScore(activeChain.uniqueParticipants, activeChain.uniqueBusinesses);
        comp.chainFinalLengths[activeChain.chainId] = activeChain.chainLength;
        // compare scores for nuked chain with overall winning chain
        if (comp.chainFinalScores[activeChain.chainId] > comp.chainFinalScores[comp.overallWinningChainId]) {
            comp.overallWinningChainId = activeChain.chainId;
        }
        //reset the stats of the active chain
        activeChain.chainLength = suint(0);
        activeChain.uniqueParticipants = suint(0);
        activeChain.uniqueBusinesses = suint(0);
        activeChain.chainId++;
    }

    // helper function to calculate a chains' final score
    function calcChainScore(suint pScore, suint bScore) internal pure returns (suint) {
        // the equation is finalScore = # unique businesses * [1 + (#unique participants/10)]
        return bScore * (suint256(1) + (pScore / suint256(10)));
    }

    // getter function for winning chain
    function getWinningChainId() public view isCompManager returns (uint256) {
        return uint256(comp.overallWinningChainId);
    }

    // getter function for the winning chains total length
    function getWinningChainLength() public view isCompManager returns (uint256) {
        return uint256(comp.chainFinalLengths[comp.overallWinningChainId]);
    }

    // getter function for participant/business best chain
    function getBestChainId(saddress addr) public view isCompManager returns (uint256) {
        return uint256(user.bestChain[addr]);
    }

    // getter function for participant/business best chains count
    function getBestChainCount(saddress addr) public view isCompManager returns (uint256) {
        return uint256(user.bestChainLinks[addr]);
    }

    // setter function for when a participant is claims payout, so they can't claim repeatedly
    function walletHasBeenPaid(saddress addr) public isCompManager {
        user.bestChainLinks[addr] = suint(0);
    }
}
