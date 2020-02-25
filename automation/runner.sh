#! /bin/bash

set -e
set -u
set -x

WORKING_DIR=$(dirname "${BASH_SOURCE[0]}")

if [ ! -d "/logs/artifacts" ]; then
    mkdir -p "/logs/artifacts"
fi

bash "${WORKING_DIR}/main.sh" "$@" | tee "$/logs/artifacts/build-log.txt"

az logout
unset KUBECONFIG
