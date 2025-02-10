// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

/// @title Pay-it-Forward Chain Management Contract
/// @notice This contract manages the process of tracking chains and chain details during a pay-it-forward competition.
contract Chain {

    /// @notice Sets up the manager
    address manager; 

    constructor() {
        manager = msg.sender;
    }

    /// @notice Modifier to ensure only the competition contract can call certain functions
    modifier competitionOnly() {
        require(msg.sender == manager, "Only the competition manager can call this.");
        _;
    }

    /**
     * @dev Represents a "pay-it-forward" chain.
     * Tracks participants, their contributions, and overall chain statistics.
     */
    struct ChainStats {
        suint chainId; // Unique identifier for the chain
        mapping(saddress => suint) links; // Tracks number of contributions for each participant/business
        suint uniqueBusinesses; // Total distinct businesses involved in the chain
        suint uniqueParticipants; // Total distinct participants in the chain
        suint chainLength; // Total number of transactions in the chain
    }

    /**
     * @dev Stores competition-wide statistics of terminated (nuked) chains.
     * Tracks scores, lengths, and the highest-scoring chain.
     */
    struct CompStats {
        mapping(suint => suint) chainFinalScores; // Chain ID => Final score of that chain
        mapping(suint => suint) chainFinalLengths; // Chain ID => Total length of that chain
        suint overallWinningChainId; // The ID of the highest-scoring chain
    }

    /**
     * @dev Stores per-participant and per-business statistics for chain participation.
     * Tracks their latest chains, and best chains and their contributions.
     */
    struct UserStats {
        mapping(saddress => suint) latestChain; // Address => Last chain participated in
        mapping(saddress => suint) bestChain; // Address => Best (longest) chain participated in
        mapping(saddress => suint) bestChainLinks; // Address => Number of contributions in the best chain
    }

    ChainStats activeChain; // The currently active chain
    CompStats comp; // Tracks global competition statistics
    UserStats user; // Tracks user-specific statistics

    /**
     * @notice Adds transaction details to the active chain.
     * Updates participation records for both the participant and the business.
     * If the participant or business is contributing for the first time, their records are updated accordingly.
     * @param pAddr The participant's address.
     * @param bAddr The business's address.
     */
    function forgeLink(saddress pAddr, saddress bAddr) public competitionOnly {
        // If this is the participant's first time contributing to this chain, update records.
        if (user.latestChain[pAddr] != activeChain.chainId) {
            updateToCurrentChain(pAddr);
            activeChain.uniqueParticipants++;
        }
        activeChain.links[pAddr]++; // Increment participant’s contribution count

        // If this is the business's first time being added to this chain, update records.
        if (user.latestChain[bAddr] != activeChain.chainId) {
            updateToCurrentChain(bAddr);
            activeChain.uniqueBusinesses++;
        }
        activeChain.links[bAddr]++; // Increment business’s contribution count
    }

    /**
     * @dev Resets a participant/business’s contribution count and updates their latest chain.
     * @param addr The address of the participant/business.
     */
    function updateToCurrentChain(saddress addr) internal {
        checkIsChainLongest(addr); // Check if their latest chain was their longest
        activeChain.links[addr] = suint(0); // Reset contribution count
        user.latestChain[addr] = activeChain.chainId; // Assign the latest chain
    }

    /**
     * @dev Checks if the participant/business’s latest chain had the highest score.
     * If so, update their best chain records.
     * This is public due to the need to check the final chain after the competition ends
     * @param addr The address of the participant/business.
     */
    function checkIsChainLongest(saddress addr) public competitionOnly {
	suint latestScore = comp.chainFinalScores[user.latestChain[addr]];
	suint bestScore = comp.chainFinalScores[user.bestChain[addr]];
        if (latestScore > bestScore) {
            user.bestChain[addr] = user.latestChain[addr]; // Update best chain
            user.bestChainLinks[addr] = activeChain.links[addr]; // Update best chain's contribution count
        }
    }

    /**
     * @notice Ends the active chain, records its statistics, and resets it to be used as the next chain.
     * Updates the overall highest-scoring chain if applicable.
     */
    function nuke() public competitionOnly {
        // Record final score and length of the nuked chain
        comp.chainFinalScores[activeChain.chainId] = calcChainScore(activeChain.uniqueParticipants, activeChain.uniqueBusinesses);
        comp.chainFinalLengths[activeChain.chainId] = activeChain.chainLength;

        // Update the overall winning chain if this one has a higher score
        if (comp.chainFinalScores[activeChain.chainId] > comp.chainFinalScores[comp.overallWinningChainId]) {
            comp.overallWinningChainId = activeChain.chainId;
        }

        // Reset the active chain for a fresh start
        activeChain.chainLength = suint(0);
        activeChain.uniqueParticipants = suint(0);
        activeChain.uniqueBusinesses = suint(0);
        activeChain.chainId++;
    }

    /**
     * @dev Calculates a chain's final score based on distinct participants and businesses.
     * @param pScore The number of distinct participants.
     * @param bScore The number of distinct businesses.
     * @return The calculated final score.
     */
    function calcChainScore(suint pScore, suint bScore) internal pure returns (suint) {
        // Formula: finalScore = unique businesses * (1 + (unique participants / 10))
        return bScore * (suint(1) + (pScore / suint(10)));
    }

    /// @notice Returns the ID of the highest-scoring chain.
    function getWinningChainId() public view competitionOnly returns (uint256) {
        return uint256(comp.overallWinningChainId);
    }

    /// @notice Returns the total length of the highest-scoring chain.
    function getWinningChainLength() public view competitionOnly returns (uint256) {
        return uint256(comp.chainFinalLengths[comp.overallWinningChainId]);
    }

    /// @notice Returns the best (highest-scoring) chain a participant/business has contributed to.
    /// @param addr The address of the participant/business.
    function getBestChainId(saddress addr) public view competitionOnly returns (uint256) {
        return uint256(user.bestChain[addr]);
    }

    /// @notice Returns the number of times a participant/business contributed to their best chain.
    /// @param addr The address of the participant/business.
    function getBestChainCount(saddress addr) public view competitionOnly returns (uint256) {
        return uint256(user.bestChainLinks[addr]);
    }

    /**
     * @dev Resets a participant/business contribution count on the winning chain
     * Prevents them from claiming rewards multiple times.
     * @param addr The address of the participant/business.
     */
    function walletHasBeenPaid(saddress addr) public competitionOnly {
        user.bestChainLinks[addr] = suint(0);
    }
}