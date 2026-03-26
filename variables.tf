variable "cluster_name" {
  description = "The name to use for all cluster resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the cluster"
  type        = string
  default     = "t2.micro"
}

variable "min_size" {
  description = "Minimum number of EC2 instances in the Auto Scaling Group"
  type        = number
}

variable "max_size" {
  description = "Maximum number of EC2 instances in the Auto Scaling Group"
  type        = number
}

variable "server_port" {
  description = "Port the web server listens on"
  type        = number
  default     = 8080
}

variable "server_text" {
  description = "Text to display on the web page"
  type        = string
  default     = "Hello from Terraform module"
}

variable "alb_port" {
  description = "Port the ALB listens on"
  type        = number
  default     = 80
}

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}
variable "environment" {
  description = "Environment name for the deployment"
  type        = string
  default     = "dev"
}