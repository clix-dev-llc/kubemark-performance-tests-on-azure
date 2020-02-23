#! /bin/bash

WORKING_DIR=$(dirname "${BASH_SOURCE[0]}")
ROOT_DIR="${WORKING_DIR}/.."

if [ ! -d "${ROOT_DIR}/reports" ]; then
    mkdir "${ROOT_DIR}/reports"
fi

bash "${WORKING_DIR}/main.sh" | tee "${ROOT_DIR}/reports/build-log.txt"
