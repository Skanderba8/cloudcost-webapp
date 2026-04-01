resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_1" {
  vpc_id       = aws_vpc.main.id
  cidr_block   = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-subnet-public-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_2" {
  vpc_id       = aws_vpc.main.id
  cidr_block   = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-subnet-public-2"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_1" {
  vpc_id       = aws_vpc.main.id
  cidr_block   = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project_name}-subnet-private-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_2" {
  vpc_id       = aws_vpc.main.id
  cidr_block   = "10.0.4.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name        = "${var.project_name}-subnet-private-2"
    Environment = var.environment
  }
}
