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
- **Compute**: AWS Lambda (Python 3.12, arm64 architecture)
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
└── variables.tf        # Module variables

Note: Terraform state backend (S3 bucket) is created by ./bootstrap_account.sh
      using AWS CLI - not managed by Terraform infrastructure code
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
- Runtime: Python 3.12, arm64 architecture
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
- `python_runtime`: Python version for Lambda (default: python3.12)

**Environment-Specific** (`envs/{dev,prod}/terraform.tfvars`):
- Environment-specific bucket prefix
- Extra tags for environment identification

## Development Commands

### One-Time Bootstrap (Required)

```bash
# Initialize AWS account, GitHub OIDC, and Terraform state backend
./bootstrap_account.sh ap-southeast-2

# Initialize Terraform with S3 backend
terraform init
```

### Terraform Operations (Local)

```bash
# Validate Terraform configuration
terraform validate

# Format code
terraform fmt -recursive

# Plan changes
terraform plan

# Deploy infrastructure
terraform apply

# Destroy infrastructure (careful!)
terraform destroy
```

### Automated Deployments (GitHub Actions)

**Automatic Deploy on Push:**
```bash
# Push to main branch - CI/CD pipeline automatically:
git add .
git commit -m "Update infrastructure"
git push origin main
# → terraform plan runs
# → terraform apply runs automatically
```

**Manual Destroy (GitHub Actions):**
```
Go to GitHub → Actions → terraform_destroy
Click "Run workflow" → Enter "DESTROY" confirmation
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
│   ├── variables.tf              # Module variables
│   ├── outputs.tf                # Module outputs
│   └── .gitkeep                  # Ensures directory tracked
│
│   Note: State backend bucket is created by bootstrap_account.sh, not Terraform
│
├── .github/                      # GitHub Actions configuration
│   └── workflows/                # CI/CD pipelines
│       ├── terraform_deploy.yml  # Auto-deploy on push to main
│       └── terraform_destroy.yml # Manual destroy workflow
│
├── envs/                         # Environment-specific configurations
│   ├── dev/
│   │   └── terraform.tfvars      # Dev environment variables
│   └── prod/
│       └── terraform.tfvars      # Production environment variables
│
├── .gitignore                    # Git ignore rules
├── .python-version               # Python version (for pyenv)
├── bootstrap_account.sh          # One-time AWS account initialization
├── prep_dbt_layer.sh             # Build dbt Lambda layer (arm64)
├── main.tf                       # Root Terraform configuration
├── main.py                       # Python entry point (example)
├── outputs.tf                    # Root-level outputs
├── provider.tf                   # AWS provider configuration
├── terraform.tf                  # Backend configuration (auto-updated by bootstrap)
├── terraform.tfvars              # Default variable values (auto-updated by bootstrap)
├── variables.tf                  # Root-level variables
├── pyproject.toml                # Python project configuration
├── uv.lock                       # UV dependency lock file
├── README.md                     # User documentation
├── CLAUDE.md                     # This file (AI assistant guidance)
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

## Quick Start

Quick reference for getting started with dbt-on-Lambda:

```bash
# 1. Clone and install dependencies
git clone <repository-url>
cd dbt-lambda-starter
uv sync

# 2. Bootstrap AWS account (one-time)
./bootstrap_account.sh ap-southeast-2

# 3. Update configuration
# Edit terraform.tfvars with your bucket_prefix and other settings

# 4. Deploy infrastructure (choose one approach):

# Option A: GitHub Actions (recommended)
git push origin main
# → Automatic terraform plan and apply

# Option B: Local Terraform
terraform init
terraform plan
terraform apply

# 5. Upload sample data to raw bucket
RAW_BUCKET=$(terraform output -raw data_buckets | jq -r '.raw')
aws s3 cp sample.csv s3://$RAW_BUCKET/

# 6. Test the Lambda function
aws lambda invoke \
  --function-name dev-dbt-runner \
  --payload '{"command": ["build"], "cli_args": []}' \
  response.json

