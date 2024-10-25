from pytest import fixture, raises
from .. import airbyte
from .. import constants

import logging

logger = logging.getLogger()


known_lakehouse_config_name = "Eletive database [anonymized] <> LH Eletive App"
known_datalake_config_name = "HubSpot <> S3"


@fixture(scope="module")
def airbyte_configuration() -> airbyte.Repository:
    return airbyte.Repository(constants.AIRBYTE_PROJECT_DIR, logger)


def test_get_non_existing(airbyte_configuration: airbyte.Repository):
    with raises(Exception) as e:
        _ = airbyte_configuration.get_connection("non existing")


def test_get_connection(airbyte_configuration: airbyte.Repository):
    conn = airbyte_configuration.get_connection(known_lakehouse_config_name)
    assert conn is not None
    assert isinstance(conn, airbyte.Connection)


def test_get_lakehouse_destination(airbyte_configuration: airbyte.Repository):
    conn = airbyte_configuration.get_connection(known_lakehouse_config_name)

    assert conn.destination is not None
    assert isinstance(conn.destination, airbyte.LakehouseDestination)


def test_get_datalake_destination(airbyte_configuration: airbyte.Repository):
    conn = airbyte_configuration.get_connection(known_datalake_config_name)

    assert conn.destination is not None
    assert isinstance(conn.destination, airbyte.DataLakeDestination)
