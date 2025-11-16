variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for regional services (Cloud Run, Scheduler, Artifact Registry)"
  default     = "europe-west1"
}

variable "bq_location" {
  type        = string
  description = "Location for BigQuery datasets"
  default     = "US"
}

variable "raw_dataset_id" {
  type        = string
  description = "BigQuery dataset ID for raw data"
  default     = "taxi_raw"
}

variable "staging_dataset_id" {
  type        = string
  description = "BigQuery dataset ID for staging data"
  default     = "taxi_staging"
}

variable "mart_dataset_id" {
  type        = string
  description = "BigQuery dataset ID for mart data"
  default     = "taxi_mart"
}

variable "artifact_repo" {
  type        = string
  description = "Artifact Registry repository for Docker images"
  default     = "docker-repo"
}

variable "cloud_run_image" {
  type        = string
  description = "Fully qualified image URI for the Cloud Run service"
}