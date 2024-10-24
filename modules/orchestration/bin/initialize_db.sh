#!/bin/bash

set -e

# BASTION_INSTANCE_ID
# DOMAIN_NAME
# TODO Do not hardcode the name of the ssh-key like this
aws ec2-instance-connect send-ssh-public-key \
    --ssh-public-key "file://${HOME}/.ssh/id_ed25519.pub" \
    --instance-id ${BASTION_INSTANCE_ID} \
    --instance-os-user ec2-user

ssh -o StrictHostKeyChecking=no -L 5433:postgres.${DOMAIN_NAME}:5432 -N ec2-user@bastion.${DOMAIN_NAME} &
TUNNEL_PID=$!
TUNNEL_STATUS=$?

if [[ ${TUNNEL_STATUS} -ne 0 ]]; then
  echo "Failed to establish tunnel"
  kill -9 $TUNNEL_PID
  exit 1
fi
sleep 3

aws secretsmanager get-secret-value --secret-id ${db_master_credentials_arn}  \
   | jq .SecretString \
   | sed 's/^"\(.*\)"$/\1/' \
   | sed 's/\\"/"/g' \
   | jq '.' > .dbmastercredentials

export PGPASSWORD="$(jq -r '.password' .dbmastercredentials)"

aws secretsmanager get-secret-value --secret-id ${dagster_credentials} \
   | jq .SecretString \
   | sed 's/^"\(.*\)"$/\1/' \
   | sed 's/\\"/"/g' \
   | jq '.' > .dagstercredentials


cat << EOF > bootstrap_db.sql
CREATE DATABASE $(jq -r ".database" .dagstercredentials);
CREATE USER $(jq -r ".username" .dagstercredentials) PASSWORD '$(jq -r ".password" .dagstercredentials)';
GRANT ALL PRIVILEGES ON DATABASE $(jq -r ".database" .dagstercredentials) TO $(jq -r ".username" .dagstercredentials);
ALTER DATABASE $(jq -r ".database" .dagstercredentials) OWNER TO $(jq -r ".username" .dagstercredentials);
EOF

# First of all initialize the database and create necessary databases and users
psql --host=localhost \
  --port=5433 \
  --username=$(jq -r ".username" .dbmastercredentials) \
  --dbname=postgres < bootstrap_db.sql

kill $TUNNEL_PID
echo "Killed tunnel"
rm .dagstercredentials
rm .dbmastercredentials
