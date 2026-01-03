# S3 Data Bucket Outputs
output "data_buckets" {
  description = "Names of the dbt data pipeline S3 buckets (raw input, processed output)"
  value = {
    raw       = aws_s3_bucket.raw.id
    processed = aws_s3_bucket.processed.id
  }
}

output "data_bucket_arns" {
  description = "ARNs of the dbt data pipeline S3 buckets"
  value = {
    raw       = aws_s3_bucket.raw.arn
    processed = aws_s3_bucket.processed.arn
  }
}

# Athena Query Results
output "athena_results_bucket" {
  description = "Name of the Athena query results S3 bucket for temporary query output"
  value       = aws_s3_bucket.athena_results.id
}

# Glue Database Outputs
output "glue_database_name" {
  description = "Name of the Glue catalog database for dbt metadata"
  value       = aws_glue_catalog_database.dbt_data_platform.name
}

output "glue_database_arn" {
  description = "ARN of the Glue catalog database"
  value       = aws_glue_catalog_database.dbt_data_platform.arn
}

# Lambda Function Outputs
output "dbt_runner_arn" {
  description = "ARN of the dbt_runner Lambda function"
  value       = aws_lambda_function.dbt_runner.arn
}

output "dbt_runner_name" {
  description = "Name of the dbt_runner Lambda function for invocation"
  value       = aws_lambda_function.dbt_runner.function_name
}