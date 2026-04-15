variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key" {
  description = "AWS access key"
  type        = string
# default     = "your_aws_access_key"
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true
# default     = "your_aws_secret_key"
}

variable "aws_session_token" {
  description = "AWS session token for temporary credentials"
  type        = string
  sensitive   = true
# default     = "your_aws_session_token"
  }

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "Ngembane-ai-optimization"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "ec2_instance_type" {
  description = "EC2 instance type for the demo application"
  type        = string
  default     = "t3.micro"
}

variable "notification_email" {
  description = "Email address for SNS notification subscription"
  type        = string
  default     = "nobase@student.umgc.edu"
}

variable "lookback_days" {
  description = "Number of days of CloudWatch history to analyze"
  type        = number
  default     = 7
}

variable "cpu_low_threshold" {
  description = "Average CPU utilization threshold for downsize recommendation"
  type        = number
  default     = 20
}

variable "cpu_high_threshold" {
  description = "Average CPU utilization threshold for upsize recommendation"
  type        = number
  default     = 80
}

variable "schedule_expression" {
  description = "EventBridge schedule for analysis"
  type        = string
  default     = "rate(1 day)"
}
