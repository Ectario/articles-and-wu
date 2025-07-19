// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Script.sol";

abstract contract CTFDeployment is Script {
    address challenge;

    function run() external {
        uint256 playerKey = getPrivateKey(0);
        uint256 systemKey = getPrivateKey(1);
        address system = getAddress(1);
        address player = getAddress(0);
        challenge = deploy(systemKey, playerKey, system, player);
        
        // vm.writeFile(vm.envOr("OUTPUT_FILE", string("/tmp/deploy.txt")), vm.toString(challenge));
        console.log("player:", player);
        console.log("system:", system);
        console.log("challenge:", challenge);
    }

    function deploy(uint256 systemKey, uint256 playerKey, address system, address player) virtual internal returns (address);
    
    function getAdditionalAddress(uint32 index) internal returns (address) {
        return getAddress(index + 2);
    }

    function getPrivateKey(uint32 index) private returns (uint) {
        string memory mnemonic = vm.envOr("MNEMONIC", string("test test test test test test test test test test test junk"));
        return vm.deriveKey(mnemonic, index);
    }

    function getAddress(uint32 index) private returns (address) {
        return vm.addr(getPrivateKey(index));
    }
}