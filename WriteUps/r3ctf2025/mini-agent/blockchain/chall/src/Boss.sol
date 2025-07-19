// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./IAgent.sol";
import "./Randomness.sol";

contract Boss is IAgent {

    function acceptBattle(address opponent, uint256 wager) external override returns (bool) {
        // Always accept the battle
        return true;
    }

    function tick(
        address opponent,
        uint256 wager,
        uint256 round,
        Arena.Pig[] memory fromPigs,
        Arena.Pig[] memory toPigs
    ) external override returns (uint256 fromWhich, uint256 toWhich, uint256 r) {
        fromWhich = 0;
        toWhich = 0;
        r = 50;

        uint256 maxAttack = 0;
        for (uint256 i = 0; i < fromPigs.length; i++) {
            if (fromPigs[i].health > 0 && fromPigs[i].attack > maxAttack) {
                maxAttack = fromPigs[i].attack;
                fromWhich = i;
            }
        }

        maxAttack = 0;
        for (uint256 i = 0; i < toPigs.length; i++) {
            if (toPigs[i].health > 0 && toPigs[i].attack > maxAttack) {
                maxAttack = toPigs[i].attack;
                toWhich = i;
            }
        }
        return (fromWhich, toWhich, r);
    }
}