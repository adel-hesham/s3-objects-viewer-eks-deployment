# s3.tf

resource "aws_s3_bucket" "main" {
  bucket = "${var.cluster_name}-storage"

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "test_txt" {
  bucket  = aws_s3_bucket.main.id
  key     = "test/hello.txt"
  content = "hello from terraform"
}

resource "aws_s3_object" "test_json" {
  bucket       = aws_s3_bucket.main.id
  key          = "test/config.json"
  content      = jsonencode({
    app     = "my-eks-app"
    version = "1.0.0"
    env     = var.environment
  })
  content_type = "application/json"
}

resource "aws_s3_object" "test_folder" {
  bucket  = aws_s3_bucket.main.id
  key     = "logs/"             # trailing slash creates a folder
  content = ""
}

resource "aws_s3_object" "test_log" {
  bucket  = aws_s3_bucket.main.id
  key     = "logs/app.log"
  content = "2024-01-01 00:00:00 INFO app started\n2024-01-01 00:00:01 INFO ready"
}