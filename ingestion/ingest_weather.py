import os
import datetime as dt

from flask import Flask, request, jsonify
import requests
import pandas as pd
from google.cloud import bigquery
from google.api_core.exceptions import NotFound

app = Flask(__name__)

# Dataset donde se escribirá la tabla daily_weather_chicago
BQ_DATASET = os.environ.get("BQ_DATASET", "taxi_raw")
BQ_TABLE = "daily_weather_chicago"

# Coordenadas aproximadas de Chicago
LAT, LON = 41.8781, -87.6298


def fetch_weather(date: dt.date) -> pd.DataFrame:
    base_url = "https://archive-api.open-meteo.com/v1/archive"
    params = {
        "latitude": LAT,
        "longitude": LON,
        "start_date": date.isoformat(),
        "end_date": date.isoformat(),
        "hourly": "temperature_2m,precipitation,cloudcover,windspeed_10m",
        "timezone": "UTC",
    }

    resp = requests.get(base_url, params=params, timeout=30)

    try:
        resp.raise_for_status()
    except requests.HTTPError as e:
        app.logger.error(
            "Error calling Open-Meteo API: %s, response: %s",
            e,
            resp.text[:500],
        )
        raise

    data = resp.json()["hourly"]
    df = pd.DataFrame(data)

    numeric_cols = ["temperature_2m", "precipitation", "cloudcover", "windspeed_10m"]
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    df["date"] = pd.to_datetime(df["time"]).dt.date
    return df



def load_to_bigquery(df: pd.DataFrame, date: dt.date) -> None:
    client = bigquery.Client()
    table_id = f"{client.project}.{BQ_DATASET}.{BQ_TABLE}"

    # 1) Intento borrar datos de ese día (idempotencia)
    try:
        client.query(
            f"""
            DELETE FROM `{table_id}`
            WHERE date = @date
            """,
            job_config=bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ScalarQueryParameter("date", "DATE", date)
                ]
            ),
        ).result()
    except NotFound:
        # Primera ejecución: la tabla aún no existe → lo ignoramos
        pass

    # 2) Cargo los datos del DataFrame
    job = client.load_table_from_dataframe(
        df,
        table_id,
        job_config=bigquery.LoadJobConfig(write_disposition="WRITE_APPEND"),
    )
    job.result()


@app.route("/", methods=["GET"])
def main():
    date_param = request.args.get("date")
    if date_param:
        target_date = dt.datetime.strptime(date_param, "%Y-%m-%d").date()
    else:
        # Por defecto, día anterior → ideal para Cloud Scheduler diario
        target_date = dt.date.today() - dt.timedelta(days=1)

    df = fetch_weather(target_date)
    load_to_bigquery(df, target_date)

    return jsonify(
        {"status": "ok", "date": target_date.isoformat(), "rows": len(df)}
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
