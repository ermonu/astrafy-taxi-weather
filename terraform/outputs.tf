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
  description = "URL of the Cloud Run weather ingestion service"
  value       = google_cloud_run_service.weather_ingest.status[0].url
}


output "payment_type_policy_tag_name" {
  value = google_data_catalog_policy_tag.payment_type_restricted.name
}


