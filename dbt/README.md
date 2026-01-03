# dbt Project for dbt-on-Lambda

This directory contains a complete dbt project optimized for AWS Lambda execution with Athena as the analytical database. It follows dbt best practices while being tailored for serverless execution.

## Project Overview

The dbt project is configured to:
- Execute on AWS Lambda (Python 3.13)
- Query and transform data in Amazon Athena
- Store results in S3 and register them in Glue Catalog
- Work with environment-specific configurations (dev/prod)

## Directory Structure

```
dbt/
├── dbt_project.yml          # Main dbt configuration
├── profiles.yml             # Athena connection settings
├── handler.py               # Lambda entry point for dbt execution
├── models/
│   ├── staging/             # Raw data transformations
│   ├── marts/               # Business-ready models
│   └── example/             # Example models (can be deleted)
├── tests/                   # dbt tests and validations
├── macros/                  # Custom dbt macros and utilities
├── snapshots/               # Type 2 slowly changing dimensions
├── seeds/                   # Static reference data
├── analyses/                # Ad-hoc queries and analysis
└── dbt_packages/            # External dbt packages (dbt-utils, etc.)
```

## Key Features

### Handler Entry Point

Unlike standard dbt projects, this one includes `handler.py`:
- Lambda function handler for executing dbt commands
- Accepts event payload with command and CLI arguments
- Handles multiprocessing patches for Lambda's `/dev/shm` limitations
- Returns JSON with execution status

**Example event payload:**
```json
{
  "command": ["run"],
  "cli_args": ["--select", "my_model"]
}
```

### Athena Integration

The project uses the `dbt-athena` adapter:
- Native Athena SQL support
- Automatic table creation and registration in Glue Catalog
- S3 staging directory for temporary query results
- IAM authentication (no passwords needed)

### Environment Variables

dbt looks for these environment variables (set by Lambda):
- `AWS_REGION` - AWS region for Athena and S3
- `PROCESSED_BUCKET_NAME` - S3 bucket for model output
- `ATHENA_RESULTS_BUCKET` - S3 bucket for query results
- `GLUE_DATABASE_NAME` - Glue Catalog database name

These are automatically set by Terraform when deploying the Lambda function.

## Development Workflow

### Local Setup

```bash
# Activate virtual environment
source .venv/bin/activate

# Set environment variables for local testing
export AWS_PROFILE=your-profile-name
export AWS_REGION=ap-southeast-2
export PROCESSED_BUCKET_NAME=your-bucket-name
export GLUE_DATABASE_NAME=your-database-name
export ATHENA_RESULTS_BUCKET=your-results-bucket

# Install dependencies
cd dbt
dbt deps
```

### Running Models Locally

```bash
# Build all models
dbt build

# Run specific model
dbt run --select my_model

# Run models in a tag
dbt run --select tag:daily

# Generate documentation
dbt docs generate
```

### Running Tests

```bash
# Run all tests
dbt test

# Run tests for specific model
dbt test --select my_model
```

### On Lambda

Use the Lambda event payload instead:

```json
{
  "command": ["build"],
  "cli_args": []
}
```

## dbt Best Practices Used

### 1. Staging Models

Raw data transformations in `models/staging/`:
- Clean and standardize raw data
- Add basic validations
- Materialize as views (lightweight)

Example:
```sql
-- models/staging/stg_users.sql
{{ config(materialized='view') }}

select
  user_id,
  user_name as name,
  created_at,
  updated_at
from {{ source('raw', 'users') }}
where deleted_at is null
```

### 2. Mart Models

Business-ready models in `models/marts/`:
- Combine staging models
- Implement business logic
- Materialize as tables (Iceberg format)

Example:
```sql
-- models/marts/fct_orders.sql
{{ config(
  materialized='table',
  table_type='iceberg',
  format='parquet'
) }}

select
  {{ dbt_utils.generate_surrogate_key(['order_id']) }} as order_key,
  order_id,
  customer_id,
  order_date,
  total_amount
from {{ ref('stg_orders') }}
```

### 3. Tests

