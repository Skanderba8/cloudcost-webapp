# Launch Template - blueprint for creating EC2 instances
resource "aws_launch_template" "app" {
  name          = "${var.project_name}-lt"
  image_id      = "ami-0f989e78a92d5f420"
  instance_type = var.instance_type
  key_name      = "cloudcost-keypair"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker
    systemctl start docker
    systemctl enable docker

    dnf install -y amazon-cloudwatch-agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 -s -c default

    docker pull skander212/cloudcost-backend:latest
    docker run -d \
      --name cloudcost-backend \
      --restart unless-stopped \
      --log-driver=awslogs \
      --log-opt awslogs-group=/cloudcost/app \
      --log-opt awslogs-region=${var.aws_region} \
      --log-opt tag="{{.Name}}/{{.ID}}" \
      -p 5000:5000 \
      -e DB_SECRET_NAME="${aws_secretsmanager_secret.db_password.name}" \
      -e DB_HOST="${aws_db_instance.main.address}" \
      -e DB_NAME="cloudcost" \
      -e DB_USER="${var.db_username}" \
      skander212/cloudcost-backend:latest
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project_name}-asg-instance"
      Environment = var.environment
      Project     = var.project_name
    }
  }
}

# Application Load Balancer
resource "aws_lb" "app" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Target Group - ALB sends traffic here, health checks EC2 on /tasks
resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/tasks"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-tg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Listener - ALB listens on port 80 and forwards to target group
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  vpc_zone_identifier = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns   = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
}

# Scale out - add instance when CPU above 70%
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.project_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

# Scale in - remove instance when CPU below 30%
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.project_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.app.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}