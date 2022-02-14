#!/usr/bin/env bash

set -euxo pipefail

docker-compose --env-file="./${1}.env" pull # prevent 'up' from building instead of pulling
NODE_NAME=qwerty docker-compose --env-file="./${1}.env" up --no-build
