
# Raw Bucket
resource "aws_s3_bucket" "raw" {
  bucket              = lower("${var.bucket_prefix}-raw")
  force_destroy       = true

  tags = merge(
    {
      Name  = "${var.bucket_prefix}-raw"
      Layer = "Raw"
      Type  = "Data-Bucket"
    },
    var.extra_tags
  )
}

resource "aws_s3_bucket_versioning" "raw_versioning" {
  bucket = aws_s3_bucket.raw.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw_encryption" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "raw_access" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "raw_policy" {
  bucket = aws_s3_bucket.raw.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSSLRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "raw_lifecycle" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    filter {}

    transition {
      days          = 1095
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "raw_tiering" {
  bucket = aws_s3_bucket.raw.id
  name   = "EntireBucket"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}

# Processed Bucket
resource "aws_s3_bucket" "processed" {
  bucket              = lower("${var.bucket_prefix}-processed")
  force_destroy       = true

  tags = merge(
    {
      Name  = "${var.bucket_prefix}-processed"
      Layer = "Processed"
      Type  = "Data-Bucket"
    },
    var.extra_tags
  )
}

resource "aws_s3_bucket_versioning" "processed_versioning" {
  bucket = aws_s3_bucket.processed.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed_encryption" {
  bucket = aws_s3_bucket.processed.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "processed_access" {
  bucket = aws_s3_bucket.processed.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "processed_policy" {
  bucket = aws_s3_bucket.processed.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSSLRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.processed.arn,
          "${aws_s3_bucket.processed.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "processed_tiering" {
  bucket = aws_s3_bucket.processed.id
  name   = "EntireBucket"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}

# dbt State Bucket
resource "aws_s3_bucket" "dbt_state" {
  bucket              = lower("${var.bucket_prefix}-dbt-state")
  force_destroy       = true

  tags = merge(
    {
      Name  = "${var.bucket_prefix}-dbt-state"
      Type  = "dbt-State-Bucket"
      Purpose = "dbt-manifest-and-artifacts"
    },
    var.extra_tags
  )
}

resource "aws_s3_bucket_versioning" "dbt_state_versioning" {
  bucket = aws_s3_bucket.dbt_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dbt_state_encryption" {
  bucket = aws_s3_bucket.dbt_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "dbt_state_access" {
  bucket = aws_s3_bucket.dbt_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "dbt_state_policy" {
  bucket = aws_s3_bucket.dbt_state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSSLRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.dbt_state.arn,
          "${aws_s3_bucket.dbt_state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "dbt_state_tiering" {
  bucket = aws_s3_bucket.dbt_state.id
  name   = "EntireBucket"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}

# dbt Docs Static Website Bucket (Public)
resource "aws_s3_bucket" "dbt_docs" {
  bucket              = lower("${var.bucket_prefix}-dbt-docs")
  force_destroy       = true

  tags = merge(
    {
      Name  = "${var.bucket_prefix}-dbt-docs"
      Type  = "dbt-Docs-Bucket"
      Purpose = "Static-Website-Hosting"
    },
    var.extra_tags
  )
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dbt_docs_encryption" {
  bucket = aws_s3_bucket.dbt_docs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Public access configuration - this bucket is intentionally public
resource "aws_s3_bucket_public_access_block" "dbt_docs_access" {
  bucket = aws_s3_bucket.dbt_docs.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "dbt_docs_policy" {
  bucket = aws_s3_bucket.dbt_docs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.dbt_docs.arn}/*"
      },
      {
        Sid       = "PublicListBucket"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:ListBucket"
        Resource  = aws_s3_bucket.dbt_docs.arn
      }
    ]
  })
}

# Enable static website hosting
resource "aws_s3_bucket_website_configuration" "dbt_docs_website" {
  bucket = aws_s3_bucket.dbt_docs.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Configure CORS for dbt docs
resource "aws_s3_bucket_cors_configuration" "dbt_docs_cors" {
  bucket = aws_s3_bucket.dbt_docs.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}