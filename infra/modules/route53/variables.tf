variable "domain_name" {
  description = "Domain name for Route 53 hosted zone"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name for alias record"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB canonical hosted zone ID"
  type        = string
}
