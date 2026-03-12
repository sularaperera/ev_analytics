{{
config(
    materialized='incremental',
    unique_key='STATION_ID',
    incremental_strategy='merge',
    schema='_02_SILVER',
    on_schema_change='append_new_columns'
)
}}

WITH bronze_filtered AS (

    SELECT *
    FROM {{ ref('bronze_stations') }}

    {% if is_incremental() %}
    -- Only process stations that arrived in bronze after the last silver run
    WHERE LOADED_AT > (SELECT COALESCE(MAX(LOADED_AT), '1900-01-01') FROM {{ this }})
    {% endif %}

),

stations AS (

    SELECT
        STATION_ID,
        STATION_NAME,
        OPERATOR,
        OWNER,
        ADDRESS,
        IS24HOURS,
        CARPARKCOUNT,
        HASCARPARKCOST,
        MAXTIMELIMIT,
        HASTOURISTATTRACTION,

        TRY_TO_DOUBLE(LATITUDE)                         AS LATITUDE,
        TRY_TO_DOUBLE(LONGITUDE)                        AS LONGITUDE,

        CURRENTTYPE,

        -- Drop raw string, keep only the parsed date
        TRY_TO_DATE(DATEFIRSTOPERATIONAL, 'DD/MM/YYYY') AS DATE_FIRST_OPERATIONAL,
        YEAR(TRY_TO_DATE(DATEFIRSTOPERATIONAL, 'DD/MM/YYYY'))  AS OPERATIONAL_YEAR,
        MONTH(TRY_TO_DATE(DATEFIRSTOPERATIONAL, 'DD/MM/YYYY')) AS OPERATIONAL_MONTH,

        TRY_TO_NUMBER(NUMBEROFCONNECTORS)             AS NUMBER_OF_CONNECTORS,
        CONNECTORSLIST,
        HASCHARGINGCOST,
        GLOBALID,

        LOADED_AT,
        LOAD_ID,
        FILE_ROW_NUMBER,
        SOURCE_FILE

    FROM bronze_filtered

),

regions AS (

    SELECT
        REGION,                    
        CAST(LAT_MIN AS FLOAT) AS LAT_MIN,
        CAST(LAT_MAX AS FLOAT) AS LAT_MAX,
        CAST(LONG_MIN AS FLOAT) AS LON_MIN,
        CAST(LONG_MAX AS FLOAT) AS LON_MAX
    FROM {{ ref('ref_nz_regions_coordinates') }}

),

region_mapping AS (

    SELECT
        s.STATION_ID,
        s.STATION_NAME,
        s.OPERATOR,
        s.OWNER,
        s.ADDRESS,
        s.IS24HOURS,
        s.CARPARKCOUNT,
        s.HASCARPARKCOST,
        s.MAXTIMELIMIT,
        s.HASTOURISTATTRACTION,
        s.LATITUDE,
        s.LONGITUDE,
        s.CURRENTTYPE,
        s.DATE_FIRST_OPERATIONAL,
        s.OPERATIONAL_YEAR,
        s.OPERATIONAL_MONTH,
        s.NUMBER_OF_CONNECTORS,
        s.CONNECTORSLIST,
        s.HASCHARGINGCOST,
        s.GLOBALID,
        s.LOADED_AT,
        s.LOAD_ID,
        s.FILE_ROW_NUMBER,
        s.SOURCE_FILE,

        -- Region mapping
        r.REGION,
        CASE
            WHEN s.LATITUDE  BETWEEN -47.3 AND -34.0
             AND s.LONGITUDE BETWEEN 166.0 AND 179.0
            THEN 'inside_NZ'
            ELSE 'outlier'
        END AS NZ_LOCATION_STATUS

    FROM stations s
    LEFT JOIN regions r
        ON  s.LATITUDE  BETWEEN r.LAT_MIN AND r.LAT_MAX
        AND s.LONGITUDE BETWEEN r.LON_MIN AND r.LON_MAX

)

SELECT *
FROM region_mapping
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY STATION_ID
    ORDER BY STATION_ID ASC NULLS LAST 
) = 1