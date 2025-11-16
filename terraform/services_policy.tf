resource "google_project_service" "policy_tag_apis" {
  project = var.project_id

  for_each = toset([
    "datacatalog.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
  ])

  service                    = each.key
  disable_on_destroy         = false
  disable_dependent_services = true
}
