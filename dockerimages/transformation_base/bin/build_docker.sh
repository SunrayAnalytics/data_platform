#!/bin/bash
set -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

pushd $SCRIPT_DIR/..

#if [[ $( git status --porcelain . | wc -l) != "0" ]]; then
#    echo "This checkout is dirty refusing to build"
#    exit 1
#fi

CFN_EXPORTS=$(aws cloudformation list-exports | jq '.Exports | map({"key": .Name, "value": .Value}) | from_entries')
DockerRepository=$(echo "$CFN_EXPORTS" | jq -r '."TransformRepositoryUri-transform"')
CurrentRevision=$(git rev-parse --short HEAD)

DockerRepository="184065244952.dkr.ecr.eu-west-1.amazonaws.com/transformation-base"

pwd
echo "Building ${DockerRepository}:${CurrentRevision}"
cp ../../pip_constraints.txt ./
docker build \
    -t ${DockerRepository}:${CurrentRevision} \
    .
rm pip_constraints.txt
popd
