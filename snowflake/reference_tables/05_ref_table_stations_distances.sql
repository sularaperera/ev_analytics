-- Distance between charging stations using Haversine formula 

CREATE OR REPLACE TABLE DEV_EV_ANALYTICS._99_REFERENCE.STATION_DISTANCES_KM AS
WITH valid_stations AS (
    SELECT *,
        CASE 
            WHEN LATITUDE BETWEEN -47.3 AND -34.0
            AND LONGITUDE BETWEEN 166.0 AND 179.0
            THEN 'inside_NZ'
            ELSE 'outlier'
        END AS nz_location_status
    FROM DEV_EV_ANALYTICS.DBT_SPERERA__02_SILVER.SILVER_STATIONS_TBL
)
SELECT
    s1.NAME AS STATION_1,
    s2.NAME AS STATION_2,
    s1.LATITUDE  AS LAT1,
    s1.LONGITUDE AS LON1,
    s1.nz_location_status AS NZ_STATUS_1,
    s2.LATITUDE  AS LAT2,
    s2.LONGITUDE AS LON2,
    s2.nz_location_status AS NZ_STATUS_2,
    -- Haversine formula rounded to 0 decimal places
    ROUND(
        2 * 6371 * ASIN(
            SQRT(
                POWER(SIN(RADIANS(s2.LATITUDE - s1.LATITUDE) / 2), 2) +
                COS(RADIANS(s1.LATITUDE)) *
                COS(RADIANS(s2.LATITUDE)) *
                POWER(SIN(RADIANS(s2.LONGITUDE - s1.LONGITUDE) / 2), 2)
            )
        ), 0
    ) AS DISTANCE_KM
FROM valid_stations s1
JOIN valid_stations s2
    ON s1.OBJECTID < s2.OBJECTID
WHERE s1.nz_location_status = 'inside_NZ'
AND s2.nz_location_status = 'inside_NZ'
ORDER BY DISTANCE_KM DESC;