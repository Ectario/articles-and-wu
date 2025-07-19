// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";

import "src/Challenge.sol";
import "src/Arena.sol";

contract GatherInfos is Script {

    address challenge = 0xeC977c63bC40119A8746eaA142F87a989216FB26;
    uint256 playerPk = 0x1c207c3a1fb67290046586a731b44ca2937b39eb116813ee153ba16c63e05d45;
    address player = 0xF85432cea25949e96fa2107900E2712523386856;    
    Arena arena;
    address system;

    function run() public {
        
        arena = Challenge(challenge).arena();
        system = arena.owner();

        vm.startBroadcast(player);
        vm.prank(player);
        console.log("arena.balanceOf(challenge)", arena.balanceOf(challenge));
        console.log("arena.balanceOf(system)", arena.balanceOf(system));
        console.log("arena.balanceOf(player)", arena.balanceOf(player));
        console.log("");
        console.log("address(challenge).balance", address(challenge).balance);
        console.log("address(system).balance", address(system).balance);
        console.log("address(player).balance", address(player).balance);
        console.log("address(arena).balance", address(arena).balance);
        console.log("");
    }

}
