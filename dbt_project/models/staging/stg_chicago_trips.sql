{{ config(
    materialized='incremental',
    unique_key='trip_id',
    partition_by={"field": "trip_start_date", "data_type": "date"}
) }}

--
-- Stage the Chicago taxi trips data for the period 2023‑06‑01 to 2023‑12‑31.
-- This model selects and casts relevant columns, generates a date key
-- (`trip_start_date`) and limits the rows to the challenge period.  On
-- incremental runs it only processes records newer than the maximum
-- timestamp already loaded.
--

with source_data as (
    select
        trip_id,
        trip_start_timestamp,
        trip_end_timestamp,
        trip_seconds,
        trip_miles,
        payment_type,
        fare,
        tips,
        extras,
        total
    from `bigquery-public-data.chicago_taxi_trips.taxi_trips`
    where trip_start_timestamp >= '2023-06-01'
      and trip_start_timestamp < '2024-01-01'
      {% if is_incremental() %}
        and trip_start_timestamp > (select max(trip_start_timestamp) from {{ this }})
      {% endif %}
)

select
    cast(trip_id as string) as trip_id,
    cast(trip_start_timestamp as timestamp) as trip_start_timestamp,
    cast(trip_end_timestamp as timestamp) as trip_end_timestamp,
    cast(trip_seconds as int64) as trip_seconds,
    cast(trip_miles as numeric) as trip_miles,
    cast(payment_type as string) as payment_type,
    cast(fare as numeric) as fare,
    cast(tips as numeric) as tips,
    cast(extras as numeric) as extras,
    cast(total as numeric) as total,
    cast(date(trip_start_timestamp) as date) as trip_start_date
from source_data