// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFees;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subId;
        uint32 callbackGasLimit;
    }

    NetworkConfig public networkConfig;

    constructor() {
        if (block.chainid == 80001) {
            networkConfig = getMumbaiConfig();
        }
        else {
            networkConfig = getAnvilConfig();
        }
    }

    function getMumbaiConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFees: 0.01 ether,
            interval: 60,
            vrfCoordinator: 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed,
            gasLane: 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f,
            subId: 0,
            callbackGasLimit: 500000
        });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        if (networkConfig.vrfCoordinator != address(0)) {
            return networkConfig;
        }

        uint96 baseFee = 0.25 ether;  // 0.25 LINK
        uint96 gasPriceLink = 1e9;    // 1 gwei LINK
        uint96 FUND_AMT = 10 ether;

        vm.startBroadcast();

        VRFCoordinatorV2Mock vrfCoordinator = new VRFCoordinatorV2Mock(baseFee, gasPriceLink);
        uint64 subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, FUND_AMT);

        vm.stopBroadcast();

        return NetworkConfig({
            entranceFees: 0.01 ether,
            interval: 60,
            vrfCoordinator: address(vrfCoordinator),
            gasLane: 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f,
            subId: subId,
            callbackGasLimit: 500000
        });
    }
}