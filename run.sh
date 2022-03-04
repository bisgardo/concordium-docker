#!/usr/bin/env bash

set -euo pipefail

if [ "${#}" -lt 1 ]; then
	>&2 echo "Error: Network parameter not provided."
	exit 1
fi

if [ -z "${NODE_NAME-}" ]; then
	>&2 echo "Error: NODE_NAME variable is not set or empty."
	exit 2
fi

network="${1}"
shift
docker_compose_up_args=("${@}")

env_file="./${network}.env"
if ! [ -f "${env_file}" ]; then
	if [ -e "${env_file}" ]; then
		>&2 echo "Error: Environment file '${env_file}' for network '${network}' is not a regular file."
		exit 3
	fi
	>&2 echo "Error: Environment file '${env_file}' for network '${network}' not found."
	exit 4
fi

# Force Compose to start system with pulled images
# rather than building them from scratch.
#docker-compose --env-file="${env_file}" pull
docker-compose --env-file="${env_file}" up "${docker_compose_up_args[@]}"
