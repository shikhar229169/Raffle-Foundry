// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;
    address user = makeAddr("user");
    uint256 START_BALANCE = 20 ether;
    uint256 entranceFees;
    uint256 interval;
    address vrfCoordinatorAddr;
    bytes32 gasLane;
    uint64 subId;
    uint32 callbackGasLimit;

    VRFCoordinatorV2Mock vrfCoordinator;

    // Events
    event enteredRaffle(uint256 indexed entryId, address indexed participant);
    event vrfRequest(uint256 indexed reqId);

    modifier enterRaffle() {
        vm.prank(user);
        raffle.enterRaffle{value: entranceFees}();
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();

        (entranceFees,
        interval,
        vrfCoordinatorAddr,
        gasLane,
        subId,
        callbackGasLimit, ) = helperConfig.networkConfig();

        vrfCoordinator = VRFCoordinatorV2Mock(vrfCoordinatorAddr);

        vm.deal(user, START_BALANCE);
    }

    function getSelector(string memory sign) private pure returns (bytes4) {
        return bytes4(keccak256(bytes(sign)));
    }

    function test_ConstructorArgsSetUpCorrectly() public {
        assertEq(raffle.getEntranceFees(), entranceFees);
        assertEq(raffle.getInterval(), interval);
        assertEq(raffle.getVrfCoordinator(), vrfCoordinatorAddr);
        assertEq(raffle.getGasLane(), gasLane);
        assertEq(raffle.getSubId(), subId);
        assertEq(raffle.getCallbackGasLimit(), callbackGasLimit);
        assert(raffle.getLotteryState() == Raffle.LotteryState.OPEN);
    }

    function test_EnterRaffle_RevertsIfLessETHSent() public {
        vm.expectRevert(getSelector("Raffle__lessETHSent()"));
        vm.prank(user);
        raffle.enterRaffle{value: 0}();
    }


    function test_EnterRaffle_RevertsIfLotteryClosed() public enterRaffle {
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        vm.expectRevert(getSelector("Raffle__Calculating()"));
        raffle.enterRaffle{value: entranceFees}();
    }

 
    function test_EnterRaffle_WorksCorrectlyIfEverythingisCorrect() public {
        vm.prank(user);
        vm.expectEmit(true, true, false, false, address(raffle));
        emit enteredRaffle(0, user);
        
        raffle.enterRaffle{value: entranceFees}();

        assertEq(raffle.getParticipant(0), user);
        assertEq(address(raffle).balance, entranceFees);
    }

    function test_CheckUpkeep_ReturnsFalseIfZeroETH() public {
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assertEq(upkeepNeeded, false);
    }

    function test_CheckUpkeep_ReturnsFalseIfRaffleClosed() public enterRaffle {
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assertEq(upkeepNeeded, false);
    }

    function test_CheckUpkeed_ReturnsFalseIfIntervalNotPassed() public enterRaffle {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assertEq(upkeepNeeded, false);
    }

    function test_CheckUpkeep_ReturnsTrueIfEveryThingIsSatisfied() public enterRaffle {
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assertEq(upkeepNeeded, true);
    }

    function test_PerformUpkeep__Reverts_IfRaffleHasNotEnoughETH() public {
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__upkeepNotNeeded.selector, 0, Raffle.LotteryState.OPEN, interval)
        );
        raffle.performUpkeep("");
    }

    function test_PerformUpkeep__Reverts_IfIntervalNotPassed() public enterRaffle {
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__upkeepNotNeeded.selector, entranceFees, Raffle.LotteryState.OPEN, block.timestamp - raffle.getLastTimestamp())
        );
        raffle.performUpkeep("");
    }

    function test_PerformUpkeep__Reverts_IfRaffleIsClosed() public enterRaffle {
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__upkeepNotNeeded.selector, entranceFees, Raffle.LotteryState.CALCULATING, interval)
        );
        raffle.performUpkeep("");
    }

    function test_PerformUpkeep_WorksCorrectly() public enterRaffle {
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        // vm.expectEmit(address(raffle));
        // emit vrfRequest(1);
        raffle.performUpkeep("");

        assert(raffle.getLotteryState() == Raffle.LotteryState.CALCULATING);
    }

    function test_PerformUpkeep_GeneratesRequestId() public enterRaffle {
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        vm.recordLogs();

        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        assert(uint256(requestId) > 0);
    }

    function test_FulfillRandomWords_Reverts_IfPerformUpkeepNotCalled(uint256 randomRequestId) public skipFork enterRaffle {
        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);
        
        vm.expectRevert("nonexistent request");
        vrfCoordinator.fulfillRandomWords(randomRequestId, address(raffle));
    }

    function test_EnterInLottery_RequestRandomness_WinnerPicked() public skipFork enterRaffle {
        for (uint160 i = 1; i < 10; i++) {
            address player = address(i);
            hoax(player, START_BALANCE);
            raffle.enterRaffle{value: entranceFees}();
        }

        uint256 initialRaffleBalance = address(raffle).balance;

        vm.warp(block.timestamp + interval);
        vm.roll(block.number + 1);

        vm.recordLogs();

        raffle.performUpkeep("");
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        
        vrfCoordinator.fulfillRandomWords(uint256(requestId), address(raffle));

        assert(raffle.getLotteryState() == Raffle.LotteryState.OPEN);
        assert(address(raffle).balance == 0);
        assert(raffle.getRecentWinner() != address(0));
        assertEq(raffle.getLastTimestamp(), block.timestamp);
        assertEq(raffle.getRecentWinner().balance, START_BALANCE + initialRaffleBalance - entranceFees);

        vm.expectRevert();
        raffle.getParticipant(0);
    }
}