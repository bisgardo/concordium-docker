#!/usr/bin/env bash

# Start a Concordium node deployment using Docker Compose with node images pulled from an external registry.
# 
# Usage:
# 
#   NODE_NAME=<node-name> ./run.sh <network>
# 
# where <network> is the network on which the node is intended to join
# and <node-name> is the name of the node to appear on CCDScan for that network.
# 
# The parameters of the deployment are loaded from an environment file <network>.env in the current working directory.
# All images referenced in this file are expected to be pullable from the appropriate image registry.
# 
# Environment files are predefined for the public Testnet and Mainnet networks.
# They reference the newest versions of the images built using a CI workflow in this project (see the readme for details).

set -eo pipefail

export profiles=("${COMPOSE_PROFILES}")

network="${1}"
if [ -z "${network}" ]; then
	>&2 echo "Error: Missing or empty network value (first argument)."
	exit 1
fi

if [ -z "${NODE_NAME-}" ]; then
	>&2 echo "Error: Missing or empty variable 'NODE_NAME'."
	exit 2
fi

files=("docker-compose.yaml")

for arg in "${@}"; do
	profile="${arg#+}"
	if [ "${profile}" != "${arg}" ]; then
		profiles+=("${profile}")
		f="docker-compose.${profile}.yaml"
		if [ -e "${f}" ]; then
			files+=("${f}")
		fi
	fi
done

env_file="./${network}.env"
if ! [ -f "${env_file}" ]; then
	if [ -e "${env_file}" ]; then
		>&2 echo "Error: Environment file '${env_file}' for network '${network}' is not a regular file."
		exit 3
	fi
	>&2 echo "Error: Environment file '${env_file}' for network '${network}' not found."
	exit 4
fi

export COMPOSE_PROFILES
COMPOSE_PROFILES="$(IFS=,; echo "${profiles[*]}")" # join array 'profiles' by ","

args=(--env-file="${env_file}")
for f in "${files[@]}"; do
	args+=(-f "${f}")
done

docker compose "${args[@]}" up
