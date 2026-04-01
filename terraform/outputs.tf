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

