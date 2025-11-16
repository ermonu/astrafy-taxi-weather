resource "google_service_account" "ingestor" {
  account_id   = "weather-ingestor"
  display_name = "Weather ingestion service account"
}


resource "google_cloud_run_service" "weather_ingest" {
  name     = "weather-ingestion"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.ingestor.email

      containers {
        image = var.cloud_run_image

        env {
          name  = "BQ_DATASET"
          value = google_bigquery_dataset.raw.dataset_id
        }

        env {
          name  = "GCP_PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "GCP_LOCATION"
          value = var.bq_location
        }

        env {
          name  = "GCP_DATASET_NAME"
          value = google_bigquery_dataset.staging.dataset_id
        }

        env {
          name  = "RAW_DATASET_NAME"
          value = google_bigquery_dataset.raw.dataset_id
        }

        env {
          name  = "MART_DATASET_NAME"
          value = google_bigquery_dataset.mart.dataset_id
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}
