// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-ctf/CTFDeployment.sol";

import "src/Challenge.sol";
import "src/Arena.sol";

contract Deploy is CTFDeployment {
    function deploy(uint256 systemKey, uint256 playerKey, address system, address player) internal override returns (address challenge) {
        vm.startBroadcast(playerKey);

        payable(system).transfer(player.balance - 8 ether);

        vm.stopBroadcast();

        vm.startBroadcast(systemKey);

        challenge = address(new Challenge{value: 500 ether}());

        vm.stopBroadcast();
    }
}
