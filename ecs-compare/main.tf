# ==============================================================================
# Provider Configuration
# ==============================================================================
provider "aws" {
  region = "us-east-1" # Hardcoded region
}

# ==============================================================================
# Variables (variables.tf) - Often incomplete or missing defaults
# ==============================================================================
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "ecs-demo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}


# ==============================================================================
# VPC (vpc.tf)
# ==============================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
    # Missing environment tag
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Only public subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a" 
  map_public_ip_on_launch = true         

  tags = {
    Name = "${var.project_name}-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b" # Hardcoded AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-b"
    # Inconsistent tagging style
    Project = var.project_name
  }
}

# Missing private subnets and NAT Gateway

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}


# ==============================================================================
# Security Groups (security.tf)
# ==============================================================================

# Security group for the Load Balancer
resource "aws_security_group" "lb_sg" {
  name        = "${var.project_name}-lb-sg"
  description = "Allow HTTP traffic to LB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Overly permissive
  }

  # Missing egress rule, might default to allow all, but explicit is better.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-lb-sg"
  }
}

# Security group for the EC2 Instances in the ASG
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow traffic from LB and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow HTTP from LB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["8.8.8.8/32"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# ==============================================================================
# S3 Bucket for Nginx Content (s3.tf)
# ==============================================================================
resource "aws_s3_bucket" "nginx_content" {
  bucket = "${var.project_name}-nginx-content-${random_id.bucket_suffix.hex}" # Ensure unique name


  tags = {
    Name        = "${var.project_name}-nginx-content"
    Environment = "dev" # Tagging example
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Example content (usually you'd upload this separately)
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.nginx_content.id
  key    = "index.html"
  content = <<-EOT
  <!DOCTYPE html>
  <html>
  <head><title>ECS Demo</title></head>
  <body><h1>Welcome to the ECS Demo!</h1><p>Content served from S3.</p></body>
  </html>
  EOT
  content_type = "text/html"

  # ACL set to public-read - better to use bucket policy or CloudFront OAI
  acl = "public-read"
}

# ==============================================================================
# IAM Roles (iam.tf)
# ==============================================================================

# EC2 Instance Profile Role
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project_name}-ecs-instance-role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.project_name}-ecs-instance-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance_policy_attachment" {
  role       = aws_iam_role.ecs_instance_role.name
  # Attaching the AWS managed policy for ECS instances
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.project_name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name

}


# ECS Task Execution Role (for ECS agent to pull images, publish logs)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  # Attaching the AWS managed policy for task execution
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role (for application code permissions)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-role"
  }
}

# Inline policy granting S3 access
resource "aws_iam_role_policy" "task_s3_policy" {
  name = "${var.project_name}-task-s3-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.nginx_content.arn}/*",
        ]
      },
      # Overly permissive S3 access?
       {
         Action = [
           "s3:GetObject"
           "ssm:GetParameter",
           "iam:PassRole"
         ]
         Effect = "Allow"
         Resource = "*"
       }
    ]
  })
}

# ==============================================================================
# ECS Cluster (ecs.tf)
# ==============================================================================
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  tags = {
    Name = "${var.project_name}-cluster"
    # Missing other standard tags
  }
}

# ==============================================================================
# EC2 Auto Scaling Group and Launch Template (asg.tf)
# ==============================================================================

# Data source to get the latest ECS Optimized AMI
data "aws_ami" "ecs_optimized_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    # Filter might be too broad or could change
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "${var.project_name}-ecs-"
  image_id      = data.aws_ami.ecs_optimized_ami.id # Using data source is good
  instance_type = "t2.micro"                       # Might be underpowered

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_instance_profile.arn
  }

  network_interfaces {
    associate_public_ip_address = true # Necessary because only public subnets used
    security_groups             = [aws_security_group.ec2_sg.id]
    # delete_on_termination defaults to true
  }



  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-ecs-instance"
    }
  }

  # Missing tag_specifications for volume tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ecs_asg" {
  name_prefix = "${var.project_name}-ecs-asg-"
  # Using only one subnet/AZ - poor resiliency
  # vpc_zone_identifier = [aws_subnet.public_a.id]
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id] # Corrected for multi-AZ

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  min_size         = 1 # Single point of failure
  max_size         = 3
  desired_capacity = 2

  # Health check settings
  health_check_type         = "EC2" # Should be "ELB"?
  health_check_grace_period = 300

  # Missing suspended_processes

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "AmazonECSManaged" # Important tag for ECS
    value               = ""
    propagate_at_launch = true
  }
  # Missing other project/environment tags

  lifecycle {
    create_before_destroy = true
  }

  # Missing termination policies
}


