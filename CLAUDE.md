# CLAUDE.md - dbt-on-Lambda Starter

This file provides guidance for Claude Code and AI assistants when working with this dbt-on-Lambda starter project.

## Project Overview

**dbt-on-Lambda Starter** is a production-ready, serverless template for running dbt transformations on AWS Lambda with Athena as the data warehouse. It's designed to be simple, extensible, and suitable for public distribution.

### Core Concept

```
Raw Data (S3) → dbt_runner Lambda → Processed Data (S3) + Athena/Glue Metadata
```

- **Input**: Data in S3 raw bucket (users provide their own ingestion)
- **Processing**: dbt transformations executed on Lambda
- **Output**: Transformed data in S3 processed bucket, registered in Glue Catalog
- **Querying**: Results queryable via Athena or accessible as Parquet/CSV files

### Key Principles

1. **Minimal**: Only include infrastructure needed for dbt execution
2. **Extensible**: Users can add their own orchestration (EventBridge, SQS, etc.)
3. **Serverless**: No EC2, VPC, or manual scaling
4. **Cost-Optimized**: ARM64 Graviton, intelligent tiering, lifecycle policies
5. **Production-Ready**: Security, encryption, logging, and error handling built-in

## Technology Stack

- **Infrastructure**: Terraform (AWS ~5.0, archive ~2.0, random ~3.0)
- **Compute**: AWS Lambda (Python 3.13, arm64 architecture)
- **Data Storage**: S3 (raw, processed, athena_results buckets)
- **Data Catalog**: AWS Glue
- **Query Engine**: Amazon Athena
- **Logging**: CloudWatch Logs (14-day retention)
- **Data Transform**: dbt (core, dbt-athena adapter)

## Architecture Overview

### Infrastructure Components

```
Terraform Modules:
├── compute.tf          # dbt_layer Lambda layer
├── dbt_runner.tf       # dbt_runner Lambda function + IAM role
├── storage.tf          # S3 buckets (raw, processed, athena_results)
├── glue.tf             # Glue database for Athena metadata
├── notifications.tf    # (Simplified - no orchestration)
├── state_backend.tf    # Terraform state backend
└── variables.tf        # Module variables
```

### S3 Bucket Design

- **raw**: Input data for dbt transformations
  - Versioning: Enabled
  - Encryption: AES256
  - Public Access: Blocked
  - Lifecycle: Transition to Glacier after 1095 days (3 years)
  - Intelligent Tiering: Enabled for cost optimization

- **processed**: Output location for dbt models
  - Versioning: Enabled
  - Encryption: AES256
  - Public Access: Blocked
  - Intelligent Tiering: Enabled
  - Lifecycle: No transitions (permanent storage)

- **athena_results**: Temporary Athena query results
  - Versioning: Enabled with 7-day cleanup
  - Encryption: AES256
  - Public Access: Blocked
  - Lifecycle: Auto-deletion after 30 days

### Lambda Configuration

**dbt_runner Lambda**:
- Runtime: Python 3.13, arm64 architecture
- Memory: 3008 MB
- Timeout: 900 seconds (15 minutes)
- Layer: dbt_layer (pre-built with dbt and dependencies)
- Triggers: Manual, EventBridge, S3 events (users configure)
- Environment Variables:
  - `RAW_BUCKET_NAME`: Input bucket name
  - `PROCESSED_BUCKET_NAME`: Output bucket name
  - `GLUE_DATABASE_NAME`: Glue catalog database
  - `ATHENA_RESULTS_BUCKET`: Athena query results bucket
  - `ENVIRONMENT`: dev/prod environment name

### IAM Security

**dbt_runner Role Policy**:
- `ReadRawData`: s3:GetObject on raw bucket
- `WriteProcessedData`: s3:PutObject, s3:DeleteObject on processed bucket
- `AthenaQueryResults`: Full access to athena_results bucket
- `GlueCatalogAccess`: Create/update tables, partitions, databases
- `AthenaQueryExecution`: Execute queries, get results
- No SNS/SQS permissions (simplified, users add if needed)

