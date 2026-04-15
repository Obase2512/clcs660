variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key" {
  description = "AWS access key"
  type        = string
  default     = "ASIA2JFJRJ7VNQ2DERGE"
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true
  default     = "XxwIOgpVu5cb0fm27PJkJW8oRQGnIuNHcI2N6W1f"
}

variable "aws_session_token" {
  description = "AWS session token for temporary credentials"
  type        = string
  sensitive   = true
  default     = "IQoJb3JpZ2luX2VjENP//////////wEaCXVzLWVhc3QtMSJGMEQCIEBn37HSoKHpY/vp87UOj24yitBMGYMg88cX50gPGg/IAiAMY5UMIKlpKcfMjTN/5cby6g7YAv2ASFSYj/4x9XhQpCqYAwib//////////8BEAAaDDcwNjg3NzY3MzQ1MCIMbBNPnGLRYGDMNYHPKuwCRUTQRgSzz0EqLat3LiKtazAAKYiZKg6RsLw3XNxXeQVWuhWy8dxn3EXkypR5VTY7L2RR8x+4pkPvntB3XEZkzI7F1SBw+iI4EyjFvCQcaCJ2hhVJUNWMGWhQx6CSOg2Uc5x9l2c4DDQajoW6IM7i04qMqm7hY+h1Yvx/3IYLxuQDU4qEYsjvKVIvECvBUrhflZJN6l0/qgUb3UTV42C+j5qWpuI6gTisbdgkMS5FGCK//c1UX8BKAx3Btg2LNHB/PC/eprR3fQMkZKDM3/Wwcne1Vq7yxUVlkQ4QzdOxBoB+SQPTxsJI5RNbOhLWuoOQ4stezDTq/IweYvrqzPQQk1Lo6mpT0jxKmdIWzGaHbz3KG3qYqzgNTidh02eXABRmqW7y2ps8TzCXtnFWQbJVJlQMg+oFrIZw3vm1E0k7S5PArOviZHZNF+1hytRcZcClT+5Xzjzj3qbMUJjTcFwIq0U6ntDvqA1PiTLpLDDK5fvOBjqlAYUPK/6Yr8nFAkMin84NFnJUfkP5MQgwnxanircgcMuWVWQ4Yg37n6EV+ckrpeDZsoYl03V6eUcBV/FOkd5nJOMnm6xx8RMD6HldXFgnVLgnS2656X3bhjSsVI1033Xs7FV0Ho4bmcmq/2zHOeGtviJa5+RldPtHc79beZs1V8pVJ5uSFS+K2wkLTlusPrU1q49E5Q+mfI4o9C1zSRzvMg5pgewacw=="
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
