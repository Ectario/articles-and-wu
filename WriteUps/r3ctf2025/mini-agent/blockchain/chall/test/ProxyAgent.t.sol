// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

contract RandomTest {
    uint r = 10;
    function very_random_value() external returns (uint256) {
        r += 1;
        return r;
    }
}

contract Impl {

    function test_no_pure_view(address randomizer) public returns (uint256) {
        return RandomTest(randomizer).very_random_value();
    }

    function ping() external pure returns (uint256) {
        return 42;
    }

    function tick(uint256 a, uint256 b) external pure returns (uint256, uint256, uint256) {
        return (a + 1, b + 1, 42);
    }
}


contract ProxyTest is Test {
    function test_ProxyDelegation() external {
        Impl impl = new Impl();
        console.log("Implementation contract deployed at:", address(impl));

        bytes memory proxyBytecode = abi.encodePacked(
            hex"602780600a5f395ff3fe365f80375f80368173",
            bytes20(address(impl)),
            hex"5afa503d5f803e3d5ff3"
        );
        
        console.log("Proxy bytecode length:", proxyBytecode.length);
        assertTrue(proxyBytecode.length < 100, "Bytecode should be under 100 bytes");

        address proxyAddress;
        assembly {
            // create(value, offset, size)
            proxyAddress := create(0, add(proxyBytecode, 0x20), mload(proxyBytecode))
        }
        require(proxyAddress != address(0), "Proxy deployment failed");
        console.log("Proxy contract deployed at:", proxyAddress);

        (bool success, bytes memory result) = proxyAddress.staticcall(
            abi.encodeWithSelector(Impl.ping.selector)
        );
        require(success, "staticcall to ping() failed");
        assertEq(abi.decode(result, (uint256)), 42, "Returned value from ping() is incorrect");
        console.log("ping() via proxy returned:", abi.decode(result, (uint256)));
    }

    function test_tickDelegation() public {
        Impl impl = new Impl();

        bytes memory proxyBytecode = abi.encodePacked(
            hex"602780600a5f395ff3fe365f80375f80368173",
            bytes20(address(impl)),
            hex"5afa503d5f803e3d5ff3"
        );
        address proxy;
        assembly {
            proxy := create(0, add(proxyBytecode, 0x20), mload(proxyBytecode))
            if iszero(proxy) { revert(0, 0) }
        }

        (bool ok, bytes memory res) = proxy.staticcall(
            abi.encodeWithSelector(Impl.tick.selector, 10, 20)
        );
        require(ok, "tick staticcall failed");

        (uint256 a1, uint256 b1, uint256 pr) =
            abi.decode(res, (uint256, uint256, uint256));
        assertEq(a1, 11, "fromWhich wrong");
        assertEq(b1, 21, "toWhich wrong");
        assertEq(pr, 42, "pr wrong");
    }

    function test_call_and_storage_modified() public {
        Impl impl = new Impl();
        RandomTest randomizer = new RandomTest();

        bytes memory proxyBytecode = abi.encodePacked(
            hex"602780600a5f395ff3fe365f80375f80368173",
            bytes20(address(impl)),
            hex"5afa503d5f803e3d5ff3"
        );
        address proxy;
        assembly {
            proxy := create(0, add(proxyBytecode, 0x20), mload(proxyBytecode))
            if iszero(proxy) { revert(0, 0) }
        }

        (bool ok, bytes memory res) = proxy.staticcall(
            abi.encodeWithSelector(Impl.test_no_pure_view.selector, address(randomizer))
        );
        require(ok, "randomizer staticcall failed");

        (uint256 r) =
            abi.decode(res, (uint256));
        assertEq(r, 11, "randomizer value wrong");
    }
}