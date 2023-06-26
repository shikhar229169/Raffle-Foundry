// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract CreateSubscription is Script {
    function createSubscription(address vrfCoordinator) public returns (uint64) {
        console.log("Creating subscription on chain: ", block.chainid);

        vm.startBroadcast();

        uint64 subid = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();

        vm.stopBroadcast();

        console.log("Subscription Created. Id = ", subid);

        return subid;
    }

    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();

        (,,address vrfCoordinator,,,,) = helperConfig.networkConfig();

        return createSubscription(vrfCoordinator);
    }


    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}