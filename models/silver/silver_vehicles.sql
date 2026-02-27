{{
config(
    materialized='incremental',
    unique_key='VEHICLE_ID',
    incremental_strategy='merge',
    schema='_02_SILVER',
    on_schema_change='append_new_columns'
)
}}

WITH bronze_filtered AS (

    SELECT *
    FROM {{ ref('bronze_vehicles') }}

    {% if is_incremental() %}
    -- Only process rows that arrived in bronze after the last silver run
    WHERE LOADED_AT > (SELECT COALESCE(MAX(LOADED_AT), '1900-01-01') FROM {{ this }})
    {% endif %}

),

ev_only AS (

    SELECT *
    FROM bronze_filtered
    WHERE UPPER(MOTIVE_POWER) LIKE '%ELECTRIC%'
       OR UPPER(MOTIVE_POWER) LIKE '%PLUGIN%'

),

tla_cleaned AS (

    SELECT *,
        TRIM(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(v.TLA, 'CITY',      ''),
                          'DISTRICT',   ''),
                          'TERRITORY',  ''),
                          'COUNCIL',    '')
        ) AS TLA_CLEANED
    FROM ev_only v

),

-- If same VEHICLE_ID appears multiple times in bronze, take the latest loaded row
deduplicated AS (

    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY VEHICLE_ID
            ORDER BY LOADED_AT DESC
        ) AS rn
    FROM tla_cleaned

),

region_joined AS (

    SELECT
        d.VEHICLE_ID,
        d.BASIC_COLOUR,
        d.BODY_TYPE,
        d.CC_RATING,
        d.CHASSIS7,
        d.CLASS,
        d.ENGINE_NUMBER,
        CAST(d.REGISTERED_YEAR AS INT)  AS REGISTERED_YEAR,
        CAST(d.REGISTERED_MONTH AS INT) AS REGISTERED_MONTH,
        d.GROSS_VEHICLE_MASS,
        d.HEIGHT,
        d.IMPORT_STATUS,
        d.INDUSTRY_CLASS,
        d.INDUSTRY_MODEL_CODE,
        d.MAKE,
        d.MODEL,
        d.MOTIVE_POWER,
        d.MVMA_MODEL_CODE,
        d.NUMBER_OF_AXLES,
        d.NUMBER_OF_SEATS,
        d.NZ_ASSEMBLED,
        d.ORIGINAL_COUNTRY,
        d.POWER_RATING,
        d.PREVIOUS_COUNTRY,
        d.ROAD_TRANSPORT_CODE,
        d.SUBMODEL,
        d.TLA,
        d.TLA_CLEANED,
        d.TRANSMISSION_TYPE,
        d.VDAM_WEIGHT,
        d.VEHICLE_TYPE,
        d.VEHICLE_USAGE,
        d.VEHICLE_YEAR,
        d.VIN11,
        d.WIDTH,
        d.SYNTHETIC_GREENHOUSE_GAS,
        d.FC_COMBINED,
        d.FC_URBAN,
        d.FC_EXTRA_URBAN,
        d.LOADED_AT,
        d.LOAD_ID,
        d.FILE_ROW_NUMBER,
        d.SOURCE_FILE,
        r.REGION

    FROM deduplicated d
    LEFT JOIN {{ ref('ref_tla_to_region') }} r
        ON d.TLA_CLEANED = r.TLA_CLEANED

    WHERE d.rn = 1  -- keep only the latest row per vehicle

)

SELECT * FROM region_joined