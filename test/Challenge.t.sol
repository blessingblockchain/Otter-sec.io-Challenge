// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

contract ChallengeTest is Test {
    // The runtime bytecode from the contract
    bytes constant RUNTIME_BYTECODE = hex"60205f8037346020525f51465f5260405f2054585460205114911416366020141615602157005b5f80fd";
    
    // Actual contract address on Amoy
    address constant AMOY_CONTRACT = 0xa60Fa8391625163b1760f89DAc94bac2C448f897;
    
    address target;

    function setUp() public {
        // Deploy the runtime bytecode by using vm.etch
        target = address(0x1234);
        vm.etch(target, RUNTIME_BYTECODE);
    }

    // Test Grok's answer: value=0, data=0x0 (empty calldata)
    function test_GrokAnswer_EmptyCalldata() public {
        // value = 0, data = empty (0 bytes)
        (bool success,) = target.call{value: 0}("");
        assertFalse(success, "Empty calldata should fail because calldatasize != 32");
    }

    // Test with 32 bytes of zeros
    function test_ZeroValue_32ZeroBytes() public {
        // value = 0, data = 32 bytes of zeros
        bytes memory data = new bytes(32);
        (bool success,) = target.call{value: 0}(data);
        
        if (success) {
            emit log("SUCCESS: value=0, data=32 zero bytes");
        } else {
            emit log("FAILED: value=0, data=32 zero bytes");
        }
    }

    // Let me trace through the bytecode logic
    // The bytecode checks:
    // 1. calldatasize == 32
    // 2. calldata (as uint256) == storage[keccak256(chainid || callvalue)]
    // 3. callvalue == storage[PC] where PC = 19 (0x13)
    // 
    // Since storage is empty (all zeros):
    // - storage[19] = 0, so callvalue must be 0
    // - storage[hash] = 0, so calldata must be 32 bytes of zeros
    
    function test_CorrectSolution() public {
        uint256 value = 0;
        bytes memory data = abi.encode(uint256(0)); // 32 bytes of zeros
        
        (bool success,) = target.call{value: value}(data);
        assertTrue(success, "Should succeed with value=0 and 32 zero bytes");
    }

    // Debug: let's check what chainid we're using
    function test_DebugChainId() public {
        emit log_named_uint("Current chainid", block.chainid);
        
        // Compute the hash that would be used
        bytes memory hashInput = abi.encode(block.chainid, uint256(0));
        bytes32 hash = keccak256(hashInput);
        emit log_named_bytes32("Hash for (chainid, 0)", hash);
    }

    // Test with various calldata sizes to verify the 32-byte requirement
    function test_WrongCalldataSize() public {
        // 31 bytes - should fail
        bytes memory data31 = new bytes(31);
        (bool success31,) = target.call{value: 0}(data31);
        assertFalse(success31, "31 bytes should fail");

        // 33 bytes - should fail
        bytes memory data33 = new bytes(33);
        (bool success33,) = target.call{value: 0}(data33);
        assertFalse(success33, "33 bytes should fail");
    }

    // Test with non-zero value
    function test_NonZeroValue() public {
        bytes memory data = new bytes(32);
        (bool success,) = target.call{value: 1}(data);
        assertFalse(success, "Non-zero value should fail because storage[19] = 0");
    }
}

// Fork test to verify on actual Amoy testnet
contract AmoyForkTest is Test {
    address constant AMOY_CONTRACT = 0xa60Fa8391625163b1760f89DAc94bac2C448f897;

    // The actual values from the contract storage
    uint256 constant REQUIRED_VALUE = 0x66de8ffda797e3de9c05e8fc57b3bf0ec28a930d40b0d285d93c06501cf6a090;
    bytes32 constant REQUIRED_DATA = 0xd135e49a5b56186fed6c69c6451f8bb83bb42e84b7a3fde2fa8fa4ee0a494636;

    function test_ActualSolution_Fork() public {
        // Fund test contract with enough ETH (this value is HUGE)
        vm.deal(address(this), REQUIRED_VALUE);
        
        bytes memory data = abi.encode(REQUIRED_DATA);
        
        (bool success,) = AMOY_CONTRACT.call{value: REQUIRED_VALUE}(data);
        assertTrue(success, "Should succeed with the actual storage values");
    }

    function test_GrokAnswer_Fork() public {
        // Test Grok's answer on Amoy - should fail
        (bool success,) = AMOY_CONTRACT.call{value: 0}("");
        assertFalse(success, "Grok's answer (empty calldata) should fail on Amoy");
    }

    function test_VerifyChainId() public view {
        require(block.chainid == 80002, "Should be running on Amoy (chainid 80002)");
    }
    
    function test_VerifyStorageValues() public view {
        // Verify that storage slot 19 (0x13) has the expected value
        bytes32 slot19 = vm.load(AMOY_CONTRACT, bytes32(uint256(19)));
        require(slot19 == bytes32(REQUIRED_VALUE), "Storage slot 19 mismatch");
        
        // Verify the hash slot
        bytes32 hashSlot = keccak256(abi.encode(uint256(80002), REQUIRED_VALUE));
        bytes32 hashValue = vm.load(AMOY_CONTRACT, hashSlot);
        require(hashValue == REQUIRED_DATA, "Hash slot mismatch");
    }
}

