import pathlib
import os
from dagster import file_relative_path

DBT_MANIFEST_FILE = file_relative_path(
    __file__, os.path.join("..", "dbt", "target", "manifest.json")
)
DBT_PROJECT_DIR = file_relative_path(__file__, os.path.join("..", "dbt"))
DBT_PROFILES_DIR = str(pathlib.Path.home() / ".dbt")

DBT_JOB_NAME = f"dbt_job_{os.getenv('ENVIRONMENT', 'development')}"
AIRBYTE_JOB_NAME = f"airbyte_sync_{os.getenv('ENVIRONMENT', 'development')}"
REPORTING_MART_JOB_NAME = f"reporting_job_{os.getenv('ENVIRONMENT', 'development')}"

ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

DAGIT_BASE_URL = os.getenv("DAGIT_BASE_URL", "http://localhost:3000").rstrip("/")
NOTIFICATION_EMAILS = [
    email.strip() for email in os.getenv("NOTIFICATION_EMAILS", "").split(",")
]

# Where in the s3 documentation bucket should the dbt documentation be uploaded
DBT_DOCS_S3_PREFIX = (
    "dbt" + f"_{ENVIRONMENT.lower()}" if ENVIRONMENT != "production" else ""
)
DOCUMENTATION_BUCKET = os.getenv("DOCUMENTATION_BUCKET")

GROUP_NAME_REFERENCE_DATA = "reference_data"
GROUP_NAME_BUSINESS_VAULT = "business_vault"
GROUP_NAME_RAW_VAULT = "raw_vault"


ASSET_GROUP_DATA_LAKE = "data_lake"
ASSET_GROUP_SNOWFLAKE = "snowflake"
# --------------------------------
# External Dependencies
# --------------------------------
# This job is defined in the extraction module
JOB_LOAD_RAW_VAULT = "load_raw_vault_job"
DATABASE_VAULT = os.getenv("DATABASE_VAULT", "vault")
