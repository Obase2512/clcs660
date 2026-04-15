output "asg_name" {
  description = "Name of the Auto Scaling Group used for optimization"
  value       = aws_autoscaling_group.asg.name
}

output "demo_app_url" {
  description = "Public URL for the demo application (check EC2 console for public IPs)"
  value       = "http://<ASG-instances-public-IP>:80 (refresh after launch)"
}

output "ec2_public_ip" {
  description = "Public IP of the first instance (for quick testing)"
  value       = "Check AWS Console → EC2 → Instances"
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.recommendations.name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}

output "sagemaker_endpoint" {
  description = "SageMaker endpoint created by sagemaker-train.py"
  value       = "demand-forecast-endpoint"
}

output "alb_dns" {
  value = aws_lb.web.dns_name
}