variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "ap-southeast-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "The aws_region must be a valid AWS region format (e.g., ap-southeast-2)."
  }
}

variable "aws_profile" {
  description = "The AWS CLI profile to use for authentication"
  type        = string
  default     = "default"
}

variable "environment" {
  description = "The environment name (e.g., dev, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either 'dev' or 'prod'."
  }
}

variable "bucket_prefix" {
  description = "The prefix for the S3 bucket name."
  type        = string

  validation {
    condition     = length(var.bucket_prefix) > 3 && length(var.bucket_prefix) < 37
    error_message = "The bucket_prefix must be between 4 and 36 characters."
  }
}

variable "default_tags" {
  description = "Default tags to apply to all AWS resources"
  type        = map(string)
  default = {
    Project   = "DBT-Lambda"
    ManagedBy = "Terraform"
    Purpose   = "Data-Transformation"
  }
}

variable "extra_tags" {
  description = "Additional tags to merge with default_tags."
  type        = map(string)
  default     = {}
}

variable "python_runtime" {
  description = "The Python runtime for Lambda functions."
  type        = string
  default     = "python3.12"
}

