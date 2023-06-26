// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (uint256 entranceFees,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subId,
        uint32 callbackGasLimit, uint256 deployerKey) = helperConfig.networkConfig();

        vm.startBroadcast(deployerKey);

        Raffle raffle = new Raffle(entranceFees, interval, vrfCoordinator, gasLane, subId, callbackGasLimit);
        
        if (block.chainid == 31337) {
            VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, address(raffle));
        }
        else {
            VRFCoordinatorV2Interface(vrfCoordinator).addConsumer(subId, address(raffle));
        }

        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}