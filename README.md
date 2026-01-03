# OtterSec Challenge Solution

## Challenge

A contract is deployed on the Polygon Amoy Testnet at [`0xa60Fa8391625163b1760f89DAc94bac2C448f897`](https://amoy.polygonscan.com/address/0xa60Fa8391625163b1760f89DAc94bac2C448f897#code).

**Task:** Find a combination of `tx.value` and `tx.data` that does not result in a revert.

---

## Solution

```python
>>> value = 0x66de8ffda797e3de9c05e8fc57b3bf0ec28a930d40b0d285d93c06501cf6a090
>>> data = 0xd135e49a5b56186fed6c69c6451f8bb83bb42e84b7a3fde2fa8fa4ee0a494636
>>> print('answer: 0x%064x%064x' % (value, data))
answer: 0x66de8ffda797e3de9c05e8fc57b3bf0ec28a930d40b0d285d93c06501cf6a090d135e49a5b56186fed6c69c6451f8bb83bb42e84b7a3fde2fa8fa4ee0a494636
```

---

## Approach

### 1. Bytecode Retrieval & Disassembly

Retrieved the runtime bytecode from Polygonscan:

```
0x60205f8037346020525f51465f5260405f2054585460205114911416366020141615602157005b5f80fd
```

Fully disassembled to understand the control flow. See [`SOLUTION.md`](./SOLUTION.md) for the complete opcode breakdown.

### 2. Control Flow Analysis

The contract reaches `STOP` (success) only when **all three conditions** are satisfied:

```
success = (calldatasize == 32) 
        && (msg.value == storage[19]) 
        && (calldata == storage[keccak256(chainid || msg.value)])
```

Key insights:
- Uses `PC` opcode at offset `0x13` to create a self-referencing storage key (slot 19)
- Uses `CHAINID` opcode, binding the solution to Polygon Amoy (chainid 80002)
- Uses `PUSH0` (0x5f), indicating post-Shanghai EVM bytecode

### 3. On-Chain Storage Queries

```bash
# Query storage slot 19 for required msg.value
cast storage 0xa60Fa8391625163b1760f89DAc94bac2C448f897 0x13 --rpc-url https://rpc-amoy.polygon.technology
# → 0x66de8ffda797e3de9c05e8fc57b3bf0ec28a930d40b0d285d93c06501cf6a090

# Compute the derived hash slot
cast keccak256 $(cast abi-encode "f(uint256,uint256)" 80002 0x66de8ffda797e3de9c05e8fc57b3bf0ec28a930d40b0d285d93c06501cf6a090)
# → 0x9a7c6623207a1c3a727a6bf353300be7fb9bda1c9e094cb9724c54a0fbda1b5e

# Query the hash slot for required calldata
cast storage 0xa60Fa8391625163b1760f89DAc94bac2C448f897 0x9a7c6623207a1c3a727a6bf353300be7fb9bda1c9e094cb9724c54a0fbda1b5e --rpc-url https://rpc-amoy.polygon.technology
# → 0xd135e49a5b56186fed6c69c6451f8bb83bb42e84b7a3fde2fa8fa4ee0a494636
```

### 4. Verification

Verified via Foundry fork test against the live Amoy testnet:

```bash
forge test --fork-url https://rpc-amoy.polygon.technology --match-contract AmoyForkTest -vvv
```

All tests pass, confirming the solution works on the actual deployed contract.

---

## Project Structure

```
├── README.md           # This file
├── SOLUTION.md         # Detailed technical write-up with opcode table
├── foundry.toml        # Foundry configuration
├── src/                # Source contracts
└── test/
    └── Challenge.t.sol # Foundry tests including fork verification
```

---

## Run Tests Locally

```bash
# Install Foundry if needed
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Run local tests
forge test -vvv

# Run fork tests against Amoy
forge test --fork-url https://rpc-amoy.polygon.technology --match-contract AmoyForkTest -vvv
```

---

## Tools Used

- [Foundry](https://github.com/foundry-rs/foundry) - Smart contract development toolkit
- [cast](https://book.getfoundry.sh/cast/) - CLI for EVM interactions
- [Polygonscan](https://amoy.polygonscan.com/) - Block explorer for bytecode retrieval
