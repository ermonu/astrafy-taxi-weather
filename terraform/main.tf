terraform {
  required_version = ">= 1.3.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.54.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

## Storage bucket for raw files
resource "google_storage_bucket" "raw" {
  name                        = "${var.bucket_name}-${random_id.bucket_suffix.hex}"
  location                    = var.region
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }
}

## BigQuery datasets
resource "google_bigquery_dataset" "raw" {
  dataset_id = var.raw_dataset_id
  project    = var.project_id
  location   = var.region
  description = "Raw taxi and weather data (Bronze layer)"
  labels = {
    stage = "raw"
  }
}

resource "google_bigquery_dataset" "staging" {
  dataset_id = var.staging_dataset_id
  project    = var.project_id
  location   = var.region
  description = "Staging tables for dbt models"
  labels = {
    stage = "staging"
  }
}

resource "google_bigquery_dataset" "mart" {
  dataset_id = var.mart_dataset_id
  project    = var.project_id
  location   = var.region
  description = "Analytics and mart tables"
  labels = {
    stage = "mart"
  }
}

## Service account for the ingestion service
resource "google_service_account" "ingestion" {
  account_id   = "taxi-weather-ingestion-sa"
  display_name = "Taxi weather ingestion service account"
}

## IAM bindings for the service account
resource "google_project_iam_member" "ingestion_bigquery_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.ingestion.email}"
}

resource "google_project_iam_member" "ingestion_storage_objectAdmin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.ingestion.email}"
}

## Cloud Run service for weather ingestion
resource "google_cloud_run_service" "ingestion" {
  name     = "taxi-weather-ingestion"
  location = var.region

  template {
    spec {
      containers {
        image = var.run_image
        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }
        env {
          name  = "RAW_DATASET"
          value = google_bigquery_dataset.raw.dataset_id
        }
      }
      service_account_name = google_service_account.ingestion.email
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "1"
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

## Allow the ingestion service account to invoke the Cloud Run service (self-invocation)
resource "google_cloud_run_service_iam_member" "ingestion_invoker" {
  location = google_cloud_run_service.ingestion.location
  service  = google_cloud_run_service.ingestion.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.ingestion.email}"
}

## Cloud Scheduler job to trigger the ingestion daily
resource "google_cloud_scheduler_job" "ingestion_daily" {
  name     = "taxi-weather-ingestion-daily"
  region   = var.region
  schedule = var.ingestion_schedule

  http_target {
    http_method = "POST"
    uri         = google_cloud_run_service.ingestion.status[0].url
    oidc_token {
      service_account_email = google_service_account.ingestion.email
      audience              = google_cloud_run_service.ingestion.status[0].url
    }
  }
}
