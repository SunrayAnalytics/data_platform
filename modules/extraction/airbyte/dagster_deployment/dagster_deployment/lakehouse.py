from . import airbyte
from .constants import *


import time
from typing import Callable, Any, Union, TypeAlias, Iterable
import yaml

from dagster import (
    asset,
    AssetKey,
    AssetsDefinition,
)
from dagster_airbyte import load_assets_from_airbyte_project
from dagster._core.definitions.cacheable_assets import CacheableAssetsDefinition

AssetDef: TypeAlias = Union[
    AssetsDefinition, Callable[[Callable[..., Any]], AssetsDefinition]
]


def asset_from_lakehouse_ingest(namespace: str, table_name: str) -> AssetDef:
    @asset(
        group_name=namespace,  # GROUP_NAME_LAKEHOUSE,
        key_prefix=([ASSET_GROUP_SNOWFLAKE, DATABASE_LAKEHOUSE, namespace]),
        name=table_name,  # Since we are dynamically generating asset names we cannot take the name of the function
        non_argument_deps={AssetKey([ASSET_GROUP_DATA_LAKE, namespace, table_name])},
    )
    def asset_fn() -> None:
        # For now, let snowpipe push data into the lakehouse
        time.sleep(2)  # Give the washing lambda a chance to run and the copy to happen

    return asset_fn


def load_lakehouse_ingest_assets() -> Iterable[AssetDef]:
    with open(INGEST_CONFIG_FILE, "r") as f:
        ingest_config = yaml.safe_load(f)

        for data_source_name, definition in ingest_config["data_lake"].items():
            if data_source_name == "_settings":
                continue

            for table_name, table_definition in definition.items():
                yield asset_from_lakehouse_ingest(data_source_name, table_name)


airbyte_repo = airbyte.Repository(AIRBYTE_PROJECT_DIR)
airbyte_assets: CacheableAssetsDefinition = load_assets_from_airbyte_project(
    project_dir=AIRBYTE_PROJECT_DIR,
    connection_to_asset_key_fn=lambda connection, stream_name: airbyte_repo.get_connection(
        connection.name
    ).destination.asset_key(
        stream_name
    ),
    connection_to_group_fn=lambda connection_name: airbyte_repo.get_connection(
        connection_name
    ).destination.schema,
)

lakehouse_assets = load_lakehouse_ingest_assets()
