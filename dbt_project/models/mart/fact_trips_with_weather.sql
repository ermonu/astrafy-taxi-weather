{{ config(
    materialized = 'table',
    partition_by = {
      "field": "trip_start_date",
      "data_type": "date"
    },
    cluster_by = ["payment_type"],
    require_partition_filter = true
) }}

with trips as (
    select
        date(trip_start_timestamp) as trip_start_date,
        count(*)                  as trips,
        avg(trip_seconds)         as avg_trip_duration,
        avg(trip_miles)           as avg_trip_miles,
        payment_type
    from {{ ref('stg_chicago_trips') }}
    group by 1, 5
),

weather as (
    select
        date                as date,
        avg(temperature_2m) as avg_temp,
        avg(precipitation)  as avg_precip,
        avg(cloudcover)     as avg_cloudcover,
        avg(windspeed_10m)  as avg_windspeed
    from {{ source('weather', 'daily_weather_chicago') }}
    group by 1
)

select
    t.trip_start_date,
    t.trips,
    t.avg_trip_duration,
    t.avg_trip_miles,
    t.payment_type,
    w.avg_temp,
    w.avg_precip,
    w.avg_cloudcover,
    w.avg_windspeed
from trips t
left join weather w
  on t.trip_start_date = w.date

