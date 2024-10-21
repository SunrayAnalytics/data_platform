FROM python:3.10-slim

RUN mkdir -p /opt/dagster/dagster_home /opt/dagster/app
WORKDIR /opt/dagster/app

COPY pip_constraints.txt  /opt/dagster/app
RUN pip install dagit dagster-postgres dagster-aws -c /opt/dagster/app/pip_constraints.txt

# Copy your code and workspace to /opt/dagster/app
COPY workspace.yaml /opt/dagster/app/

ENV DAGSTER_HOME=/opt/dagster/dagster_home/

# Copy dagster instance YAML to $DAGSTER_HOME
COPY dagster.yaml /opt/dagster/dagster_home/


EXPOSE 3000

ENTRYPOINT ["dagit", "-h", "0.0.0.0", "-p", "3000"]