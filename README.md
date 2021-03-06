# concordium-docker

A collection of scripts and configuration files to build and deploy a containerized,
dynamically linked node for the [Concordium](https://concordium.com) blockchain.

## Quick run

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

## Build

By default, the builds run in images based on Debian Buster (10).
Use the build arg `debian_base_image_tag` to use another base.
The only supported value other than `buster` is `stretch` (Debian 9).

### `concordium-node`

Dual-purpose Docker image containing the applications `concordium-node` and `node-collector`
(for reporting state to the public [dashboard](https://dashboard.mainnet.concordium.software/)).
The two applications are intended to be run in separate containers instantiated from this image.

The image may be build with Docker using the following command or using Docker Compose as described below:

```shell
docker build -t concordium-node:<tag> --build-arg tag=<tag> .
```

where `<tag>` is the desired commit tag from the
[`concordium-node`](https://github.com/Concordium/concordium-node) code repository.
The tag is also used for the resulting Docker image.

If a branch name is used for `<tag>` (not recommended),
then the `--no-cache` flag should be set to prevent the Docker daemon from caching
the cloned source code at the current commit.

The currently active tag (as of 2022-06-20) is `4.2.1-0` for both mainnet and testnet.

*Optional*

The build args `ghc_version` and `rust_version` override the default values of 9.0.2 and 1.53.0, respectively.
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

- `mainnet-0.dat`: Initial genesis data for the mainnet (started on 2021-06-09; [source](https://distribution.mainnet.concordium.software/data/genesis.dat)).
- `testnet-1.dat`: Genesis data for the current testnet (started on 2022-06-13; [source](https://distribution.testnet.concordium.com/data/genesis.dat)).

The directory also holds the now-unused dockerfile for the genesis image. See commit `17dde7d` for the old instructions.

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

See [`docker-compose.yaml`](./docker-compose.yaml) for a working run configuration (set profile `node-dashboard` to enable).

## Build and/or run using Docker Compose

The setup relies on features that are only available in relatively recent versions of Docker Compose.
The `requirements.txt` file specifies a compatible version (the latest v1 release at the time of this writing)
which may be installed (preferably in a [virtualenv](https://docs.python.org/3/library/venv.html))
using `pip install -r requirements.txt`.

The setup has not yet been tested with [Compose v2](https://docs.docker.com/compose/cli-command/).

To run a node and collector with genesis `mainnet-0` on the mainnet network, adjust and run the following command:

```shell
NODE_NAME=my_node \
NODE_TAG=<tag> \
DOMAIN=mainnet.concordium.software \
GENESIS_DATA_FILE=./genesis/mainnet-0.dat \
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

### Metrics

The node exposes a few metrics as a [Prometheus](https://prometheus.io/) scrape endpoint on port `9090`.
If profile `prometheus` is enabled, a Prometheus [instance](https://hub.docker.com/r/prom/prometheus)
that is configured to scrape itself and the node (see [prometheus.yml](./prometheus.yml) for the configuration)
is started as well.
The web UI of that service is exposed to the host on port `9009`.

### Backing up persisted data

Data in a persisted volume may be mounted into a throwaway container and backed up from there,
for instance by archiving it into a bind mount.

The data compresses well with LZMA (usually uses `.xz` extension).
The dockerfile `backup.Dockerfile` builds an image that supports that format:

```shell
docker build -f backup.Dockerfile -t concordium-backup --pull .
```

As an example, the following command archives the contents of a volume `data` (excluding any `blocks.mdb` file with OOB catchup data)
into a file `./backup/data.tar.xz` located in a bind mount:

```shell
docker run --rm --volume=data:/data --volume="${PWD}/backup":/backup --workdir=/ concordium-backup tar -Jcf ./backup/data.tar.xz --exclude=blocks.mdb  ./data
```

Restoring the backup at `./backup/data.tar.xz` into a fresh (or properly wiped) volume `data`
is then just a matter of extracting instead of creating:

```shell
docker run --rm --volume=data:/data --volume="${PWD}"/backup:/backup --workdir=/ concordium-backup tar -xf ./backup/data.tar.xz
```

## Usage

Run the following command to get a list of supported arguments:

```shell
docker run --rm concordium-node:<tag> /concordium-node --help | less
```

## Transaction logging

The Concordium Node includes the ability to
[log transactions to an external PostgreSQL database](https://github.com/Concordium/concordium-node/blob/main/docs/transaction-logging.md).
Due to various shortcomings, this feature is now deprecated in favor of an equivalent
[independent service](https://github.com/Concordium/concordium-transaction-logger):
The service is deployed separately, handles errors gracefully,
and may run against multiple nodes that don't need any particular configuration or state.
The DB schemas are documented in the links above.
This project used to support the legacy method, but this was removed in commit `6933166`.

The Docker Compose file includes a transaction logger instance under the profile `txlog`.
The [image](https://hub.docker.com/r/concordium/transaction-logger/tags) is specified with the variable `TRANSACTION_LOGGER_IMAGE`.

Database credentials etc. are configured with the following variables:

- `TXLOG_PGDATABASE` (default: `concordium_txlog`): Name of the database in the PostgreSQL instance created for the purpose.
- `TXLOG_PGHOST` (default: `172.17.0.1`): DNS or IP address of the host.
  The default value assumes that the PostgreSQL instance is running natively, i.e. outside of Docker.
- `TXLOG_PGPORT` (default: `5432`): Port of the PostgreSQL instance.
- `TXLOG_PGUSER` (default: `postgres`): Username of the PostgreSQL user used to log the transactions.
- `TXLOG_PGPASSWORD`: Password of the PostgreSQL user.

The variables may be passed to the `docker-compose` command above or persisted in a `.env` file as described below
(see [`testnet+txlog.env`](./testnet+txlog.env) and [`mainnet+txlog.env`](./mainnet+txlog.env);
note that `TXLOG_PGPASSWORD` still has to be passed explicitly).

See [`postgresql.md`](./postgresql.md) for instructions on how to set up a local database.

## CI: Public images

A GitHub Actions CI job for building and pushing the images to
[a public registry](https://hub.docker.com/r/bisgardo/concordium-node) is defined in
[`./.github/workflows/build-push.yaml`](.github/workflows/build-push.yaml).

A mainnet node setup may for example be run using the Docker Compose script like so:

```shell
export NODE_NAME=my_node
export DOMAIN=mainnet.concordium.software
export GENESIS_DATA_FILE=./genesis/mainnet-0.dat
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

For running with [transaction logging](#transaction-logging) enabled, use the `+txlog` variant, e.g.:

```shell
export TRANSACTION_LOGGER_PGPASSWORD=<database-password>
export TXLOG_PGPASSWORD=<database-password>
NODE_NAME=my_node ./run.sh <network>+txlog
```

Working environment files that reference the most recently built public images
are provided for Testnet and Mainnet.

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
