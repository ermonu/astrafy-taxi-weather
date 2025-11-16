FROM python:3.10-slim

ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    Flask==2.3.* \
    requests==2.31.* \
    pandas==2.1.* \
    pyarrow==14.* \
    google-cloud-bigquery==3.12.* \
    google-api-core==2.11.*

WORKDIR /app

COPY ingestion/ingest_weather.py /app/ingest_weather.py

ENV PORT=8080

CMD ["python", "ingest_weather.py"]