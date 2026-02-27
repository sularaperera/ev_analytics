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

    -- Only calculate distances for stations confirmed inside NZ
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

        -- Useful derived flags for Power BI analysis
        CASE
            WHEN s1.REGION = s2.REGION THEN 'Same Region'
            ELSE 'Different Region'
        END AS REGION_RELATIONSHIP,

        CASE
            WHEN s1.OPERATOR = s2.OPERATOR THEN 'Same Operator'
            ELSE 'Different Operator'
        END AS OPERATOR_RELATIONSHIP

    FROM valid_stations s1
    JOIN valid_stations s2
        -- s1.STATION_ID < s2.STATION_ID avoids duplicate pairs (A↔B and B↔A)
        ON s1.STATION_ID < s2.STATION_ID

)

SELECT * FROM distances