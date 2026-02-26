{{ 
config(
    materialized='incremental',
    schema='_02_SILVER',
    unique_key='OBJECTID'
) 
}}


WITH source_data AS (

    SELECT
        st.*,
        -- Flag whether the location is inside NZ
        CASE 
            WHEN st.LATITUDE BETWEEN -47.3 AND -34.0
            AND st.LONGITUDE BETWEEN 166.0 AND 179.0
            THEN 'inside_NZ'
            ELSE 'outlier'
        END AS location_status,

        COALESCE(re.REGION,'Auckland') AS REGION,
        re.LAT_MIN,
        re.LAT_MAX,
        re.LON_MIN,
        re.LON_MAX

    FROM {{ source('bronze','STATIONS_TBL') }} st
    LEFT JOIN {{ source('reference','NZ_REGION_BOUNDS') }} re
    
    ON st.LATITUDE BETWEEN re.LAT_MIN - 0.05 AND re.LAT_MAX + 0.05
    AND st.LONGITUDE BETWEEN re.LON_MIN - 0.05 AND re.LON_MAX + 0.05

    WHERE 1=1

    {% if is_incremental() %}
        AND st._LOADED_AT > (
            SELECT COALESCE(MAX(_LOADED_AT),'1900-01-01')
            FROM {{ this }}
        )
    {% endif %}

)

SELECT source_data.* EXCLUDE (
        LAT_MIN,
        LAT_MAX,
        LON_MIN,
        LON_MAX
    )
FROM source_data

QUALIFY ROW_NUMBER() OVER (
    PARTITION BY OBJECTID
    ORDER BY
        ABS(LATITUDE - ((LAT_MIN + LAT_MAX)/2)) +
        ABS(LONGITUDE - ((LON_MIN + LON_MAX)/2))
) = 1