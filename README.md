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
   - Runtime: Python 3.12, ARM64 architecture
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

- **AWS Account** with AdministratorAccess permissions
- **AWS CLI v2** configured with credentials
- **Terraform** >= 1.0
- **Python 3.12+** (for local development)
- **Git** with a GitHub remote

## Quick Start

This project uses **Bootstrap** for one-time AWS account setup, then **Terraform** for infrastructure management, and **GitHub Actions** for CI/CD automation.

### Step 1: Clone Repository and Install Dependencies

```bash
git clone <repository-url>
cd dbt-lambda-starter
uv sync
```

### Step 2: Bootstrap AWS Account (One-Time Only)

The bootstrap script sets up GitHub OIDC authentication and Terraform state backend:

```bash
# Set your desired AWS region (optional, defaults to configured region)
./bootstrap_account.sh ap-southeast-2
```

**What bootstrap does:**
- ✓ Creates GitHub OIDC provider for secure CI/CD authentication
- ✓ Creates IAM role for GitHub Actions deployment
- ✓ Creates S3 bucket for Terraform state with encryption and versioning
- ✓ Updates `terraform.tf` with state backend configuration
- ✓ Updates `terraform.tfvars` with your AWS region
- ✓ Outputs `.arn` file containing the GitHub Actions role ARN

### Step 3: Configure Your Project

Edit `terraform.tfvars` to customize your deployment:

```hcl
aws_region    = "ap-southeast-2"         # Your AWS region (auto-set by bootstrap)
bucket_prefix = "my-company-dbt"         # Unique S3 bucket prefix
environment   = "dev"

extra_tags = {
  Environment = "Development"
  Owner       = "your-team"
  CostCenter  = "12345"
}
```

### Step 4: Deploy Infrastructure

**Option A: Terraform CLI (Local Deployment)**

```bash
# Initialize Terraform (uses backend from bootstrap)
terraform init

# Review changes
terraform plan

# Deploy
terraform apply
```

**Option B: GitHub Actions (Automated CI/CD)**

Push to `main` branch and the `terraform_deploy` workflow automatically:
- ✓ Runs `terraform plan`
- ✓ Validates infrastructure
- ✓ Runs `terraform apply -auto-approve`

No manual steps needed after bootstrap!

### Step 5: Upload Sample Data

```bash
# Get raw bucket name from Terraform outputs
RAW_BUCKET=$(terraform output -raw data_buckets | jq -r '.raw')

# Create and upload sample data
cat > sample.csv << EOF
id,name,value
1,product-a,100
2,product-b,200
3,product-c,300
EOF

aws s3 cp sample.csv s3://$RAW_BUCKET/
```

### Step 6: Invoke dbt Transformation

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
│   ├── variables.tf             # Module variables
│   └── outputs.tf               # Module outputs
│
├── envs/                        # Environment-specific configs
│   ├── dev/
│   │   └── terraform.tfvars
│   └── prod/
│       └── terraform.tfvars
│
├── .github/workflows/           # GitHub Actions CI/CD pipelines
│   ├── terraform_deploy.yml     # Auto-deploy on push to main
│   └── terraform_destroy.yml    # Manual destroy workflow
│
├── .gitignore                   # Git ignore rules
├── bootstrap_account.sh         # One-time AWS account setup
├── prep_dbt_layer.sh            # Build dbt Lambda layer
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

## CI/CD Pipelines

This project includes automated GitHub Actions workflows for deployment and destruction.

### Automatic Deployment (terraform_deploy.yml)

**Triggered:** Every push to `main` branch

**What it does:**
1. Checks out code
2. Installs dependencies (uv sync)
3. Authenticates to AWS using GitHub OIDC (`.arn` file)
4. Runs `terraform init` (uses S3 backend from bootstrap)
5. Runs `terraform plan` (validates changes)
6. Runs `terraform apply -auto-approve` (deploys infrastructure)

**No manual action needed** - just push to main and watch the workflow run!

### Manual Destruction (terraform_destroy.yml)

**Triggered:** Manual workflow dispatch in GitHub Actions

**To destroy infrastructure:**
1. Go to GitHub repository → Actions → terraform_destroy
2. Click "Run workflow"
3. Enter "DESTROY" as confirmation
4. Confirm to delete all infrastructure

**Warning:** This destroys all AWS resources created by Terraform. Use with caution!

## Deployment Guide (Local Alternative)

If you prefer local Terraform management instead of GitHub Actions:

### Local Deployment

```bash
# Initialize (uses S3 backend from bootstrap)
terraform init

# Review changes
terraform plan

# Deploy infrastructure
terraform apply
```

### Local Destruction

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy
```

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
