#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

pushd "$SCRIPT_DIR"/..

# DockerRepository

CurrentRevision=$(git rev-parse --short HEAD)

echo "Getting buildtime secrets"
cp ../../../../pip_constraints.txt ./
echo "Building ${DockerRepository}:${CurrentRevision}"
docker build \
    -t ${DockerRepository}:${CurrentRevision} \
    .
rm pip_constraints.txt

popd
