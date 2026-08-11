FROM python:3.12-slim

WORKDIR /usr/src/dbt/dbt_project

# Install the dbt Postgres adapter. This step will also install dbt-core
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir dbt-postgres==1.11.0

# Install dbt dependencies (as specified in packages.yml file)
# Build seeds, models and snapshots (and run tests wherever applicable)
CMD dbt deps && dbt build --profiles-dir profiles && sleep infinity
