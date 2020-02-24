#! /bin/bash

set -e
set -u
set -x

WORKING_DIR=$(dirname "${BASH_SOURCE[0]}")
ROOT_DIR="${WORKING_DIR}/.."

if [ ! -d "${ROOT_DIR}/_artifacts" ]; then
    mkdir "${ROOT_DIR}/_artifacts"
fi

bash "${WORKING_DIR}/main.sh" "$@" | tee "${ROOT_DIR}/_artifacts/build-log.txt"

az logout
unset KUBECONFIG