### Variables and Configuration

**Root Level** (`variables.tf`):
- `aws_region`: AWS region (default: ap-southeast-2)
- `aws_profile`: AWS CLI profile (default: default)
- `environment`: dev or prod
- `bucket_prefix`: S3 bucket name prefix (4-36 chars)
- `default_tags`: Default tags for all resources
- `extra_tags`: Additional environment-specific tags

**Module Level** (`infra/variables.tf`):
- Same variables duplicated for module isolation
- `python_runtime`: Python version for Lambda (default: python3.13)

**Environment-Specific** (`envs/{dev,prod}/terraform.tfvars`):
- Environment-specific bucket prefix
- Extra tags for environment identification

## Development Commands

### Terraform Operations

```bash
# Initialize (required once)
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Plan changes (dev)
terraform plan -var-file="envs/dev/terraform.tfvars"

# Apply changes (dev)
terraform apply -var-file="envs/dev/terraform.tfvars"

# Plan changes (prod)
terraform plan -var-file="envs/prod/terraform.tfvars"

# Apply to production
terraform apply -var-file="envs/prod/terraform.tfvars"

# Destroy infrastructure (careful!)
terraform destroy -var-file="envs/dev/terraform.tfvars"
```

### Lambda Invocation

```bash
# Invoke with CLI
aws lambda invoke \
  --function-name dev-dbt-runner \
  --payload '{"command": ["build"], "cli_args": []}' \
  response.json

# View logs
aws logs tail /aws/lambda/dev-dbt-runner --follow

# Check function details
aws lambda get-function --function-name dev-dbt-runner
```

### dbt Project

```bash
# Run locally (requires local dbt setup)
cd dbt
dbt build --target dev

# Run tests only
dbt test

# Generate docs
dbt docs generate
```

## Project Structure

```
dbt-lambda-starter/
├── dbt/                          # dbt project root
│   ├── dbt_project.yml           # dbt configuration
│   ├── profiles.yml              # Athena connection (env-specific)
│   ├── handler.py                # Lambda entry point for dbt execution
│   ├── models/                   # dbt models
│   │   ├── staging/              # Staging models from raw data
│   │   ├── marts/                # Business models
│   │   └── example_models.sql    # Example dbt models
│   ├── tests/                    # dbt tests
│   ├── macros/                   # Custom dbt macros
│   ├── seeds/                    # Static data files
│   ├── analysis/                 # Ad-hoc queries
│   ├── dbt_packages/             # External dbt packages (dbt_utils, etc.)
│   ├── target/                   # dbt build artifacts (git-ignored)
│   ├── logs/                     # dbt execution logs (git-ignored)
│   └── README.md                 # dbt project documentation
│
├── dbt_layer/                    # Pre-built Lambda layer
│   ├── dbt_layer.zip             # Packaged dbt + dependencies
│   └── Dockerfile                # Instructions for building layer
│
├── infra/                        # Terraform infrastructure code
│   ├── compute.tf                # Lambda layer definitions
│   ├── dbt_runner.tf             # dbt_runner Lambda + IAM role + policy
│   ├── storage.tf                # S3 bucket configurations
│   ├── glue.tf                   # Glue database + Athena bucket
│   ├── notifications.tf          # Simplified (comments only)
│   ├── state_backend.tf          # Terraform state S3 backend
│   ├── variables.tf              # Module variables
│   ├── outputs.tf                # Module outputs
│   └── .gitkeep                  # Ensures directory tracked
│
├── envs/                         # Environment-specific configurations
│   ├── dev/
│   │   └── terraform.tfvars      # Dev environment variables
│   └── prod/
│       └── terraform.tfvars      # Production environment variables
│
├── .gitignore                    # Git ignore rules
├── .python-version               # Python version (for pyenv)
├── main.tf                       # Root Terraform configuration
├── main.py                       # Python entry point (example)
├── outputs.tf                    # Root-level outputs
├── provider.tf                   # AWS provider configuration
├── terraform.tf                  # Backend configuration
├── terraform.tfvars              # Default variable values
├── variables.tf                  # Root-level variables
├── pyproject.toml                # Python project configuration
├── uv.lock                       # UV dependency lock file
├── README.md                     # User documentation
├── CLAUDE.md                     # This file
└── LICENSE                       # MIT License
```

