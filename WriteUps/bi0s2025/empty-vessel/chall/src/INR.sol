// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console2} from "forge-std/Test.sol";

contract INR {
    error InsufficientBalance(uint256 _actualBalance,uint256 _expectedAmount);
    error InsufficientAllowance(uint256,uint256);
    error Invalid_Length(uint256,uint256);
    error INR__Zero__Balance();
    error OwnableUnauthorizedAccount(address);
    
    constructor(uint256 initalSupply,string memory name,string memory symbol){
        assembly {
            let ptr := mload(0x40)

            // Check if 'name' string is longer than 32 bytes; revert if so
            if gt(mload(name), 0x20) {
                // Encode and revert with Error(string) for long 'name'
                mstore(add(ptr, 0x20), 0xc4609c1e)          // Function selector for Error(string)
                mstore(add(ptr, 0x40), 0x20)
                mstore(add(ptr, 0x60), mload(name))
                revert(add(add(ptr, 0x20), 0x1c), 0x44)
            }

            // Check if 'symbol' string is longer than 32 bytes; revert if so
            if gt(mload(symbol), 0x20) {
                // Encode and revert with Error(string) for long 'symbol'
                mstore(add(ptr, 0x20), 0xc4609c1e)          // Function selector for Error(string)
                mstore(add(ptr, 0x40), 0x20)
                mstore(add(ptr, 0x60), mload(symbol))
                revert(add(add(ptr, 0x20), 0x1c), 0x44)
            }
            // setting of the storage
            // slot 0 = owner
            // slot 1 = balances
            // slot 2 = allowances
            // slot 3 = initialSupply
            // slot 4 = name
            // slot 5 = buggy symbol?
            sstore(0x00, caller())
            sstore(0x03, initalSupply)
            sstore(0x04, mload(add(name, 0x20)))
            sstore(0x05, mload(add(ptr, 0x20)))
            mstore(ptr, caller())
            mstore(add(ptr, 0x20), 1)
            sstore(keccak256(ptr, 0x40), initalSupply)
        }
    }
    

    function totalSupply()public view returns (uint256){
        assembly{
            let ptr:=mload(0x40)
            mstore(ptr,sload(3))
            return(ptr,0x20)
        }
    }

    function balanceOf(address _account)public view returns (uint256 _balance){
        assembly{
            let ptr:=mload(0x40)
            mstore(ptr,_account)
            mstore(add(ptr,0x20),1)
            let slot:=keccak256(ptr,0x40)
            _balance:=sload(slot)
        }
    }

    function transfer(address _to, uint256 _value)public returns (bool){
        assembly{
            let ptr:=mload(0x40)
            mstore(ptr,caller())
            mstore(add(ptr,0x20),1)
            let slot_from:=keccak256(ptr,0x40)
            
            let from_Balance:=sload(slot_from) // balance[from]
            
            if lt(from_Balance,_value){
                mstore(ptr,0xcf479181) // InsufficientBalance(uint256,uint256)"
                mstore(add(ptr,0x20),from_Balance)
                mstore(add(ptr,0x40),_value)
                revert(add(ptr,0x1c),0x44)
            }
            ptr:=add(ptr,0x40)
            mstore(ptr,_to)
            mstore(add(ptr,0x20),1)
            let slot_to:=keccak256(ptr,0x40)
            let to_Balance:=sload(slot_to) // balance[to]
            sstore(slot_from,sub(from_Balance,_value)) // balance[from] = balance[from] - _value
            sstore(slot_to,add(to_Balance,_value)) // balance[to] = balance[to] + _value
            mstore(ptr,0x01)
            return(ptr,0x20)
        }
    }

    function allowance(address owner,address spender)public view returns (uint256){
        assembly{
            let ptr:=mload(0x40)
            mstore(ptr,owner)
            mstore(add(ptr,0x20),2)
            mstore(add(ptr,0x40),spender)
            mstore(add(ptr,0x60),keccak256(ptr,0x40))
            mstore(ptr,sload(keccak256(add(ptr,0x40),0x40)))
            return(ptr,0x20)
        }
    }

    function approve(address spender,uint256 amount)public returns (bool){
        assembly{
            let ptr:=mload(0x40)
            mstore(ptr,caller()) // owner = caller()
            mstore(add(ptr,0x20),2)
            mstore(add(ptr,0x40),spender)
            mstore(add(ptr,0x60),keccak256(ptr,0x40)) // keccak256(owner, 2) is equal to allowances[owner]
            // allowance[owner][spender] = amount
            sstore(keccak256(add(ptr,0x40),0x40),amount) 
            mstore(ptr,0x01)
            return(ptr,0x20)
        }
    }

    function transferFrom(address from,address to,uint256 amount)public returns (bool){
        uint256 fromBalance;
        assembly{
            let ptr:=mload(0x40)
            mstore(ptr,from)
            mstore(add(ptr,0x20),2)
            mstore(add(ptr,0x40),caller())
            mstore(add(ptr,0x60),keccak256(ptr,0x40)) // allowance[from]
            mstore(ptr,keccak256(add(ptr,0x40),0x40)) // ptr = allowance[from][caller()]
            let _allowance:=sload(mload(ptr))
            if lt(_allowance,amount){
                mstore(ptr,0x2a1b2dd8) // InsufficientAllowance(uint256,uint256)
                mstore(add(ptr,0x20),_allowance)
                mstore(add(ptr,0x40),amount)
                revert(add(ptr,0x1c),0x44)
            }
            sstore(mload(ptr),sub(_allowance,amount))
            
            mstore(ptr,from)
            mstore(add(ptr,0x20),1)
            let slot_from:=keccak256(ptr,0x40)
            let from_Balance:=sload(slot_from)
            fromBalance:=from_Balance // ???? useless
            
            if lt(from_Balance,amount){
                mstore(ptr,0xcf479181) // InsufficientBalance(uint256,uint256)
                mstore(add(ptr,0x20),from_Balance)
                mstore(add(ptr,0x40),amount)
                revert(add(ptr,0x1c),0x44)
            }
            mstore(ptr,to)
            mstore(add(ptr,0x20),0x01)
            let slot_to:=keccak256(ptr,0x40) // balances[to]
            sstore(slot_from,sub(from_Balance,amount))
            sstore(slot_to,add(sload(slot_to),amount))
            mstore(ptr,0x01)
            return(ptr,0x20)   
        }
    }

    //! no check to see whether receivers are uniques or not
    //! wtf is this? what's its purpose?????? (not used by Stake or Setup, is this a backdoor function?)
    function batchTransfer(address[] memory receivers, uint256 amount) public returns (bool){
        assembly{
            let ptr:= mload(0x40)
            mstore(ptr,caller())
            mstore(add(ptr,0x20),1)
            // getting the caller balance
            mstore(ptr,sload(keccak256(ptr,0x40))) // ptr = caller.balance
            if eq(mload(ptr),0x00){
                mstore(ptr,0xf8118546) // INR__Zero__Balance()
                revert(add(ptr,0x1c),0x04)
            }
            // caller.balance >= amount * receivers.length
            //! if we control receivers.length (which is the case since we can manipulate calldata as we are the caller), can't we just overflow and thus amount * receivers.length < caller.balance????
            //  okey maybe not using the receivers.length because the out of gas will say "welcome to my realm", instead we can just use an amount HUGE, since except this check there is NO other check on amount, wtf is goin' on, soon get REKTED my dear
            if lt(mload(ptr),mul(mload(receivers),amount)){
                mstore(add(ptr,0x20),0xcf479181) // InsufficientBalance(uint256,uint256)"
                mstore(add(ptr,0x40),mload(ptr))
                mstore(add(ptr,0x60),mul(mload(receivers),amount))
                revert(add(add(ptr,0x20),0x1c),0x44)
            }
            
            for {let i := 0x00} lt(i, mload(receivers)) {i := add(i, 0x01)} {
                // let to = receivers[i];
                mstore(ptr, mload(add(receivers, mul(add(i, 0x01), 0x20))))
                // balances[to] is stored at keccak256(to, 1)
                mstore(add(ptr, 0x20), 1)
                // balances[to] = balances[to] + amount;
                sstore(keccak256(ptr, 0x40), add(sload(keccak256(ptr, 0x40)), amount))
            }
            mstore(ptr,caller())
            mstore(add(ptr,0x20),1)
            // set the caller balance to caller.balance - amount*receivers.length
            sstore(keccak256(ptr,0x40),sub(sload(keccak256(ptr,0x40)), mul(amount, mload(receivers))))
            mstore(ptr,0x01)
            return(ptr,0x20)
        }        
    }
    
    function mint(address to, uint256 amount) public { // onlyOwner
        assembly {
            let ptr := mload(0x40)
            if iszero(eq(caller(), sload(0x00))) { // check ownership by caller == owner (owner is at storage slot 0)
                mstore(ptr, 0x118cdaa7) // OwnableUnauthorizedAccount(address)
                mstore(add(ptr, 0x20), caller())
                revert(add(ptr, 0x1c), 0x24)
            }

            mstore(ptr, to)
            mstore(add(ptr, 0x20), 1)
            mstore(ptr, keccak256(ptr, 0x40)) // slot = balances[to]
            sstore(mload(ptr), add(sload(mload(ptr)), amount)) // balances[to] += amount
            sstore(3, add(sload(3), amount)) // totalSupply += amount
        }
    }


    function burn(address from,uint256 amount) public { // onlyOwner
        assembly{
            let ptr:=mload(0x40)
            if iszero(eq(caller(),sload(0x00))){ // check ownership by caller == owner (owner is at storage slot 0)
                mstore(ptr,0x118cdaa7) // OwnableUnauthorizedAccount(address)
                mstore(add(ptr,0x20),caller())
                revert(add(ptr,0x1c),0x24)
            }
            mstore(ptr,from)
            mstore(add(ptr,0x20),1)
            mstore(ptr,keccak256(ptr,0x40)) // ptr = slot = keccak256(from, 1)
            mstore(add(ptr,0x20),sload(mload(ptr)))
            if lt(mload(add(ptr,0x20)),amount){ // check funds
                mstore(ptr,0xcf479181) // InsufficientBalance(uint256,uint256)"
                mstore(add(ptr,0x20),mload(add(ptr,0x20)))
                mstore(add(ptr,0x40),amount)
                revert(add(ptr,0x1c),0x44)
            }
            // balances[from] = balance - amount
            sstore(mload(ptr),sub(mload(add(ptr,0x20)),amount))
            sstore(3,sub(sload(3),amount))
        }
    }
}
