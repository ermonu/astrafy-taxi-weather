resource "google_data_catalog_taxonomy" "taxi_pii_taxonomy" {
  provider = google-beta
  project  = var.project_id
  region   = var.region

  display_name           = "taxi_pii_taxonomy"
  description            = "Taxonomy for sensitive taxi data"
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

resource "google_data_catalog_policy_tag" "payment_type_restricted" {
  provider     = google-beta
  taxonomy     = google_data_catalog_taxonomy.taxi_pii_taxonomy.id
  display_name = "payment_type_restricted"
  description  = "Only Manuel can access payment_type column"
}

resource "google_data_catalog_policy_tag_iam_binding" "payment_type_restricted_reader" {
  provider   = google-beta
  policy_tag = google_data_catalog_policy_tag.payment_type_restricted.name
  role       = "roles/datacatalog.categoryFineGrainedReader"

  members = [
    "user:manuel.pinar.ibanez@gmail.com",
  ]
}
