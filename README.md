# A Containerized dbt Workflow

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/datamindedacademy/dbt-docker)

A runnable dbt project that builds seeds, models, snapshots and tests against a
Postgres database, with both services defined in `docker-compose.yml`. Clone it,
run one command, and get a working warehouse to experiment against.

It closes out the Dataminded Academy dbt and Docker courses, and stands on its
own as a sandbox for a dbt project that runs locally without a cloud warehouse.

## What's in the box

Two services:

- `postgres`: built from `Dockerfile.postgres`, a Postgres 18 instance preloaded
  with [Pagila], the Postgres port of the Sakila example database. Sakila models
  a DVD rental store: films, customers, payments, rentals and a dozen other
  normalised tables.
- `dbt`: built from `Dockerfile`, running dbt Core with the Postgres adapter. It
  builds the example project in `dbt_project/` into the Postgres database.

## Running it

### In GitHub Codespaces

Click the badge above. The devcontainer installs Docker and runs
`docker compose up -d --build` on creation, so the models are already built by
the time the editor opens.

### Locally

Docker Desktop, or Docker Engine with the Compose plugin, is the only
requirement.

```bash
docker compose up --build
```

Either way, Postgres starts first, and dbt waits for it to accept connections
before running `dbt deps && dbt build`. The `dbt` container stays up afterwards
so we can keep working inside it.

The first start takes a minute or so: the Pagila SQL downloads during the image
build, then Postgres loads roughly 13 MB of it before dbt begins. Later starts
reuse the existing image and volume, and are quick.

## What gets built

The project takes one source table, `public.payment`, plus a seed file, and
builds staging, intermediate and mart models on top:

| Model | Type | What it does |
| --- | --- | --- |
| `stg_payment` | view | Staging layer over the `payment` source table |
| `customer_base` | seed | 599 customers loaded from `seeds/customer_base.csv` |
| `int_revenue_by_date` | view | Daily revenue |
| `int_customers_per_store` | view | Customer count per store |
| `cumulative_revenue` | table | Running revenue total over time |
| `int_customers_per_store_snapshot` | snapshot | Tracks customer counts per store as they change |

Nine data tests run alongside them, covering uniqueness and null checks.

Note that this is a dummy project. Some entities, including the aggregations,
would not make much sense to a real DVD rental business. The `customer` table
already exists in Sakila, and we still build a separate `customer_base` seed
from a CSV to show how seeds work. For a deeper treatment of how to structure
the layers, the dbt docs on [how we structure our dbt projects] are a better
guide than these models.

## Working inside the containers

Both services have fixed container names, so we can reach them directly.

Rebuild models after editing them:

```bash
docker exec -it dbt dbt build --profiles-dir profiles
```

Or open a shell and work from there:

```bash
docker exec -it dbt /bin/bash

dbt deps                              # install packages from packages.yml
dbt seed --profiles-dir profiles      # load seeds
dbt run --profiles-dir profiles       # build models
dbt snapshot --profiles-dir profiles  # build snapshots
dbt test --profiles-dir profiles      # run tests
dbt build --profiles-dir profiles     # all of the above, in dependency order
```

The repository is mounted into the container, so edits on the host apply
immediately.

## Querying the results

```bash
docker exec -it postgres psql -U postgres
```

Then:

```sql
-- Seeds
SELECT * FROM customer_base;

-- Staging views
SELECT * FROM stg_payment;

-- Intermediate views
SELECT * FROM int_customers_per_store;
SELECT * FROM int_revenue_by_date;

-- Mart tables
SELECT * FROM cumulative_revenue;

-- Snapshots
SELECT * FROM int_customers_per_store_snapshot;
```

Postgres is also published on `localhost:5430` for connecting a database client
or BI tool from the host.

## Making changes

Add, modify or remove models freely. The `dbt_project/` folder holds the whole
project: models in `models/`, seeds in `seeds/`, snapshots in `snapshots/`, and
connection settings in `profiles/profiles.yml`.

To start over from an empty database, drop the volume:

```bash
docker compose down -v && docker compose up --build
```

## Where the data comes from

The Postgres schema and data come from [Pagila], maintained by Devrim Gündüz.
Pagila is a port of the Sakila database originally written by Mike Hillyer at
MySQL AB, and is available under the PostgreSQL License.

`Dockerfile.postgres` fetches it at build time and drops it into the image's
first-start hook, so the SQL lives upstream instead of in this repository.
Moving to a different release means editing the `PAGILA_TAG` argument at the top
of that file, then rebuilding:

```bash
docker compose build postgres && docker compose up -d --force-recreate postgres
```

[Pagila]: https://github.com/devrimgunduz/pagila
[how we structure our dbt projects]: https://docs.getdbt.com/best-practices/how-we-structure/1-guide-overview
