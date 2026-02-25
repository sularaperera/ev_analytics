{{ config(
    materialized='table',
    schema='_03_GOLD'
) }}


WITH vehicle_growth AS (

SELECT

    FIRST_NZ_REGISTRATION_YEAR AS YEAR,
    COUNT(*) AS EV_COUNT

FROM {{ ref('silver_vehicles_tbl') }}

WHERE FIRST_NZ_REGISTRATION_YEAR IS NOT NULL

GROUP BY 1

),


station_growth AS (

SELECT

    YEAR(TRY_TO_DATE(DATE_FIRST_OPERATIONAL)) AS YEAR,
    COUNT(*) AS STATION_COUNT

FROM {{ ref('silver_stations_tbl') }}

WHERE TRY_TO_DATE(DATE_FIRST_OPERATIONAL) IS NOT NULL

GROUP BY 1

)


SELECT

    v.YEAR,

    v.EV_COUNT,

    COALESCE(s.STATION_COUNT,0) AS STATION_COUNT,

    ROUND(
        v.EV_COUNT / NULLIF(s.STATION_COUNT,0),
        2
    ) AS EVS_PER_STATION

FROM vehicle_growth v

LEFT JOIN station_growth s
ON v.YEAR = s.YEAR

ORDER BY s.YEAR