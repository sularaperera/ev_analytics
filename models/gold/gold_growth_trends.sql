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

    SELECT
        YEAR,
        SUM(MONTHLY_EV_COUNT)           AS YEARLY_EV_COUNT
    FROM vehicle_growth
    GROUP BY YEAR

),

station_growth_monthly AS (

    SELECT
        OPERATIONAL_YEAR                AS YEAR,
        OPERATIONAL_MONTH               AS MONTH,
        COUNT(*)                        AS MONTHLY_STATION_COUNT,
        SUM(NUMBER_OF_CONNECTORS)       AS MONTHLY_CONNECTOR_COUNT
    FROM {{ ref('silver_stations') }}
    WHERE OPERATIONAL_YEAR IS NOT NULL
      AND OPERATIONAL_MONTH IS NOT NULL
      AND NZ_LOCATION_STATUS = 'inside_NZ'
    GROUP BY
        OPERATIONAL_YEAR,
        OPERATIONAL_MONTH

),

station_growth_yearly AS (

    SELECT
        YEAR,
        SUM(MONTHLY_STATION_COUNT)      AS YEARLY_STATION_COUNT,
        SUM(MONTHLY_CONNECTOR_COUNT)    AS YEARLY_CONNECTOR_COUNT
    FROM station_growth_monthly
    GROUP BY YEAR

),

-- ─────────────────────────────────────────────
-- MONTHLY GRAIN
-- ─────────────────────────────────────────────
monthly_joined AS (

    SELECT
        v.YEAR,
        v.MONTH,
        COALESCE(v.MONTHLY_EV_COUNT,        0) AS MONTHLY_EV_COUNT,
        COALESCE(s.MONTHLY_STATION_COUNT,   0) AS MONTHLY_STATION_COUNT,
        COALESCE(s.MONTHLY_CONNECTOR_COUNT, 0) AS MONTHLY_CONNECTOR_COUNT
    FROM vehicle_growth v
    LEFT JOIN station_growth_monthly s
           ON v.YEAR  = s.YEAR
          AND v.MONTH = s.MONTH

),

monthly_cumulative AS (

    SELECT
        YEAR,
        MONTH,
        MONTHLY_EV_COUNT,
        MONTHLY_STATION_COUNT,
        MONTHLY_CONNECTOR_COUNT,

        SUM(MONTHLY_EV_COUNT)        OVER (ORDER BY YEAR, MONTH) AS CUMULATIVE_EV_COUNT,
        SUM(MONTHLY_STATION_COUNT)   OVER (ORDER BY YEAR, MONTH) AS CUMULATIVE_STATION_COUNT,
        SUM(MONTHLY_CONNECTOR_COUNT) OVER (ORDER BY YEAR, MONTH) AS CUMULATIVE_CONNECTOR_COUNT

    FROM monthly_joined

),

monthly_final AS (

    SELECT
        YEAR,
        MONTH,
        'monthly'                           AS GRAIN,
        MONTHLY_EV_COUNT                    AS PERIOD_EV_COUNT,
        MONTHLY_STATION_COUNT               AS PERIOD_STATION_COUNT,
        MONTHLY_CONNECTOR_COUNT             AS PERIOD_CONNECTOR_COUNT,
        CUMULATIVE_EV_COUNT,
        CUMULATIVE_STATION_COUNT,
        CUMULATIVE_CONNECTOR_COUNT,
        ROUND(
            CUMULATIVE_EV_COUNT / NULLIF(CUMULATIVE_STATION_COUNT, 0),
            2
        )                                   AS CUMULATIVE_EVS_PER_STATION,
        ROUND(
            CUMULATIVE_CONNECTOR_COUNT / NULLIF(CUMULATIVE_EV_COUNT, 0),
            2
        )                                   AS CUMULATIVE_CONNECTORS_PER_EV
    FROM monthly_cumulative

),

-- ─────────────────────────────────────────────
-- YEARLY GRAIN
-- ─────────────────────────────────────────────
yearly_joined AS (

    SELECT
        v.YEAR,
        COALESCE(v.YEARLY_EV_COUNT,         0) AS YEARLY_EV_COUNT,
        COALESCE(s.YEARLY_STATION_COUNT,    0) AS YEARLY_STATION_COUNT,
        COALESCE(s.YEARLY_CONNECTOR_COUNT,  0) AS YEARLY_CONNECTOR_COUNT
    FROM vehicle_yearly v
    LEFT JOIN station_growth_yearly s ON v.YEAR = s.YEAR

),

yearly_cumulative AS (

    SELECT
        YEAR,
        YEARLY_EV_COUNT,
        YEARLY_STATION_COUNT,
        YEARLY_CONNECTOR_COUNT,

        SUM(YEARLY_EV_COUNT)        OVER (ORDER BY YEAR) AS CUMULATIVE_EV_COUNT,
        SUM(YEARLY_STATION_COUNT)   OVER (ORDER BY YEAR) AS CUMULATIVE_STATION_COUNT,
        SUM(YEARLY_CONNECTOR_COUNT) OVER (ORDER BY YEAR) AS CUMULATIVE_CONNECTOR_COUNT

    FROM yearly_joined

),

yearly_final AS (

    SELECT
        YEAR,
        NULL                                AS MONTH,
        'yearly'                            AS GRAIN,
        YEARLY_EV_COUNT                     AS PERIOD_EV_COUNT,
        YEARLY_STATION_COUNT                AS PERIOD_STATION_COUNT,
        YEARLY_CONNECTOR_COUNT              AS PERIOD_CONNECTOR_COUNT,
        CUMULATIVE_EV_COUNT,
        CUMULATIVE_STATION_COUNT,
        CUMULATIVE_CONNECTOR_COUNT,
        ROUND(
            CUMULATIVE_EV_COUNT / NULLIF(CUMULATIVE_STATION_COUNT, 0),
            2
        )                                   AS CUMULATIVE_EVS_PER_STATION,
        ROUND(
            CUMULATIVE_CONNECTOR_COUNT / NULLIF(CUMULATIVE_EV_COUNT, 0),
            2
        )                                   AS CUMULATIVE_CONNECTORS_PER_EV
    FROM yearly_cumulative

)

-- ─────────────────────────────────────────────
-- UNION BOTH GRAINS
-- ─────────────────────────────────────────────
SELECT * FROM monthly_final
UNION ALL
SELECT * FROM yearly_final
ORDER BY YEAR ASC, MONTH ASC NULLS LAST, GRAIN DESC