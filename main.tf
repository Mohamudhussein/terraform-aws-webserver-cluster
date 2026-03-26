terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Security group for the ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow HTTP inbound"
    from_port   = var.alb_port
    to_port     = var.alb_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-alb-sg"
  }
}

resource "aws_security_group" "instance" {
  name        = "${var.cluster_name}-instance-sg"
  description = "Security group for EC2 instances"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Allow traffic from ALB to EC2 instances"
    from_port       = var.server_port
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-instance-sg"
  }
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.cluster_name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y python3
              mkdir -p /var/www/html
              cat > /var/www/html/index.html <<HTML
              <html>
                <head><title>${var.cluster_name}</title></head>
                <body>
                  <p>Environment: ${var.environment}</p>
                  <h1>${var.server_text}</h1>
                  <p>Cluster: ${var.cluster_name}</p>
                </body>
              </html>
              HTML
              cd /var/www/html
              python3 -m http.server ${var.server_port} &
              EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.cluster_name}-instance"
    }
  }
}

resource "aws_lb" "this" {
  name               = substr(replace(var.cluster_name, "/[^a-zA-Z0-9-]/", "-"), 0, 32)
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]

  tags = {
    Name = "${var.cluster_name}-alb"
  }
}

resource "aws_lb_target_group" "this" {
  name     = substr("${var.cluster_name}-tg", 0, 32)
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.cluster_name}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.alb_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_autoscaling_group" "this" {
  name                = "${var.cluster_name}-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.min_size
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.this.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-asg-instance"
    propagate_at_launch = true
  }
}