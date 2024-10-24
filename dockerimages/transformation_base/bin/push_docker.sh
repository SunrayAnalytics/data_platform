#!/bin/bash
set -e

#if [[ $( git status --porcelain | wc -l) != "0" ]]; then
#    echo "This checkout is dirty refusing to build"
#    exit 1
#fi

#DockerRepository="184065244952.dkr.ecr.eu-west-1.amazonaws.com/transformation-base"
CurrentRevision=$(git rev-parse --short HEAD)
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin ${DockerRepository}:${CurrentRevision}

echo "Pushing image ${DockerRepository}:${CurrentRevision}"
docker push ${DockerRepository}:${CurrentRevision}

docker tag ${DockerRepository}:${CurrentRevision} ${DockerRepository}:latest
docker push ${DockerRepository}:latest
