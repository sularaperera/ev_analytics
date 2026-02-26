{{ config(
    materialized='incremental',
    on_schema_change='append_new_columns'
) }}


WITH raw_data AS (
    SELECT 
        vh.$1 AS VEHICLE_ID,                    
        vh.$2 AS BASIC_COLOUR,               
        vh.$3 AS BODY_TYPE,                   
        vh.$4 AS CC_RATING,                   
        vh.$5 AS CHASSIS7,                    
        vh.$6 AS CLASS,                       
        vh.$7 AS ENGINE_NUMBER,               
        vh.$8 AS REGISTERED_YEAR,  
        vh.$9 AS REGISTERED_MONTH, 
        vh.$10 AS GROSS_VEHICLE_MASS,          
        vh.$11 AS HEIGHT,                      
        vh.$12 AS IMPORT_STATUS,               
        vh.$13 AS INDUSTRY_CLASS,              
        vh.$14 AS INDUSTRY_MODEL_CODE,         
        vh.$15 AS MAKE,                        
        vh.$16 AS MODEL,                       
        vh.$17 AS MOTIVE_POWER,                
        vh.$18 AS MVMA_MODEL_CODE,             
        vh.$19 AS NUMBER_OF_AXLES,             
        vh.$20 AS NUMBER_OF_SEATS,             
        vh.$21 AS NZ_ASSEMBLED,                
        vh.$22 AS ORIGINAL_COUNTRY,            
        vh.$23 AS POWER_RATING,                
        vh.$24 AS PREVIOUS_COUNTRY,            
        vh.$25 AS ROAD_TRANSPORT_CODE,         
        vh.$26 AS SUBMODEL,                    
        vh.$27 AS TLA,                         
        vh.$28 AS TRANSMISSION_TYPE,           
        vh.$29 AS VDAM_WEIGHT,                 
        vh.$30 AS VEHICLE_TYPE,                
        vh.$31 AS VEHICLE_USAGE,               
        vh.$32 AS VEHICLE_YEAR,                
        vh.$33 AS VIN11,                       
        vh.$34 AS WIDTH,                       
        vh.$35 AS SYNTHETIC_GREENHOUSE_GAS,    
        vh.$36 AS FC_COMBINED,                 
        vh.$37 AS FC_URBAN,                    
        vh.$38 AS FC_EXTRA_URBAN,              
        -- adding meta data
        current_timestamp() AS loaded_at,
        '{{ invocation_id }}' AS load_id,
        METADATA$FILE_ROW_NUMBER AS FILE_ROW_NUMBER,
        METADATA$FILENAME AS SOURCE_FILE

    FROM @DEV_EV_ANALYTICS._00_STAGING.EV_CSV_STAGE/Motor_Vehicles_Register_API_dt.csv
    (FILE_FORMAT => DEV_EV_ANALYTICS._00_STAGING.CSV_FORMAT) vh
)

SELECT *
FROM raw_data

{% if is_incremental() %}

WHERE SOURCE_FILE NOT IN (
    SELECT DISTINCT SOURCE_FILE
    FROM {{ this }}
)

{% endif %}


