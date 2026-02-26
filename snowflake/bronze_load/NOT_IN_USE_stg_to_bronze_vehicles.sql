SET JOB_ID = 'JOB_ID' || TO_VARCHAR(CURRENT_TIMESTAMP(),'YYYYMMDDHH24MISS');

CREATE OR REPLACE TABLE DEV_EV_ANALYTICS._01_BRONZE.VEHICLES_TBL (
    OBJECTID                    NUMBER,
    BASIC_COLOUR                VARCHAR,
    BODY_TYPE                   VARCHAR,
    CC_RATING                   NUMBER,
    CHASSIS7                    VARCHAR,
    CLASS                       VARCHAR,
    ENGINE_NUMBER               VARCHAR,
    FIRST_NZ_REGISTRATION_YEAR  NUMBER,
    FIRST_NZ_REGISTRATION_MONTH NUMBER,
    GROSS_VEHICLE_MASS          NUMBER,
    HEIGHT                      NUMBER,
    IMPORT_STATUS               VARCHAR,
    INDUSTRY_CLASS              VARCHAR,
    INDUSTRY_MODEL_CODE         VARCHAR,
    MAKE                        VARCHAR,
    MODEL                       VARCHAR,
    MOTIVE_POWER                VARCHAR,
    MVMA_MODEL_CODE             VARCHAR,
    NUMBER_OF_AXLES             NUMBER,
    NUMBER_OF_SEATS             NUMBER,
    NZ_ASSEMBLED                VARCHAR,
    ORIGINAL_COUNTRY            VARCHAR,
    POWER_RATING                NUMBER,
    PREVIOUS_COUNTRY            VARCHAR,
    ROAD_TRANSPORT_CODE         VARCHAR,
    SUBMODEL                    VARCHAR,
    TLA                         VARCHAR,
    TRANSMISSION_TYPE           VARCHAR,
    VDAM_WEIGHT                 NUMBER,
    VEHICLE_TYPE                VARCHAR,
    VEHICLE_USAGE               VARCHAR,
    VEHICLE_YEAR                NUMBER,
    VIN11                       VARCHAR,
    WIDTH                       NUMBER,
    SYNTHETIC_GREENHOUSE_GAS    VARCHAR,
    FC_COMBINED                 FLOAT,
    FC_URBAN                    FLOAT,
    FC_EXTRA_URBAN              FLOAT,
    -- Added Metadata
    _SOURCE_FILENAME            STRING,
    _LOADED_AT                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    JOB_ID                      STRING
);

COPY INTO DEV_EV_ANALYTICS._01_BRONZE.VEHICLES_TBL
FROM (
  SELECT 
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 
    $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, 
    $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, 
    $31, $32, $33, $34, $35, $36, $37, $38,
    -- Metadata Columns 
    METADATA$FILENAME,              -- Track source file
    CURRENT_TIMESTAMP(),            -- Ingestion time
    $JOB_ID,
  FROM @DEV_EV_ANALYTICS._00_STAGING.EV_CSV_STAGE/Motor_Vehicles_Register_API_dt.csv
)
FILE_FORMAT = (FORMAT_NAME = 'DEV_EV_ANALYTICS._01_BRONZE.csv_format')
-- Have used File Format created in /02_init_ingestion_objects.sql file for _00_STAGING
ON_ERROR = 'CONTINUE'; -- Skips rows with errors; change to 'ABORT_STATEMENT' to fail on first error


SET COPY_QUERY_ID = LAST_QUERY_ID();

-- Create the Error Log Table
CREATE OR REPLACE TABLE DEV_EV_ANALYTICS._98_LOGGING.VEHICLES_LOAD_ERRORS (
    ERROR_MESSAGE    STRING,
    ERROR_CODE       STRING,
    ERROR_COLUMN     STRING,
    ERROR_LINE       NUMBER,
    ERROR_CHARACTER  NUMBER,
    REJECTED_RECORD  STRING, -- The actual raw row text
    FILE_NAME        STRING,
    LOAD_TIME        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    JOB_ID           STRING
);


INSERT INTO DEV_EV_ANALYTICS._98_LOGGING.VEHICLES_LOAD_ERRORS (
    ERROR_MESSAGE, 
    ERROR_CODE, 
    ERROR_COLUMN, 
    ERROR_LINE, 
    ERROR_CHARACTER, 
    REJECTED_RECORD, 
    FILE_NAME,
    JOB_ID
)
SELECT 
    ERROR, 
    CODE, 
    COLUMN_NAME, 
    LINE, 
    CHARACTER, 
    REJECTED_RECORD, 
    FILE,
    $JOB_ID
FROM TABLE(VALIDATE(DEV_EV_ANALYTICS._01_BRONZE.VEHICLES_TBL, JOB_ID => $COPY_QUERY_ID));