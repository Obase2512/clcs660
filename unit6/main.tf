data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ==========================================
# NETWORKING (VPC, Subnets, Gateways, Routes)
# ==========================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "${local.name_prefix}-public-${count.index}" })
}

resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags                    = merge(local.common_tags, { Name = "${local.name_prefix}-private-${count.index}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rt" })
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  depends_on = [aws_internet_gateway.igw]
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(local.common_tags, { Name = "${local.name_prefix}-nat" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-private-rt" })
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ==========================================
# SECURITY GROUPS (Strict Chaining)
# ==========================================

resource "aws_security_group" "alb" {
  name   = "${local.name_prefix}-alb-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })
}

resource "aws_security_group" "web" {
  name   = "${local.name_prefix}-ec2-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ec2-sg" })
}

resource "aws_security_group" "lambda" {
  vpc_id = aws_vpc.main.id
  name   = "${local.name_prefix}-lambda-sg"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-lambda-sg" })
}

# ==========================================
# APPLICATION LOAD BALANCER
# ==========================================

resource "aws_lb" "web" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "web" {
  name     = "${local.name_prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ==========================================
# KMS + S3 (Data Protection)
# ==========================================

resource "aws_kms_key" "main" {
  description             = "KMS for AI artifacts"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = merge(local.common_tags, { Name = "${local.name_prefix}-kms" })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.name_prefix}-kms"
  target_key_id = aws_kms_key.main.key_id
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "ngembane-ai-opt-dev-${data.aws_caller_identity.current.account_id}-artifacts"
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-s3" })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==========================================
# ASG + LAUNCH TEMPLATE
# ==========================================

resource "aws_launch_template" "web" {
  name_prefix            = "${local.name_prefix}-web-"
  image_id               = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.ec2_instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y && dnf install -y nginx
    systemctl enable --now nginx
    echo '<h1>Ngembane: AI-Enhanced Cloud Automation for Intelligent Resource Optimization - Optimized by SageMaker DeepAR</h1>' > /usr/share/nginx/html/index.html
  EOF
  )
  metadata_options {
  http_tokens = "required"
}
  tags = local.common_tags
}

resource "aws_autoscaling_group" "asg" {
  name                = "${local.name_prefix}-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.web.arn]
  min_size            = 1
  max_size            = 8
  desired_capacity    = 2
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
  tag {
    key                 = "OptimizationTarget"
    value               = "true"
    propagate_at_launch = true
  }
}

# Predictive Scaling Policy (unchanged)
resource "aws_autoscaling_policy" "predictive" {
  name                   = "${local.name_prefix}-predictive-policy"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  policy_type            = "PredictiveScaling"
  predictive_scaling_configuration {
    mode = "ForecastAndScale"
    metric_specification { 
      target_value = 70
      predefined_metric_pair_specification {
      predefined_metric_type = "ASGCPUUtilization"
      }
    }
  }
}

# ==========================================
# IAM + LAMBDA + EVENTBRIDGE
# ==========================================

resource "aws_iam_role" "lambda_role" {
  name               = "${local.name_prefix}-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_logs" {
  name   = "${local.name_prefix}-lambda-logs"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${local.name_prefix}-optimizer:*"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_cloudwatch" {
  name   = "${local.name_prefix}-lambda-cloudwatch"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["cloudwatch:GetMetricData"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_sagemaker" {
  name   = "${local.name_prefix}-lambda-sagemaker"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sagemaker-runtime:InvokeEndpoint"]
      Resource = "arn:aws:sagemaker:*:*:endpoint/demand-forecast-endpoint"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_autoscaling" {
  name   = "${local.name_prefix}-lambda-autoscaling"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["autoscaling:DescribeAutoScalingGroups"], Resource = "*" },
      { Effect = "Allow", Action = ["autoscaling:PutScalingPolicy"], Resource = aws_autoscaling_group.asg.arn }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_ddb_sns" {
  name   = "${local.name_prefix}-lambda-ddb-sns"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:GetItem"], Resource = aws_dynamodb_table.recommendations.arn },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = aws_sns_topic.alerts.arn }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/optimizer.py"
  output_path = "${path.module}/optimizer.zip"
}

resource "aws_lambda_function" "optimizer" {
  function_name = "${local.name_prefix}-optimizer"
  role          = aws_iam_role.lambda_role.arn
  handler       = "optimizer.lambda_handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda_zip.output_path
  timeout       = 300
  memory_size   = 512

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SAGEMAKER_ENDPOINT = "demand-forecast-endpoint"
      ASG_NAME           = aws_autoscaling_group.asg.name
      SNS_TOPIC_ARN      = aws_sns_topic.alerts.arn
      DDB_TABLE          = aws_dynamodb_table.recommendations.name
    }
  }
}

resource "aws_cloudwatch_event_rule" "daily" {
  name                = "${local.name_prefix}-daily"
  schedule_expression = "cron(0 2 * * ? *)"
}

resource "aws_cloudwatch_event_target" "target" {
  rule      = aws_cloudwatch_event_rule.daily.name
  target_id = "Optimizer"
  arn       = aws_lambda_function.optimizer.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.optimizer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily.arn
}

# ==========================================
# SNS & DYNAMODB (Notifications & Storage)
# ==========================================

resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_dynamodb_table" "recommendations" {
  name         = "${local.name_prefix}-recommendations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "instance_id"
  attribute {
    name = "instance_id"
    type = "S"
  }
}

# ==========================================
# AWS CONFIG SETUP (Governance)
# ==========================================

resource "aws_iam_role" "config_role" {
  name               = "${local.name_prefix}-config-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_s3_bucket_policy" "config_bucket_policy" {
  bucket = aws_s3_bucket.artifacts.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck",
        Effect = "Allow",
        Principal = { Service = "config.amazonaws.com" },
        Action = "s3:GetBucketAcl",
        Resource = aws_s3_bucket.artifacts.arn
      },
      {
        Sid    = "AWSConfigBucketDelivery",
        Effect = "Allow",
        Principal = { Service = "config.amazonaws.com" },
        Action = "s3:PutObject",
        Resource = "${aws_s3_bucket.artifacts.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*",
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      }
    ]
  })
}

resource "aws_config_configuration_recorder" "main" {
  name     = "${local.name_prefix}-config-recorder"
  role_arn = aws_iam_role.config_role.arn
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${local.name_prefix}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.artifacts.id
  snapshot_delivery_properties { delivery_frequency = "TwentyFour_Hours" }
  depends_on     = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_config_rule" "encrypted_volumes" {
  name = "${local.name_prefix}-encrypted-volumes"
  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }
  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "iam_policy_no_admin" {
  name = "${local.name_prefix}-iam-no-admin"
  source {
    owner             = "AWS"
    source_identifier = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS"
  }
  depends_on = [aws_config_configuration_recorder.main]
}
