// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Randomness.sol";
import "./IERC20.sol";
import "./IAgent.sol";

contract Arena is IERC20 {
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "Who are you?");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "No address");
        owner = newOwner;
    }

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    struct Pig {
        uint256 health;
        uint256 attack;
        uint256 defense;
    }

    Pig[] public pigs;

    struct PlayerInfo {
        address agent;
        Pig[] pigs;
    }

    mapping(address => PlayerInfo) public playerInfo;

    modifier onlyRegistered(address player) {
        require(playerInfo[player].agent != address(0), "Not registered");
        _;
    }

    struct Battle {
        address player1;
        address player2;
        uint256 wager;
    }

    Battle[] public battleStack;

    Randomness public randomness;


    event BattleResult(
        address indexed player1,
        address indexed player2,
        uint256 winner,
        uint256 wager
    );

    constructor() {
        owner = msg.sender;
        randomness = new Randomness();
    }


    function deposit() public payable {
        unchecked {
            balanceOf[msg.sender] += msg.value;
        }
    }

    function withdraw(uint amount) public {
        require(balanceOf[msg.sender] >= amount, "Too low");
        require(amount >= 10 ether, "So little");
        require(tx.origin == msg.sender, "No call");

        payable(msg.sender).call{value: amount, gas: 5000}("");
        unchecked {
            balanceOf[msg.sender] -= amount;
        }
    }

    // useless not used?
    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }

    function approve(address to, uint amount) public returns (bool) {
        allowance[msg.sender][to] = amount;
        return true;
    }

    function transfer(address to, uint amount) public returns (bool) {
        uint256 rbalance = balanceOf[msg.sender];
        require(rbalance >= amount, "Too low");

        unchecked {
            balanceOf[msg.sender] = rbalance - amount;
            balanceOf[to] += amount;
        }

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint amount
    ) public returns (bool) {
        require(balanceOf[from] >= amount, "Too low");

        if (from != msg.sender && allowance[from][msg.sender] != type(uint).max) {
            require(allowance[from][msg.sender] >= amount, "Not approved");
            unchecked {
                allowance[from][msg.sender] -= amount;
            }
        }

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }

        return true;
    }

    function claim(uint256 amount) public onlyOwner {
        payable(msg.sender).transfer(amount);
    }


    function createPig(uint256 health, uint256 attack, uint256 defense) public onlyOwner {
        pigs.push(Pig(health, attack, defense));
    }

    function register(address agent) public {
        require(agent != address(0), "No address");
        require(balanceOf[msg.sender] >= 1 ether, "So poor");
        require(tx.origin == msg.sender, "No call");
        require(msg.sender.code.length == 0, "No contract");

        unchecked {
            balanceOf[msg.sender] -= 1 ether;
        }

        uint256 codeSize = agent.code.length;
        require(codeSize > 0, "Deploy first");
        require(codeSize < 100, "Too big");

        bytes memory data = new bytes(codeSize);
        assembly {
            extcodecopy(agent, add(data, 0x20), 0, codeSize)
        }

        for(uint256 i = 0; i < codeSize; i++) {
            uint8 b = uint8(data[i]);
            if((b >= 0xf0 && b <= 0xf2) || (b >= 0xf4 && b <= 0xf5) || (b == 0xff)) {
                revert("Do yourself");
            }
        }

        playerInfo[msg.sender].agent = agent;
    }

    function registerAdmin(address player, address agent) public onlyOwner {
        require(player != address(0), "No address");
        require(agent != address(0), "No agent");

        playerInfo[player].agent = agent;
    }

    function claimPig() public onlyRegistered(msg.sender) {
        require(pigs.length > 0, "No pigs available");

        PlayerInfo storage info = playerInfo[msg.sender];
        require(info.pigs.length < 3, "Too many pigs");

        Pig memory pig = pigs[pigs.length - 1];
        pigs.pop();
        info.pigs.push(pig);
    }

    function requestBattle(address opponent, uint256 wager) public onlyRegistered(msg.sender) onlyRegistered(opponent) {
        require(opponent != address(0), "No opponent");
        require(opponent != msg.sender, "Cannot battle yourself");
        require(wager >= 1 ether, "Invalid wager");
        require(battleStack.length < 10, "Battle stack full");

        battleStack.push(Battle({
            player1: msg.sender,
            player2: opponent,
            wager: wager
        }));
    }

    function getBattleCount() public view returns (uint256) {
        return battleStack.length;
    }

    function processBattle(uint256 randomnessSeed) public onlyOwner {
        require(battleStack.length > 0, "No battles available");

        Battle memory battle = battleStack[battleStack.length - 1];
        battleStack.pop();

        randomness.setSeed(randomnessSeed);
        _processBattle(battle.player1, battle.player2, battle.wager);
    }

    //catch return data error
    function mockAcceptBattle(IAgent agent, address opponent, uint256 wager) public returns (bool) {
        return agent.acceptBattle(opponent, wager);
    }

    function mockTick(
        IAgent agent,
        address opponent,
        uint256 wager,
        uint256 round,
        Pig[] memory fromPigs,
        Pig[] memory toPigs
    ) public returns (uint256 fromWhich, uint256 toWhich, uint256 r) {
        return agent.tick(opponent, wager, round, fromPigs, toPigs);
    }

    function _processBattle(
        address player1,
        address player2,
        uint256 wager
    ) internal {
        if (balanceOf[player1] < wager || balanceOf[player2] < wager) {
            return;
        }
        balanceOf[player1] -= wager;
        balanceOf[player2] -= wager;

        IAgent[2] memory agents = [
            IAgent(playerInfo[player1].agent),
            IAgent(playerInfo[player2].agent)
        ];

        bool accepted = true;
        for (uint256 i = 0; i < 2; i++) {
            try this.mockAcceptBattle(agents[i], i == 0 ? player2 : player1, wager) returns (bool result) {
                if (!result) {
                    accepted = false;
                    break;
                }
            } catch {
                accepted = false;
                break;
            }
        }

        if (!accepted) {
            return;
        }

        // If both agents accepted, proceed with the battle

        Pig[][] memory battle = new Pig[][](2);
        battle[0] = playerInfo[player1].pigs;
        battle[1] = playerInfo[player2].pigs;

        uint256 winner = 9;

        for(uint256 round = 0; round < 100 && winner > 1; round++) {
            uint256 who = round % 2;
            uint256 opponent = 1 - who;

            try this.mockTick{gas: 100000}(
                agents[who],
                who == 0 ? player2 : player1,
                wager,
                round,
                battle[who],
                battle[opponent]
            ) returns (uint256 fromWhich, uint256 toWhich, uint256 pr) {
                if (fromWhich >= battle[who].length || toWhich >= battle[opponent].length) {
                    winner = opponent;
                    break;
                }
                if (pr >= 100) {
                    winner = opponent;
                    break;
                }

                if (battle[who][fromWhich].health == 0) {
                    winner = opponent;
                    break;
                }

                uint256 rr = randomness.random() % 100;
                uint256 dis = 0;
                if (rr < pr) {
                    dis = pr - rr;
                }
                else {
                    dis = rr - pr;
                }

                uint256 boost = 1;
                if (dis == 0) {
                    boost = 5;
                } else if (dis < 10) {
                    boost = 2;
                }

                uint256 damage = battle[who][fromWhich].attack * boost;
                uint256 defense = battle[opponent][toWhich].defense;

                damage = damage > defense ? damage - defense : 0;

                if (damage > battle[opponent][toWhich].health) {
                    damage = battle[opponent][toWhich].health;
                }
                battle[opponent][toWhich].health -= damage;

                if (battle[opponent][toWhich].health == 0) {
                    uint256 totalDead = 0;
                    for (uint256 i = 0; i < battle[opponent].length; i++) {
                        if (battle[opponent][i].health == 0) {
                            totalDead++;
                        }
                    }
                    if (totalDead == battle[opponent].length) {
                        winner = who;
                        break;
                    }
                }
            } catch {
                winner = opponent;
                break;
            }
        }

        if (winner == 9) {
            balanceOf[player1] += wager - 0.1 ether;
            balanceOf[player2] += wager - 0.1 ether;
        } else if (winner == 0) {
            balanceOf[player1] += wager * 2 - 0.1 ether;
        } else if (winner == 1) {
            balanceOf[player2] += wager * 2 - 0.1 ether;
        }
        emit BattleResult(player1, player2, winner, wager);
    }
}