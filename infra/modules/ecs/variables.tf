variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS instances"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "min_size" {
  description = "ASG minimum size"
  type        = number
}

variable "max_size" {
  description = "ASG maximum size"
  type        = number
}

variable "desired_capacity" {
  description = "ASG desired capacity"
  type        = number
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "container_image" {
  description = "Container image URI"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "container_cpu" {
  description = "CPU units for container"
  type        = number
}

variable "container_memory" {
  description = "Memory in MiB for container"
  type        = number
}

variable "service_desired_count" {
  description = "Desired count for ECS service"
  type        = number
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name for ECS instances"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret for DB credentials"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
