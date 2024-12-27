DROP DATABASE IF EXISTS redfin_database_1;
CREATE DATABASE redfin_database_1;
CREATE SCHEMA redfin_schema;


-- Create Table
CREATE OR REPLACE TABLE redfin_database_1.redfin_schema.redfin_table (
period_begin DATE,
period_end DATE,
period_duration INT,
region_type STRING,
region_type_id INT,
table_id INT,
is_seasonally_adjusted STRING,
city STRING,
state STRING,
state_code STRING,
property_type STRING,
property_type_id INT NULL,
median_sale_price FLOAT,
median_list_price FLOAT,
median_ppsf FLOAT,
median_list_ppsf FLOAT,
homes_sold FLOAT,
inventory FLOAT,
months_of_supply FLOAT,
median_dom FLOAT,
avg_sale_to_list FLOAT,
sold_above_list FLOAT,
parent_metro_region_metro_code STRING,
last_updated DATETIME,
period_begin_in_years STRING,
period_end_in_years STRING,
period_begin_in_months STRING,
period_end_in_months STRING
);

-- Create file format object
CREATE SCHEMA file_format_schema;

CREATE OR REPLACE file format redfin_database_1.file_format_schema.format_csv
    type = 'CSV'
    field_delimiter = ','
    RECORD_DELIMITER = '\n'
    skip_header = 1
    -- error_on_column_count_mismatch = FALSE;
    
-- Create staging schema
CREATE SCHEMA external_stage_schema;

-- Create staging
CREATE OR REPLACE STAGE redfin_database_1.external_stage_schema.redfin_ext_stage_yml 
    url=""
    credentials=(aws_key_id=''
    aws_secret_key='')
    FILE_FORMAT = redfin_database_1.file_format_schema.format_csv;

list @redfin_database_1.external_stage_schema.redfin_ext_stage_yml PATTERN = '^redfin/redfin_data.*';

-- Create schema for snowpipe
CREATE OR REPLACE SCHEMA redfin_database_1.snowpipe_schema;

-- Create Pipe
CREATE OR REPLACE PIPE redfin_database_1.snowpipe_schema.redfin_snowpipe
auto_ingest = TRUE
AS 
COPY INTO redfin_database_1.redfin_schema.redfin_table
FROM @redfin_database_1.external_stage_schema.redfin_ext_stage_yml
PATTERN = '^redfin/redfin_data.*';

--get notification channel from below and add it to event notification within s3 properties
DESC PIPE redfin_database_1.snowpipe_schema.redfin_snowpipe;


--SELECT COUNT(*) FROM redfin_database_1.redfin_schema.redfin_table
--SELECT * FROM redfin_database_1.redfin_schema.redfin_table LIMIT 10;

--TRUNCATE TABLE redfin_database_1.redfin_schema.redfin_table
--DESC TABLE redfin_database.redfin_schema.redfin_table;


