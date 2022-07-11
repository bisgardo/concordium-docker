# Concordium Docker

A collection of configuration files, documentation, and tools that make up a complete setup
for building and running containerized nodes on the [Concordium](https://concordium.com) blockchain.

## Quick start

Start a Concordium node deployment with node name `<node-name>`
using Docker Compose with publicly available images:

*Testnet*

```shell
NODE_NAME=<node-name> ./run.sh testnet
```

*Mainnet*

```shell
NODE_NAME=<node-name> ./run.sh mainnet
```

## Build/run using Docker Compose

The setup relies on features that are only available in relatively recent versions of Docker Compose.
The `requirements.txt` file specifies a compatible version (the latest v1 release at the time of this writing)
which may be installed (preferably in a [virtualenv](https://docs.python.org/3/library/venv.html))
using `pip install -r requirements.txt`.

The setup has not yet been tested with [Compose v2](https://docs.docker.com/compose/cli-command/).

To run a node, collector, and node dashboard on the mainnet network, adjust and run the following command:

```shell
NODE_NAME=my_node \
NODE_TAG=<tag> \
DOMAIN=mainnet.concordium.software \
GENESIS_DATA_FILE=./concordium/genesis/mainnet-0.dat \
NODE_IMAGE=concordium-node:<tag> \
NODE_DASHBOARD_IMAGE=concordium-node-dashboard:node-<tag> \
COMPOSE_PROFILES=node-dashboard \
docker-compose --project-name=mainnet up
```

where `<tag>` is as described above.
This will spin up the setup configured in [`docker-compose.yaml`](./docker-compose.yaml)
(use `-f` to make it read another file).

The variable `NODE_NAME` sets the name to be displayed on the public dashboard.

The variable `DOMAIN` determines what concrete network the node should join.
The publicly available official options are:

- `mainnet.concordium.software`
- `testnet.concordium.com`

Defining the variable `CONCORDIUM_NODE_LOG_LEVEL_DEBUG` (with any value) enables debug logging for the node.

The node collector starts up with a default delay of 2 mins to avoid filling the log with query errors until the node is ready.
This may be overridden with the variable `NODE_COLLECTOR_DELAY_MS` which takes the delay in milliseconds.
The service restarts automatically if it crashes due to too many unsuccessful connection attempts.

Adding `--project-name=<name>` to `docker-compose up` prepends `<name>` to the names of containers and other persistent resources,
making it possible to switch between networks without having to delete data and existing containers.
Note that because ports are fixed, running multiple nodes at the same time is not supported with the current setup.

Enabling profile `node-dashboard` (i.e. adding `--profile=node-dashboard` or setting `COMPOSE_PROFILES=node-dashboard`)
activates a Node Dashboard instance on port `8099` (and an accompanying Envoy gRPC proxy instance)
to be started up as part of the deployment.

The command will automatically build the images from scratch if they don't already exist.
Set the flag `--no-build` to prevent that.
To only build the images without starting containers, use the command `... docker-compose build`,
which also supports the option `--build-arg` to override build args in the compose file.
See the [Compose CLI reference](https://docs.docker.com/compose/reference/)
for the full list of commands and arguments.

Running a node without Docker Compose or some other orchestration tool is cumbersome but of course possible:
[Look up](https://docs.docker.com/compose/compose-file/compose-file-v3/) the features used in the Compose file
and [find](https://docs.docker.com/engine/reference/commandline/run/) the corresponding `docker run` args.

The deployment may be stopped using `Ctrl-C` (unless running in detached mode) or `docker-compose stop`.
In the latter case, make sure to pass all the same project name, environment variables, etc. as were given to `up`.
In both cases, the default behavior is to send a SIGTERM signal to the running containers with a
[10 sec deadline](https://docs.docker.com/compose/faq/#why-do-my-services-take-10-seconds-to-recreate-or-stop)
for the containers to stop.
Once the deadline has passed, the containers are killed with SIGKILL.
In certain cases (like on startup), the node may need more than a few seconds to terminate gracefully.
It's therefore good practice to increase this deadline using e.g.

```shell
docker-compose stop --timeout=120
```

An even safer option is to only send it a SIGTERM signal:

```shell
docker kill --signal=SIGTERM <container>
```

Stopping the node during the initial out-of-band catchup is not recommended
as it might lead to internal data corruption.

## Run on Kubernetes

A Helm chart is provided in [`./helm-charts/concordium-node`](./helm-charts/concordium-node).

## CI: Public images

A GitHub Actions CI job for building and pushing the images to
[a public registry](https://hub.docker.com/r/bisgardo/concordium-node) is defined in
[`./.github/workflows/build-push.yaml`](.github/workflows/build-push.yaml).

A mainnet node setup may for example be run using the Docker Compose script like so:

```shell
export NODE_NAME=my_node
export DOMAIN=mainnet.concordium.software
export GENESIS_DATA_FILE=./concordium/genesis/mainnet-0.dat
export NODE_IMAGE=bisgardo/concordium-node:<tag>
export NODE_DASHBOARD_IMAGE=bisgardo/concordium-node-dashboard:<tag>
docker-compose pull # prevent 'up' from building instead of pulling
docker-compose --project-name=mainnet up --profile=node-dashboard --no-build
```

The convenience script `run.sh` loads the parameters from a `<network>.env` file
and may simplify this into

```shell
NODE_NAME=my_node ./run.sh <network>
```

For running with [transaction logging](./concordium/node/transaction-logging.md) enabled, use the `+txlog` variant, e.g.:

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

## Development

### Git pre-commit hook

To avoid committing incorrectly formatted YAML (and have it rejected by the CI), a git pre-commit hook can verify it before committing:

The hook is implemented using the [`pre-commit`](https://pre-commit.com/) tool which may be installed using `pip`:

```shell
pip install pre-commit
```

The `requirements.txt` file specifies a compatible version.

Then just run `pre-commit install` from the project root to install the hook that's defined in `.pre-commit-config.yaml`.
