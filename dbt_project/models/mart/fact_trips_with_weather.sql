{{ config(
    materialized='table'
) }}

--
-- Fact table combining taxi trips with daily weather metrics.
--
-- It joins the staging trips model to the raw weather data on the
-- trip_start_date and computes aggregate measures per day and weather
-- metrics.  This table can be used directly in Looker Studio to build
-- dashboards analysing the correlation between weather and trip
-- duration.
--

with trips as (
    select
        trip_start_date as date,
        trip_seconds / 60.0 as trip_minutes
    from {{ ref('stg_chicago_trips') }}
),
weather as (
    select
        date,
        precipitation_sum,
        temp_max,
        temp_min,
        windspeed_max
    from `{{ var('raw_dataset') }}`.weather_daily
)

select
    trips.date,
    weather.precipitation_sum,
    weather.temp_max,
    weather.temp_min,
    weather.windspeed_max,
    count(*) as trip_count,
    avg(trips.trip_minutes) as avg_trip_minutes
from trips
left join weather
  on trips.date = weather.date
group by 1,2,3,4,5
order by 1;