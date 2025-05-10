provider "aws" {
  region = "us-east-1"
}

resource "aws_sns_topic" "demo_topic" {
  name = "demo-sns-topic"
  tags = {
    Environment = "Demo"
    App         = "SchedulerTest"
    ManagedBy   = "Terraform"
    CostCenter  = "12345"
  }
}

resource "aws_sqs_queue" "demo_queue" {
  name = "demo-queue"
  tags = {
    Environment = "Demo"
    App         = "SchedulerTest"
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "demo_subscription" {
  topic_arn = aws_sns_topic.demo_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.demo_queue.arn

  depends_on = [aws_sqs_queue_policy.demo_queue_policy]
}

resource "aws_sqs_queue_policy" "demo_queue_policy" {
  queue_url = aws_sqs_queue.demo_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Principal = { Service = "sns.amazonaws.com" },
      Action    = "sqs:SendMessage",
      Resource  = aws_sqs_queue.demo_queue.arn
      Effect    = "Allow"
    }]
  })
}

resource "aws_iam_role" "scheduler_role" {
  name = "demo-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_policy" {
  name = "scheduler-sns-publish"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2025-04-24",
    Statement = [{
      Action   = "sns:Publish",
      Resource = aws_sns_topic.demo_topic.arn
    }]
  })
}

resource "aws_scheduler_schedule" "demo_schedule" {
  name       = "demo-schedule"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(0/5 * * * ? *)"
  schedule_expression_timezone = "UTC"

  target {
    arn      = aws_sns_topic.demo_topic.arn
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      message = "Hello from EventBridge Scheduler!"
    })
  }
}