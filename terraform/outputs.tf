output "ec2_public_ip" {
    description = "Public IP Address of EC2 Instance"
    value = aws_instance.app.public_ip
}

output "rds_endpoint" {
    description = "Endpoint Address of RDS Instance"
    value = aws_db_instance.main.endpoint
}

output "vpc_id" {
    description = "VPC ID"
    value = aws_vpc.main.id
}

output "cloudwatch_dashboard_url" {
  description = "URL to CloudWatch dashboard in AWS console"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.project_name}-dashboard"
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name for Flask app logs"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "ec2_cloudwatch_alarm" {
  description = "Name of EC2 CPU alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "rds_cloudwatch_alarm_cpu" {
  description = "Name of RDS CPU alarm"
  value       = aws_cloudwatch_metric_alarm.rds_cpu_high.alarm_name
}

output "rds_cloudwatch_alarm_storage" {
  description = "Name of RDS storage alarm"
  value       = aws_cloudwatch_metric_alarm.rds_storage_low.alarm_name
}

output "secrets_manager_secret_name" {
  description = "Name of the secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.db_password.name
}

output "secrets_manager_secret_arn" {
  description = "ARN of the secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.db_password.arn
}