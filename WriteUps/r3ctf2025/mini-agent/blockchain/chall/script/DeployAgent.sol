// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

contract DeployAgent is Script {
    function run() external {
        vm.startBroadcast();

        bytes memory creationCode = hex"604380600a5f395ff3fe632f865bd95f526020604060045f731234567890abcdef1234567890abcdef123456785afa50445f5233602052606460605f200660015f525f60205260405260605ff3";

        address deployed;
        assembly {
            deployed := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        console.log("Deployed at:", deployed);

        vm.stopBroadcast();
    }
}
