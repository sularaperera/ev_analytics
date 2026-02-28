{{
config(
    materialized='table',
    schema='_03_GOLD',
)
}}

WITH valid_stations AS (

    SELECT
        STATION_ID,
        STATION_NAME,
        OPERATOR,
        REGION,
        LATITUDE,
        LONGITUDE,
        NZ_LOCATION_STATUS

    FROM {{ ref('silver_stations') }}

    WHERE NZ_LOCATION_STATUS = 'inside_NZ'
      AND LATITUDE  IS NOT NULL
      AND LONGITUDE IS NOT NULL

),

distances AS (

    SELECT
        s1.STATION_ID                       AS STATION_1_ID,
        s1.STATION_NAME                     AS STATION_1_NAME,
        s1.OPERATOR                         AS STATION_1_OPERATOR,
        s1.REGION                           AS STATION_1_REGION,
        s1.LATITUDE                         AS STATION_1_LAT,
        s1.LONGITUDE                        AS STATION_1_LON,

        s2.STATION_ID                       AS STATION_2_ID,
        s2.STATION_NAME                     AS STATION_2_NAME,
        s2.OPERATOR                         AS STATION_2_OPERATOR,
        s2.REGION                           AS STATION_2_REGION,
        s2.LATITUDE                         AS STATION_2_LAT,
        s2.LONGITUDE                        AS STATION_2_LON,

        -- Haversine formula (Earth radius = 6371 km)
        ROUND(
            2 * 6371 * ASIN(
                SQRT(
                    POWER(SIN(RADIANS(s2.LATITUDE  - s1.LATITUDE)  / 2), 2) +
                    COS(RADIANS(s1.LATITUDE))  *
                    COS(RADIANS(s2.LATITUDE))  *
                    POWER(SIN(RADIANS(s2.LONGITUDE - s1.LONGITUDE) / 2), 2)
                )
            ), 2
        ) AS DISTANCE_KM,

        CASE
            WHEN s1.REGION = s2.REGION THEN 'Same Region'
            ELSE 'Different Region'
        END AS REGION_RELATIONSHIP,

        CASE
            WHEN s1.OPERATOR = s2.OPERATOR THEN 'Same Operator'
            ELSE 'Different Operator'
        END AS OPERATOR_RELATIONSHIP

    FROM valid_stations s1
    -- Use != instead of < so every station gets ALL other stations as candidates
    -- This is required for nearest-neighbour: each station needs its own minimum
    JOIN valid_stations s2
        ON s1.STATION_ID != s2.STATION_ID

),

-- ============================================================
-- NEAREST NEIGHBOUR: for each station, find its single
-- closest neighbour regardless of region or operator
-- ============================================================
nearest_neighbour AS (

    SELECT
        STATION_1_ID                        AS STATION_ID,
        STATION_1_NAME                      AS STATION_NAME,
        STATION_1_OPERATOR                  AS OPERATOR,
        STATION_1_REGION                    AS REGION,
        STATION_1_LAT                       AS LATITUDE,
        STATION_1_LON                       AS LONGITUDE,

        -- The nearest station details
        FIRST_VALUE(STATION_2_ID)
            OVER (
                PARTITION BY STATION_1_ID
                ORDER BY DISTANCE_KM ASC
            )                               AS NEAREST_STATION_ID,

        FIRST_VALUE(STATION_2_NAME)
            OVER (
                PARTITION BY STATION_1_ID
                ORDER BY DISTANCE_KM ASC
            )                               AS NEAREST_STATION_NAME,

        FIRST_VALUE(STATION_2_REGION)
            OVER (
                PARTITION BY STATION_1_ID
                ORDER BY DISTANCE_KM ASC
            )                               AS NEAREST_STATION_REGION,

        FIRST_VALUE(STATION_2_OPERATOR)
            OVER (
                PARTITION BY STATION_1_ID
                ORDER BY DISTANCE_KM ASC
            )                               AS NEAREST_STATION_OPERATOR,

        FIRST_VALUE(DISTANCE_KM)
            OVER (
                PARTITION BY STATION_1_ID
                ORDER BY DISTANCE_KM ASC
            )                               AS NEAREST_STATION_DISTANCE_KM,

        REGION_RELATIONSHIP,
        OPERATOR_RELATIONSHIP,
        DISTANCE_KM

    FROM distances

),

-- Deduplicate: each station appears once with its nearest neighbour row
nearest_neighbour_deduped AS (

    SELECT DISTINCT
        STATION_ID,
        STATION_NAME,
        OPERATOR,
        REGION,
        LATITUDE,
        LONGITUDE,
        NEAREST_STATION_ID,
        NEAREST_STATION_NAME,
        NEAREST_STATION_REGION,
        NEAREST_STATION_OPERATOR,
        NEAREST_STATION_DISTANCE_KM

    FROM nearest_neighbour

),