# ==============================================================================
# Application Load Balancer (alb.tf)
# ==============================================================================
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id] # Good: Multi-AZ


  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "nginx" {
  name        = "${var.project_name}-nginx-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance" # Should be 'ip' if using awsvpc network mode?

  health_check {
    enabled             = true
    interval            = 30
    path                = "/" # Assumes Nginx root serves health check
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200" # Too strict?
  }

  # Stickiness not configured
  # stickiness {
  #   type            = "lb_cookie"
  #   cookie_duration = 86400 # 1 day
  #   enabled         = true
  # }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-nginx-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP" # Should be HTTPS in production

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }

  # No HTTPS listener or redirect configured
}

# ==============================================================================
# ECS Task Definition and Service (ecs.tf continued)
# ==============================================================================

# app which will read from S3 bucket
resource "aws_ecs_task_definition" "nginx" {
  family                   = "${var.project_name}-nginx"
  network_mode             = "bridge" # Could be host or awsvpc
  requires_compatibilities = ["EC2"]  # Explicitly require EC2
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn # Task role assigned, but nginx config doesn't use it

  cpu                      = 256


  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 0 # Using dynamic host port mapping
          protocol      = "tcp"
        }
      ]

      # Nginx isn't configured to use the S3 bucket content.
    }
  ])

  tags = {
    Name = "${var.project_name}-nginx-task"
  }
}

# Log group (needed if logConfiguration uncommented)
# resource "aws_cloudwatch_log_group" "ecs_nginx" {
#   name = "/ecs/${var.project_name}/nginx"
#
#   tags = {
#     Name = "${var.project_name}-nginx-logs"
#   }
# }

resource "aws_ecs_service" "nginx" {
  name            = "${var.project_name}-nginx-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 2 # Start with 2 tasks
  launch_type     = "EC2" # Explicitly EC2 launch type

  # Missing network_configuration if using awsvpc mode
  # network_configuration {
  #   subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  #   security_groups = [aws_security_group.ecs_tasks_sg.id]
  # }

  load_balancer {
    target_group_arn = aws_lb_target_group.nginx.arn
    container_name   = "nginx"
    container_port   = 80
  }

  # Depends on ASG, but not explicitly defined
  depends_on = [
    aws_lb_listener.http,
    aws_autoscaling_group.ecs_asg # Make sure ASG instances are available
  ]

  # Deployment settings might be too aggressive or too slow
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  # No service discovery configured

  # No placement constraints or strategies
  # placement_constraints {
  #   type = "distinctInstance"
  # }

  tags = {
    Name = "${var.project_name}-nginx-service"
  }
}

# ==============================================================================
# ECS Service Auto Scaling (ecs.tf continued)
# ==============================================================================
resource "aws_appautoscaling_target" "ecs_service_scaling_target" {
  max_capacity       = 6 # Max capacity might not align well with ASG max_size
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.nginx.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale Up Policy
resource "aws_appautoscaling_policy" "ecs_service_scale_up" {
  name               = "${var.project_name}-nginx-scale-up"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_service_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service_scaling_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60 # Cooldown period in seconds after a scale-up activity
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0 # When > threshold
      scaling_adjustment          = 3 # Add 2 tasks on scale-up
    }
  }
}

# Scale Down Policy
resource "aws_appautoscaling_policy" "ecs_service_scale_down" {
  name               = "${var.project_name}-nginx-scale-down"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_service_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service_scaling_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300 # Longer cooldown for scale down
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0 # When < threshold
      scaling_adjustment          = -1 # Remove 1 task
    }
  }
}

# CloudWatch Alarm for Scaling Up
resource "aws_cloudwatch_metric_alarm" "ecs_service_cpu_high" {
  alarm_name          = "${var.project_name}-nginx-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2" # Require two consecutive periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60" # Check every 60 seconds
  statistic           = "Average"
  threshold           = "70" # Threshold might be too high or too low
  alarm_description   = "Alarm when ECS service CPU exceeds 70%"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.nginx.name
  }

  alarm_actions = [aws_appautoscaling_policy.ecs_service_scale_up.arn]
}

# CloudWatch Alarm for Scaling Down
resource "aws_cloudwatch_metric_alarm" "ecs_service_cpu_low" {
  alarm_name          = "${var.project_name}-nginx-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "5" # Require lower CPU for longer before scaling down
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "30" # Threshold might be too low, causing flapping
  alarm_description   = "Alarm when ECS service CPU drops below 30%"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.nginx.name
  }

  alarm_actions = [aws_appautoscaling_policy.ecs_service_scale_down.arn]
}


# ==============================================================================
# Outputs (outputs.tf)
# ==============================================================================
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for content"
  value       = aws_s3_bucket.nginx_content.bucket
}

output "ecs_cluster_name" {
  description = "Name of the ECS Cluster"
  value       = aws_ecs_cluster.main.name
}
