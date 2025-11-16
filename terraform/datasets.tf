# BigQuery datasets (US for compatibility with data source location)
resource "google_bigquery_dataset" "raw" {
  dataset_id = var.raw_dataset_id
  location   = var.bq_location
}

resource "google_bigquery_dataset" "staging" {
  dataset_id = var.staging_dataset_id
  location   = var.bq_location
}

resource "google_bigquery_dataset" "mart" {
  dataset_id = var.mart_dataset_id
  location   = var.bq_location
}