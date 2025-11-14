FROM python:3.10-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \
    Flask==2.3.* \
    requests==2.31.* \
    pandas==2.1.* \
    google-cloud-bigquery==3.12.*

# Copy source code
WORKDIR /app
COPY ingest_weather.py /app/ingest_weather.py

# Expose port for Cloud Run
ENV PORT 8080

# Environment variables with defaults (can be overridden at deploy time)
ENV LAT=41.8781 \
    LON=-87.6298

# Run the Flask application using gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "ingest_weather:app"]