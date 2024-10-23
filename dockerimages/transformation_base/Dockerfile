FROM python:3.10-slim

# Add repository code
WORKDIR /opt/dagster/app
COPY pyproject.toml /opt/dagster/app
COPY pip_constraints.txt /opt/dagster/app
RUN pip install '.' -c pip_constraints.txt
COPY dagster_deployment /opt/dagster/app/dagster_deployment

# Prepare dbt profile settings
RUN mkdir -p ~/.dbt/
COPY dbt_profile.yml /root/.dbt/profiles.yml

EXPOSE 4000

# CMD allows this to be overridden from run launchers or executors that want
# to run other commands against your repository
# -f file.py
ENTRYPOINT ["dagster", "api", "grpc", "-h", "0.0.0.0", "-p", "4000", "-m"]
CMD ["dagster_deployment"]
