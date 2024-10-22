from dagster import (
    op,
    job,
    OpExecutionContext,
)

from dagster_dbt import DbtCliResource

import boto3

from .constants import *


@op(required_resource_keys={"dbt"})
def dbt_data_tests(context: OpExecutionContext) -> None:
    dbt: DbtCliResource = context.resources.dbt
    dbt.cli("test --select test_type:singular")


@op(required_resource_keys={"dbt"})
def dbt_generate_and_upload_documentation(context: OpExecutionContext) -> None:
    dbt: DbtCliResource = context.resources.dbt
    dbt.cli("docs generate")

    project_dir = dbt.default_flags["project-dir"]
    bucket = DOCUMENTATION_BUCKET
    s3client = boto3.client("s3")
    files_to_upload = [
        ("catalog.json", "application/json"),
        ("index.html", "text/html"),
        ("manifest.json", "application/json"),
    ]
    context.log.info(
        f"Uploading dbt site to location s3://{bucket}/{DBT_DOCS_S3_PREFIX}"
    )
    for file_to_upload, content_type in files_to_upload:
        try:
            with open(
                os.path.join(project_dir, "target", file_to_upload), "rb"
            ) as the_file:
                s3client.put_object(
                    Body=the_file,
                    Bucket=bucket,
                    Key=f"{DBT_DOCS_S3_PREFIX}/{file_to_upload}",
                    ContentType=content_type,
                )
        except Exception as e:
            context.log.exception("Failed to upload dbt documentation to S3")
            raise e
    context.log.info(f"Uploading dbt site. Done")


@job(
    description="Executes data tests on dbt-models that I don't think are executed on noremal asset materialization"
)
def execute_tests_job():
    # We pass a dummy variable between the ops here just to make sure that they are executed sequentially
    # two instances of the dbt-command should not be running simultaneously.
    dbt_data_tests()
    dbt_generate_and_upload_documentation()


@op
def fail_op() -> None:
    # force failure
    test = 4 / 0


@job(
    description="A bogus-job is only used to force errors to test failure notifications"
)
def fail_job():
    fail_op()
