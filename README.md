# concordium-docker

A collection of scripts and configuration files to build and deploy a containerized,
dynamically linked node for the [Concordium](https://concordium.com) blockchain.

## Quickstart

Start a Concordium Node deployment with name `<node-name>`
using Docker Compose with [pre-built images](#ci-public-images):

*Testnet*

```shell
NODE_NAME=<node-name> ./run.sh testnet
```

*Mainnet*

```shell
NODE_NAME=<node-name> ./run.sh mainnet
```

### Additional Features

The default deployment is minimal; consisting only of a node and collector.
Instances of additional services and configurations are available as "features" that may be enabled individually.

To enable a given feature, append `+` followed by the name of the feature to the command above.

The following features are available:

- [Prometheus](#metrics) (metrics): `+prometheus`
- [Transaction Logger](#transaction-logging): `+txlog`
- [Rosetta](#rosetta): `+rosetta`
- [CCDScan](#ccdscan): `+ccdscan`

*Example*

Run a node with name `<node-name>` and connected instances of Prometheus and Transaction Logger on network `<network>`:

```shell
NODE_NAME=<node-name> ./run.sh <network> +prometheus +txlog
```

## Build

By default, the builds run in images based on Debian Bullseye (11).
The build arg `debian_release` may be used to select another Debian release
(though historically, the official Haskell image don't seem to support more than one Debian version for any given GHC version).

### `concordium-node`

Dual-purpose Docker image containing the applications `concordium-node` and `node-collector`
(for reporting state to the public [dashboard](https://dashboard.mainnet.concordium.software)).
The two applications are intended to run in separate containers instantiated from this image.

The image may be build with Docker using the following command or using Docker Compose as described below:

```shell
docker build -t concordium-node:<tag> --build-arg=tag=<tag> .
```

where `<tag>` is the desired commit tag from the
[`concordium-node`](https://github.com/Concordium/concordium-node) code repository.
The tag is also used for the resulting Docker image.

If a branch name is used for `<tag>` (not recommended),
then the `--no-cache` flag should be set to prevent the Docker daemon from using a
previously cached clone of the source code at an older version of the branch.

The latest tag may be found in the [official repository](https://github.com/Concordium/concordium-node/tags).
However, the tags don't always match the currently deployed software versions on both networks.

You may also check the tags of the [public images](#ci-public-images) (the part before `_`)
to see what Concordium Node tag was used in the latest build (and which networks' .env files have been updated to use it).
However, this repo not being updated regularly, so this information is prone to being outdated.

*Optional*

The versions of external tools used in the build are defined as the default values of build arguments.
This is mostly done to keep them in one place as a set of constants, but also means that they can be overriden at build time.
See the top of the dockerfile for the available set of args.

### `concordium-node-genesis`

Micro image that holds a genesis data file for the purpose of copying it into the node container on startup.

This was originally the preferred method of injecting the file,
but the node now allows its location to be configurable,
allowing it to be passed as a simple bind mount.

To this end, the following genesis files are located in directory [`genesis`](./genesis):

- `mainnet-0.dat`: Initial genesis data for Mainnet (started on 2021-06-09; [source](https://distribution.mainnet.concordium.software/data/genesis.dat)).
- `testnet-1.dat`: Genesis data for Testnet (started on 2022-06-13; [source](https://distribution.testnet.concordium.com/data/genesis.dat)).

The directory also holds the now-unused dockerfile for the genesis image. See commit `17dde7d` for the old instructions.

## Build and/or run using Docker Compose

The project includes a full Docker Compose (v2) deployment for running a node and collector,
optionally along with a set of related services (each of which is enabled individually).
Instructions on how to install the Compose plugin are given in the [official documentation](https://docs.docker.com/compose/install/).

The project has been tested with Compose v2.20.2.

The main setup is configured in [`docker-compose.yaml`](./docker-compose.yaml)
and is thoroughly parameterized to work with any Concordium blockchain network (including unofficial ones).

To build and run a node/collector instance on Mainnet with Prometheus enabled, adjust and run the following command:

```shell
NODE_NAME=my_node \
NODE_TAG=<tag> \
DOMAIN=mainnet.concordium.software \
GENESIS_DATA_FILE=./genesis/mainnet-0.dat \
NODE_IMAGE=concordium-node:<tag> \
COMPOSE_PROFILES=prometheus \
docker compose --project-name=mainnet up
```

where `<tag>` is as described above.

The variable `NODE_NAME` sets the name to be displayed on [CCDScan](https://ccdscan.io/nodes).

The variable `DOMAIN` determines which concrete network to join.
The publicly available official options are:

- `mainnet.concordium.software`
- `testnet.concordium.com`

Defining the variable `CONCORDIUM_NODE_LOG_LEVEL_DEBUG` (with any value) enables debug logging for the node.

The node collector starts up with a default delay of 30s to avoid filling the log with query errors until the node is ready.
This may be overridden with the variable `NODE_COLLECTOR_DELAY_MS` which takes the delay in milliseconds.
The service restarts automatically if it crashes due to too many unsuccessful connection attempts.

By default the node collector uses gRPC APIv2 (on port 11000).
To support running older images, this value may be overridden using the variable `NODE_COLLECTOR_PORT`.

Adding `--project-name=<name>` to `docker compose up` prepends `<name>` to the names of containers and other persistent resources,
making it possible to switch between networks without having to delete data and existing containers.
Note that because ports are fixed, running multiple nodes at the same time is not supported with the current setup.

The command will automatically build the images from scratch if they don't already exist.
Set the flag `--no-build` to prevent that.
To only build the images without starting containers, use the command `... docker compose build`,
which also supports the option `--build-arg` to override build args in the compose file.
See the [Compose CLI reference](https://docs.docker.com/compose/reference/)
for the full list of commands and arguments.

Running a node without Docker Compose or some other orchestration tool is cumbersome but of course possible:
[Look up](https://docs.docker.com/compose/compose-file/compose-file-v3/) the features used in the Compose file
and [find](https://docs.docker.com/engine/reference/commandline/run/) the corresponding `docker run` args.

The deployment may be stopped using `Ctrl-C` (unless running in detached mode) or `docker compose stop`.
In the latter case, make sure to pass all the same project name, environment variables, etc. as were given to `up`.
In both cases, the default behavior is to send a SIGTERM signal to the running containers with a
[10 sec deadline](https://docs.docker.com/compose/faq/#why-do-my-services-take-10-seconds-to-recreate-or-stop)
for the containers to stop.
Once the deadline has passed, the containers are killed with SIGKILL.
In certain cases (like on startup), the node may need more than a few seconds to terminate gracefully.
It's therefore good practice to increase this deadline using e.g.

```shell
docker compose stop --timeout=120
```

An even safer option is to only send it a SIGTERM signal:

```shell
docker kill --signal=SIGTERM <container>
```

Stopping the node during OOB catchup (see below) is not recommended
as it's been seen to cause internal data corruption in the past.

### Out-of-band (OOB) catchup

When the node needs to catch up a large number of blocks (like when it's starting from scratch),
it may minimize its network activity by importing blocks "out-of-band".

The Concordium Foundation publishes archived chunks of blocks once per day for Mainnet and Testnet.
The feature for downloading and ingesting these archives is enabled by default.

While running in catchup mode, the node will not have any peers.

The OOB feature used to be implemented in a way that required the user
to download one big archive in advance of starting the node.
The new mode is supported by recent node versions only.
Support for the old mode was removed from this project in commit `bdd0731`.

### Metrics

The node exposes a few metrics as a [Prometheus](https://prometheus.io) scrape endpoint on port `9090`.
If profile `prometheus` is enabled, a Prometheus [instance](https://hub.docker.com/r/prom/prometheus)
that is configured to scrape itself and the node is started as well.
See [prometheus.yml](./metrics/prometheus.yml) for the configuration.
The web UI of that service is exposed to the host on port `9009`.

The Prometheus server may also serve as a Grafana data source for powering advanced dashboards.
See this project's [metrics documentation](./metrics/README.md) for details.

### Backing up persisted data

Data in a persisted volume may be mounted into a throwaway container and backed up from there,
for instance by archiving it into a bind mount.

The data compresses well with LZMA (usually uses `.xz` extension).
The dockerfile `backup.Dockerfile` builds an image that supports that format:

```shell
docker build -f ./backup.Dockerfile -t concordium-backup --pull .
```

As an example, the following command archives the contents of a volume `data` into a file `./backup/data.tar.xz` located in a bind mount:

```shell
docker run --rm --volume=data:/mnt/data --volume="${PWD}/backup":/mnt/backup --workdir=/mnt concordium-backup tar -Jcf ./backup/data.tar.xz ./data
```

Restoring the backup at `./backup/data.tar.xz` into a fresh (or properly wiped) volume `data`
is then just a matter of extracting instead of creating:

```shell
docker run --rm --volume=data:/mnt/data --volume="${PWD}"/backup:/mnt/backup --workdir=/mnt concordium-backup tar -xf ./backup/data.tar.xz
```

## Usage

Run the following command to get a list of supported arguments:

```shell
docker run --rm concordium-node:<tag> /concordium-node --help | less
```

## Transaction logging

The Concordium Node used to include the ability to log transactions to an external PostgreSQL database.
Due to various shortcomings, this feature has been removed in favor of an equivalent service
[`concordium-transaction-logger`](https://github.com/Concordium/concordium-transaction-logger).
This service is deployed separately, handles errors gracefully,
and may run against multiple nodes that don't need any particular configuration or state.
The DB schemas are documented in the readme of the logger service.

The Docker Compose file includes a transaction logger service under the profile `txlog`.
The [image](https://hub.docker.com/r/concordium/transaction-logger/tags) is specified with the variable `TRANSACTION_LOGGER_IMAGE`.

Database credentials etc. are configured with the following variables:

- `TXLOG_PGDATABASE` (default: `concordium_txlog`): Name of the database in the PostgreSQL instance created for the purpose.
- `TXLOG_PGHOST` (default: `172.17.0.1`): DNS or IP address of the host.
  The default value assumes that the PostgreSQL instance is running natively, i.e. outside of Docker.
- `TXLOG_PGPORT` (default: `5432`): Port of the PostgreSQL instance.
- `TXLOG_PGUSER` (default: `postgres`): Username of the PostgreSQL user used to log the transactions.
- `TXLOG_PGPASSWORD`: Password of the PostgreSQL user.
- `TXLOG_QUERY_CONCURRENCY` (default: 4): Number of threads to allocate for querying the node's gRPC interface.
  This value of this variable only matters when catching up a large number of blocks -
  setting it to 1 is fine during normal operation.

The variables may be passed to the `docker compose` command above or persisted in a `.env` file as described below
(see [`testnet.env`](./testnet.env) and [`mainnet.env`](./mainnet.env);
note that `TXLOG_PGPASSWORD` still has to be passed explicitly).

See [`postgresql.md`](./postgresql.md) for instructions on how to set up a local database.

## Rosetta

The Docker Compose file supports running an instance of the [Concordium implementation](https://github.com/Concordium/concordium-rosetta)
of the [Rosetta](https://www.rosetta-api.org/) API under the profile `rosetta`.
The server registers itself on port `8086`.
The [image](https://hub.docker.com/r/concordium/rosetta/tags) to deploy is specified with the variable `ROSETTA_IMAGE`.
To avoid initial crash-looping until the node is up,
the variable `ROSETTA_STARTUP_DELAY_SECS` sets an optional delay (defaults to 1 min) before the service is started.

The [`network_identifier`](https://github.com/Concordium/concordium-rosetta#identifiers) expected by the instance is

```shell
{"blockchain": "concordium", "network": "<project name>"}
```

where `<project name>` is the Compose project name; i.e. the value of `--project-name`
or the `<network>` parameter of `./run.sh`.

See the [official documentation](https://github.com/Concordium/concordium-rosetta) of `concordium-rosetta`
for more details about this application.

## CCDScan

Enabling the override `ccdscan` activates an instance of CCDScan as part of the deployment.
The backend is exposed on port `5000` and the frontend on port `5080`.
The frontend is built from a custom dockerfile with a configuration that makes it independent of Firebase.
The backend is deployed from an image in the [public repository](https://hub.docker.com/r/concordium/ccdscan/)
or one [built separately](https://github.com/Concordium/concordium-scan/blob/main/backend/Dockerfile).

## CI: Public images

A GitHub Actions CI job for building and pushing the images to
[a public registry](https://hub.docker.com/r/bisgardo/concordium-node) is defined in
[`./.github/workflows/build-push.yaml`](.github/workflows/build-push.yaml).

For example, a Mainnet node setup that includes a Prometheus instance may be run using the Docker Compose script like so:

```shell
export NODE_NAME=my_node
export DOMAIN=mainnet.concordium.software
export GENESIS_DATA_FILE=./genesis/mainnet-0.dat
export NODE_IMAGE=bisgardo/concordium-node:<tag>
docker compose pull # prevent 'up' from building instead of pulling
docker compose --project-name=mainnet up --profile=prometheus --no-build
```

The convenience script [`run.sh`](./run.sh) expects to find a file `./<network>.env`
([`mainnet.env`](./mainnet.env) and [`testnet.env`](./testnet.env) being provided with the repo)
from which it loads the deployment parameters and network-specific values:

```shell
NODE_NAME=my_node ./run.sh <network> [+<feature>...]
```

where `<feature>` is a Compose profile to be enabled and/or an override to be applied ([list](#additional-features)).

An override `<feature>` is a file `docker-compose.<feature>.yaml` which - if it exists - get merged
onto the "base" `docker-compose.yaml` file.
Multiple profiles/overrides may be enabled by appending a `+` argument for each of them.
Overrides are applied in the order of the enabling arguments.

This mechanism provides a flexible way for users to reconfigure and extend the deployment
by adding their own override files to modify existing services, extend existing profiles, define new profiles, etc.

Note that `run.sh` doesn't follow Compose's
[default behavior](https://docs.docker.com/compose/extends/#understanding-multiple-compose-files)
of applying `docker-compose.override.yaml` automatically (it could still be enabled manually with the option `+override`).

Using `run.sh`, the example above simplifies to

```shell
NODE_NAME=my_node ./run.sh mainnet +prometheus
```

To instead enable [transaction logging](#transaction-logging), append `+txlog` and pass the DB password:

```shell
TXLOG_PGPASSWORD=<database-password> NODE_NAME=my_node ./run.sh <network> +txlog
```

The .env files reference the most recently published images,
where the version is compatible with the "currently active" tag of the corresponding network
(as of the time the image was built).
The tag of a given image mathes the tag of the git commit that Concordium Node was built from
followed by an additional "build version" component (the part after `_`)
The build version starts at 0 for any given Node tag and is bumped whenever a new build is pushed for that same tag
(for example when building with an updated compiler).

### Disclaimer

Feel free to use these images for testing and experimentation,
but never trust random internet strangers' pre-built binaries with anything secret or valuable.

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
