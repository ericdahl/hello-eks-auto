resource "aws_s3_bucket" "my_bucket" {
  bucket = "test-bucket-for-lambda-events"

  tags = {
    Name        = "LambdaEventBucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_public_access_block" "my_bucket_blok_public" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "my_bucket_lifecycle" {
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    id      = "expire-and-transition"
    status  = "Enabled"

    expiration {
      days = 7
    }

    transition {
      days          = 30
      storage_class = "GLACIER_IR"
    }
  }

  }

resource "aws_iam_role" "lambda_role" {
  name = "lambda-s3-access-role"

  assume_role_policy = jsonencode({
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "lambda-s3-access-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.my_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_sqs_queue" "my_queue" {
  name = "lambda-event-queue"
}

resource "aws_s3_bucket_notification" "s3_notify" {
  bucket = aws_s3_bucket.my_bucket.id

  queue {
    events    = ["s3:ObjectCreated:*"]
    queue_arn = aws_sqs_queue.my_queue.arn
  }
}