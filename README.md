# DataEngineering_RedfinData

This project downloads, cleans, and aggregates Redfin real estate data using Airflow, S3, and Snowflake.  
The high-level architecture is:

1. **Airflow** (running on an Amazon EC2 instance, or any environment you choose) executes a DAG that:
   - Downloads the TSV data from Redfin’s public S3 bucket.  
   - Transforms and cleans the data.  
   - Pushes the final CSV data to your own S3 bucket.  
2. **Snowpipe** (in Snowflake) automatically ingests data from the S3 bucket into a Snowflake table, triggered by **SQS** notifications.

## Table of Contents
1. [Prerequisites](#prerequisites)  
2. [Installation & Environment Setup](#installation--environment-setup)  
3. [Configuration File](#configuration-file)  
4. [Project Structure](#project-structure)  
5. [Airflow Setup & Running the DAG](#airflow-setup--running-the-dag)  
6. [AWS S3 and SQS Setup for Snowpipe](#aws-s3-and-sqs-setup-for-snowpipe)  
7. [Snowflake Setup](#snowflake-setup)  
8. [Testing & Verification](#testing--verification)  
9. [Troubleshooting](#troubleshooting)  

---

## 1. Prerequisites
- **Python 3.9+** (or compatible version)
- **Amazon AWS Account** with access to:
  - S3 Bucket creation
  - SQS
  - IAM roles/policies for S3/SQS
- **Snowflake** account with privileges to create databases, schemas, pipes, etc.
- (Optional) **Amazon EC2** instance if you wish to run Airflow and Python scripts in the cloud.  

> **Note:** You can run Airflow on your local machine or any other environment instead of EC2, but these instructions use EC2 as an example.

---

## 2. Installation & Environment Setup

### 2.1. Launch an Amazon EC2 Instance (optional)
1. Log in to AWS and go to the **EC2** dashboard.  
2. Launch a new instance with an AMI of your choice (e.g., Amazon Linux 2).  
3. Make sure you allow inbound traffic for:
   - SSH (port 22) – so you can connect.
   - Airflow Webserver (port 8080) – if you want to view Airflow in the browser externally.
4. SSH into the instance once it’s running.

### 2.2. Python Environment Setup
1. **Install Python 3** (if not already installed) on your machine/instance.  
2. Create a virtual environment (recommended) and activate it. For example:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
   
### 2.3. Install Required Python Libraries
  ```bash
  pip install apache-airflow==2.10.3
  pip install boto3==1.35.57
  pip install pandas==2.2.3
  ```
---
## 3. Configuration Files
1. The code references a JSON config file `config.json` containing keys for AWS and personal settings. An example structure might look like this:
    ```json
    {
      "aws": {
        "S3_BUCKET_NAME": "your-s3-bucket-name"
      },
      "personal": {
        "EMAIL": "your_email@example.com"
      }
    }
    ```
> **Note:**  You can store your AWS credentials (Access Key, Secret Key) either in the environment variables, ~/.aws/credentials, or use IAM roles.
Update the path to the config file in redfin_analytics.py if you store it elsewhere.
---
## 4. Project Structure
  ```arduino
    ├── airflow/
    │   └── dags/
    │       └── redfin_analytics.py          <-- The DAG script
    ├── snowflake_redfin_script.sql          <-- Snowflake setup SQL
    ├── ReadMe.md
    └── config.json
  ```

1. `redfin_analytics.py` Contains the Airflow DAG and associated Python functions for extracting, transforming, and loading Redfin data to S3.
2. `snowflake_redfin_script.sql` Snowflake SQL script to create a database, schema, table, stage, file format, and Snowpipe.
3. `config.json` JSON file storing configuration details (bucket name, email, etc.).
4. `ReadMe.md` Documentation (this file).
---
## 5. Airflow Setup & Running the DAG
1. Initialize Airflow
   ```bash
   airflow standalone
   ```
2. Get username and password from terminal output and login to Airflow to confirm it is running.
    > **Notes:** By default, the Airflow web UI is available at http://localhost:8080 (or :8080 if on EC2 and port 8080 is opened).
3. Copy/Place the DAG file `redfin_analytics.py` into the `airflow/dags/` folder.
4. Access Airflow UI to see the DAG, enable it, and trigger it manually (if desired)
---
## 6. AWS S3 and SQS Setup for Snowpipe
Snowflake’s Snowpipe supports auto-ingest via S3 event notifications to an SQS queue. Below is a typical setup:

1. Create/Use an S3 Bucket
  - Let’s assume your bucket is named your-s3-bucket-name.
2. Create an SQS Queue
    - Go to AWS SQS console and create a queue (e.g., redfin-snowpipe-queue).
    - Note the ARN of the queue (it will look like arn:aws:sqs:us-east-1:123456789012:redfin-snowpipe-queue).
3. Configure S3 Event Notifications
    - In the S3 console, select your bucket, go to the Properties tab, and scroll to Event notifications.
    - Create a new notification:
        - Event name: e.g., redfin-auto-ingest
        - Prefix: redfin/ (if your data files have that prefix)
        - Suffix: (optional) e.g., .csv if you want only CSV files.
        - Event types: All object create events.
        - Destination: SQS queue, select your newly created redfin-snowpipe-queue.
    - Save the notification.
4. Set Permissions (IAM)
    - Ensure the S3 bucket has permission to publish to your SQS queue. This can be done by attaching the appropriate IAM policy to the S3 bucket or by configuring the SQS Access Policy. The SQS Access Policy should allow the S3 principal to send messages. For example:
      ```json
      {
      "Version": "2012-10-17",
      "Id": "AllowS3ToSendMessage",
      "Statement": [
        {
          "Sid": "MySQSPolicyStmt001",
          "Effect": "Allow",
          "Principal": {
            "Service": "s3.amazonaws.com"
          },
          "Action": "SQS:SendMessage",
          "Resource": "arn:aws:sqs:us-east-1:123456789012:redfin-snowpipe-queue",
          "Condition": {
            "ArnEquals": {
              "aws:SourceArn": "arn:aws:s3:::your-s3-bucket-name"
            }
          }
        }
      ]
      }
      ```
    - This ensures that when a new file is added to your-s3-bucket-name/redfin/..., a message is published to the SQS queue.
  Once these steps are done, the pipeline from S3 -> SQS is ready.

---
## 7. Snowflake Setup

Use the provided **`snowflake_redfin_script.sql`** to create the database, schema, table, stage, file format, and Snowpipe. Below is a summary:

1. **Connect to Snowflake** (e.g., via Snowflake UI or SnowSQL).  
2. **Run** the SQL script:
   ```sql
   -- Example:
   DROP DATABASE IF EXISTS redfin_database_1;
   CREATE DATABASE redfin_database_1;
   CREATE SCHEMA redfin_schema;

   CREATE OR REPLACE TABLE redfin_database_1.redfin_schema.redfin_table (...);
   ...
   CREATE OR REPLACE STAGE redfin_database_1.external_stage_schema.redfin_ext_stage_yml
       URL = 's3://your-s3-bucket-name'
       CREDENTIALS = (
         aws_key_id     = 'YOUR_AWS_KEY'
         aws_secret_key = 'YOUR_AWS_SECRET'
       )
       FILE_FORMAT = redfin_database_1.file_format_schema.format_csv;

   -- Snowpipe with auto_ingest
   CREATE OR REPLACE PIPE redfin_database_1.snowpipe_schema.redfin_snowpipe
   auto_ingest = TRUE
   AS
   COPY INTO redfin_database_1.redfin_schema.redfin_table
   FROM @redfin_database_1.external_stage_schema.redfin_ext_stage_yml
   PATTERN = '^redfin/redfin_data.*';

   DESC PIPE redfin_database_1.snowpipe_schema.redfin_snowpipe;
   ```
3. Copy the “notification channel” from the DESC PIPE output.
    - It will look something like an ARN for an SQS queue that Snowflake manages: `arn:aws:sqs:us-east-1:123456789012:snowpipe-xyz-abcd-queue`
    - However, in many cases for Snowflake auto-ingest from S3, you will use the custom SQS queue you created, configured to point to the Snowpipe. (If you see that Snowflake is providing a different queue, please ensure you follow the official Snowflake auto-ingest docs or confirm that the queue in S3 event notifications is the same that’s described in your Snowpipe config.)
4. Validate the Snowpipe is active. When new data is placed in `s3://your-s3-bucket-name/redfin/...`, Snowpipe should automatically load it into `redfin_database_1.redfin_schema.redfin_table`.
---
## 8. Testing & Verification

1. **Trigger the Airflow DAG**  
   - Via the Airflow UI or CLI. The DAG will:
     - Download the Redfin dataset from the public URL.
     - Transform and clean the data.
     - Upload the processed CSV to `your-s3-bucket-name/redfin/`.
   - The last step (`tsk_load_to_s3`) moves the raw CSV from EC2 to S3.  

2. **Check S3**  
   - Ensure a new object with prefix `redfin/` (e.g., `redfin_data_XXXXXXXX.csv`) shows up in your bucket.

3. **Check Snowflake**  
   - Log in to Snowflake and query:
     ```sql
     SELECT COUNT(*) FROM redfin_database_1.redfin_schema.redfin_table;
     ```
   - If Snowpipe loaded successfully, the count should increase after the new file is added.

4. **Monitor SQS**  
   - You can look at the SQS queue to see if messages are being published from S3.
---
## 9. Troubleshooting

- **Permission Errors**:  
  - Ensure the IAM role attached to your EC2 (or local environment’s AWS CLI credentials) can read/write to S3.  
  - Make sure S3 can publish to your SQS queue (check Access Policy).  

- **Snowflake Stage Credentials**:  
  - Double-check your `aws_key_id` and `aws_secret_key` in the Snowflake `CREATE STAGE` command, or confirm you’re using an external stage with an IAM role.

- **Airflow Import Issues**:  
  - If Airflow doesn’t recognize the DAG, ensure the file is in the correct `airflow/dags/` directory and that the Python environment is consistent.

- **No Data in Snowflake Table**:  
  - Ensure your Snowpipe `PATTERN` in the script matches the file name(s) you are uploading.  
  - Confirm that S3 events are firing and that the SQS queue is receiving messages.
---





    
