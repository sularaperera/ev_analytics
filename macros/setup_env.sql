{% macro setup_environment(
    warehouse_name,
    database_name,
    git_username='sularaperera')
%}

{% set git_token = env_var('DBT_GIT_TOKEN') %}

-- =========================
-- Warehouse
-- =========================

CREATE WAREHOUSE IF NOT EXISTS {{ warehouse_name }}
WITH 
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE WAREHOUSE {{ warehouse_name }};


-- =========================
-- Database
-- =========================

CREATE DATABASE IF NOT EXISTS {{ database_name }};
USE DATABASE {{ database_name }};


-- =========================
-- Schemas
-- =========================

CREATE SCHEMA IF NOT EXISTS _00_STAGING;
-- CREATE SCHEMA IF NOT EXISTS _01_BRONZE;
-- CREATE SCHEMA IF NOT EXISTS _02_SILVER;
-- CREATE SCHEMA IF NOT EXISTS _03_GOLD;
-- CREATE SCHEMA IF NOT EXISTS _99_REFERENCE;

-- Switch to staging schema for infra objects
USE SCHEMA _00_STAGING;


-- =========================
-- File Formats
-- =========================

-- CSV Format
CREATE FILE FORMAT IF NOT EXISTS csv_format
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null', '')
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    COMMENT = 'Standard CSV format for EV Station data';


-- JSON Format
CREATE FILE FORMAT IF NOT EXISTS json_format
    TYPE = 'JSON'
    STRIP_OUTER_ARRAY = TRUE
    IGNORE_UTF8_ERRORS = TRUE
    COMMENT = 'Standard JSON format for semi-structured EV logs';


-- =========================
-- Create Stages
-- =========================

-- CSV Stage
CREATE STAGE IF NOT EXISTS ev_csv_stage
    FILE_FORMAT = csv_format
    COMMENT = 'Landing zone for CSV files';

-- JSON Stage
CREATE STAGE IF NOT EXISTS ev_json_stage
    FILE_FORMAT = json_format
    COMMENT = 'Landing zone for JSON files';


-- =========================
-- Git Integration
-- =========================

USE DATABASE {{ database_name }};

CREATE OR REPLACE SECRET GIT_SECRET
    TYPE = PASSWORD
    USERNAME = '{{ git_username }}'
    PASSWORD = '{{ git_token }}';

CREATE OR REPLACE API INTEGRATION GIT_INT
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/{{ git_username }}/')
    ENABLED = TRUE
    ALLOWED_AUTHENTICATION_SECRETS = (GIT_SECRET);

{% endmacro %}


