# Taxi Trips & Weather Analysis Project

This project implements a **fully automated data pipeline** that ingests raw taxi trip data and weather data, models them with **dbt**, and serves the resulting metrics through a **Looker Studio dashboard**.  The end‑to‑end workflow follows **Infrastructure as Code (IaC)** and **GitOps** practices, ensuring all resources are reproducible via **Terraform** and the pipeline is executed via **CI/CD**.

## Overview

The goal is to enrich historical Chicago taxi trip data with corresponding hourly weather metrics and provide analytical insights via dashboards.  The pipeline ingests raw weather data from Open‑Meteo and raw taxi trips from the Chicago data portal, stages them in BigQuery, transforms them into analytical fact tables using dbt, and exposes the resulting metrics.

Key features:

- **Ingestion service** – A Python Flask app containerised with Docker and deployed on **Cloud Run**.  It calls Open‑Meteo's API for a given date, writes results to a staging landing bucket, and loads them into BigQuery using the BigQuery client.
- **Schedule** – A **Cloud Scheduler** job triggers the ingestion service daily to ingest weather data for the previous day.  All historic dates can be backfilled by parameterising the date.
- **dbt transformations** – Models defined in `dbt_project/` stage raw trip and weather tables, join them into a **fact table** (`fact_trips_with_weather`) and summarise them in the **mart layer**.  The models use **incremental materialisation** with partitioning on `trip_start_date` for efficiency.
- **Infrastructure as Code** – The entire GCP setup (service accounts, Artifact Registry, Cloud Run service, BigQuery datasets, bucket, scheduler and IAM bindings) is defined in Terraform under `terraform/`.  A single `terraform apply` provisions and configures the environment.
- **Governance** – An optional policy tag is created for sensitive columns (`payment_type`) to demonstrate fine‑grained access control.  This uses Data Catalog taxonomy resources in Terraform.
- **CI/CD** – A GitHub Actions workflow (`.github/workflows/gcp-ci.yml`) plans and applies Terraform on pushes to specific branches, builds and pushes the ingestion image, and executes dbt tests on pull requests.  Secrets for GCP authentication are stored as GitHub secrets.

## Architecture

```
+-----------------+        +-----------------+         +-----------------+
|   GitHub Repo   |        | Terraform (IaC) |         |  GitHub Actions |
|  (Source code)  | -----> |  provision GCP  |  -----> |   CI/CD         |
+-----------------+        +-----------------+         +-----------------+
          |                                                       |
          |                               deploys                 |
          v                                                       |
   +-------------+      triggers        +------------------+      |
   | Cloud       | <-------------+------|  Cloud Scheduler |      |
   | Run Service |               |      +------------------+      |
   +-------------+               |                                  |
          |                      |          invokes                  |
          |                      |                                   |
          v                      |                                   |
+-------------------+            |                                   |
|  Ingestion Flask  |            |                                   |
|  App (Docker)     | -----------+---> Writes to BigQuery            |
+-------------------+                                            |
          |                                                            |
          v                                                            |
  +--------------+         +-----------------+        +---------------+
  | Raw Weather  |         | Raw Taxi Trips |        |    dbt        |
  |   (BQ table) |         |  (BQ table)    |        | Transformations|
  +--------------+         +-----------------+        +---------------+
          \                            /                      |
           \                          /                       |
            +----> Fact & Mart  <----+                        |
                      Models                             +----v----+
                                                       | Looker   |
                                                       |  Studio  |
                                                       +---------+
```

1. **GitHub** hosts all code (ingestion script, dbt models, Terraform).  A GitHub Actions workflow runs lint/tests, plans Terraform, builds & pushes the image, and executes dbt.
2. **Terraform** provisions GCP resources: Artifact Registry, Cloud Run service, BigQuery datasets, Cloud Storage bucket, IAM roles, Cloud Scheduler job and Data Catalog policy tags.
3. **Cloud Scheduler** calls the Cloud Run ingestion endpoint daily to fetch weather data for the previous day.  The ingestion service loads the data into the `weather_raw` table in BigQuery.
4. **dbt** models join the weather and taxi trip tables and produce the `fact_trips_with_weather` table, partitioned by date for efficiency, and the `mart_taxi_trips_weather` table with aggregated metrics.
5. **Looker Studio** connects to the mart table and exposes a dashboard (daily trips vs temperature, precipitation, cloud cover and wind speed).

## Repository structure

