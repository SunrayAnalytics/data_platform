CREATE DATABASE dagster_${tenant_id};
CREATE USER dagster_${tenant_id} PASSWORD '${password}';
GRANT ALL PRIVILEGES ON DATABASE dagster_${tenant_id} to dagster_${tenant_id};
ALTER DATABASE dagster${tenant_id} OWNER TO dagster_${tenant_id};
