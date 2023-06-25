// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";

error Raffle__lessETHSent();
error Raffle__ethTxnFailed();
error Raffle__Calculating();
error Raffle__upkeedNotNeeded(uint256 balance, uint256 lotteryState, uint256 intervalPassed);

/**
 * @title Lottery Contract
 * @author Shikhar Agarwal
 * @dev Implements Chainlink VRF and Chainlink Automation
*/
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface{
    enum LotteryState {
        OPEN,
        CALCULATING
    }

    uint256 private immutable i_entranceFees;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    address payable[] private participants;
    uint256 private lastTimeStamp;
    address private recentWinner;
    LotteryState private lotteryState;

    // Events
    event enteredRaffle(uint256 indexed entryId, address indexed participant);
    event winnerPicked(address indexed winner, uint256 indexed amount);
    event vrfRequest(uint256 indexed reqId);

    constructor(uint256 entranceFees, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint64 subId, uint32 callbackGasLimit) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFees = entranceFees;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subId = subId;
        i_callbackGasLimit = callbackGasLimit;
        lastTimeStamp = block.timestamp;
        lotteryState = LotteryState.OPEN;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFees) {
            revert Raffle__lessETHSent();
        }

        if (lotteryState == LotteryState.CALCULATING) {
            revert Raffle__Calculating();
        }

        participants.push(payable(msg.sender));

        emit enteredRaffle(participants.length - 1, msg.sender);
    }

    function checkUpkeep(bytes memory /* checkData */) public view override returns (bool upkeepNeeded, bytes memory performData) {
        bool intervalCheck = ((block.timestamp - lastTimeStamp) >= i_interval);
        bool lotteryStateCheck = (lotteryState == LotteryState.OPEN);
        bool hasEth = (address(this).balance > 0);

        upkeepNeeded = (intervalCheck && lotteryStateCheck && hasEth);
        performData = "";
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle__upkeedNotNeeded(address(this).balance, uint256(lotteryState), block.timestamp - lastTimeStamp);
        }

        uint256 reqId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        lotteryState = LotteryState.CALCULATING;
        emit vrfRequest(reqId);
    }

    function fulfillRandomWords(uint256 /*_requestId*/, uint256[] memory _randomWords) internal override {
        uint256 randomNumber = _randomWords[0] % participants.length;
        address payable winner = participants[randomNumber];
        uint256 amount = address(this).balance;
        recentWinner = winner;

        participants = new address payable[](0);

        emit winnerPicked(winner, amount);

        (bool success, ) = winner.call{value: amount}("");
        if (!success) {
            revert Raffle__ethTxnFailed();
        }
        
        // Update for PC Fren
        lastTimeStamp = block.timestamp;
        lotteryState = LotteryState.OPEN;
    }

    function getEntranceFees() external view returns (uint256) {
        return i_entranceFees;
    }

    function getParticipant(uint256 idx) external view returns (address) {
        return participants[idx];
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    function getVrfCoordinator() external view returns (address) {
        return address(i_vrfCoordinator);
    }

    function getLastTimestamp() external view returns (uint256) {
        return lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return recentWinner;
    }

    function getLotteryState() external view returns (LotteryState) {
        return lotteryState;
    }

    function getGasLane() external view returns (bytes32) {
        return i_gasLane;
    }

    function getSubId() external view returns (uint64) {
        return i_subId;
    }

    function getCallbackGasLimit() external view returns (uint32) {
        return i_callbackGasLimit;
    }

    function getRequestConfirmations() external pure returns (uint16) {
        return REQUEST_CONFIRMATIONS;
    }

    function getNumWords() external pure returns (uint32) {
        return NUM_WORDS;
    }
}