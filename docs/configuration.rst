=====================================
Configuration of Platform
=====================================

The configuration below will configure the platform with a dbt project under
the organization SunrayAnalytics

.. code-block::

    aws_region       = "eu-west-1"
    environment_name = "dev"
    domain_name      = "sunray.ie"
    my_ip = "185.206.192.12/32"
    dbt_projects = [
      {
        github = {
          org  = "SunrayAnalytics"
          repo = "data_platform_reference_implementation"
        }
        snowflake_account_id = "fbecjtl-tb09991"
      }
    ]

To set up a dbt-project initialize a dbt project in an empty repository.

In order to deploy to the platform create a Github Actions workflow that looks something like
the following and place in ``.github/workflows/ci.yaml``:

.. code-block:: yaml

    name: Continuous Integration

    on:
      push:
        branches:
          - main

    jobs:
      deploy:
        permissions:
          id-token: write # This is required for requesting the JWT
          #  contents: read  # This is required for actions/checkout
          actions: read
          deployments: write
          contents: write
          attestations: write # Not sure is this needed
        name: deploy dbt
        uses: SunrayAnalytics/data_platform/.github/workflows/deploy_dbt.yaml@main
        with:
          environment: prod
        secrets: inherit
