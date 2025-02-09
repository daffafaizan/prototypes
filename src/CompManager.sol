// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "./Chain.sol";
import "./IStoreFront.sol";

contract CompManager {
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~at deploy~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // settings for the owner/manager and creating the chainContract and its address
    address public manager;
    ChainContract public chain;
    address public chainAddress;
    // address of charity selected for competition
    address charity;
    mapping(address => bool) approvedBusinesses;
    // setting up the competititon phase cycles
    CompetitionPhases public competition = CompetitionPhases.PRE;

    // constructor function that run at deployment
    constructor(address charAddr) {
        require(charAddr != address(0x0), "Invalid charity address.");
        manager = msg.sender;
        chain = new ChainContract();
        chainAddress = address(chain);
        charity = charAddr;
    }

    // enum sets up the different phases of the game, which loop
    enum CompetitionPhases {
        PRE,
        DURING,
        POST
    }

    // modifier to restrict function calls to just the manager of the contract
    modifier managerOnly() {
        require(msg.sender == manager, "The competition manager must call this.");
        _;
    }

    // modifier to restrict function calls to only calls that contain an approved business wallet
    modifier approvedBusinessesOnly(address businessAddr) {
        require(approvedBusinesses[businessAddr], "This business is not approved.");
        _;
    }

    // modifier to restrict function calls to only if they occur during the correct stage
    modifier atStage(CompetitionPhases phase) {
        require(phase == competition, "This function is is invalid at this stage.");
        _;
    }

    // public vars are the vars we want people to read/verify the rules of the competition that we laid out
    // the percentages of the prize pot each group has access to
    uint256 public constant participantPerc = 50;
    uint256 public constant businessPerc = 15;
    uint256 public constant charityPerc = 35;
    // the prize pot allotment val (money going to pot per transaction)
    uint256 public constant prizePotAllotment = 1;
    // competition time parameters
    uint256 public competitionStartTime;
    uint256 public duration = 10; //this should be read as seconds, i.e. 2592000 seconds = 30 days

    // amount being donated to charity
    uint256 donation;
    // vals used to calculate the single entry value of participant/business winnings
    uint256 pWinnings;
    uint256 bWinnings;

    // important flag/db for competition
    sbool lastPifChoice = sbool(false);

    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~pre competition~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // functions to set up the competition prior to starting it

    // determines the charity we will be donating to
    function selectCharity(address charityAddr) public managerOnly atStage(CompetitionPhases.PRE) {
        require(charityAddr != address(0x0), "Invalid address.");
        charity = charityAddr;
    }

    // a business approval process so that only businesses that we have agreed with can be involved in the competition
    // safeguards against random people setting up wallets as fake businesses
    function businessApprovalProcess(address businessAddr) public managerOnly atStage(CompetitionPhases.PRE) {
        approvedBusinesses[businessAddr] = true;
    }

    // If any business if feeling generous and wants to donate money to the prize pool
    function businessContribution()
        external
        payable
        approvedBusinessesOnly(msg.sender)
        atStage(CompetitionPhases.PRE)
    {
        require(msg.value > 0, "Contribution has been rejected.");
    }

    // starts the competition
    function startCompetition() public managerOnly atStage(CompetitionPhases.PRE) {
        competitionStartTime = block.timestamp;
        competition = CompetitionPhases.DURING;
    }
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~during competition~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // Called by competition customers when they want to purchase things
    // currentPifChoice: flag determining if you chose to PIF
    // prodID: indicates what you want to buy, this is part of the Storefront interface that we assume all businesses have implemented

    function makeCompTransaction(sbool currentPifChoice, address business, suint prodID)
        external
        payable
        approvedBusinessesOnly(business)
        atStage(CompetitionPhases.DURING)
    {
        if (lastPifChoice && currentPifChoice) {
            // case: last person pif, current person pif
            // send money to business
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
            // send money to business
            uint256 prodPrice = msg.value - (5 + (prizePotAllotment / 100)); //subtract pif amount and prize pot amount
            IStoreFront(business).purchase{value: prodPrice}(prodID); // store implements their own purchase logic

            // rebate: no, last person didn't pif

            // update chain with new pif information
            chain.forgeLink(saddress(msg.sender), saddress(business));

            //update lastPifChoice to new choice
            lastPifChoice = currentPifChoice;
        } else if (lastPifChoice && !currentPifChoice) {
            // case: last person pif, current person did not pif
            // send money to business
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
            // last person did not pif, you did not pif
            // send money to business
            uint256 prodPrice = msg.value; // since current person didn't pif, they send the exact amount
            IStoreFront(business).purchase{value: prodPrice}(prodID); // store implements their own purchase logic

            // rebate: no, last person didn't pif

            // no update/nuke because chain is default

            //don't update last PIF because it is the same
        }
        endCompetition(); //checks every transaction if the competition should be ended
    }

    // checks if the competition has been running for the set duration, and if so ends the competition
    function endCompetition() internal atStage(CompetitionPhases.DURING) {
        if (block.timestamp >= competitionStartTime + duration) {
            competition = CompetitionPhases.POST;
            setupPostCompetition();
        }
    }
    // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~post competition~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // sets up post competition conditions

    function setupPostCompetition() internal atStage(CompetitionPhases.POST) {
        chain.nuke(); //performs final nuke to save final active chains stats and compare to the overall winning chain
        setupPayout(); //determines the payouts
    }

    // helper function for setupPostCompetition
    // determines amount to be paid per entry in the chain for participant/business
    // the portion being donated to charity is calculated and then donated
    function setupPayout() internal atStage(CompetitionPhases.POST) {
        // calc prize pot amount of a single link for participant/business
        pWinnings = ((address(this).balance * participantPerc) / (chain.getWinningChainLength() * 100));
        bWinnings = ((address(this).balance * businessPerc) / (chain.getWinningChainLength() * 100));

        // calc amount of prize pot being donated to charity
        donation = ((address(this).balance * charityPerc) / 100);

        // check if charity address if valid
        require(charity != address(0x0), "Invalid address.");
        // payout charity
        (bool paid,) = charity.call{value: donation}("");
        require(paid, "Donation failed.");
    }

    // payout function participants/businesses will execute to claim their respective payouts
    function payout() external payable atStage(CompetitionPhases.POST) {
        chain.checkIsChainLongest(saddress(msg.sender));
        if (chain.getBestChainId(saddress(msg.sender)) == chain.getWinningChainId()) {
            uint256 linkCount = chain.getBestChainCount(saddress(msg.sender)); // gets participant/business # of links
            if (!approvedBusinesses[msg.sender]) {
                // payout to participant
                (bool paid,) = msg.sender.call{value: linkCount * pWinnings}("");
                require(paid, "Payout failed.");
            } else {
                // payout to business
                (bool paid,) = msg.sender.call{value: linkCount * bWinnings}("");
                require(paid, "Payout failed.");
            }
            chain.walletHasBeenPaid(saddress(msg.sender)); // if payment goes through we reset # of links to prevent repeated payouts
        }

        // checks every payout if the competition can be reset
        resetCompetition();
    }

    // reset's the competition if everyone has been paid out and the wallet balance is empty
    function resetCompetition() internal atStage(CompetitionPhases.POST) {
        if (address(this).balance == 0) {
            competition = CompetitionPhases.PRE;
        }
    }
}
