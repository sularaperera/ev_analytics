{{ 
config(
    materialized='incremental',
    unique_key='VEHICLE_ID',
    incremental_strategy='merge',
    schema='_02_SILVER',
    on_schema_change='append_new_columns'
) 
}}


WITH vehicle_data AS (

    SELECT
        v.VEHICLE_ID,	
        v.BASIC_COLOUR,	
        v.BODY_TYPE,	
        v.CC_RATING,	
        v.CHASSIS7,	
        v.CLASS,
        v.ENGINE_NUMBER,	
        CAST(v.REGISTERED_YEAR AS INT) AS REGISTERED_YEAR,	
        CAST(v.REGISTERED_MONTH AS INT) AS REGISTERED_MONTH,	
        v.GROSS_VEHICLE_MASS,	
        v.HEIGHT,	
        v.IMPORT_STATUS,	
        v.INDUSTRY_CLASS,	
        v.INDUSTRY_MODEL_CODE,	
        v.MAKE,	
        v.MODEL,	
        v.MOTIVE_POWER,	
        v.MVMA_MODEL_CODE,	
        v.NUMBER_OF_AXLES,	
        v.NUMBER_OF_SEATS,	
        v.NZ_ASSEMBLED,	
        v.ORIGINAL_COUNTRY,	
        v.POWER_RATING,	
        v.PREVIOUS_COUNTRY,	
        v.ROAD_TRANSPORT_CODE,	
        v.SUBMODEL,	
        v.TLA,	
        v.TRANSMISSION_TYPE,	
        v.VDAM_WEIGHT,	
        v.VEHICLE_TYPE,	
        v.VEHICLE_USAGE,	
        v.VEHICLE_YEAR,	
        v.VIN11,	
        v.WIDTH,	
        v.SYNTHETIC_GREENHOUSE_GAS,	
        v.FC_COMBINED,	
        v.FC_URBAN,	
        v.FC_EXTRA_URBAN,	
        v.LOADED_AT,	
        v.LOAD_ID,	
        v.FILE_ROW_NUMBER,	
        v.SOURCE_FILE,

        -- Clean TLA by removing 'CITY' and 'DISTRICT' and trimming spaces
        TRIM(REPLACE(REPLACE(v.TLA,'CITY',''),'DISTRICT','')) AS TLA_CLEANED,
        r.REGION
    FROM {{ ref('bronze_vehicles') }} v
    LEFT JOIN {{ ref('ref_tla_to_region') }} r
    ON TRIM(REPLACE(REPLACE(v.TLA,'CITY',''),'DISTRICT','')) = r.TLA_CLEANED
    WHERE UPPER(v.MOTIVE_POWER) LIKE '%ELECTRIC%'
    OR UPPER(v.MOTIVE_POWER) LIKE '%PLUGIN%'
)

SELECT *
FROM vehicle_data

{% if is_incremental() %}
-- Only load new rows where _loaded_at is greater than the max in target table
WHERE _LOADED_AT > (SELECT COALESCE(MAX(_LOADED_AT), '1900-01-01') 
                    FROM {{ this }})
{% endif %}