## Important Files

### dbt/handler.py

The Lambda entry point that:
1. Patches multiprocessing for Lambda's /dev/shm limitations
2. Initializes dbt runner
3. Accepts event with command and cli_args
4. Executes dbt commands
5. Returns success/failure status

Example invocation:
```python
{
  "command": ["build"],
  "cli_args": ["--select", "+my_model"]
}
```

### infra/dbt_runner.tf

Defines:
- IAM role and policy for dbt execution
- Lambda function resource
- CloudWatch log group
- Environment variables

Update this file to:
- Increase timeout for long-running models
- Increase memory for large data volumes
- Add SNS/SQS permissions if adding orchestration

### dbt/profiles.yml

Athena connection configuration:
```yaml
dbt_lambda:
  target: dev
  outputs:
    dev:
      type: athena
      method: iam
      database: dev-dbt-lambda-dataplatform
      s3_staging_dir: s3://dev-dbt-lambda-athena-results-ACCOUNT_ID/
```

Must match the Glue database name created by Terraform.

## Common Development Tasks

### Adding New dbt Model

1. Create file in `dbt/models/staging/` or `dbt/models/marts/`
2. Use source() to reference raw data:
   ```sql
   {{ config(materialized='table') }}
   select * from {{ source('raw', 'my_table') }}
   ```
3. Define sources in `dbt/models/sources.yml`
4. Run `dbt build --select +my_new_model`

### Modifying Lambda Configuration

Edit `infra/dbt_runner.tf`:
- Change `timeout` for longer transformations
- Change `memory_size` for memory-intensive operations
- Update `environment` variables if needed

Then run:
```bash
terraform apply -var-file="envs/dev/terraform.tfvars"
```

### Adding EventBridge Scheduling

Create a new resource in `infra/`:
```hcl
resource "aws_cloudwatch_event_rule" "daily_dbt" {
  schedule_expression = "cron(0 2 * * ? *)"
}

resource "aws_cloudwatch_event_target" "dbt_runner" {
  rule      = aws_cloudwatch_event_rule.daily_dbt.name
  target_id = "dbt_runner"
  arn       = aws_lambda_function.dbt_runner.arn
  role_arn  = aws_iam_role.eventbridge_role.arn
  input     = jsonencode({
    command   = ["build"]
    cli_args  = []
  })
}
```

### Increasing Lambda Timeout

For models taking >15 minutes:
```hcl
# In infra/dbt_runner.tf
timeout = 1800  # 30 minutes
```

### Adding S3 Event Triggers

```hcl
# In infra/storage.tf
resource "aws_s3_bucket_notification" "raw_notification" {
  bucket      = aws_s3_bucket.raw.id
  eventbridge = true
}

# In infra/ (new file or existing)
resource "aws_cloudwatch_event_rule" "s3_raw_objects" {
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.raw.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "invoke_dbt" {
  rule      = aws_cloudwatch_event_rule.s3_raw_objects.name
  target_id = "dbt_runner"
  arn       = aws_lambda_function.dbt_runner.arn
  role_arn  = aws_iam_role.eventbridge_role.arn
}
```

## Best Practices for Users

1. **Use dbt Best Practices**: Follow dbt style guide, use staging models, document everything
2. **Partition Output Data**: For large datasets, partition by date or other keys for faster Athena queries
3. **Test Models**: Write dbt tests to validate data quality
4. **Monitor Costs**: Check CloudWatch for execution times, adjust Lambda memory accordingly
5. **Version Control**: Keep dbt models in git, use dbt Cloud for CI/CD
6. **Backup Processed Bucket**: Enable S3 cross-region replication for critical data

