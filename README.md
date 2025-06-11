![image](https://github.com/user-attachments/assets/23a05b6b-d8ea-4cbc-920d-67b41a374e76)

# ERC-7702-TokenSaver

The contract [`TokenSaver`](./src/TokenSaver.sol) shows an example of how smart wallet could be used to avoid any loss by front-running, or running a transaction to a malicious contract. 

I was inspired to create this after reading about this attack: https://drops.scamsniffer.io/transaction-simulation-spoofing-a-new-threat-in-web3/

More information in the [documentation](./DOC.md).

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

### Installation
After installing forge following the [official documentation](https://book.getfoundry.sh/), one should install the dependencies
```shell 

   forge install foundry-rs/forge-std; 
   forge install OpenZeppelin/openzeppelin-contracts;

```
### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

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

**dependency: Geth** - [installation](https://geth.ethereum.org/docs/getting-started/installing-geth)

Before deploying, ensure to **securely store your private key**, preferably in a **keystore file**.

To create a keystore file, first add your private key to a temporary file. Ensure the file contains only the 64-character private key (without the `0x` prefix or any extra spaces or newlines).

```shell
$ vim pk.txt
```
create your keystore using Geth

```shell
 geth account import --keystore ./keystore ./pk.txt
```

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --keystore <path_to_keystore_file>
```

**(Not Recommended)** For a quicker but less secure approach, you can add your private key to an `.env` file. However, this is discouraged as it exposes sensitive information in cleartext. Instead, consider using encrypted keystores.

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key $PRIVATE_KEY
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
