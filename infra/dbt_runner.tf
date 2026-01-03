# --- DBT Layer for dbt execution ---
resource "aws_lambda_layer_version" "dbt_layer" {
  filename                 = "${path.module}/../dbt_layer.zip"
  layer_name               = "${var.environment}-dbt-layer"
  compatible_runtimes      = [var.python_runtime]
  compatible_architectures = ["arm64"]
  source_code_hash         = fileexists("${path.module}/../dbt_layer.zip") ? filebase64sha256("${path.module}/../dbt_layer.zip") : null
}

# --- DBT Runner Lambda (Modular dbt execution) ---

data "archive_file" "dbt_runner_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../dbt"
  output_path = "${path.module}/../dbt_runner.zip"
  excludes    = ["dbt_layer.zip", "logs", "target", "dbt_packages"]
}

resource "aws_iam_role" "dbt_runner_role" {
  name = "${var.environment}-dbt-runner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = merge(
    {
      Name = "${var.environment}-dbt-runner-role"
      Role = "Lambda-Execution"
    },
    var.extra_tags
  )
}

resource "aws_iam_role_policy_attachment" "dbt_runner_basic" {
  role       = aws_iam_role.dbt_runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "dbt_runner_policy" {
  name = "${var.environment}-dbt-runner-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadRawData"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*"
        ]
      },
      {
        Sid    = "WriteProcessedData"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:DeleteObject"]
        Resource = [
          aws_s3_bucket.processed.arn,
          "${aws_s3_bucket.processed.arn}/*"
        ]
      },
      {
        Sid    = "AthenaQueryResults"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.athena_results.arn,
          "${aws_s3_bucket.athena_results.arn}/*"
        ]
      },
      {
        Sid    = "GlueCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:CreateDatabase",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetTableVersion",
          "glue:GetTableVersions",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:DeleteTableVersion",
          "glue:CreatePartition",
          "glue:GetPartition",
          "glue:GetPartitions",
          "glue:DeletePartition",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:BatchGetPartition"
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:database/*",
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/*/*"
        ]
      },
      {
        Sid    = "AthenaQueryExecution"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:StopQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:GetQueryResultsStream",
          "athena:BatchGetQueryExecution",
          "athena:ListQueryExecutions",
          "athena:GetWorkGroup",
          "athena:GetDataCatalog",
          "athena:ListDatabases",
          "athena:ListTableMetadata",
          "athena:GetTableMetadata"
        ]
        Resource = ["*"]
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.environment}-dbt-runner-policy"
    },
    var.extra_tags
  )
}

resource "aws_iam_role_policy_attachment" "dbt_runner_attach" {
  role       = aws_iam_role.dbt_runner_role.name
  policy_arn = aws_iam_policy.dbt_runner_policy.arn
}

resource "aws_lambda_function" "dbt_runner" {
  filename         = data.archive_file.dbt_runner_zip.output_path
  function_name    = "${var.environment}-dbt-runner"
  role             = aws_iam_role.dbt_runner_role.arn
  handler          = "handler.handler"
  runtime          = var.python_runtime
  architectures    = ["arm64"]
  timeout          = 900
  memory_size      = 3008
  source_code_hash = data.archive_file.dbt_runner_zip.output_base64sha256

  layers = [aws_lambda_layer_version.dbt_layer.arn]

  environment {
    variables = {
      RAW_BUCKET_NAME       = aws_s3_bucket.raw.id
      PROCESSED_BUCKET_NAME = aws_s3_bucket.processed.id
      GLUE_DATABASE_NAME    = aws_glue_catalog_database.dbt_data_platform.name
      ATHENA_RESULTS_BUCKET = aws_s3_bucket.athena_results.id
      ENVIRONMENT           = var.environment
    }
  }

  tags = merge(
    {
      Name     = "${var.environment}-dbt-runner"
      Function = "Data-Transformation"
    },
    var.extra_tags
  )
}

resource "aws_cloudwatch_log_group" "dbt_runner_logs" {
  name              = "/aws/lambda/${var.environment}-dbt-runner"
  retention_in_days = 14

  tags = merge(
    {
      Name     = "dbt-runner-logs"
      Function = "Data-Transformation"
    },
    var.extra_tags
  )
}
