// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (uint256 entranceFees,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subId,
        uint32 callbackGasLimit) = helperConfig.networkConfig();

        vm.startBroadcast();

        Raffle raffle = new Raffle(entranceFees, interval, vrfCoordinator, gasLane, subId, callbackGasLimit);
        
        if (block.chainid == 31337) {
            VRFCoordinatorV2Mock _vrfCoordinator = VRFCoordinatorV2Mock(vrfCoordinator);
            _vrfCoordinator.addConsumer(subId, address(raffle));
        }

        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}