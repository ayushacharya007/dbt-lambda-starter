# dbt-on-Lambda Starter

A production-ready starter template for running [dbt](https://www.getdbt.com/) transformations on AWS Lambda using Athena as the data warehouse. Built with Terraform for infrastructure-as-code.

## Overview

This project provides a streamlined, serverless data transformation pipeline where:

- **Raw data** is stored in an S3 bucket (you provide the data ingestion)
- **dbt Lambda** executes transformations using Athena as the analytical database
- **Processed data** is written to an S3 bucket and cataloged in the Glue Data Catalog
- **Infrastructure** is fully defined in Terraform and ready to deploy

```
[Raw Data S3] → [dbt_runner Lambda] → [Processed S3] + [Athena/Glue Metadata]
                      ↓
              [CloudWatch Logs]
```

## Key Features

- **Serverless**: No EC2 instances to manage. Pay only for Lambda execution and data scanned
- **dbt Integration**: Full dbt support including models, tests, macros, and documentation
- **Athena Integration**: Query and transform data using standard SQL via Amazon Athena
- **Cost Efficient**: Uses ARM64 Graviton processors, intelligent tiering, and automatic archival
- **Modular**: Easily extensible for your specific data transformation needs
- **Production Ready**: Includes security best practices, encryption, versioning, and logging

## Architecture

### Components

1. **dbt_runner Lambda**
   - Runtime: Python 3.13, ARM64 architecture
   - Timeout: 900 seconds (15 minutes)
   - Memory: 3008 MB
   - Triggered manually or via EventBridge/S3 events (you can add)

2. **S3 Data Buckets**
   - **Raw Bucket**: Input data for dbt transformations
   - **Processed Bucket**: Output location for transformed data
   - Features: Versioning, encryption, public access blocks, lifecycle policies

3. **Athena & Glue**
   - **Glue Catalog Database**: Metadata for dbt to discover and create tables
   - **Athena Results Bucket**: Temporary query result storage (auto-cleaned)

4. **CloudWatch**
   - Automatic logs for all Lambda executions
   - 14-day retention for debugging and monitoring

## Prerequisites

- **AWS Account** with appropriate permissions
- **Terraform** >= 1.0
- **AWS CLI** configured with your credentials
- **Python 3.13+** (for local dbt project development)
- **Git** (to clone this repository)

## Quick Start

### 1. Clone and Setup

```bash
git clone <repository-url>
cd dbt-lambda-starter

# Install dependencies (if using Python virtual env)
uv sync
```

Replace `<repository-url>` with the URL of your cloned repository.

### 2. Configure AWS Profile

```bash
# Set up your AWS credentials (if not already configured)
aws configure --profile default

# then login to your profile
aws sso login --profile your-profile-name

# Or use an existing profile
export AWS_PROFILE=your-profile-name
```

### 3. Update Configuration

Edit `terraform.tfvars` for your environment:

```hcl
aws_region    = "us-east-1"              # Your AWS region
bucket_prefix = "my-company-dbt"         # Unique prefix for S3 buckets
environment   = "dev"

extra_tags = {
  Environment = "Development"
  Owner       = "your-team"
  CostCenter  = "12345"
}
```

### 4. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Save the outputs for reference
terraform output > outputs.json
```

### 5. Upload Sample Data

```bash
# Get your raw bucket name from outputs
RAW_BUCKET=$(terraform output -raw data_buckets | jq -r '.raw')

# Create a sample CSV file
cat > sample.csv << EOF
id,name,value
1,product-a,100
2,product-b,200
3,product-c,300
EOF

# Upload to raw bucket
aws s3 cp sample.csv s3://$RAW_BUCKET/
```

### 6. Prepare Your dbt Project

Edit `dbt/profiles.yml` if needed (preconfigured for Athena):

```yaml
dbt_lambda:
  target: dev
  outputs:
    dev:
      type: athena
      method: iam
      database: dev-dbt-lambda-dataplatform  # Matches Glue database
      s3_staging_dir: s3://dev-dbt-lambda-athena-results-ACCOUNT_ID/
      aws_region: us-east-1
      schema: public
      threads: 4
```

### 7. Invoke dbt Transformation

**Option A: AWS Console**
1. Go to Lambda → Functions → `dev-dbt-runner`
2. Click "Test"
3. Use event payload:
   ```json
   {
     "command": ["build"],
     "cli_args": ["--select", "+my_first_dbt_model"]
   }
   ```

**Option B: AWS CLI**
```bash
aws lambda invoke \
  --function-name dev-dbt-runner \
  --payload '{"command": ["build"], "cli_args": ["--select", "+my_first_dbt_model"]}' \
  response.json

cat response.json
```

**Option C: View Logs**
```bash
aws logs tail /aws/lambda/dev-dbt-runner --follow
```

## VSCode IDE Setup (Recommended)

This project includes pre-configured VSCode settings for an optimal development experience:

### Automatic Setup

1. Open the project in VSCode
2. You'll see a prompt to install recommended extensions
3. Click **"Install all"** to install:
   - **dbt Power User** - dbt IDE with autocompletion, lineage visualization
   - **Terraform** (HashiCorp) - Terraform formatting and validation
   - **Python** (Microsoft) - Full Python development support
   - **GitLens** - Advanced Git integration
   - **AWS Toolkit** - AWS service integration
   - **SQL Tools** - SQL editing and execution
   - And 15+ more productivity extensions

### Included Configuration

- ✅ **Python formatter** (Black) - Auto-format Python on save
- ✅ **Terraform formatter** - Auto-format Terraform files
- ✅ **dbt Jinja syntax highlighting** - Color-coded dbt files
- ✅ **MCP Servers** - Terraform and dbt context for AI assistants
- ✅ **Environment variables** - Pre-configured for dbt and Terraform
- ✅ **Code style rules** - 2-space indentation, 80/120 character rulers

### Manual Extension Installation

If the automatic prompt doesn't appear, install manually:

```bash
code --install-extension dbt-labs.dbt-power-user
code --install-extension hashicorp.terraform
code --install-extension ms-python.python
code --install-extension eamodio.gitlens
code --install-extension amazonwebservices.aws-toolkit-vscode
```

### Features Unlocked

With these extensions enabled, you get:

| Feature | Extension | Benefit |
|---------|-----------|---------|
| **dbt Model Autocompletion** | dbt Power User | Type `ref(` and see suggestions |
| **Lineage Visualization** | dbt Power User | See model dependencies in sidebar |
| **Test Execution** | dbt Power User | Run dbt tests directly from editor |
| **Terraform Validation** | HashiCorp Terraform | Catch errors before `apply` |
| **Python Linting** | ms-python.python | Real-time code quality feedback |
| **Git History** | GitLens | See who changed each line |
| **SQL Execution** | SQLTools | Run queries against Athena |

### Using MCP with Claude Code

If you use Claude Code, the project is configured with:
- **Terraform MCP** - Intelligent Terraform assistance
- **dbt MCP** - Real-time dbt model insights

See [.vscode/README.md](.vscode/README.md) for detailed configuration and troubleshooting.

## Project Structure

```
dbt-lambda-starter/
├── .vscode/                     # VSCode IDE configuration
│   ├── settings.json            # Editor settings (Python, dbt, Terraform)
│   ├── extensions.json          # Recommended extensions for power users
│   ├── mcp.json                 # MCP server configuration (Terraform, dbt)
│   └── README.md                # VSCode setup guide
│
├── dbt/                         # dbt project
│   ├── dbt_project.yml          # dbt configuration
│   ├── profiles.yml             # Athena connection config
│   ├── handler.py               # Lambda handler for dbt execution
│   ├── models/
│   │   ├── staging/
│   │   ├── marts/
│   │   └── example_models.sql
│   ├── tests/
│   ├── macros/
│   └── dbt_packages/            # External dbt packages
│
├── dbt_layer/
│   └── dbt_layer.zip            # Pre-built dbt dependencies layer
│
├── infra/                       # Terraform infrastructure modules
│   ├── compute.tf               # Lambda functions and layers
│   ├── dbt_runner.tf            # dbt_runner Lambda and IAM
│   ├── storage.tf               # S3 buckets
│   ├── glue.tf                  # Glue catalog database
│   ├── state_backend.tf         # Terraform state configuration
│   ├── variables.tf             # Module variables
│   └── outputs.tf               # Module outputs
│
├── envs/                        # Environment-specific configs
│   ├── dev/
│   │   └── terraform.tfvars
│   └── prod/
│       └── terraform.tfvars
│
├── .gitignore                   # Git ignore rules
├── main.tf                      # Root Terraform configuration
├── variables.tf                 # Root variables
├── outputs.tf                   # Root outputs
├── provider.tf                  # AWS provider configuration
├── terraform.tf                 # Backend configuration
├── terraform.tfvars             # Default variable values
├── pyproject.toml               # Python project configuration
├── README.md                    # This file
└── CLAUDE.md                    # AI assistant guidance
```

## Deployment Guide

### Development Environment

```bash
# Deploy to dev with dev-specific tfvars
terraform apply -var-file="envs/dev/terraform.tfvars"
```

### Production Environment

```bash
# Plan for prod
terraform plan -var-file="envs/prod/terraform.tfvars"

# Apply for prod (review output carefully!)
terraform apply -var-file="envs/prod/terraform.tfvars"
```

### Remote State (Recommended)

For team collaboration, enable remote state:

```bash
# The terraform.tf file includes a backend configuration
# After the initial apply (which creates the state bucket), uncomment:
# backend "s3" {
#   bucket         = "dbt-lambda-terraform-state"
#   key            = "terraform.tfstate"
#   region         = "us-east-1"
#   dynamodb_table = "terraform-locks"
#   encrypt        = true
# }

# Then run:
terraform init -migrate-state
```
### Running it for the first time to set up remote state

Because we use s3 as our remote state and the s3 state bucket used for the state is also part of this terraform project, the first time you run `terraform init` you will need to do so without the backend configuration enabled. This will create the s3 state bucket and dynamodb table. After that you can uncomment the backend configuration and run `terraform init -migrate-state` to migrate your local state to the remote s3 backend.

1. Comment the backend "s3" block in `terraform.tf`
2. Run `terraform init` and `terraform apply -var-file="envs/dev/terraform.tfvars"`
3. Uncomment the backend "s3" block in `terraform.tf`. Populate the bucket and region with the values created in step 2.
4. Run `terraform init -migrate-state`

You only need to do this once.

## dbt Commands

### Build Everything

```json
{
  "command": ["build"],
  "cli_args": []
}
```

### Run Specific Models

```json
{
  "command": ["run"],
  "cli_args": ["--select", "my_model_name"]
}
```

### Run Tests

```json
{
  "command": ["test"],
  "cli_args": []
}
```

### Generate Documentation

```json
{
  "command": ["docs", "generate"],
  "cli_args": []
}
```

### Dry Run

```json
{
  "command": ["run"],
  "cli_args": ["--select", "my_model", "--debug"]
}
```

## Monitoring & Logging

### View Lambda Logs

```bash
# Real-time logs
aws logs tail /aws/lambda/dev-dbt-runner --follow

# Search for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/dev-dbt-runner \
  --filter-pattern "ERROR"
```

### Monitor Costs

```bash
# List all resources and their tags
aws resourcegroupstaggingapi get-resources \
  --resource-type-filter lambda s3 glue \
  --tag-filters Key=Project,Values=DBT-Lambda
```

## Security Best Practices

- **IAM**: Each Lambda has least-privilege permissions
- **Encryption**: S3 buckets use AES256, with versioning enabled
- **Public Access**: S3 buckets block all public access
- **SSL/TLS**: All S3 operations require HTTPS
- **Secrets**: Store sensitive data in AWS Secrets Manager (not in code)
- **Audit Logging**: Enable CloudTrail for compliance

## Extending This Project

### Add Manual Data Ingestion

Create a simple Lambda or use the AWS CLI:

```bash
# Upload data to raw bucket
aws s3 cp my_data.parquet s3://$(terraform output -raw data_buckets | jq -r '.raw')/
```

### Add Scheduled Execution

Create an EventBridge rule:

```bash
aws events put-rule \
  --name dbt-daily-run \
  --schedule-expression "cron(0 2 * * ? *)"  # 2 AM UTC daily
```

### Add Data Validation

Use dbt's built-in tests:

```sql
-- models/staging/my_model.sql
{{ config(materialized='table') }}

select * from {{ source('raw', 'my_table') }}

tests:
  - not_null:
      columns:
        - id
  - unique:
      columns:
        - id
```

### Trigger from S3 Events

Add S3 event notification to the raw bucket:

```hcl
resource "aws_s3_bucket_notification" "raw_notification" {
  bucket      = aws_s3_bucket.raw.id
  eventbridge = true
}

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

## Troubleshooting

### Lambda Timeout

Increase the timeout in `infra/dbt_runner.tf`:

```hcl
timeout = 1800  # 30 minutes
```

### Out of Memory

Increase memory in `infra/dbt_runner.tf`:

```hcl
memory_size = 4096  # Up to 10,240 MB available
```

### Athena Query Errors

Check that:
1. Raw data is in S3 correctly formatted
2. Glue database matches `GLUE_DATABASE_NAME` environment variable
3. Athena results bucket exists and is writable

### dbt Profile Issues

Verify in `dbt/profiles.yml`:
```yaml
database: <environment>-dbt-lambda-dataplatform
s3_staging_dir: s3://<bucket>-athena-results-<account>/
```

## Cost Optimization

- **Lambda**: Uses ARM64 (Graviton) for 20% cost savings
- **S3**: Intelligent tiering and lifecycle policies reduce storage costs
- **Athena**: Pay only for data scanned; consider partitioning
- **Glue**: Catalog is free; pay for crawler and ETL if used

## Contributing

Found a bug or have an improvement? Please open an issue or submit a pull request!

## License

This project is licensed under the MIT License - see LICENSE file for details.

## Support

For questions or issues:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review CloudWatch logs for error details
3. Open an issue on GitHub with:
   - Your Terraform version (`terraform --version`)
   - Error message and logs
   - Steps to reproduce

## Resources

- [dbt Documentation](https://docs.getdbt.com/)
- [dbt Athena Adapter](https://github.com/dbt-labs/dbt-athena)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Amazon Athena Documentation](https://docs.aws.amazon.com/athena/)
- [AWS Glue Catalog](https://docs.aws.amazon.com/glue/)
