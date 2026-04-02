resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
      Project     = var.project_name

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
      Project     = var.project_name

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
      Project     = var.project_name

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
      Project     = var.project_name

  }
}

resource "aws_subnet" "private_2" {
  vpc_id       = aws_vpc.main.id
  cidr_block   = "10.0.4.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name        = "${var.project_name}-subnet-private-2"
    Environment = var.environment
      Project     = var.project_name

  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
      Project     = var.project_name

  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
      Project     = var.project_name

  }

}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ec2" {
    name = "${var.project_name}-ec2-sg"
    description = "EC2 Security Group"
    vpc_id = aws_vpc.main.id

    ingress {
        description = "HTTP from internet"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "Flask app port"
        from_port = 5000
        to_port = 5000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH access"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["196.176.234.139/32"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name        = "${var.project_name}-ec2-sg"
        Environment = var.environment
          Project     = var.project_name

    }
}
resource "aws_security_group" "rds" {
    name = "${var.project_name}-rds-sg"
    description = "RDS Security Group"
    vpc_id = aws_vpc.main.id
    ingress {
        description = "Postgres from EC2 only"
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        security_groups = [aws_security_group.ec2.id]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1" 
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name        = "${var.project_name}-rds-sg"
        Environment = var.environment
          Project     = var.project_name

    }
}

resource "aws_db_subnet_group" "main" {
    name = "${var.project_name}-rds-subnet-group"
    subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
    tags = {
        Name        = "${var.project_name}-rds-subnet-group"
        Environment = var.environment
          Project     = var.project_name

    }
}

resource "aws_db_instance" "main" {
    identifier = "${var.project_name}-db"
    engine = "postgres"
    engine_version = "15"
    allocated_storage = 20
    instance_class = "db.t3.micro"

    db_name = "cloudcost"
    username = var.db_username
    password = var.db_password

    db_subnet_group_name = aws_db_subnet_group.main.name
    vpc_security_group_ids = [aws_security_group.rds.id]

    skip_final_snapshot = true
    deletion_protection = false
    publicly_accessible = false
    multi_az = false

    tags = {
        Name        = "${var.project_name}-db"
        Environment = var.environment
          Project     = var.project_name

    }
}

resource "aws_instance" "app" {
  ami                    = "ami-0f989e78a92d5f420"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = "cloudcost-keypair"
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y docker
              systemctl start docker
              systemctl enable docker

              # install CloudWatch agent
              dnf install -y amazon-cloudwatch-agent

              # start CloudWatch agent with default config
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
                -a fetch-config \
                -m ec2 \
                -s \
                -c default

              docker pull python:3.11-slim
              EOF

  tags = {
    Name        = "${var.project_name}-app-server"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM role so EC2 can write to CloudWatch
resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "${var.project_name}-ec2-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-cloudwatch-role"
    Environment = var.environment
    Project     = var.project_name
  }
}
# Allow EC2 to read secrets from Secrets Manager
resource "aws_iam_role_policy" "secrets_policy" {
  name = "${var.project_name}-secrets-policy"
  role = aws_iam_role.ec2_cloudwatch_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })
}
# Attach AWS managed CloudWatch policy to the role
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance profile wraps the role so EC2 can use it
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_cloudwatch_role.name

  tags = {
    Name        = "${var.project_name}-ec2-profile"
    Environment = var.environment
    Project     = var.project_name
  }
}