```
repo/
│  README.md              ← project documentation (to be replaced by this file)
│  docker-compose.yml     ← optional local setup (if used)
└──terraform/             ← all IaC definitions
    ├── provider.tf       ← providers & backend config
    ├── variables.tf      ← input variables
    ├── artifact_registry.tf
    ├── cloud_run.tf      ← Cloud Run service & IAM
    ├── datasets.tf       ← BigQuery datasets & tables
    ├── scheduler.tf      ← Cloud Scheduler job
    ├── services_policy.tf← IAM API enablement
    ├── governance.tf     ← optional Data Catalog policy tags
    └── outputs.tf        ← useful outputs
└──ingestion/
    ├── ingest_weather.py ← Python Flask app to fetch weather data and load to BQ
    ├── Dockerfile        ← container definition for ingestion service
└──dbt_project/
    ├── dbt_project.yml   ← dbt project configuration
    ├── packages.yml      ← (empty if no packages)
    ├── profiles.yml     
    └── models/
        ├── sources.yml   ← source definitions for taxi and weather
        ├── staging/
        │   ├── stg_chicago_trips.sql
        │   └── stg_weather.sql
        ├── mart/
        │   ├── mart_taxi_trips_weather.sql
        │   └── mart.yml
        └── intermediate/
            └── fact_trips_with_weather.sql
└──.github/workflows/
    └── gcp-ci.yml        ← CI/CD pipeline
```

## Setup and Deployment

1. **Clone repository and install tools**:

   ```bash
   git clone https://github.com/your-org/astrafy-taxi-weather-main.git
   cd astrafy-taxi-weather-main
   # install Terraform & dbt if not already installed
   ```

2. **Create a GCP project** and enable the following APIs: Cloud Run, Cloud Scheduler, BigQuery, Artifact Registry, BigQuery Data Transfer, Service Usage, Cloud Build and Data Catalog.

3. **Prepare Terraform variables**:

   Copy `terraform.tfvars.example` to `terraform.tfvars` and set values for your project ID, region, and Cloud Run image (for example `REGION-docker.pkg.dev/PROJECT_ID/docker-repo/weather-ingest:latest`).  Optionally specify a partition start date for the mart table.

4. **Initialise and apply Terraform**:

   ```bash
   cd terraform
   terraform init
   terraform apply  # will create all GCP resources
   ```

5. **Build and push ingestion image** (CI pipeline does this automatically).  For local build:

   ```bash
   cd ingestion
   docker build -t REGION-docker.pkg.dev/PROJECT_ID/docker-repo/weather-ingest:dev .
   docker push REGION-docker.pkg.dev/PROJECT_ID/docker-repo/weather-ingest:dev
   ```

   After pushing, run `terraform apply` again so Cloud Run is deployed with the new image.

6. **Run dbt models**:

   Configure your `~/profiles.yml` to point to the BigQuery project and dataset.  Then run:

   ```bash
   cd dbt_project
   dbt seed   # if seeds provided
   dbt run    # builds staging, fact and mart tables
   dbt test   # optional tests
   ```

7. **Looker Studio dashboard**:

   The public report is in: https://lookerstudio.google.com/reporting/1fe523b4-16a6-46a1-b86c-2c0708dcb761

## CI/CD Pipeline

The GitHub Actions workflow located at `.github/workflows/gcp-ci.yml` automates testing, building and deployment:

- **Terraform**: On commits to `main` or a dedicated environment branch (e.g. `prod`), the workflow runs `terraform plan` and `terraform apply` using a service account key stored in the repository secrets (`GCP_SA_KEY`).  This ensures infrastructure is always in sync with code.
- **Docker build & push**: When changes are made to the ingestion service or on PR merges, the workflow builds the Docker image, tags it with the commit SHA, and pushes it to Artifact Registry.
- **dbt tests**: On pull requests, the workflow installs Python and the `dbt-bigquery` adapter, runs `dbt deps`, `dbt compile` and `dbt test` to verify model validity.  It fails the PR if any tests fail.
- **GitFlow**: Developers work on feature branches, open pull requests to `main`, and rely on CI to validate changes.  Merging to `main` triggers deployment automatically.

### Security and governance

The pipeline creates a **Data Catalog policy tag** and attaches it to the `payment_type` column in the `fact_trips_with_weather` table.  Only the user email specified in Terraform is granted the `roles/datacatalog.categoryFineGrainedReader` role.  This demonstrates column‑level security.  BigQuery table partitions restrict query costs.

## Adding or extending features

- **Additional weather metrics** can be added by modifying `ingest_weather.py` to request more variables (e.g. humidity) and updating the schema in dbt models.
- **New transformations** or analytics can be added by creating additional dbt models in the `mart` layer.
- **Cost optimisation**: Partition and cluster the mart table by `trip_start_date` and additional fields (`pickup_community_area`) to improve performance.
- **Monitoring and alerts**: Integrate Stackdriver monitoring for the Cloud Run service and set up alerting on job failures.

## Conclusion

This repository delivers a robust, production‑ready data pipeline using modern data stack practices.  Infrastructure is versioned in Terraform, ingestion is containerised on Cloud Run, transformations are modularised in dbt, and dashboards are built in Looker Studio.  CI/CD ensures code quality and reproducible deployments.  The modular design makes it easy to extend the pipeline with new sources or analytics while maintaining strong governance and cost controls.
