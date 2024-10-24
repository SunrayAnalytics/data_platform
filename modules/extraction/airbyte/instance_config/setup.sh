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
CREATE USER ${database_username} PASSWORD '$${DATABASE_PASSWORD}';

CREATE DATABASE ${database_name} OWNER ${database_username};
CREATE DATABASE temporal OWNER ${database_username};
CREATE DATABASE temporal_visibility OWNER ${database_username};

GRANT ALL PRIVILEGES ON DATABASE ${database_name} TO ${database_username};
GRANT ALL PRIVILEGES ON DATABASE temporal TO ${database_username};
GRANT ALL PRIVILEGES ON DATABASE temporal_visibility TO ${database_username};

ALTER DATABASE ${database_name} OWNER TO ${database_username};
ALTER DATABASE temporal OWNER TO ${database_username};
ALTER DATABASE temporal_visibility OWNER TO ${database_username};
EOF

mkdir -p temporal/dynamicconfig
touch temporal/dynamicconfig/development.yaml
# First of all initialize the database and create necessary databases and users
psql --host=${database_host} --port=${database_port} --username=${master_username} --dbname=postgres < bootstrap_db.sql

#rm .dbmastercredentials
docker compose up -d