Define tests in YAML:
```yaml
# models/schema.yml
models:
  - name: fct_orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: customer_id
        tests:
          - relationships:
              to: ref('fct_customers')
              field: customer_id
```

### 4. Documentation

Include descriptions and documentation:
```yaml
models:
  - name: fct_orders
    description: "Fact table for orders"
    columns:
      - name: order_id
        description: "Unique order identifier"
        data_tests:
          - unique
```

## Adding New Models

### 1. Create Staging Model

```sql
-- models/staging/stg_my_table.sql
{{ config(materialized='view') }}

select
  *
from {{ source('raw', 'my_table') }}
```

### 2. Define Source

```yaml
# models/sources.yml
sources:
  - name: raw
    tables:
      - name: my_table
        description: "Raw data from source system"
```

### 3. Create Tests

```yaml
# models/staging/schema.yml
models:
  - name: stg_my_table
    tests:
      - dbt_expectations.expect_row_count_to_be_between:
          min_value: 1
```

### 4. Run and Test

```bash
dbt run --select +stg_my_table
dbt test --select stg_my_table
```

## Customization

### Add External Packages

```yaml
# dbt_project.yml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
```

Then run:
```bash
dbt deps
```

### Configure dbt Profiles

Edit `profiles.yml` for different environments:
```yaml
dbt_models:
  outputs:
    dev:
      type: athena
      method: iam
      database: dev-database
      s3_data_dir: s3://dev-processed-bucket/
      s3_staging_dir: s3://dev-results-bucket/
      schema: default
      threads: 4

    prod:
      type: athena
      method: iam
      database: prod-database
      s3_data_dir: s3://prod-processed-bucket/
      s3_staging_dir: s3://prod-results-bucket/
      schema: default
      threads: 8
```

### Adjust Model Configuration

Models support Athena-specific configurations:
```sql
{{ config(
  materialized='table',
  format='parquet',
  table_type='iceberg',
  write_compression='snappy',
  partition_by=['date_column']
) }}

select * from {{ ref('my_model') }}
```

## Troubleshooting

### "Profile not found" Error

**Solution**: Ensure `profiles.yml` exists and is in the dbt directory:
```bash
ls -la dbt/profiles.yml
```

### "Table not found" Error

**Solution**:
1. Verify raw data is uploaded to S3 raw bucket
2. Check Glue database name matches `GLUE_DATABASE_NAME`
3. Run Glue crawler or manual table creation

### dbt Command Timeout

**Solution**: Increase Lambda timeout in Terraform:
```hcl
# infra/dbt_runner.tf
timeout = 1800  # 30 minutes
```

### Memory Errors

**Solution**: Increase Lambda memory in Terraform:
```hcl
# infra/dbt_runner.tf
memory_size = 4096  # Up to 10,240 MB
```

## Performance Optimization

### 1. Use Iceberg Tables

```sql
{{ config(table_type='iceberg') }}
```
- Better query performance for large tables
- Version history and time-travel queries
- Partition evolution support

### 2. Partition Data

```sql
{{ config(
  partition_by=['year', 'month']
) }}
```
- Reduces data scanned by Athena
- Faster query execution
- Lower costs

### 3. Use Appropriate Materialization

- **Views**: Small transformations, staging models
- **Tables**: Business-ready models, frequently queried
- **Incremental**: Large fact tables (only load new data)

### 4. Optimize Model Selection

```bash
# Only run changed models
dbt run --select state:modified+

# Run models with specific tag
dbt run --select tag:daily_refresh
```

## Resources

- [dbt Documentation](https://docs.getdbt.com/)
- [dbt Athena Adapter](https://github.com/dbt-labs/dbt-athena)
- [dbt Best Practices](https://docs.getdbt.com/guides/best-practices)
- [Amazon Athena Documentation](https://docs.aws.amazon.com/athena/)
- [AWS Glue Catalog](https://docs.aws.amazon.com/glue/)

## Getting Help

1. Check dbt logs: `cat logs/dbt.log`
2. Review CloudWatch logs: `aws logs tail /aws/lambda/dev-dbt-runner --follow`
3. Validate dbt project: `dbt parse`
4. Test model: `dbt test --select my_model --debug`

