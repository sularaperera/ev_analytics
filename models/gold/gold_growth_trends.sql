{{ config(
    materialized='table',
    schema='_03_GOLD'
) }}

WITH vehicle_growth AS (

    SELECT
        REGISTERED_YEAR                 AS YEAR,
        REGISTERED_MONTH                AS MONTH,
        COUNT(*)                        AS MONTHLY_EV_COUNT
    FROM {{ ref('silver_vehicles') }}
    WHERE REGISTERED_YEAR IS NOT NULL
      AND REGISTERED_MONTH IS NOT NULL
    GROUP BY
        REGISTERED_YEAR,
        REGISTERED_MONTH

),

vehicle_yearly AS (

    -- Roll up to yearly for joining with station data
    SELECT
        YEAR,
        SUM(MONTHLY_EV_COUNT)           AS YEARLY_EV_COUNT
    FROM vehicle_growth
    GROUP BY YEAR

),

station_growth AS (

    SELECT
        OPERATIONAL_YEAR                AS YEAR,
        COUNT(*)                        AS YEARLY_STATION_COUNT,
        SUM(NUMBER_OF_CONNECTORS)       AS YEARLY_CONNECTOR_COUNT
    FROM {{ ref('silver_stations') }}
    WHERE OPERATIONAL_YEAR IS NOT NULL
      AND NZ_LOCATION_STATUS = 'inside_NZ'
    GROUP BY OPERATIONAL_YEAR

),

yearly_joined AS (

    SELECT
        v.YEAR,
        COALESCE(v.YEARLY_EV_COUNT,         0) AS YEARLY_EV_COUNT,
        COALESCE(s.YEARLY_STATION_COUNT,    0) AS YEARLY_STATION_COUNT,
        COALESCE(s.YEARLY_CONNECTOR_COUNT,  0) AS YEARLY_CONNECTOR_COUNT
    FROM vehicle_yearly v
    LEFT JOIN station_growth s ON v.YEAR = s.YEAR

),

cumulative AS (

    SELECT
        YEAR,
        YEARLY_EV_COUNT,
        YEARLY_STATION_COUNT,
        YEARLY_CONNECTOR_COUNT,

        -- Running totals: the key metric for "has supply kept up with demand"
        SUM(YEARLY_EV_COUNT)        OVER (ORDER BY YEAR)  AS CUMULATIVE_EV_COUNT,
        SUM(YEARLY_STATION_COUNT)   OVER (ORDER BY YEAR)  AS CUMULATIVE_STATION_COUNT,
        SUM(YEARLY_CONNECTOR_COUNT) OVER (ORDER BY YEAR)  AS CUMULATIVE_CONNECTOR_COUNT

    FROM yearly_joined

)

SELECT
    YEAR,
    YEARLY_EV_COUNT,
    YEARLY_STATION_COUNT,
    YEARLY_CONNECTOR_COUNT,
    CUMULATIVE_EV_COUNT,
    CUMULATIVE_STATION_COUNT,
    CUMULATIVE_CONNECTOR_COUNT,

    -- How many EVs per station cumulatively (the core supply vs demand ratio)
    ROUND(
        CUMULATIVE_EV_COUNT / NULLIF(CUMULATIVE_STATION_COUNT, 0),
        2
    ) AS CUMULATIVE_EVS_PER_STATION,

    -- How many connectors available per EV cumulatively
    ROUND(
        CUMULATIVE_CONNECTOR_COUNT / NULLIF(CUMULATIVE_EV_COUNT, 0),
        2
    ) AS CUMULATIVE_CONNECTORS_PER_EV

FROM cumulative
ORDER BY YEAR ASC