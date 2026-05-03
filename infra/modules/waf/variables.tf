variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the ALB to associate with WAF"
  type        = string
}

variable "rate_limit" {
  description = "Rate limit per 5-minute window per IP"
  type        = number
  default     = 2000
}
