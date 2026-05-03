variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "domain_name" {
  description = "Domain name for Route 53 and ACM"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS"
  type        = string
}

variable "ecs_instance_type" {
  description = "EC2 instance type for ECS cluster"
  type        = string
  default     = "t3.medium"
}

variable "ecs_min_size" {
  description = "Minimum number of ECS instances"
  type        = number
  default     = 2
}

variable "ecs_max_size" {
  description = "Maximum number of ECS instances"
  type        = number
  default     = 6
}

variable "ecs_desired_capacity" {
  description = "Desired number of ECS instances"
  type        = number
  default     = 2
}

variable "container_image" {
  description = "Container image URI (populated after first ECR push)"
  type        = string
  default     = ""
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "container_cpu" {
  description = "CPU units for container"
  type        = number
  default     = 512
}

variable "container_memory" {
  description = "Memory in MiB for container"
  type        = number
  default     = 1024
}

variable "service_desired_count" {
  description = "Desired count for ECS service"
  type        = number
  default     = 2
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Name of the database"
  type        = string
}

variable "db_username" {
  description = "Master username for RDS (password stored in Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "waf_rate_limit" {
  description = "WAF rate limit per 5-minute window per IP"
  type        = number
  default     = 2000
}
