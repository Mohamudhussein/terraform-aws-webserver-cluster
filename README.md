# Webserver Cluster Module

This Terraform module creates a reusable web server cluster on AWS using:

- Security groups
- Launch template
- Auto Scaling Group
- Application Load Balancer
- Target group
- Listener

## Inputs

- cluster_name
- instance_type
- min_size
- max_size
- server_port
- server_text
- alb_port
- aws_region

## Outputs

- alb_dns_name
- asg_name
- alb_security_group_id
- instance_security_group_id