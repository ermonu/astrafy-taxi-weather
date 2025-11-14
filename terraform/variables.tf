variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region to deploy resources"
  default     = "europe-west1"
}

variable "raw_dataset_id" {
  type        = string
  description = "ID of the BigQuery dataset storing raw data"
  default     = "taxi_raw"
}

variable "staging_dataset_id" {
  type        = string
  description = "ID of the BigQuery dataset storing staging models"
  default     = "taxi_staging"
}

variable "mart_dataset_id" {
  type        = string
  description = "ID of the BigQuery dataset storing analytics data"
  default     = "taxi_mart"
}

variable "bucket_name" {
  type        = string
  description = "Name of the Cloud Storage bucket for raw files"
  default     = "taxi-raw-data"
}

variable "run_image" {
  type        = string
  description = "Container image for the weather ingestion service"
  default     = "gcr.io/cloudrun/hello"
}

variable "ingestion_schedule" {
  type        = string
  description = "Cron schedule for daily ingestion (Cloud Scheduler)"
  default     = "0 7 * * *" # every day at 07:00 UTC
}