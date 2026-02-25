{{ config(
    materialized='table',
    schema='_03_GOLD'
) }}

WITH vehicles AS (

SELECT

    REGION,
    COUNT(*) AS EV_COUNT

FROM {{ ref('silver_vehicles_tbl') }}

GROUP BY REGION

),

stations AS (

SELECT

    REGION,
    COUNT(*) AS STATION_COUNT

FROM {{ ref('silver_stations_tbl') }}

GROUP BY REGION

),

population AS (

SELECT
    REGION,
    POPULATION
FROM {{ source('reference','POPULATION_BY_REGION') }}

)


SELECT

    p.REGION,

    p.POPULATION,

    COALESCE(v.EV_COUNT,0) AS EV_COUNT,

    COALESCE(s.STATION_COUNT,0) AS STATION_COUNT,

    ROUND(
        EV_COUNT / NULLIF(STATION_COUNT,0),
        2
    ) AS EVS_PER_STATION,

    ROUND(
        STATION_COUNT * 1000 / POPULATION,
        4
    ) AS STATIONS_PER_1000_PEOPLE

FROM population p

LEFT JOIN vehicles v
ON p.REGION = v.REGION

LEFT JOIN stations s
ON p.REGION = s.REGION