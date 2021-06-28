# concordium-docker

A collection of scripts and configuration files to build and deploy a containerized node for the Concordium blockchain.

## Build

### `concordium-node`

Dual-purpose Docker image containing the applications `concordium-node` and `node-collector`
(for reporting state to the public [dashboard](https://dashboard.mainnet.concordium.software/)).
The two applications are intended to be run in separate containers instantiated from this image.

Build:

```
docker build -t concordium-node:<tag> --build-arg tag=<tag> .
```

where `<tag>` is the desired commit tag from the
[`concordium-node`](https://github.com/Concordium/concordium-node) code repository.
This tag is also used for the resulting image.

If a branch name is used for `<tag>` (not recommended),
then the `--no-cache` flag should be set to prevent the Docker daemon from caching
the cloned source code at the current commit.

*Optional*

The build args `ghc_version` and `rust_version` override the default values of 8.10.4 and 1.45.2, respectively.
Additionally, the build arg `extra_features` (defaults to "instrumentation") set
desired feature flags ("collector" is hardcoded so should not be specified).
The feature "profiling" should not be set for reasons documented in the dockerfile.

### `concordium-node-genesis`

Micro image that just holds a genesis data file for the purpose of copying it into the node container on startup.

Build:

```
docker build -t concordium-node-genesis:mainnet-1 --build-arg genesis_file=mainnet-1.dat genesis
```

The image is built with the initial genesis file `genesis/mainnet-1.dat`
of the Concordium mainnet and tagged accordingly.

## Run

### Using `docker-compose`

Run a node and collector (image: `concordium-node:<tag>`) with genesis `mainnet-1`
(image: `concordium-node-genesis:mainnet-1`):

```
NODE_NAME=my_node GENESIS_TAG=mainnet-1 NODE_TAG=<tag> docker-compose up
```

The command will build the images automatically if they don't already exist.

The variable `NODE_NAME` sets the name to be displayed on the public dashboard.
