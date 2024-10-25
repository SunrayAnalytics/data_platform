#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

AirbyteConfigDir="${SCRIPT_DIR}/../config/airbyte"

docker run -i --rm \
    --name octavia-cli \
    -v ${AirbyteConfigDir}:/home/octavia-project \
    --network host \
    --env-file $HOME/.octavia \
    --user "$(id -u):$(id -g)" \
    airbyte/octavia-cli:0.42.1 "$@"
