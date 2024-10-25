#!/bin/bash
set -e

# Gets supplied by terraform
#DockerRepository
CurrentRevision=$(git rev-parse --short HEAD)
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin ${DockerRepository}:${CurrentRevision}

echo "Pushing image ${DockerRepository}:${CurrentRevision}"
docker push ${DockerRepository}:${CurrentRevision}

docker tag ${DockerRepository}:${CurrentRevision} ${DockerRepository}:latest
docker push ${DockerRepository}:latest
