#!/usr/bin/env bash

# Start a Concordium node deployment using Docker Compose with node images pulled from an external registry.
# 
# Usage:
# 
#   NODE_NAME=<node-name> ./run.sh <network>
# 
# where <network> is the network on which the node is intended to join
# and <node-name> is the name of the node to appear on the dashboard of that network.
# 
# The parameters of the deployment are loaded from an environmnent file <network>.env in the current working directory.
# All images referenced in this file are expected to be pullable from the appropriate image registry.
# 
# Environment files are predefined for the public Testnet and Mainnet networks.
# They reference the newest versions of the images built using a CI workflow in this project (see the readme for details).

set -euo pipefail

if [ "${#}" -lt 1 ]; then
	>&2 echo "Error: Network parameter not provided."
	exit 1
fi
network="${1}"

if [ -z "${NODE_NAME-}" ]; then
	>&2 echo "Error: NODE_NAME variable is not set or empty."
	exit 2
fi


env_file="./${network}.env"
if ! [ -f "${env_file}" ]; then
	if [ -e "${env_file}" ]; then
		>&2 echo "Error: Environment file '${env_file}' for network '${network}' is not a regular file."
		exit 3
	fi
	>&2 echo "Error: Environment file '${env_file}' for network '${network}' not found."
	exit 4
fi

# Invoke 'pull' and then 'up' to force Compose to start from public images rather than building from scratch,
# as that is the default behavior when the 'build' field is set
# (reference: 'https://github.com/compose-spec/compose-spec/blob/master/spec.md#pull_policy').
# Note that not even setting 'pull_policy' to 'always' will force 'up' to pull;
# it will still attempt building (which will then fail because of the flag '--no-build').
docker-compose --env-file="${env_file}" pull
docker-compose --env-file="${env_file}" up --no-build
