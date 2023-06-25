// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test{
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


    event enteredRaffle(uint256 indexed entryId, address indexed participant);
    event vrfRequest(uint256 indexed reqId);

    modifier enterRaffle() {
        vm.prank(user);
        raffle.enterRaffle{value: entranceFees}();
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
        callbackGasLimit) = helperConfig.networkConfig();

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
        vm.roll(1);

        raffle.performUpkeep("");

        vm.expectRevert(getSelector("Raffle__Calculating()"));
        raffle.enterRaffle{value: entranceFees}();
    }

 
    function test_EnterRaffle_WorksCorrectlyIfEverythingisCorrect() public {
        vm.prank(user);
        vm.expectEmit(address(raffle));
        emit enteredRaffle(0, user);
        raffle.enterRaffle{value: entranceFees}();

        assertEq(raffle.getParticipant(0), user);
        assertEq(address(raffle).balance, entranceFees);
    }

    function test_PerformUpkeep__Reverts_IfRaffleHasNotEnoughETH() public {
        vm.expectRevert();
        raffle.performUpkeep("");
    }

    function test_PerformUpkeep__Reverts_IfIntervalNotPassed() public enterRaffle {
        vm.expectRevert();
        raffle.performUpkeep("");
    }

    function test_PerformUpkeep__Reverts_IfRaffleIsClosed() public enterRaffle {
        vm.warp(block.timestamp + interval);
        vm.roll(1);

        raffle.performUpkeep("");

        vm.expectRevert();
        raffle.performUpkeep("");
    }

    function test_PerformUpkeep_WorksCorrectly() public enterRaffle {
        vm.warp(block.timestamp + interval);
        vm.roll(1);

        vm.expectEmit(address(raffle));
        emit vrfRequest(1);
        raffle.performUpkeep("");
    }

    
}