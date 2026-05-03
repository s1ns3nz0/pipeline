variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for HTTPS"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
}

variable "alb_log_bucket" {
  description = "S3 bucket name for ALB access logs"
  type        = string
}
