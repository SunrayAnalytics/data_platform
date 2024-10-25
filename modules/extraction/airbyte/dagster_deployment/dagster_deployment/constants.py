import os
import pathlib

_PROJECT_ROOT_DIRECTORY = pathlib.Path(__file__).parent.parent

CONFIG_DIR = _PROJECT_ROOT_DIRECTORY / "config"
AIRBYTE_PROJECT_DIR = CONFIG_DIR / "airbyte"
INGEST_CONFIG_FILE = CONFIG_DIR / "lakehouse_ingest.yaml"

AIRBYTE_JOB_NAME = "airbyte_sync"

GROUP_NAME_RAW_VAULT = "raw_vault"
GROUP_NAME_LAKEHOUSE = "lakehouse"

ASSET_GROUP_DATA_LAKE = "data_lake"
ASSET_GROUP_SNOWFLAKE = "snowflake"

DATABASE_VAULT = os.getenv("DATABASE_VAULT", "vault")
DATABASE_LAKEHOUSE = "lakehouse"


# Offset the window for partitions to 5AM UTC
# we schedule the Airbyte at 3AM so that we will always get previous days data regardless of daylight savings
# in Europe/Stockholm time zone. Since we want fresh data the following day the time-window is moved forward
# to make sure that we capture the data from previous day via the _airbyte_emitted_at field in the source.
offset = 5
