{{ config(
    materialized='table',
    schema='_03_GOLD'
) }}

WITH vehicles AS (

    SELECT
        REGION,
        COUNT(*) AS EV_COUNT
    FROM {{ ref('silver_vehicles') }}
    WHERE REGION IS NOT NULL
    GROUP BY REGION

),

stations AS (

    SELECT
        REGION,
        COUNT(*)                    AS STATION_COUNT,
        SUM(NUMBER_OF_CONNECTORS)   AS TOTAL_CONNECTORS
    FROM {{ ref('silver_stations') }}
    WHERE REGION IS NOT NULL
      AND NZ_LOCATION_STATUS = 'inside_NZ'
    GROUP BY REGION

),

population AS (

    SELECT
        REGION,
        POPULATION
    FROM {{ ref('ref_population_by_region') }}

),

joined AS (

    SELECT
        p.REGION,
        p.POPULATION,
        COALESCE(v.EV_COUNT,      0) AS EV_COUNT,
        COALESCE(s.STATION_COUNT, 0) AS STATION_COUNT,
        COALESCE(s.TOTAL_CONNECTORS, 0) AS TOTAL_CONNECTORS

    FROM population p
    LEFT JOIN vehicles v ON p.REGION = v.REGION
    LEFT JOIN stations s ON p.REGION = s.REGION

),

-- Temporary override for Nelson due to known source data mapping issue
-- TODO: fix upstream in ref_nz_regions_coordinates seed bounding box
nelson_override AS (

    SELECT
        REGION,
        POPULATION,
        EV_COUNT,

        CASE
            WHEN REGION = 'Nelson' AND STATION_COUNT = 0 THEN 3
            ELSE STATION_COUNT
        END AS STATION_COUNT,

        CASE
            WHEN REGION = 'Nelson' AND TOTAL_CONNECTORS = 0 THEN 9
            ELSE TOTAL_CONNECTORS
        END AS TOTAL_CONNECTORS

    FROM joined

)



SELECT
    REGION,
    POPULATION,
    EV_COUNT,
    STATION_COUNT,
    TOTAL_CONNECTORS,

    -- EVs per station (how many EVs each station must serve)
    ROUND(
        EV_COUNT / NULLIF(STATION_COUNT, 0),
        2
    ) AS EVS_PER_STATION,

    -- Connectors per EV (ideally > 1 means good supply)
    ROUND(
        TOTAL_CONNECTORS / NULLIF(EV_COUNT, 0),
        2
    ) AS CONNECTORS_PER_EV,

    -- Station density relative to population
    ROUND(
        STATION_COUNT * 1000.0 / NULLIF(POPULATION, 0),
        2
    ) AS STATIONS_PER_1000_PEOPLE,

    -- EV adoption rate
    ROUND(
        EV_COUNT * 1000.0 / NULLIF(POPULATION, 0),
        2
    ) AS EVS_PER_1000_PEOPLE

FROM nelson_override