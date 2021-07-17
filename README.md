# concordium-docker

A collection of scripts and configuration files to build and deploy a containerized node for the
[Concordium](https://concordium.com) blockchain.

## Build

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

As of the time of this writing, the newest tag is `1.0.1-0`.
The current `main` branch of `concordium-node` has some breaking changes in the way CLI arguments are parsed.
This makes it incompatible with the deployment scripts in the current version of this repo.
The scripts are updated to become compatible on the branch `next` which will get merged
once a commit with the new behavior gets tagged in `concordium-node`.
The updated scripts do not work on commits with the old behavior. 

*Optional*

The build args `ghc_version` and `rust_version` override the default values of 8.10.4 and 1.45.2, respectively.
Additionally, the build arg `extra_features` (defaults to "instrumentation") set
desired feature flags ("collector" is hardcoded so should not be specified).
The feature "profiling" should not be set for reasons documented in the dockerfile.

### `concordium-node-genesis`

Micro image that just holds a genesis data file for the purpose of copying it into the node container on startup.

Build:

```shell
docker build -t concordium-node-genesis:mainnet-1 genesis
```

The image is built with the [initial genesis file](https://distribution.mainnet.concordium.software/data/genesis.dat)
of the Concordium mainnet and tagged accordingly.

*Optional*

The build arg `genesis_file` overrides the genesis file copied into the image.
The file may be specified as a URL or a file located in the `genesis` folder (and the path given relative to this folder).

In case the official source is unavailable, this repo has a backup in `genesis/mainnet-1.dat` which may be used instead: 

```shell
docker build -t concordium-node-genesis:mainnet-1 --build-arg genesis_file=mainnet-1.dat genesis
```

## Build and/or run using Docker Compose

Run a node and collector (image: `concordium-node:<tag>`) with genesis `mainnet-1`
(image: `concordium-node-genesis:mainnet-1`):

```shell
NODE_NAME=my_node \
NODE_TAG=<tag> \
GENESIS_VERSION=mainnet-1 \
NODE_IMAGE=concordium-node:<tag> \
GENESIS_IMAGE=concordium-node-genesis:mainnet-1 \
docker-compose up
```

where `<tag>` is as described above.

The command will build the images automatically if they don't already exist.
Set the flag `--no-build` to prevent that.
The command `... docker-compose build` will only build the images, not start containers.

The variable `NODE_NAME` sets the name to be displayed on the public dashboard.

## CI: Public images

A GitHub Actions CI job for building and pushing the images to
[a public registry](https://hub.docker.com/r/bisgardo/concordium-node) is defined in
[`./.github/workflows/build-push.yaml`](.github/workflows/build-push.yaml).

The images may for example be run using the Docker Compose script like so:

```shell
export NODE_NAME=my_node
export NODE_IMAGE=bisgardo/concordium-node:1.0.1-0_0
export GENESIS_IMAGE=bisgardo/concordium-node-genesis:mainnet-1_0
docker-compose pull # prevent 'up' from building instead of pulling
docker-compose up --no-build
```

Feel free to use these images for testing and experimentation but never trust
random internet strangers' binaries with anything secret or valuable.

Instead, use the [officially released](https://developer.concordium.software/en/mainnet/net/guides/run-node-ubuntu.html)
binaries or build them yourself on trusted hardware.

Be sure to completely understand what all build and deployment files that you are using are doing.
Don't clone this repository in any kind of pipeline to use build anything critical -
use your own copy/fork or just take the files that you need.
By using any files from this repository,
you accept full responsibility of their effect and availability now and in the future,
so review carefully and only apply changes explicitly.
