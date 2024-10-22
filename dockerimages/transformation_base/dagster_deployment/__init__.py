import logging

from dagster import (
    Definitions,
    load_assets_from_modules,
    define_asset_job,
    AssetSelection,
    run_status_sensor,
    DagsterRunStatus,
    RunRequest,
    SkipReason,
)
from dagster_dbt import dbt_cli_resource

from dagster_duckdb_pandas import duckdb_pandas_io_manager

from . import assets, jobs
from .constants import *
from .notifications import make_email_on_run_failure_sensor

logger = logging.getLogger(__name__)

try:
    from dotenv import load_dotenv

    logger.info("python-dotenv was found will load environment variables from .env")
    load_dotenv()
except ImportError:
    logger.info(
        "python-dotenv was not installed will not resolve environment variables from .env"
    )

dbt_job = define_asset_job(
    name=DBT_JOB_NAME, selection=AssetSelection.assets(*assets.dbt_assets)
)


@run_status_sensor(
    run_status=DagsterRunStatus.SUCCESS,
    request_job=dbt_job,
)
def build_after_sync_sensor(context):
    print(f"Evaluating {context.dagster_run.job_name}")
    if context.dagster_run.job_name == JOB_LOAD_RAW_VAULT:
        return RunRequest(run_key=None, run_config={})
    else:
        return SkipReason(f"Should only trigger on job {REPORTING_MART_JOB_NAME}")


@run_status_sensor(
    run_status=DagsterRunStatus.SUCCESS,
    request_job=jobs.execute_tests_job,
)
def test_dbt_sensor(context):
    print(f"Evaluating {context.dagster_run.job_name}")
    if context.dagster_run.job_name == REPORTING_MART_JOB_NAME:
        return RunRequest(run_key=None, run_config={})
    else:
        return SkipReason(f"Should only trigger on job {REPORTING_MART_JOB_NAME}")


sensors = [test_dbt_sensor, build_after_sync_sensor]
if ENVIRONMENT in {"production", "development"}:
    if len(NOTIFICATION_EMAILS) > 0:
        sensors.append(
            make_email_on_run_failure_sensor(
                NOTIFICATION_EMAILS,
                monitor_all_repositories=True,
                filter_fn=lambda _: True,
                dagit_base_url=DAGIT_BASE_URL,
            ),
        )

defs = Definitions(
    assets=list(load_assets_from_modules([assets])),
    jobs=[
        dbt_job,
        jobs.execute_tests_job,
    ]
    + [jobs.fail_job]
    if ENVIRONMENT == "development"
    else [],
    schedules=[],
    sensors=sensors,
    resources={
        "dbt": dbt_cli_resource.configured(
            {
                "project_dir": assets.DBT_PROJECT_DIR,
                "profiles_dir": assets.DBT_PROFILES_DIR,
            },
        ),
        "io_manager": duckdb_pandas_io_manager.configured(
            {"database": os.path.join(assets.DBT_PROJECT_DIR, "tutorial.duckdb")}
        ),
    },
)
