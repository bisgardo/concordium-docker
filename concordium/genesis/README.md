# Genesis data

Micro image that holds a genesis data file for the purpose of copying it into the node container on startup.

This was originally the preferred method of injecting the file,
but the node now allows its location to be configurable,
allowing it to be passed as a simple bind mount.

To this end, the following genesis files are located in directory [`genesis`](concordium/genesis):

- `mainnet-0.dat`: Initial genesis data for the mainnet (started on 2021-06-09; [source](https://distribution.mainnet.concordium.software/data/genesis.dat)).
- `testnet-1.dat`: Genesis data for the current testnet (started on 2022-06-13; [source](https://distribution.testnet.concordium.com/data/genesis.dat)).

The directory also holds the now-unused dockerfile for the genesis image. See commit `17dde7d` for the old instructions.
