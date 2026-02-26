-- Create the compute engine
CREATE WAREHOUSE IF NOT EXISTS XS_WAREHOUSE
WITH WAREHOUSE_SIZE = 'X-SMALL'
AUTO_SUSPEND = 60
AUTO_RESUME = TRUE;

USE WAREHOUSE XS_WAREHOUSE;


-- Setup the Database (Environment specific)
CREATE DATABASE IF NOT EXISTS DEV_EV_ANALYTICS
    COMMENT = 'Development environment for EV Charging Station Analytics';


-- Create Medallion Layer Schemas
USE DATABASE DEV_EV_ANALYTICS;

CREATE SCHEMA IF NOT EXISTS _00_STAGING;    -- Raw file pointers / External Stages
CREATE SCHEMA IF NOT EXISTS _01_BRONZE;     -- Raw ingested tables
CREATE SCHEMA IF NOT EXISTS _02_SILVER;     -- Cleaned and Joined models
CREATE SCHEMA IF NOT EXISTS _03_GOLD;       -- Business ready Reporting tables
CREATE SCHEMA IF NOT EXISTS _98_LOGGING     -- Logging
CREATE SCHEMA IF NOT EXISTS _99_REFERENCE;  -- Reference & Lookup tables


-- Verify the setup
SHOW SCHEMAS IN DATABASE DEV_EV_ANALYTICS;



