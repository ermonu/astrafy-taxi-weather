resource "google_cloud_scheduler_job" "daily_weather" {
  name        = "daily-weather-ingest"
  description = "Fetch previous day's weather for Chicago"
  schedule    = "0 6 * * *"
  time_zone   = "Etc/UTC"

  http_target {
    uri         = google_cloud_run_service.weather_ingest.status[0].url
    http_method = "GET"
  }
}
