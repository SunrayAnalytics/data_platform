#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

pushd "$SCRIPT_DIR"/.. || exit

while getopts "e:c:h" option; do
  case $option in
    e)
      ENVIRONMENT="$OPTARG"
      if [ "$ENVIRONMENT" != "production" ]; then
        echo "Valid values for environment is currently only 'production'"
        exit 1
      fi
      ;;
    c)
      CurrentRevision="$OPTARG"
      ;;
    h)
      echo "Usage: $0 [-e environment] [-c commit]"
      exit 1
      ;;
    *)
      echo "Usage: $0 [-e environment] [-c commit]"
      exit 1
      ;;
  esac
done


ENVIRONMENT=${ENVIRONMENT:-"production"}
CurrentRevision=${CurrentRevision:-`git rev-parse --short HEAD`}

echo "Deploying docker tag '$CurrentRevision' to environment '$ENVIRONMENT'"

sam build

sam deploy \
  --stack-name=extract-deployment \
  --region=eu-west-1 \
  --s3-bucket=aws-sam-cli-managed-default-samclisourcebucket-ovg1q2bw1h7m \
  --s3-prefix=extract \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides ParameterKey=DockerTag,ParameterValue="$CurrentRevision" \
    ParameterKey=DeploymentName,ParameterValue=extraction_pipeline \
    ParameterKey=Environment,ParameterValue=production \
    ParameterKey=SnowflakeCredentials,ParameterValue=arn:aws:secretsmanager:eu-west-1:189773005890:secret:transform-ECSStack-17NU2KMSL8D74-snowflake-dbt-credentials-development-fUSAJq \
    ParameterKey=AirbyteInstanceCredentials,ParameterValue=arn:aws:secretsmanager:eu-west-1:189773005890:secret:extract-AirbyteStack-1V2Z24AK1BNAV-rds-credentials-airbyte-Rq7BL9 \
    ParameterKey=DagsterPostgresCredentials,ParameterValue=arn:aws:secretsmanager:eu-west-1:189773005890:secret:transform-ECSStack-17NU2KMSL8D74-dagster-postgres-credentials-g1CdGV \
  --no-fail-on-empty-changeset

popd || exit
