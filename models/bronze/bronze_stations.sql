{{ config(
    materialized='incremental',
    schema='_01_BRONZE',
    on_schema_change='append_new_columns'
) }}

WITH raw_json AS (

SELECT
    $1:OBJECTID::string AS STATION_ID,
    $1:NAME::string AS STATION_NAME,
    $1:OPERATOR::string AS OPERATOR,
    $1:OWNER::string AS OWNER,
    $1:ADDRESS::string AS ADDRESS,
    $1:is24Hours::string AS is24Hours,
    $1:carParkCount::string AS carParkCount,
    $1:hasCarparkCost::string AS hasCarparkCost,
    $1:maxTimeLimit::string AS maxTimeLimit,
    $1:hasTouristAttraction::string AS hasTouristAttraction,
    $1:latitude::string AS latitude,
    $1:longitude::string AS longitude,
    $1:currentType::string AS currentType,
    $1:dateFirstOperational::string AS dateFirstOperational,
    $1:numberOfConnectors::string AS numberOfConnectors,
    $1:connectorsList::string AS connectorsList,
    $1:hasChargingCost::string AS hasChargingCost,
    $1:GlobalID::string AS GlobalID,
    -- Add Metadata
    CURRENT_TIMESTAMP() AS LOADED_AT,
    '{{ invocation_id }}' AS load_id,
    METADATA$FILE_ROW_NUMBER AS FILE_ROW_NUMBER,
    METADATA$FILENAME AS SOURCE_FILE

FROM @DEV_EV_ANALYTICS._00_STAGING.EV_JSON_STAGE/EV_Roam_charging_stations_data.json
(FILE_FORMAT => DEV_EV_ANALYTICS._00_STAGING.JSON_FORMAT)

{% if is_incremental() %}

WHERE METADATA$FILENAME NOT IN (
    SELECT DISTINCT SOURCE_FILE
    FROM {{ this }}
)

{% endif %}

)

SELECT *
FROM raw_json