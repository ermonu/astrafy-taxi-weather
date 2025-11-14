"""
Ingestion service to fetch historical weather data for Chicago and load it
into BigQuery.  The service is designed to run in Cloud Run and can be
triggered via HTTP (for instance by Cloud Scheduler).  It fetches the
previous day's weather by default but allows overriding the date via a
`date` query parameter in `YYYY‑MM‑DD` format.

The ingestion uses the Open‑Meteo archive API, which does not require
authentication.  You may substitute it with any other weather API by
modifying the `fetch_weather` function.  Loaded data is appended to
`<RAW_DATASET>.weather_daily` in BigQuery.

Environment variables expected:

* `PROJECT_ID`    – GCP project ID.
* `RAW_DATASET`   – BigQuery dataset ID for raw tables.
* `LAT`           – latitude of the location (default: 41.8781 for Chicago).
* `LON`           – longitude of the location (default: -87.6298 for Chicago).

Dependencies (see Dockerfile): flask, requests, pandas, google‑cloud‑bigquery.
"""

import os
import datetime
import logging
from typing import Optional

import requests
import pandas as pd
from flask import Flask, request, jsonify

try:
    from google.cloud import bigquery
except ImportError:
    bigquery = None  # type: ignore


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def fetch_weather(date: str, lat: float, lon: float) -> pd.DataFrame:
    """Fetch daily weather metrics for a given date and location.

    Uses the Open‑Meteo archive API to retrieve precipitation, temperature
    and wind speed.  Returns a pandas DataFrame with a single row.

    Args:
        date: ISO‑formatted date (`YYYY‑MM‑DD`).  Both start and end are
            set to this date, so only one day is returned.
        lat: Latitude of the location.
        lon: Longitude of the location.

    Returns:
        DataFrame with columns [date, precipitation_sum, temp_max, temp_min, windspeed_max].
    """
    base_url = "https://archive-api.open-meteo.com/v1/archive"
    params = {
        "latitude": lat,
        "longitude": lon,
        "start_date": date,
        "end_date": date,
        "daily": [
            "precipitation_sum",
            "temperature_2m_max",
            "temperature_2m_min",
            "windspeed_10m_max",
        ],
        "timezone": "UTC",
    }
    logger.info("Fetching weather data for %s", date)
    resp = requests.get(base_url, params=params, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    if not data.get("daily"):
        raise ValueError(f"Unexpected response: {data}")
    daily = data["daily"]
    # Build DataFrame
    df = pd.DataFrame({
        "date": daily["time"],
        "precipitation_sum": daily.get("precipitation_sum", [None])[0],
        "temp_max": daily.get("temperature_2m_max", [None])[0],
        "temp_min": daily.get("temperature_2m_min", [None])[0],
        "windspeed_max": daily.get("windspeed_10m_max", [None])[0],
    }, index=[0])
    return df


def load_to_bigquery(df: pd.DataFrame, project: str, dataset: str, table: str = "weather_daily") -> None:
    """Append DataFrame rows to a BigQuery table.

    Creates the table if it does not exist.  The table schema is inferred
    from the DataFrame dtypes.  Requires the `google‑cloud‑bigquery`
    library and proper authentication via the service account attached to
    the Cloud Run service.

    Args:
        df: DataFrame to load.
        project: GCP project ID.
        dataset: BigQuery dataset ID.
        table: Table name within the dataset.
    """
    if bigquery is None:
        logger.error("google-cloud-bigquery library is not installed")
        return
    client = bigquery.Client(project=project)
    table_id = f"{project}.{dataset}.{table}"
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
        autodetect=True,
    )
    logger.info("Loading data into %s", table_id)
    job = client.load_table_from_dataframe(df, table_id, job_config=job_config)
    job.result()
    logger.info("Loaded %d row(s) into %s", df.shape[0], table_id)


def ingest_for_date(date: str) -> None:
    """Fetch weather for the given date and write to BigQuery."""
    lat = float(os.environ.get("LAT", "41.8781"))
    lon = float(os.environ.get("LON", "-87.6298"))
    project = os.environ.get("PROJECT_ID")
    dataset = os.environ.get("RAW_DATASET")
    if not project or not dataset:
        raise RuntimeError("PROJECT_ID and RAW_DATASET environment variables must be set")
    df = fetch_weather(date, lat, lon)
    load_to_bigquery(df, project, dataset)


def create_app() -> Flask:
    """Factory function to create the Flask application."""
    app = Flask(__name__)

    @app.route("/", methods=["POST", "GET"])
    def run_ingestion() -> tuple:
        # Accept an optional date parameter; default to yesterday
        date_param: Optional[str] = request.args.get("date")
        try:
            if date_param:
                date = datetime.datetime.strptime(date_param, "%Y-%m-%d").date()
            else:
                date = datetime.date.today() - datetime.timedelta(days=1)
            ingest_for_date(date.isoformat())
            return jsonify({"status": "ok", "date": date.isoformat()}), 200
        except Exception as exc:
            logger.exception("Failed to ingest weather")
            return jsonify({"status": "error", "error": str(exc)}), 500

    return app


app = create_app()

if __name__ == "__main__":
    # For local testing
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)