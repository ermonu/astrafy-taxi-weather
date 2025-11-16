resource "google_artifact_registry_repository" "docker_repo" {
  repository_id = var.artifact_repo
  project       = var.project_id
  location      = var.region
  format        = "DOCKER"
}
