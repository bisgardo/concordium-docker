# Concordium Docker

A collection of configuration files, documentation, and tools that make up a complete setup
for building and running containerized nodes on the [Concordium](https://concordium.com) blockchain.

Complete setups are provided for running a node with Docker Compose or Kubernetes using images that are published publicly or images built by yourself.

To this end, the project contains Docker build files for building the relevant components.

## Repository structure

### Docker build files

The central component of the project is `concordium-node`,
which is a dynamically linked Concordium Node with configurable feature flags and other relevant build parameters.

To provide insights into the operation of the node, `concordium-node-dashboard` is a web-based frontend ...


### Docker Compose spec

### Helm charts

A Helm chart is provided in [`./helm-charts/concordium-node`](./helm-charts/concordium-node).

## Development

### Git pre-commit hook

To avoid committing incorrectly formatted YAML (and have it rejected by the CI),
a git pre-commit hook can verify it before committing:

The hook is implemented using the [`pre-commit`](https://pre-commit.com/) tool which may be installed using `pip`:

```shell
pip install pre-commit
```

The `requirements.txt` file specifies a compatible version.

Then just run `pre-commit install` from the project root to install the hook that's defined in `.pre-commit-config.yaml`.

## CI: Public images

A GitHub Actions CI job for building and pushing the images to
[a public registry](https://hub.docker.com/r/bisgardo/concordium-node) is defined in
[`./.github/workflows/build-push.yaml`](.github/workflows/build-push.yaml).

A mainnet node setup may for example be run using the Docker Compose spec in [`./docker-compose](./docker-compose) like so:

```shell
export NODE_NAME=my_node
export DOMAIN=mainnet.concordium.software
export GENESIS_DATA_FILE=./concordium/genesis/mainnet-0.dat
export NODE_IMAGE=bisgardo/concordium-node:<tag>
export NODE_DASHBOARD_IMAGE=bisgardo/concordium-node-dashboard:<tag>
docker-compose pull # prevent 'up' from building instead of pulling
docker-compose --project-name=mainnet up --profile=node-dashboard --no-build
```

The convenience script `run.sh` loads the parameters from a `vars_<network>.env` file
and may simplify this into

```shell
NODE_NAME=my_node ./run.sh <network>
```

For running with [transaction logging](docker/concordium-node/transaction-logging.md) enabled, use the `+txlog` variant, e.g.:

```shell
export TRANSACTION_LOGGER_PGPASSWORD=<database-password>
export TXLOG_PGPASSWORD=<database-password>
NODE_NAME=my_node ./run.sh <network>+txlog
```

Working environment files that reference the most recently built public images
are provided for Testnet and Mainnet in the directory `./env`.

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
