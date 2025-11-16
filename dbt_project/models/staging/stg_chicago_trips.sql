{{ config(
    materialized='incremental',
    unique_key='taxi_id',
    partition_by={"field": "trip_start_date", "data_type": "date"}
) }}

with source_data as (

    select
        -- IDs
        taxi_id,
        unique_key,

        -- tiempos
        trip_start_timestamp,
        trip_end_timestamp,
        trip_seconds,
        trip_miles,

        -- localización (opcional, pero útil)
        pickup_census_tract,
        dropoff_census_tract,
        pickup_community_area,
        dropoff_community_area,
        pickup_latitude,
        pickup_longitude,
        pickup_location,
        dropoff_latitude,
        dropoff_longitude,
        dropoff_location,

        -- importes
        fare,
        tips,
        tolls,
        extras,
        trip_total,

        -- otros
        payment_type,
        company
    from {{ source('chicago_taxi_trips', 'taxi_trips') }}
    where trip_start_timestamp between
          timestamp('2023-06-01') and timestamp('2023-12-31 23:59:59')

    {% if is_incremental() %}
      -- En incremental solo traemos viajes nuevos respecto a lo ya cargado
      and trip_start_timestamp >
          (select max(trip_start_timestamp) from {{ this }})
    {% endif %}
)

select
    taxi_id,
    unique_key,
    date(trip_start_timestamp) as trip_start_date,
    trip_start_timestamp,
    trip_end_timestamp,
    trip_seconds,
    trip_miles,

    pickup_census_tract,
    dropoff_census_tract,
    pickup_community_area,
    dropoff_community_area,
    pickup_latitude,
    pickup_longitude,
    pickup_location,
    dropoff_latitude,
    dropoff_longitude,
    dropoff_location,

    fare,
    tips,
    tolls,
    extras,
    trip_total,

    payment_type,
    company
from source_data