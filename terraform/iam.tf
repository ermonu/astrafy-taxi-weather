resource "google_project_iam_member" "ingestor_bq_jobuser" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.ingestor.email}"
}

resource "google_project_iam_member" "ingestor_bq_dataeditor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.ingestor.email}"
}


resource "google_cloud_run_service_iam_member" "invoker_allusers" {
  location = google_cloud_run_service.weather_ingest.location
  service  = google_cloud_run_service.weather_ingest.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Service Account for github actions
resource "google_service_account" "github_actions" {
  account_id   = "github-actions-deployer"   
  display_name = "GitHub Actions Deployer"
}

resource "google_project_iam_member" "github_actions_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

output "github_actions_sa_email" {
  value = google_service_account.github_actions.email
}
