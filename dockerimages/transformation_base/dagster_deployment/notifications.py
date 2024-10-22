from typing import (
    TYPE_CHECKING,
    List,
    Sequence,
    Callable,
    Optional,
    Union,
)

if TYPE_CHECKING:
    from dagster._core.definitions.selector import (
        CodeLocationSelector,
        JobSelector,
        RepositorySelector,
    )
import boto3
import logging
import os.path
from jinja2 import Environment, FileSystemLoader

from dagster import (
    DefaultSensorStatus,
)
from dagster._core.definitions import GraphDefinition, JobDefinition
from dagster._core.definitions.run_status_sensor_definition import (
    RunFailureSensorContext,
    run_failure_sensor,
)
from dagster._core.definitions.unresolved_asset_job_definition import (
    UnresolvedAssetJobDefinition,
)

logger = logging.getLogger(__name__)

env = Environment(loader=FileSystemLoader(os.path.dirname(__file__)))
plain_text_template = env.get_template("plain_text_error_email.txt")
html_template = env.get_template("html_error_email.html")


def _default_filter_fn(_: RunFailureSensorContext) -> bool:
    """Default implementation of the filer, will always return true in order to always e-mail"""
    return True


def make_email_on_run_failure_sensor(
    recipients: List[str],
    filter_fn: Callable[[RunFailureSensorContext], bool] = _default_filter_fn,
    name: Optional[str] = None,
    dagit_base_url: Optional[str] = None,
    minimum_interval_seconds: Optional[int] = None,
    monitored_jobs: Optional[
        Sequence[
            Union[
                JobDefinition,
                GraphDefinition,
                UnresolvedAssetJobDefinition,
                "RepositorySelector",
                "JobSelector",
                "CodeLocationSelector",
            ]
        ]
    ] = None,
    monitor_all_repositories: bool = False,
    default_status: DefaultSensorStatus = DefaultSensorStatus.STOPPED,
):
    """Create a sensor on job failures that will email people.

    Args:
        text_fn (Optional(Callable[[RunFailureSensorContext], str])): Function which
            takes in the ``RunFailureSensorContext`` and outputs the message you want to send.
            Defaults to a text message that contains error message, job name, and run ID.
        filter_fn (Callable[[RunFailureSensorContext], bool]): Function which takes in
            the ``RunFailureSensorContext`` determines whether or not to send and email, the default
            implementation always returns True which causes the e-mail to be sent
        name: (Optional[str]): The name of the sensor. Defaults to "email_on_run_failure".
        dagit_base_url: (Optional[str]): The base url of your Dagit instance. Specify this to allow
            messages to include deeplinks to the failed job run.
        minimum_interval_seconds: (Optional[int]): The minimum number of seconds that will elapse
            between sensor evaluations.
        monitored_jobs (Optional[List[Union[JobDefinition, GraphDefinition, RepositorySelector, JobSelector, CodeLocationSensor]]]): The jobs in the
            current repository that will be monitored by this failure sensor. Defaults to None, which
            means the alert will be sent when any job in the repository fails. To monitor jobs in external repositories, use RepositorySelector and JobSelector
        monitor_all_repositories (bool): If set to True, the sensor will monitor all runs in the
            Dagster instance. If set to True, an error will be raised if you also specify
            monitored_jobs or job_selection. Defaults to False.
        default_status (DefaultSensorStatus): Whether the sensor starts as running or not. The default
            status can be overridden from Dagit or via the GraphQL API.

    """
    assert (
        len(recipients) > 0
    ), "The number of recipients to send emails to must be greater than zero"

    ses_client = boto3.client("ses")

    @run_failure_sensor(
        name=name,
        minimum_interval_seconds=minimum_interval_seconds,
        monitored_jobs=monitored_jobs,
        monitor_all_repositories=monitor_all_repositories,
        default_status=default_status,
    )
    def email_on_run_failure(context: RunFailureSensorContext) -> None:
        try:
            if not filter_fn(context):
                logger.info(
                    f"Filter activated on context {context} will not send email"
                )
                context.log.warning(
                    f"Filter activated on context {context} will not send email"
                )
                return
            context.log.warning(f"Will send an email to {','.join(recipients)}")
            render_context = {
                "context": {
                    "dagster_run": {"run_id": context.dagster_run.run_id},
                    "failure_event": {"message": context.failure_event.message},
                    "step_failure_events": [
                        {
                            "message": failure_event.message,
                            "event_specific_data": {
                                "error": {
                                    "message": failure_event.event_specific_data.error.message,
                                    "stack": failure_event.event_specific_data.error.stack,
                                }
                                if failure_event.event_specific_data.error is not None
                                else {},
                                "error_source": failure_event.event_specific_data.error_source,
                            },
                        }
                        for failure_event in context.get_step_failure_events()
                    ],
                },
                "dagit_base_url": dagit_base_url,
            }
            # print(render_context)
            plain_text_body = plain_text_template.render(**render_context)
            html_text_body = html_template.render(**render_context)
            # print(plain_text_body)
            ses_client.send_email(
                Source="Dagster Bot <noreply@data.eletive.com>",
                Destination={"ToAddresses": recipients},
                Message={
                    "Subject": {
                        "Data": f"Dagster Failure - {context.failure_event.event_type} {context.failure_event.job_name}",
                        "Charset": "utf-8",
                    },
                    "Body": {
                        "Text": {
                            "Data": plain_text_body,
                            "Charset": "utf-8",
                        },
                        "Html": {
                            "Data": html_text_body,
                            "Charset": "utf-8",
                        },
                    },
                },
            )
        except Exception as e:
            context.log.error(e)

    # End of decorated sensor function
    return email_on_run_failure