-- ============================================================
-- COVERAGE GAP FLAGS: classify each station by how isolated
-- it is from its nearest neighbour
-- Thresholds are NZ-context informed:
--   < 10 km  = densely clustered (urban)
--   10-50 km = reasonable highway corridor spacing
--   > 50 km  = potential coverage gap
--   > 100 km = critical coverage gap
-- ============================================================
coverage_flags AS (

    SELECT
        STATION_ID,
        STATION_NAME,
        OPERATOR,
        REGION,
        LATITUDE,
        LONGITUDE,
        NEAREST_STATION_ID,
        NEAREST_STATION_NAME,
        NEAREST_STATION_REGION,
        NEAREST_STATION_OPERATOR,
        NEAREST_STATION_DISTANCE_KM,

        CASE
            WHEN NEAREST_STATION_DISTANCE_KM <  10  THEN 'Densely Clustered'
            WHEN NEAREST_STATION_DISTANCE_KM <  50  THEN 'Well Covered'
            WHEN NEAREST_STATION_DISTANCE_KM <  100 THEN 'Coverage Gap'
            ELSE                                          'Critical Coverage Gap'
        END                                         AS COVERAGE_STATUS,

        -- Boolean-style flag for easy Power BI filtering
        CASE
            WHEN NEAREST_STATION_DISTANCE_KM >= 50 THEN 'Yes'
            ELSE 'No'
        END                                         AS IS_COVERAGE_GAP,

        -- Cross-operator nearest neighbour flag: useful to show
        -- where operators are duplicating coverage vs filling gaps
        CASE
            WHEN NEAREST_STATION_OPERATOR != OPERATOR THEN 'Competitor is Nearest'
            ELSE 'Same Operator is Nearest'
        END                                         AS NEAREST_NEIGHBOUR_OPERATOR_TYPE

    FROM nearest_neighbour_deduped

),

-- ============================================================
-- REGION COVERAGE SUMMARY: roll up to region level so Power BI
-- can show a heatmap of coverage gaps per region
-- ============================================================
region_coverage_summary AS (

    SELECT
        REGION,
        COUNT(*)                                            AS TOTAL_STATIONS,
        ROUND(AVG(NEAREST_STATION_DISTANCE_KM), 2)         AS AVG_NEAREST_DISTANCE_KM,
        ROUND(MIN(NEAREST_STATION_DISTANCE_KM), 2)         AS MIN_NEAREST_DISTANCE_KM,
        ROUND(MAX(NEAREST_STATION_DISTANCE_KM), 2)         AS MAX_NEAREST_DISTANCE_KM,

        -- Spread metric: large gap between min and max suggests
        -- uneven distribution within the region
        ROUND(
            MAX(NEAREST_STATION_DISTANCE_KM)
            - MIN(NEAREST_STATION_DISTANCE_KM), 2
        )                                                   AS DISTANCE_SPREAD_KM,

        COUNT(CASE WHEN IS_COVERAGE_GAP = 'Yes' THEN 1 END) AS GAP_STATION_COUNT,

        -- % of stations in this region that are isolated (>50km from nearest)
        ROUND(
            COUNT(CASE WHEN IS_COVERAGE_GAP = 'Yes' THEN 1 END)
            * 100.0 / NULLIF(COUNT(*), 0), 1
        )                                                   AS PCT_STATIONS_IN_GAP,

        COUNT(CASE WHEN COVERAGE_STATUS = 'Critical Coverage Gap' THEN 1 END)
                                                            AS CRITICAL_GAP_COUNT

    FROM coverage_flags

    GROUP BY REGION

)

-- ============================================================
-- FINAL OUTPUT: station-level detail joined with region summary
-- Two use cases for Power BI:
--   1. Map visual  → use station-level lat/lon + COVERAGE_STATUS
--   2. Bar/table   → use REGION + PCT_STATIONS_IN_GAP
-- ============================================================
SELECT

    -- Station-level columns
    cf.STATION_ID,
    cf.STATION_NAME,
    cf.OPERATOR,
    cf.REGION,
    cf.LATITUDE,
    cf.LONGITUDE,
    cf.NEAREST_STATION_ID,
    cf.NEAREST_STATION_NAME,
    cf.NEAREST_STATION_REGION,
    cf.NEAREST_STATION_OPERATOR,
    cf.NEAREST_STATION_DISTANCE_KM,
    cf.COVERAGE_STATUS,
    cf.IS_COVERAGE_GAP,
    cf.NEAREST_NEIGHBOUR_OPERATOR_TYPE,

    -- Region-level rollup columns (repeated per station, useful for Power BI)
    rcs.TOTAL_STATIONS               AS REGION_TOTAL_STATIONS,
    rcs.AVG_NEAREST_DISTANCE_KM      AS REGION_AVG_NEAREST_DISTANCE_KM,
    rcs.MIN_NEAREST_DISTANCE_KM      AS REGION_MIN_NEAREST_DISTANCE_KM,
    rcs.MAX_NEAREST_DISTANCE_KM      AS REGION_MAX_NEAREST_DISTANCE_KM,
    rcs.DISTANCE_SPREAD_KM           AS REGION_DISTANCE_SPREAD_KM,
    rcs.GAP_STATION_COUNT            AS REGION_GAP_STATION_COUNT,
    rcs.PCT_STATIONS_IN_GAP          AS REGION_PCT_STATIONS_IN_GAP,
    rcs.CRITICAL_GAP_COUNT           AS REGION_CRITICAL_GAP_COUNT

FROM coverage_flags cf
LEFT JOIN region_coverage_summary rcs
    ON cf.REGION = rcs.REGION

ORDER BY cf.NEAREST_STATION_DISTANCE_KM DESC