# 7. Check execution logs
aws logs tail /aws/lambda/dev-dbt-runner --follow
```

## GitHub Actions CI/CD Workflows

### Automatic Deployment (terraform_deploy.yml)

This workflow runs automatically on every push to the `main` branch.

**Workflow Steps:**
1. Checkout code from repository
2. Install uv and Python dependencies
3. Read `.arn` file (GitHub Actions role ARN)
4. Assume AWS role via OIDC (no credentials stored in repository)
5. Run `terraform init` (uses S3 backend from bootstrap)
6. Run `terraform plan` (validates changes)
7. Run `terraform apply -auto-approve` (deploys infrastructure)

**Usage:**
```bash
# Make infrastructure changes
git add .
git commit -m "Update Lambda timeout"
git push origin main
# → Workflow automatically runs and deploys
```

### Manual Destruction (terraform_destroy.yml)

This workflow destroys all infrastructure and must be manually triggered.

**To Destroy:**
1. Go to GitHub repository → **Actions** tab
2. Select **terraform_destroy** workflow
3. Click **Run workflow**
4. Enter **"DESTROY"** as confirmation
5. Wait for workflow to complete

**Why manual?** Prevents accidental infrastructure deletion.

### Security Notes

- **No AWS credentials in repository**: Uses GitHub OIDC federation
- **Role-based access**: Limited permissions via IAM role
- **Audit trail**: All deployments logged in GitHub Actions and AWS CloudTrail
- **State locking**: S3 backend prevents concurrent deployments

## Important Notes

- **Do not commit**: `*.tfstate`, `.terraform/` (in .gitignore)
- **Bootstrap**: Run `./bootstrap_account.sh` once to set up AWS account infrastructure
- **dbt Layer**: Auto-built by `prep_dbt_layer.sh` with arm64-compatible dependencies
- **Python Runtime**: Lambda uses Python 3.12 with arm64 (Graviton) architecture
- **Default Region**: ap-southeast-2; specify different region as argument to bootstrap script
- **No API Ingestion**: Starter focuses on transformation; users implement data ingestion separately
- **Athena Results**: Auto-cleaned after 30 days; don't depend on old query results
- **GitHub OIDC**: Bootstrap creates federated identity for CI/CD
- **`.arn` file**: Contains GitHub Actions role ARN; must be committed to repository
- **`.state-bucket` file**: Contains Terraform state bucket name; git-ignored

## Bootstrap and Initial Setup

### Account Bootstrap (One-time)

Bootstrap your AWS account to set up GitHub Actions integration and Terraform state backend. This creates all necessary resources using AWS CLI and auto-configures Terraform:

```bash
# From project root
./bootstrap_account.sh [AWS_REGION]

# Example:
./bootstrap_account.sh ap-southeast-2
```

**Bootstrap does the following:**

1. ✓ Verify AWS CLI v2 and credentials
2. ✓ Determine AWS region (from argument or existing AWS config)
3. ✓ Create GitHub OIDC provider (federated identity)
4. ✓ Create IAM role for GitHub Actions with admin permissions
5. ✓ Create S3 bucket for Terraform state with:
   - Versioning enabled for history/rollback
   - AES256 encryption for security
   - Public access blocked
   - HTTPS-only policy enforcement
6. ✓ **Automatically update configuration files:**
   - `terraform.tf`: Backend bucket name & region
   - `terraform.tfvars`: AWS region for deployments
7. ✓ Save configuration to output files

**Output files created:**
- `.arn`: GitHub Actions role ARN for workflow configuration
- `.state-bucket`: S3 bucket name for Terraform state

**Configuration files auto-updated:**
- `terraform.tf`: Backend block with bucket and region
- `terraform.tfvars`: AWS region for all deployments

### Enable Terraform Remote State

After bootstrap completes, enable remote state management:

```bash
# Migrate from local state to S3
terraform init -migrate-state

