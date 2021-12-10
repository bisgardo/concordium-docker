# concordium-docker

A collection of scripts and configuration files to build and deploy a containerized,
dynamically linked node for the [Concordium](https://concordium.com) blockchain.

## Build

By default, the builds run in images based on Debian Buster (10).
Use the build arg `debian_base_image_tag` to use another base.
The only supported value other than `buster` is `stretch` (Debian 9).

### `concordium-node`

Dual-purpose Docker image containing the applications `concordium-node` and `node-collector`
(for reporting state to the public [dashboard](https://dashboard.mainnet.concordium.software/)).
The two applications are intended to be run in separate containers instantiated from this image.

May be build with Docker using the following command or using Docker Compose as described below:

```shell
docker build -t concordium-node:<tag> --build-arg tag=<tag> .
```

where `<tag>` is the desired commit tag from the
[`concordium-node`](https://github.com/Concordium/concordium-node) code repository.
The tag is also used for the resulting Docker image.

If a branch name is used for `<tag>` (not recommended),
then the `--no-cache` flag should be set to prevent the Docker daemon from caching
the cloned source code at the current commit.

The currently active tag (as of 2021-12-10) is `3.0.0-0`.

*Optional*

The build args `ghc_version` and `rust_version` override the default values of 8.10.4 and 1.53.0, respectively.
Additionally, the build arg `extra_features` (defaults to `instrumentation`) set
desired feature flags (`collector` is hardcoded so should not be specified).
Note that when `instrumentation` is set,
`concordium-node` must be started with one of the arguments (CLI flag or environment variable; see the docs)
`prometheus-server` or `prometheus-push-gateway` set.
The feature `profiling` should not be set for reasons explained in the dockerfile.

The full set of supported feature flags may be found in
[`Cargo.toml`](https://github.com/Concordium/concordium-node/blob/main/concordium-node/Cargo.toml),
but it's not well documented.

### `concordium-node-genesis`

Micro image that holds a genesis data file for the purpose of copying it into the node container on startup.

This was originally the preferred method of injecting the file,
but the node now allows its location to be configurable,
allowing it to be passed as a simple bind mount.

To this end, the following genesis files are located in directory [`genesis`](./genesis):
- `mainnet-0.dat`: Initial genesis data for the mainnet ([source](https://distribution.mainnet.concordium.software/data/genesis.dat)).
- `testnet-0.dat`: Initial genesis data for the current testnet ([source](https://distribution.testnet.concordium.com/data/genesis.dat)).

The directory also holds the now-unused dockerfile for the genesis image. See commit 17dde7d for the old instructions.

Note that the genesis file was renamed in commit cf9f7fe.
The corresponding [image](https://hub.docker.com/layers/164803185/bisgardo/concordium-node-genesis/mainnet-1/images/sha256-d4846eceaa6a6b75c1cdfb3d8222aa27be2a9f51acadcb82682ec4efd24dd886?context=repo)
with the old name is deprecated and will be removed.

### `node-dashboard`

Image containing the [`node-dashboard`](https://github.com/Concordium/concordium-node-dashboard.git) web app
for inspecting the state of a locally running node.

To enable the dashboard to communicate with the node over gRPC,
an [Envoy](https://www.envoyproxy.io/) instance must be running to proxy the data.
A working Envoy configuration is stored in [`envoy.yaml`](./node-dashboard/envoy.yaml).

Build:

```shell
docker build -t concordium-node-dashboard:<tag> --build-arg tag=main ./node-dashboard
```

Run:

See [`docker-compose.yaml`](./docker-compose.yaml) for a working run configuration.

## Build and/or run using Docker Compose

Run a node and collector (image: `concordium-node:<tag>`) with genesis `mainnet-0`
(image: `concordium-node-genesis:mainnet-0`):

```shell
NODE_NAME=my_node \
NODE_TAG=<tag> \
DOMAIN=mainnet.concordium.software \
GENESIS_DATA_FILE=./genesis/mainnet-0.dat \
NODE_IMAGE=concordium-node:<tag> \
NODE_DASHBOARD_IMAGE=concordium-node-dashboard:node-<tag> \
docker-compose up
```

where `<tag>` is as described above.
This will spin up the setup configured in [`docker-compose.yaml`](./docker-compose.yaml)
(use `-f` to make it read another file).

The variable `NODE_NAME` sets the name to be displayed on the public dashboard.

The variable `DOMAIN` determines what concrete network the node should join.
The publicly available official options are:

- `mainnet.concordium.software`
- `testnet.concordium.com`

Persistent volumes and container names are namespaced by the domain
in order to allow switching between networks without having to delete data and existing containers.
Note that because ports are fixed, running multiple nodes at the same time will require a few modifications to the current setup.

The command will automatically build the images from scratch if they don't already exist.
Set the flag `--no-build` to prevent that.
To only build the images without starting containers, use the command `... docker-compose build`,
which also supports the option `--build-arg` to override build args in the compose file.
See the [Compose CLI reference](https://docs.docker.com/compose/reference/)
for the full list of commands and arguments.

Running a node without Docker Compose or some other orchestration tool is cumbersome but of course possible:
[Look up](https://docs.docker.com/compose/compose-file/compose-file-v3/) the features used in the Compose file
and [find](https://docs.docker.com/engine/reference/commandline/run/) the corresponding `docker run` args.

## Usage

Run the following command to get a list of supported arguments:

```shell
docker run --rm concordium-node:<tag> /concordium-node --help | less
```

## CI: Public images

A GitHub Actions CI job for building and pushing the images to
[a public registry](https://hub.docker.com/r/bisgardo/concordium-node) is defined in
[`./.github/workflows/build-push.yaml`](.github/workflows/build-push.yaml).

The images may for example be run using the Docker Compose script like so:

```shell
export NODE_NAME=my_node
export DOMAIN=mainnet.concordium.software
export GENESIS_DATA_FILE=./genesis/mainnet-0.dat
export NODE_IMAGE=bisgardo/concordium-node:3.0.0-0_1
export NODE_DASHBOARD_IMAGE=bisgardo/concordium-node-dashboard:node-3.0.0-0_1
docker-compose pull # prevent 'up' from building instead of pulling
docker-compose up --no-build
```

Feel free to use these images for testing and experimentation,
but never trust random internet strangers' binaries with anything secret or valuable.

Instead, use the
[officially released](https://developer.concordium.software/en/mainnet/net/guides/run-node-ubuntu.html)
binaries or build them yourself on trusted hardware.

Be sure to completely understand what all build and deployment files that you are using are doing.
Don't clone this repository in any kind of pipeline to use build anything critical -
use your own copy/fork or just take the files that you need.
By using any files from this repository,
you accept full responsibility of their effect and availability now and in the future,
so review carefully and only apply changes explicitly.
