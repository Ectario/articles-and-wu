// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Arena.sol";

interface IAgent {
    function acceptBattle(address opponent, uint256 wager) external returns (bool);
    function tick(
        address opponent,
        uint256 wager,
        uint256 round,
        Arena.Pig[] memory fromPigs,
        Arena.Pig[] memory toPigs
    ) external returns (uint256 fromWhich, uint256 toWhich, uint256 r);
}