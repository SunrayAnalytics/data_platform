from .. import constants


def test_config_directory():
    assert constants.CONFIG_DIR.exists()
    assert constants.CONFIG_DIR.is_dir()


def test_dbt_project_dir():
    assert constants.DBT_PROJECT_DIR.exists()
    assert constants.DBT_PROJECT_DIR.is_dir()


def test_dbt_config_present():
    assert (
        constants.DBT_PROFILES_DIR.exists()
    ), "The dbt profiles dir didn't exist under ~/.dbt/"
    assert constants.DBT_PROFILES_DIR.is_dir()
