output "bucket_name" {
  description = "Name of the Cloud Storage bucket created for raw data"
  value       = google_storage_bucket.raw.name
}

output "raw_dataset_id" {
  description = "BigQuery dataset ID for raw data"
  value       = google_bigquery_dataset.raw.dataset_id
}

output "staging_dataset_id" {
  description = "BigQuery dataset ID for staging data"
  value       = google_bigquery_dataset.staging.dataset_id
}

output "mart_dataset_id" {
  description = "BigQuery dataset ID for mart data"
  value       = google_bigquery_dataset.mart.dataset_id
}

output "cloud_run_url" {
  description = "URL of the Cloud Run ingestion service"
  value       = google_cloud_run_service.ingestion.status[0].url
}