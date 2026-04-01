terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }

    required_version = ">= 1.0"
}

provider "aws" {
    region = var.aws_region
}

variable "aws_region" {
    description = "AWS Region"
    type = string
    default = "us-east-1"
}

variable "project_name" {
    description = "Project Name"
    type = string
    default = "cloudcost-webapp"
}

variable "environment" {
    description = "Environment"
    type = string
    default = "dev"
}

variable "instance_type" {
    description = "EC2 Instance Type"
    type = string
    default = "t3.micro"
}

variable "db_username" {
    description = "Database Username"
    type = string
    default = "admin"
}

variable "db_password" {
    description = "Database Password"
    type = string
    sensitive = true
}




