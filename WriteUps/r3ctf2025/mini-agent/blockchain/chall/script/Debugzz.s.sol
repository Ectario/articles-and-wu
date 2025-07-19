// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-ctf/CTFDeployment.sol";

import "src/Challenge.sol";
import "src/Arena.sol";

contract Debugzz is CTFDeployment {
    uint256 systemKey;
    uint256 playerKey;
    address system;
    address player;

    uint256 nonce;
    function rand() internal returns (uint256) {
        nonce++;
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, nonce)));
    }

    function _debugzz_setup(uint256 _systemKey, uint256 _playerKey, address _system, address _player) internal {
        systemKey = _systemKey;
        playerKey = _playerKey;
        system = _system;
        player = _player;
    }

    function deploy(uint256 _systemKey, uint256 _playerKey, address _system, address _player) internal override returns (address challenge) {
        _debugzz_setup(_systemKey, _playerKey, _system, _player);

        vm.startBroadcast(playerKey);

        payable(system).transfer(player.balance - 8 ether);

        vm.stopBroadcast();

        vm.startBroadcast(systemKey);

        challenge = address(new Challenge{value: 500 ether}());

        vm.stopBroadcast();

        Arena arena = Challenge(challenge).arena();

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

    function doBatlle() public {
        Challenge(challenge).arena().processBattle(rand());
    }
}
