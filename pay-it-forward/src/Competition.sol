// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "./Chain.sol";
import "./IStoreFront.sol";

/// @title Pay-it-Forward Competition Manager Contract
/// @notice Manages the different phases of a pay-it-forward competition.
contract Competition {
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~at deploy~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    /// @notice Creates the manager, chain, charity, and list of approved businesses.
    address manager;
    ChainContract public chain;
    address chainAddress;
    address charity;
    mapping(address => bool) approvedBusinesses;

    constructor() {
        manager = msg.sender;
        chain = new ChainContract();
        chainAddress = address(chain);
    }

    /**
     * @notice Details the preset competition rules, made public for verification sake /// outlining/verifying the competition rules.
     * @dev Initializes the public variables determining the competition framework including:
     * Setting the percent portion each group (participant, business, charity) gets of the prize pool
     * Setting the amount of eth per transaction that will be added to the prize pot
     * Setting up the phases of the competiton and the starting time and duration the competition will run for
     */
    uint256 public constant participantPerc = 50;
    uint256 public constant businessPerc = 15;
    uint256 public constant charityPerc = 35;
    uint256 public constant prizePotAllotment = 1;
    CompetitionPhases public competition = CompetitionPhases.PRE;
    uint256 public competitionStartTime;
    uint256 public duration = 2592000; //this should be read as seconds, i.e. 2592000 seconds = 30 days

    /// @notice Enum to manage the stages of the competition.
    /// @dev The competition progresses through these phases: `PRE`, `DURING`, and `POST`.
    enum CompetitionPhases {
        PRE,
        DURING,
        POST
    }

    /// @notice Modifier to ensure only the manager can call certain functions.
    modifier managerOnly() {
        require(msg.sender == manager, "The competition manager must call this.");
        _;
    }

    /// @notice Modifier to ensure that the restricted functions are only involving approved businesses.
    modifier approvedBusinessesOnly(address businessAddr) {
        require(approvedBusinesses[businessAddr], "This business is not approved.");
        _;
    }

    /// @notice Modifier to ensure that the function is only called during the specified competition phase.
    modifier atStage(CompetitionPhases phase) {
        require(phase == competition, "This function is is invalid at this stage.");
        _;
    }

    /**
     * @notice Internal variables used for storing relevant competiton information.
     * @dev Initializes the variables assisting the competition, including:
     * Determining a single link's worth of payout at the end of a competition for participants and businesses
     * setting an important flag to keep track of the most recent transaction's decision to pay it forward
     */
    uint256 pWinnings;
    uint256 bWinnings;
    sbool lastPifChoice = sbool(false);

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~pre competition~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    /**
     * @notice Sets the charity we will be donating to at the end of the competition.
     * @dev Checks that the charity address is not the burn address
     * @param charityAddr The address of the charity
     */
    function selectCharity(address charityAddr) public managerOnly atStage(CompetitionPhases.PRE) {
        require(charityAddr != address(0x0), "Invalid address.");
        charity = charityAddr;
    }

    /**
     * @notice Process to approve a business to participate in the competition.
     * @param businessAddr The address of the business being approved.
     * This prevents random addresses claiming themselves as businesses
     */
    function businessApprovalProcess(address businessAddr) public managerOnly atStage(CompetitionPhases.PRE) {
        approvedBusinesses[businessAddr] = true;
    }

    /// @notice Allows an approved business to donate to the prize pool, if they so choose.
    function businessContribution()
        external
        payable
        approvedBusinessesOnly(msg.sender)
        atStage(CompetitionPhases.PRE)
    {
        require(msg.value > 0, "Contribution has been rejected.");
    }

    /**
     * @notice Function for the manager to start the competition.
     * @dev Performs the necessary actions to begin the competition, specifically:
     * Checks that a charity has been selected
     * Changes the enum phase to DURING
     * Sets the competition starting time to the current time
     */
    function startCompetition() public managerOnly atStage(CompetitionPhases.PRE) {
        require(charity != address(0x0), "Charity has not been selected.");
        competitionStartTime = block.timestamp;
        competition = CompetitionPhases.DURING;
    }

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~during competition~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    /**
     * @notice Processes the financial transactions customers purchase products.
     * @dev Handles transaction data for participants at businesses
     * Checks that the transaction occurred at an approved business
     * Processes the product price and sends the money to the business, via the storefront the business will have set up
     * Processes the money paid forward and the prize pot and gives rebate depending on the current state of the chain (determined by currentPifChoice and lastPifChoice)
     * Updates the chain to reflect the current transaction
     * Ends the competition if applicable
     * @param currentPifChoice The current transactions decision to pay it forward
     * @param business The address of the business the transaction is occurring at
     * @param prodID THe ID of the product being purchased in the transaction
     */
    function makeCompTransaction(sbool currentPifChoice, address business, suint prodID)
        external
        payable
        approvedBusinessesOnly(business)
        atStage(CompetitionPhases.DURING)
    {
        if (lastPifChoice && currentPifChoice) {
            // case: last person pif, current person pif
            uint256 prodPrice = msg.value - (5 + (prizePotAllotment / 100)); //subtract pif amount and prize pot amount
            IStoreFront(business).purchase{value: prodPrice}(prodID); // store implements their own purchase logic

            // rebate: yes, last person pif
            (bool success,) = msg.sender.call{value: 5}("");
            require(success, "Rebate failed.");

            // update chain with new pif information
            chain.forgeLink(saddress(msg.sender), saddress(business));

            // don't update lastPifChoice because it is the same
        } else if (!lastPifChoice && currentPifChoice) {
            // case: last person did not pif, current person pif
            uint256 prodPrice = msg.value - (5 + (prizePotAllotment / 100)); //subtract pif amount and prize pot amount
            IStoreFront(business).purchase{value: prodPrice}(prodID); // store implements their own purchase logic

            // rebate: no, last person didn't pif

            // update chain with new pif information
            chain.forgeLink(saddress(msg.sender), saddress(business));

            //update lastPifChoice to new choice
            lastPifChoice = currentPifChoice;
        } else if (lastPifChoice && !currentPifChoice) {
            // case: last person pif, current person did not pif
            uint256 prodPrice = msg.value; // amount sent is exact
            IStoreFront(business).purchase{value: prodPrice}(prodID); // store implements their own purchase logic

            // rebate: yes, last person pif
            (bool success,) = msg.sender.call{value: 5}("");
            require(success, "Rebate failed.");

            // nuke the existing chain
            chain.nuke();

            // update lastPifChoice to new choice
            lastPifChoice = currentPifChoice;
        } else {
            // case: last person did not pif, you did not pif
            uint256 prodPrice = msg.value; // since current person didn't pif, they send the exact amount
            IStoreFront(business).purchase{value: prodPrice}(prodID); // store implements their own purchase logic

            // rebate: no, last person didn't pif

            // no update/nuke because chain is default

            //don't update last PIF because it is the same
        }
        endCompetition(); //checks every transaction if the competition should be ended
    }
    /**
     * @notice Ends the competition if the set duration has passed.
     * @dev Check if required durtation has passed since the competitions starting timestamp
     * Changes the enum phase to POST
     */

    function endCompetition() internal atStage(CompetitionPhases.DURING) {
        if (block.timestamp >= competitionStartTime + duration) {
            competition = CompetitionPhases.POST;
            setupPostCompetition();
        }
    }

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~post competition~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    /**
     * @notice Sets up the post competition phase.
     * @dev Executes final nuke to determine the overall highest-scoring chain
     * Sets up the payouts
     */
    function setupPostCompetition() internal atStage(CompetitionPhases.POST) {
        chain.nuke();
        setupPayout();
    }

    /**
     * @dev Helper function to determine the amount of payout per link in the chain for participants and businesses
     * Checks again that the charity address is not the burn address
     * Calculates the charity donation and then donates it
     */
    function setupPayout() internal atStage(CompetitionPhases.POST) {
        // calc prize pot amount of a single link for participant/business
        pWinnings = ((address(this).balance * participantPerc) / (chain.getWinningChainLength() * 100));
        bWinnings = ((address(this).balance * businessPerc) / (chain.getWinningChainLength() * 100));

        // calc amount of prize pot being donated to charity
        uint256 donation = ((address(this).balance * charityPerc) / 100);

        // check if charity address if valid
        require(charity != address(0x0), "Invalid address.");
        // payout charity
        (bool paid,) = charity.call{value: donation}("");
        require(paid, "Donation failed.");
    }

    /**
     * @notice Claim function for participants and businesses to recieve their payouts of the winning chain.
     * @dev Performs final check to determine the participants/businesses best chain
     * Checks if their best chain is the winning chain, and if so fetches the count of links they had in the winning chain
     * Checks whether the wallet is a participant or a business and pays out accordingly
     * Updates the number of links they had in the winning chain to prevent repeated payouts
     * Resets the competition if applicable
     */
    // payout function participants/businesses will execute to claim their respective payouts
    function payout() external payable atStage(CompetitionPhases.POST) {
        chain.checkIsChainLongest(saddress(msg.sender));
        if (chain.getBestChainId(saddress(msg.sender)) == chain.getWinningChainId()) {
            uint256 linkCount = chain.getBestChainCount(saddress(msg.sender));
            if (!approvedBusinesses[msg.sender]) {
                // payout to participant
                (bool paid,) = msg.sender.call{value: linkCount * pWinnings}("");
                require(paid, "Payout failed.");
            } else {
                // payout to business
                (bool paid,) = msg.sender.call{value: linkCount * bWinnings}("");
                require(paid, "Payout failed.");
            }
            chain.walletHasBeenPaid(saddress(msg.sender));
        }
    }

    function getChainContractAddress() public view returns (address) {
        return address(chainAddress);
    }

    function getManagerAddress() public view returns (address) {
        return address(manager);
    }
}
