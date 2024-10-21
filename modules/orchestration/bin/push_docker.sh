#!/bin/bash
set -e

#CFN_EXPORTS=$(aws cloudformation list-exports | jq '.Exports | map({"key": .Name, "value": .Value}) | from_entries')
#DockerRepository=$(echo "$CFN_EXPORTS" | jq -r '."DagitRepositoryUri-transform"')
DockerRepository="184065244952.dkr.ecr.eu-west-1.amazonaws.com/dagit" # TODO Get this from environment configuration
CurrentRevision=$(git rev-parse --short HEAD)
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin ${DockerRepository}:${CurrentRevision}

echo "Pushing image ${DockerRepository}:${CurrentRevision}"
docker push ${DockerRepository}:${CurrentRevision}

docker tag ${DockerRepository}:${CurrentRevision} ${DockerRepository}:latest
docker push ${DockerRepository}:latest