## Security & Best Practices (Applied)

### Infrastructure Security

- **S3 Encryption**: AES256 for all buckets
- **Public Access**: All buckets block public access
- **SSL/TLS**: Bucket policies enforce HTTPS-only access
- **Versioning**: Enabled on data buckets for recovery
- **IAM**: Least-privilege policies per Lambda function
- **Logging**: CloudWatch logs with 14-day retention

### dbt Best Practices

- **Staging Models**: Separate raw data transformation from business logic
- **Documentation**: Include descriptions in dbt YAML files
- **Testing**: Use built-in dbt tests (not_null, unique, relationships)
- **Modularization**: Use macros for repeated logic
- **Version Control**: Track all changes in git

### Operational Best Practices

- **Environment Separation**: Separate dev and prod configurations
- **Monitoring**: Check CloudWatch logs after each run
- **Backups**: Enable S3 versioning and lifecycle policies
- **Cost Tracking**: Tag resources for cost allocation
- **Documentation**: Keep README and dbt documentation updated

## Important Notes

- **Do not commit**: `*.tfstate`, `*.tfstate.backup`, `.terraform/` (in .gitignore)
- **dbt Layer**: Pre-built ZIP with dbt, dbt-athena, and dependencies must exist
- **Python Runtime**: Lambda uses Python 3.13 (update if changing dbt version requirements)
- **Region Default**: ap-southeast-2 is default; change in variables.tf or terraform.tfvars
- **No API Ingestion**: This starter focuses on transformation only; users provide their own data ingestion
- **Athena Results**: Automatically cleaned up after 30 days; don't rely on old results

## Deployment Checklist

- [ ] Update `aws_region` in `variables.tf` if not using ap-southeast-2
- [ ] Generate unique `bucket_prefix` (3-36 chars, globally unique)
- [ ] Review `envs/dev/terraform.tfvars` and `envs/prod/terraform.tfvars`
- [ ] Run `terraform validate` to check syntax
- [ ] Run `terraform plan` to review infrastructure changes
- [ ] Run `terraform apply` to deploy
- [ ] Verify S3 buckets created
- [ ] Upload sample data to raw bucket
- [ ] Test dbt_runner Lambda invocation
- [ ] Check CloudWatch logs for execution details

## Troubleshooting Guide

### Terraform Issues

**Error: "Error: failed to create bucket"**
- Bucket names must be globally unique
- Update `bucket_prefix` in terraform.tfvars

**Error: "Profile not found"**
- Ensure AWS credentials configured: `aws configure --profile default`
- Or set `AWS_PROFILE=your-profile` environment variable

### Lambda Issues

**Timeout**: Increase `timeout` in `infra/dbt_runner.tf`
**OutOfMemory**: Increase `memory_size` in `infra/dbt_runner.tf`
**Permission Denied**: Check IAM role policy in `dbt_runner.tf`

### dbt Issues

**Profile not found**: Verify `dbt/profiles.yml` matches Glue database name
**Table not found**: Check raw bucket has data and Glue database is created
**Query timeout**: Check Athena results bucket exists and is writable

## Contributing Guidelines

For contributors or future improvements:

1. **Follow Terraform Style Guide**: Use `terraform fmt` before committing
2. **Update CLAUDE.md**: Document any new infrastructure components
3. **Test Changes**: Run `terraform plan` and validate locally
4. **Add Comments**: Explain complex Terraform logic
5. **Update Documentation**: Keep README.md and inline docs current

## Version History

- **1.0.0** (2026-01): Initial public release
  - Minimal dbt-on-Lambda starter
  - Single dbt_runner Lambda
  - S3 + Glue + Athena integration
  - Terraform-based infrastructure

## Resources

- [dbt Documentation](https://docs.getdbt.com/)
- [dbt Athena Adapter](https://github.com/dbt-labs/dbt-athena)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [AWS Glue Documentation](https://docs.aws.amazon.com/glue/)
- [Amazon Athena Documentation](https://docs.aws.amazon.com/athena/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
