#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

pushd "$SCRIPT_DIR"/..

#if [[ $( git status --porcelain . | wc -l) != "0" ]]; then
#    echo "This checkout is dirty refusing to build"
#    exit 1
#fi
#CFN_EXPORTS=$(aws cloudformation list-exports | jq '.Exports | map({"key": .Name, "value": .Value}) | from_entries')
#DockerRepository=$(echo "$CFN_EXPORTS" | jq -r '."DagitRepositoryUri-transform"')
DockerRepository="184065244952.dkr.ecr.eu-west-1.amazonaws.com/dagit" # TODO Get this from environment configuration

echo "Reading the repository URL from the stack"

CurrentRevision=$(git rev-parse --short HEAD)

echo "Getting buildtime secrets"

echo "Building ${DockerRepository}:${CurrentRevision}"
docker build \
    -t ${DockerRepository}:${CurrentRevision} \
    .
popd
