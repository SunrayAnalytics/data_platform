from typing import Mapping, Any, Optional, List

from dagster_dbt import load_assets_from_dbt_project
from dagster import AssetKey

from .constants import *


def default_group_fn(node_info: Mapping[str, Any]) -> Optional[str]:
    """
    Generating the group based on logical groupings of the various layers in the DWH architecture
    """
    if node_info["resource_type"] == "source":
        return GROUP_NAME_RAW_VAULT

    fqn: List[str] = node_info.get("fqn", [])
    if len(fqn) < 3:
        return None

    if fqn[1] == "biz":
        return GROUP_NAME_BUSINESS_VAULT

    if fqn[1] == "reference_data":
        return GROUP_NAME_REFERENCE_DATA

    if fqn[1] == "marts":
        return f"{fqn[2]}_mart"


def dbt_asset_key_fn(node_info: Mapping[str, Any]) -> AssetKey:
    """Get the asset key for a dbt node.
    This will return the actual snowflake name of the table itself to make things more transparent
    with where the asset itself is actually materialized
    """
    return AssetKey(
        [ASSET_GROUP_SNOWFLAKE]
        + [name.lower() for name in node_info["relation_name"].split(".")]
    )


dbt_assets = load_assets_from_dbt_project(
    project_dir=DBT_PROJECT_DIR,
    profiles_dir=DBT_PROFILES_DIR,
    node_info_to_group_fn=default_group_fn,
    use_build_command=True,
    node_info_to_asset_key=dbt_asset_key_fn,
)
