#!/bin/bash

#
# Copyright (c) 2023. Sunray Analytics Ltd. All rights reserved
#

# This script should only be run once per instance setup

# In order to bootstrap the database
aws secretsmanager get-secret-value --secret-id ${db_master_credentials_arn} --region ${AWS_REGION} \
   | jq .SecretString \
   | sed 's/^"\(.*\)"$/\1/' \
   | sed 's/\\"/"/g' \
   | jq '.' > .dbmastercredentials

export PGPASSWORD="$(jq -r '.password' .dbmastercredentials)"

cat << EOF > bootstrap_db.sql
CREATE USER airbyte PASSWORD '$${DATABASE_PASSWORD}';

CREATE DATABASE airbyte;
CREATE DATABASE temporal;
CREATE DATABASE temporal_visibility;

GRANT ALL PRIVILEGES ON DATABASE airbyte TO airbyte;
GRANT ALL PRIVILEGES ON DATABASE temporal TO airbyte;
GRANT ALL PRIVILEGES ON DATABASE temporal_visibility TO airbyte;

ALTER DATABASE airbyte OWNER TO airbyte;
ALTER DATABASE temporal OWNER TO airbyte;
ALTER DATABASE temporal_visibility OWNER TO airbyte;
EOF

mkdir -p temporal/dynamicconfig
touch temporal/dynamicconfig/development.yaml
# First of all initialize the database and create necessary databases and users
psql --host=${database_host} --port=${database_port} --username=${master_username} --dbname=postgres < bootstrap_db.sql

#rm .dbmastercredentials
docker compose up -d