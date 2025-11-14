<!--
This repository contains the solution for the Astrafy take‑home coding challenge.
It demonstrates how to build a modern data platform on Google Cloud to analyse
the relationship between weather conditions and taxi trip duration in the
city of Chicago.  The accompanying architecture diagram and explanation can
be found in `../design_solution.pdf`.
-->

# Chicago Taxi Trips – Weather Impact Analysis

## 🎯 Goal

The objective of this project is to ingest and transform the **Chicago Taxi
Trips** public dataset along with **daily weather data** in order to
visualise whether adverse weather conditions have an impact on trip
durations.  The solution is deployed on **Google Cloud** using
open‑source technologies wherever possible and embraces **GitOps/DataOps**
principles.  All infrastructure is defined declaratively via
**Terraform**, data transformations are built with **dbt**, and the end
results are exposed in **Looker Studio** dashboards and can be consumed by
data scientists and applications.

## 🗂 Project structure

```
astrafy_case/
│
├── design_solution.pdf      # architecture diagram & explanation (Part 1)
└── repo/                    # code for the coding challenge (Part 2)
    ├── README.md            # this file – overview & instructions
    ├── terraform/           # IaC definitions for GCP resources
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ingestion/           # custom weather ingestion service
    │   ├── ingest_weather.py
    │   └── docker/
    │       └── Dockerfile
    ├── dbt_project/         # dbt project for transformations
    │   ├── dbt_project.yml
    │   └── models/
    │       ├── staging/
    │       │   └── stg_chicago_trips.sql
    │       └── mart/
    │           └── fact_trips_with_weather.sql
    └── .github/workflows/   # example CI/CD pipeline
        └── ci_cd.yml
```

## ✅ Prerequisites

To reproduce this solution you need the following:

- **Google Cloud Project** with billing enabled.
- **Service account** with roles `BigQuery Admin`, `Storage Admin`,
  `Cloud Run Admin`, `Pub/Sub Admin` and permission to create service
  accounts.  The service account key should be stored in a secure place
  and referenced in your CI/CD pipeline.
