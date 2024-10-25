import logging
import pathlib
from abc import ABC, abstractmethod
from typing import Any, Mapping
import yaml
from typing import Dict
from dagster import AssetKey

from .constants import *


class Repository:
    def __init__(
        self,
        airbyte_project_dir: pathlib.Path,
        logger: logging.Logger = logging.getLogger(__name__),
    ):
        assert isinstance(airbyte_project_dir, pathlib.Path)
        assert airbyte_project_dir.exists()
        assert airbyte_project_dir.is_dir()
        self._airbyte_project_dir = airbyte_project_dir
        self._logger = logger

        self._connections: Dict[str, Connection] = {}
        self._destinations: Dict[str, Mapping[str, Any]] = {}
        for connection_config_file in self._airbyte_project_dir.glob(
            "./connections/*/configuration.yaml"
        ):
            with connection_config_file.open("r") as f:
                connection = yaml.safe_load(f)
                logger.info(f"Loading connection {connection.get('resource_name')}")
                self._connections[connection.get("resource_name")] = Connection(
                    connection, self
                )
        if len(self._connections) == 0:
            raise Exception(
                "No airbyte connections found, this is probably a configuration error"
            )

        for destination_config_file in self._airbyte_project_dir.glob(
            "./destinations/*/configuration.yaml"
        ):
            with destination_config_file.open("r") as f:
                d = yaml.safe_load(f)

                source_path = destination_config_file.relative_to(
                    self._airbyte_project_dir
                )
                self._destinations[str(source_path)] = d
        if len(self._connections) == 0:
            raise Exception(
                "No airbyte connections found, this is probably a configuration error"
            )
        if len(self._destinations) == 0:
            raise Exception(
                "No airbyte destinations found, this is probably a configuration error"
            )

    def _get_destination(self, relative_path: str) -> Mapping[str, Any]:
        """Gets the destination by relative path"""
        ret = self._destinations.get(relative_path)
        if ret is None:
            raise Exception(
                f"The configuration with path {relative_path} was not found"
            )
        return ret

    def get_connection(self, name) -> "Connection":
        ret = self._connections.get(name, None)
        if ret is None:
            raise Exception(
                f"The connection with name {name} was not found in the configuration (it should match the key resource_name)"
            )
        return ret


class Connection:
    def __init__(self, configuration: Mapping[str, Any], config_repository: Repository):
        self._repo = config_repository
        self._config = configuration

    @property
    def destination(self) -> "Destination":
        try:
            d = self._repo._get_destination(
                self._config.get("destination_configuration_path")
            )
        except Exception as e:
            raise Exception(
                f"Configuration inconsistency detected the destination was not found for  "
            ) from e

        definition_image = d.get("definition_image")

        if definition_image == "airbyte/destination-s3":
            return DataLakeDestination(self, d)
        elif definition_image == "airbyte/destination-snowflake":
            return LakehouseDestination(self, d)
        else:
            raise Exception(f"Unsupported destination type {definition_image}")


class Destination(ABC):
    def __init__(self, connection: Connection, config: Mapping[str, Any]):
        self._config = config
        self._connection = connection

    @property
    def connection(self) -> Connection:
        return self._connection

    @property
    @abstractmethod
    def schema(self) -> str:
        pass

    @abstractmethod
    def asset_key(self, stream_name: str) -> AssetKey:
        """
        stream_name - Name of the Airbyte stream (which is roughly equivalent to a table)
        """
        pass


class DataLakeDestination(Destination):
    def __init__(self, connection: Connection, config: Mapping[str, Any]):
        super().__init__(connection, config)

    @property
    def schema(self) -> str:
        return self.connection._config.get("configuration").get("namespace_format")

    def asset_key(self, stream_name: str) -> AssetKey:
        return AssetKey(
            [
                ASSET_GROUP_DATA_LAKE,
                self.schema,
                stream_name,
            ]
        )


class LakehouseDestination(Destination):
    def __init__(self, connection: Connection, config: Mapping[str, Any]):
        super().__init__(connection, config)

    @property
    def database(self) -> str:
        return self._config.get("configuration").get("database").lower()

    @property
    def schema(self) -> str:
        return self._config.get("configuration").get("schema").lower()

    def asset_key(self, stream_name: str) -> AssetKey:
        return AssetKey(
            [
                ASSET_GROUP_SNOWFLAKE,
                self.database,
                self.schema,
                stream_name,
            ]
        )
