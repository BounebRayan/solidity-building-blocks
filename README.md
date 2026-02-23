## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

Tests live in `test/` and use [Foundry’s Solidity test framework](https://book.getfoundry.sh/forge/writing-tests). Run with `-vv` or `-vvv` for more output.

- **`setUp()`** – Runs before each test; use it to deploy the contract and set up addresses (e.g. `vm.deal` for ETH).
- **`vm.prank(user)`** – Next call is made as `user` (one call). Use **`vm.startPrank(user)`** / **`vm.stopPrank()`** for multiple calls.
- **`vm.expectRevert(CustomError.selector)`** – Assert the next call reverts with that custom error.
- **`assertEq(a, b)`** – Assert equality. Use for balances, return values, etc.
- **`vm.expectEmit(...)`** – Assert the next call emits a specific event.

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
