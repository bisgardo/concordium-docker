#!/usr/bin/env sh

# This is quite brittle and will break if the command changes to e.g. '--stack-yaml=...'.
if [ "${1}" = --stack-yaml ] && [ "${2}" = ../concordium-consensus/stack.yaml ] && [ "${3}" = path ] && [ "${4}" = --local-install-root ]; then
	echo /consensus-libs/local
	echo /consensus-libs/local >> /stack.out
elif [ "${1}" = --stack-yaml ] && [ "${2}" = ../concordium-consensus/stack.yaml ] && [ "${3}" = ghc ] && [ "${4}" = -- ] && [ "${5}" = --print-libdir ]; then
	echo /consensus-libs/ghc
	echo /consensus-libs/ghc >> /stack.out
else
	>&2 echo "Unsupported command: '${*}'" >> /stack.out
	exit 1
fi