- [Terraform](https://www.terraform.io/downloads) (>= 1.5) and [gcloud](https://cloud.google.com/sdk/docs/install) installed locally.
- [dbt‑core](https://docs.getdbt.com/dbt-cli/installation) (>= 1.5) and
  its `bigquery` adapter.  See the `dbt_project/` directory for details.
- An API token for a weather service (e.g. Open‑Meteo, WeatherAPI or
  NOAA).  The sample ingestion script uses Open‑Meteo, which does not
  require authentication, but you can adapt it to your preferred API.

> **Note**: When running in CI/CD, configure the required variables via
> secrets or environment variables rather than hard‑coding them in
> version control.  See the `variables.tf` file for configurable values.

## 🚀 Getting started

Follow these high‑level steps to deploy the solution:

### 1. Configure and apply Terraform

1. Navigate into the `terraform/` folder:

   ```sh
   cd repo/terraform
   ```

2. Export your Google Cloud project and region as environment variables or
   provide them via `terraform.tfvars`:

   ```sh
   export TF_VAR_project_id="your‑gcp‑project"
   export TF_VAR_region="europe-west1"
   ```

3. Initialise and apply the Terraform configuration:

   ```sh
   terraform init
   terraform apply
   ```

   This will create:

   - A **Cloud Storage bucket** for raw/weather files.
   - **BigQuery datasets** for raw data (`taxi_raw`), staging (`taxi_staging`)
     and analytics/mart (`taxi_mart`).
   - A **service account** and IAM bindings for Cloud Run and BigQuery.
   - A **Cloud Run** service that will run the weather ingestion container.
   - A **Pub/Sub topic** and **Cloud Scheduler** job that triggers the
     ingestion daily at a configurable time.

### 2. Build and deploy the ingestion service

The ingestion component fetches yesterday’s weather for Chicago and
uploads it into a BigQuery table `taxi_raw.weather_daily`.  It is
containerised so it can run on Cloud Run.

1. Build the Docker image locally and push it to Google Artifact Registry:

   ```sh
   cd repo/ingestion/docker
   gcloud builds submit --tag europe‑west1‑docker.pkg.dev/$PROJECT_ID/ingestion/weather:latest .
   ```

2. Deploy the container to Cloud Run (Terraform already created the
   service – this command updates the image).  Specify environment
   variables for latitude, longitude and API endpoint if necessary:

   ```sh
   gcloud run deploy taxi‑weather‑ingestion \
       --image europe‑west1‑docker.pkg.dev/$PROJECT_ID/ingestion/weather:latest \
       --region $TF_VAR_region \
       --allow‑unauthenticated=false \
       --set‑env‑vars LAT=41.8781,LON=‑87.6298
   ```

3. Verify that the Pub/Sub/Scheduler trigger executes the Cloud Run
   service once per day and that the `weather_daily` table is
   populated.  You can invoke the endpoint manually with curl for
   testing:

   ```sh
   curl -X POST $(gcloud run services describe taxi‑weather‑ingestion \
     --region $TF_VAR_region --format 'value(status.url)')
   ```

### 3. Run the dbt models

1. Copy the sample `~/.dbt/profiles.yml` provided below and adjust it to
   your project.  It defines four targets (dev, raw, staging, mart)
   pointing to the BigQuery datasets created by Terraform.

2. Install dbt dependencies and run the models:

   ```sh
   cd repo/dbt_project
   dbt deps
   dbt run --full-refresh
   dbt test
   ```

   The `stg_chicago_trips.sql` model selects only the trips between
   **2023‑06‑01** and **2023‑12‑31** from the public dataset
   `bigquery‑public‑data.chicago_taxi_trips.taxi_trips`.  It extracts
   fields such as pickup and dropoff times, distance, trip duration,
   payment type and trip_id.  The `fact_trips_with_weather.sql` model
   joins the staging table to the `weather_daily` table on the
   trip_start_date and produces metrics per day and per weather
   condition, for instance average trip duration and number of trips.

### 4. Create the Looker Studio dashboard

Open [Looker Studio](https://lookerstudio.google.com/) and connect to
the `taxi_mart.fact_trips_with_weather` table in your project.  Build
charts such as:

- A **scatter plot** showing average trip duration vs. precipitation or
  wind speed.
- A **time‑series line chart** of average trip duration per day with
  an overlaid bar chart of total precipitation.
- A **dimension table** listing top N days with the highest average
  duration and the corresponding weather summary.

Share the dashboard with the assessment committee by granting view
access to the group `founders@astrafy.io`.

### 5. Optional: Restrict access to sensitive column

If you wish to restrict access to the column **payment_type** to your
email only, create an **authorized view** that excludes this column and
grant your colleagues access to the view instead of the underlying
table.  Example:

```sql
-- Create a view without the payment_type column
CREATE OR REPLACE VIEW `taxi_mart.fact_trips_anonymised` AS
SELECT * EXCEPT(payment_type)
FROM `taxi_mart.fact_trips_with_weather`;

-- Grant users access to the view only
GRANT SELECT ON TABLE `taxi_mart.fact_trips_anonymised` TO "group:data‑analysts@example.com";

-- Grant yourself access to the full table
GRANT SELECT ON TABLE `taxi_mart.fact_trips_with_weather` TO "user:your.name@example.com";
```

## 🧠 Data modelling

The dbt project follows the [Kimball style](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/) layered approach:

- **Staging models** pull the raw public data from BigQuery, apply basic
  filters (date range), type casting and naming conventions.  This
  stage is incremental and idempotent.
- **Mart/fact models** join the staging tables to the ingested weather
  data on date.  The fact table computes aggregate measures such as
  total trip duration (in minutes) and trip count per weather
  description and day.  Surrogate keys are generated for analytics
  friendliness.

Tests are defined in YAML to ensure uniqueness of primary keys, not
null on important columns and valid relationships between models.

## 🔧 Continuous Integration / Continuous Deployment

An example GitHub Actions workflow is provided in `.github/workflows/ci_cd.yml`.  It
illustrates how to:

1. Lint the Terraform and dbt files.
2. Run `terraform plan` to detect infrastructure changes.
3. Run `dbt run` against a temporary dataset for pull requests.
4. Deploy to Cloud Run and apply Terraform changes when merging into
   `main`.

You can adapt this workflow to your preferred CI/CD provider (GitLab,
Cloud Build, etc.).  Remember to configure the necessary secrets (GCP
service account key, project ID, region) in your repository settings.

## 📄 Additional notes

- The Terraform modules can be extended to include logging, monitoring
  alerts and IAM policies following the principle of least privilege.
- For local development you can run the ingestion script directly
  (`python ingestion/ingest_weather.py --date 2023-06-01`) and load
  results into BigQuery using the Python SDK.
- The project filters the taxi data to **01‑Jun‑2023 – 31‑Dec‑2023**
  because this subset fits within BigQuery’s free tier and is
  sufficient for the challenge.  Adjust the `stg_chicago_trips.sql`
  model if you wish to analyse additional periods.

## 👏 Acknowledgements

Thanks to the [City of Chicago](https://data.cityofchicago.org/) for
making the taxi dataset publicly available and to the [Open‑Meteo
project](https://open-meteo.com/) for free weather data.
