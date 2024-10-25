from typing import List, Mapping, Any

from dagster_airbyte import load_assets_from_airbyte_instance, AirbyteResource
from dagster_airbyte.asset_defs import AirbyteConnectionMetadata

# from dagster_snowflake_pandas import SnowflakePandasIOManager
from dagster_duckdb_pandas import duckdb_pandas_io_manager
from dagster_airbyte import airbyte_resource
import os
import logging

logger = logging.getLogger(__name__)

from dagster import (
    Definitions,
    define_asset_job,
    ScheduleDefinition,
    AssetKey,
)

try:
    from dotenv import load_dotenv

    logger.info("python-dotenv was found will load environment variables from .env")
    load_dotenv()
except ImportError:
    logger.info(
        "python-dotenv was not installed will not resolve environment variables from .env"
    )

airbyte_instance = AirbyteResource(
    host=os.getenv("AIRBYTE_HOST"),
    port=os.getenv("AIRBYTE_PORT"),
    username=os.getenv("AIRBYTE_USERNAME"),
    password=os.getenv("AIRBYTE_PASSWORD"),
)
import json


def generate_asset_name(
    connection_meta: AirbyteConnectionMetadata, some_string: str
) -> AssetKey:
    print("-----------------------------------")
    # print(connection_meta)
    # print(f"SomeString: {some_string}")
    sd: List[Mapping[str, Any]] = connection_meta.stream_data
    test = list(
        filter(
            lambda sdi: sdi.get(
                "stream",
                {},
            ).get("name", "n/a")
            == some_string,
            sd,
        )
    )
    # print(test)
    # connection_meta.name
    # print(json.dumps(connection_meta.stream_data, indent=2, sort_keys=True))
    return AssetKey(["snowflake", "raw", "github", some_string])


airbyte_assets = load_assets_from_airbyte_instance(
    airbyte_instance,
    connection_to_asset_key_fn=generate_asset_name
    # io_manager_key="snowflake_io_manager",
)
# materialize all assets
run_everything_job = define_asset_job("run_everything", selection="*")
# @asset
# def stargazers_file(stargazers: pd.DataFrame):
#     with open("stargazers.json", "w", encoding="utf8") as f:
#         f.write(json.dumps(stargazers.to_json(), indent=2))

# only run the airbyte syncs necessary to materialize stargazers_file
# my_upstream_job = define_asset_job(
#     "my_upstream_job",
#     AssetSelection.keys("stargazers_file")
#     .upstream()  # all upstream assets (in this case, just the stargazers Airbyte asset)
#     .required_multi_asset_neighbors(),  # all Airbyte assets linked to the same connection
# )

defs = Definitions(
    jobs=[run_everything_job],
    assets=[airbyte_assets],
    # resources={"snowflake_io_manager": SnowflakePandasIOManager(...)},
    schedules=[
        ScheduleDefinition(
            job=run_everything_job,
            cron_schedule="@daily",
        ),
    ],
    resources={
        #         "airbyte": airbyte_resource.configured(
        #     {
        #         "host": {"env": "AIRBYTE_HOST"},
        #         "port": {"env": "AIRBYTE_PORT"},
        #         "username": {"env": "AIRBYTE_USERNAME"},
        #         "password": {"env": "AIRBYTE_PASSWORD"},
        #     })
        # }
    },
)
