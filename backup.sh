#!/usr/bin/env sh

set -eux

# Keep group 'root' to access files...
env="${1}"

docker run --rm --volume=${env}_data:/data --volume="${PWD}"/backup:/backup --workdir=/ --user="${UID}" --pull busybox:stable tar -cf ./backup/${env}-data.tar ./data
