-- Set Context
USE DATABASE DEV_EV_ANALYTICS;
USE SCHEMA _00_STAGING;


-- Create file formats

-- CSV Format: Standard for structured station exports
CREATE OR REPLACE FILE FORMAT csv_format
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null', '')
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    COMMENT = 'Standard CSV format for EV Station data';

-- JSON Format: For API logs and nested telemetry
CREATE OR REPLACE FILE FORMAT json_format
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE
    IGNORE_UTF8_ERRORS = TRUE
    COMMENT = 'Standard JSON format for semi-structured EV logs';


-- Create named stages

-- Dedicated Stage for CSVs
CREATE OR REPLACE STAGE ev_csv_stage
    FILE_FORMAT = csv_format
    COMMENT = 'Landing zone for CSV files';

-- Dedicated Stage for JSON
CREATE OR REPLACE STAGE ev_json_stage
    FILE_FORMAT = json_format
    COMMENT = 'Landing zone for JSON files';



-- Set Context
USE DATABASE DEV_EV_ANALYTICS;
USE SCHEMA _01_BRONZE;


-- Create file formats

-- CSV Format: Standard for structured station exports
CREATE OR REPLACE FILE FORMAT csv_format
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null', '')
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    COMMENT = 'Standard CSV format for EV Station data';

-- JSON Format: For API logs and nested telemetry
CREATE OR REPLACE FILE FORMAT json_format
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE
    IGNORE_UTF8_ERRORS = TRUE
    COMMENT = 'Standard JSON format for semi-structured EV logs';



-- Set Context
USE DATABASE DEV_EV_ANALYTICS;
USE SCHEMA _99_REFERENCE;



-- Create file formats

-- CSV Format: Standard for structured station exports
CREATE OR REPLACE FILE FORMAT csv_format
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null', '')
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    COMMENT = 'Standard CSV format for EV Station data';

-- JSON Format: For API logs and nested telemetry
CREATE OR REPLACE FILE FORMAT json_format
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE
    IGNORE_UTF8_ERRORS = TRUE
    COMMENT = 'Standard JSON format for semi-structured EV logs';


