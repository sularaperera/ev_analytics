{{ 
config(
    materialized='incremental',
    schema='_02_SILVER',
    unique_key='OBJECTID'
) 
}}


WITH source_data AS (

    SELECT
        v.*,
        -- Clean TLA by removing 'CITY' and 'DISTRICT' and trimming spaces
        TRIM(REPLACE(REPLACE(v.TLA,'CITY',''),'DISTRICT','')) AS TLA_CLEANED,
        r.REGION
    FROM {{ source('bronze','VEHICLES_TBL') }} v
    LEFT JOIN {{ source('reference','TLA_TO_REGION') }} r
        ON TRIM(REPLACE(REPLACE(v.TLA,'CITY',''),'DISTRICT','')) = r.TLA_CLEANED
    WHERE UPPER(v.MOTIVE_POWER) LIKE '%ELECTRIC%'
       OR UPPER(v.MOTIVE_POWER) LIKE '%PLUGIN%'
)

SELECT *
FROM source_data

{% if is_incremental() %}
-- Only load new rows where _loaded_at is greater than the max in target table
WHERE _LOADED_AT > (SELECT COALESCE(MAX(_LOADED_AT), '1900-01-01') 
                    FROM {{ this }})
{% endif %}