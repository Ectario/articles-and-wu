// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract Randomness {
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "Who are you?");
        _;
    }
    mapping(address => bool) public authorized;
    modifier onlyAuthorized() {
        require(authorized[msg.sender], "What are you doing?");
        _;
    }

    uint256 private seed;

    constructor() {
        seed = block.prevrandao;
        owner = msg.sender;
        authorized[msg.sender] = true;
    }

    function random() external returns (uint256) {
        seed = uint256(keccak256(abi.encodePacked(block.prevrandao, msg.sender, seed)));
        return seed;
    }

    function setAuthorized(address user, bool status) external onlyOwner {
        authorized[user] = status;
    }

    function setSeed(uint256 newSeed) external onlyAuthorized {
        seed = newSeed;
    }
}