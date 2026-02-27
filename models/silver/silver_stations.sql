{{ 
config(
    materialized='incremental',
    unique_key='STATION_ID',
    schema='_02_SILVER',
    on_schema_change='append_new_columns'
) 
}}

WITH stations AS (

    SELECT
        STATION_ID,
        STATION_NAME,
        OPERATOR,
        OWNER,
        ADDRESS,
        is24Hours,
        carParkCount,
        hasCarparkCost,
        maxTimeLimit,
        hasTouristAttraction,
        TRY_TO_DOUBLE(latitude)  AS LATITUDE,
        TRY_TO_DOUBLE(longitude) AS LONGITUDE,
        currentType,
        dateFirstOperational,
        numberOfConnectors,
        connectorsList,
        hasChargingCost,
        GlobalID,

        LOADED_AT,
        load_id,
        FILE_ROW_NUMBER,
        SOURCE_FILE

    FROM {{ ref('bronze_stations') }}

    {% if is_incremental() %}

    WHERE LOADED_AT >
        (SELECT COALESCE(MAX(LOADED_AT),'1900-01-01') FROM {{ this }})

    {% endif %}

),

regions AS (

    SELECT
        REGION,
        CAST(Lat_Min AS FLOAT) AS LAT_MIN,
        CAST(Lat_Max AS FLOAT) AS LAT_MAX,
        CAST(Long_Min AS FLOAT) AS LON_MIN,
        CAST(Long_Max AS FLOAT) AS LON_MAX
    FROM {{ ref('ref_nz_regions_coordinates') }}

),

region_mapping AS (

    SELECT
        s.*,

        r.REGION,

        CASE
            WHEN s.LATITUDE BETWEEN -47.3 AND -34.0
            AND s.LONGITUDE BETWEEN 166.0 AND 179.0
            THEN 'inside_NZ'
            ELSE 'outlier'
        END AS NZ_LOCATION_STATUS

    FROM stations s

    LEFT JOIN regions r
        ON s.LATITUDE BETWEEN r.LAT_MIN AND r.LAT_MAX
       AND s.LONGITUDE BETWEEN r.LON_MIN AND r.LON_MAX

)

SELECT *
FROM region_mapping
QUALIFY ROW_NUMBER() OVER (
PARTITION BY STATION_ID
ORDER BY REGION
) = 1