# Answer 'yes' when prompted to copy existing state
```

This command:
- Initializes the S3 backend (bucket already exists from bootstrap)
- Migrates any existing local state to S3
- Creates `.terraform/` configuration directory

### GitHub Actions CI/CD Integration

The project includes pre-configured GitHub Actions workflows. Bootstrap automatically creates the OIDC role needed for authentication.

**Pre-configured Workflows:**

1. **terraform_deploy.yml** (Automatic on push to main)
   - Triggered: Every push to `main` branch
   - Steps:
     - Authenticate via GitHub OIDC (uses `.arn` file)
     - Install dependencies (uv sync)
     - Terraform init/plan/apply
   - No additional setup needed!

2. **terraform_destroy.yml** (Manual dispatch)
   - Triggered: Manual GitHub Actions workflow
   - Steps:
     - Authenticate via GitHub OIDC
     - Runs `terraform destroy -auto-approve`
     - Requires "DESTROY" confirmation input

**The `.arn` file:**
- Automatically created by bootstrap_account.sh
- Contains the GitHub Actions role ARN
- Used by workflows to authenticate with AWS
- Must be committed to the repository

## Deployment Checklist

### Prerequisites
- [ ] AWS CLI v2 installed and configured with AdministratorAccess
- [ ] Git repository cloned with GitHub remote
- [ ] Python 3.12 available (via pyenv, .python-version)
- [ ] Terraform >= 1.0 installed

### Bootstrap Phase (One-time)
- [ ] Run: `./bootstrap_account.sh ap-southeast-2`
  - ✓ Creates GitHub OIDC provider
  - ✓ Creates IAM role for GitHub Actions
  - ✓ Creates S3 bucket for Terraform state
  - ✓ Auto-updates `terraform.tf` backend
  - ✓ Auto-updates `terraform.tfvars` region
  - ✓ Creates `.arn` file
- [ ] Verify `.arn` file created: `cat .arn`
- [ ] Verify `.state-bucket` file created

### Terraform Initialization
- [ ] Update `terraform.tfvars` with unique `bucket_prefix`
- [ ] Run: `terraform init` (uses S3 backend from bootstrap)
- [ ] Run: `terraform validate` to check configuration

### Infrastructure Deployment (Choose One)

**Option A: GitHub Actions (Recommended)**
- [ ] Commit and push changes to main: `git push origin main`
- [ ] Watch workflow run in GitHub Actions
- [ ] Verify `terraform apply` succeeded in workflow logs

**Option B: Local Terraform**
- [ ] Run: `terraform plan` to review changes
- [ ] Run: `terraform apply` to deploy
- [ ] Verify output shows created resources

### Post-Deployment Testing
- [ ] Verify S3 buckets created: `aws s3 ls | grep dev-`
- [ ] Verify Lambda function: `aws lambda get-function --function-name dev-dbt-runner`
- [ ] Upload sample data to raw bucket
- [ ] Test Lambda: `aws lambda invoke --function-name dev-dbt-runner --payload '{"command": ["build"], "cli_args": []}' response.json`
- [ ] Check logs: `aws logs tail /aws/lambda/dev-dbt-runner --follow`
- [ ] Verify dbt models in processed bucket and Glue catalog

## Troubleshooting Guide

### Bootstrap Issues

**Error: "AWS CLI v2 is required"**
- Install AWS CLI v2: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- Verify installation: `aws --version`

**Error: "AdministratorAccess policy is required"**
- Bootstrap script checks for admin permissions to create IAM roles and OIDC provider
- Ensure your AWS user/role has `AdministratorAccess` policy attached
- Contact your AWS account administrator if you don't have these permissions

**Error: "No git remote 'origin' found"**
- Bootstrap needs to detect GitHub repository for OIDC setup
- Ensure you're in a cloned GitHub repository with `origin` remote
- Verify: `git remote -v` shows GitHub URL

**Error: "S3 bucket creation failed"**
- S3 bucket names must be globally unique
- Check if bucket with that name already exists: `aws s3 ls | grep terraform-state`
- If it exists from a previous bootstrap, script will reuse it

**No output files created**
- Check script completed with `echo $?` (should be 0 for success)
- Verify `.arn` and `.state-bucket` files: `ls -la .arn .state-bucket`
- If missing, rerun bootstrap

**terraform.tf not updated with bucket name**
- Check file permissions: `ls -la terraform.tf`
- Verify sed syntax works on your system (macOS vs Linux have different sed)
- Manually update bucket name in `terraform.tf` backend block if needed

### Terraform Issues

**Error: "Error: failed to create bucket"**
- Bucket names must be globally unique
- Update `bucket_prefix` in terraform.tfvars

**Error: "Profile not found"**
- Ensure AWS credentials configured: `aws configure --profile default`
- Or set `AWS_PROFILE=your-profile` environment variable

**Error: "error reading S3 bucket: AccessDenied"**
- If backend is enabled and access fails, check IAM permissions
- Ensure the role has s3:GetObject and s3:PutObject on the state bucket

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
