resource "aws_route53_zone" "this" {
  name = var.domain_name
  tags = { Name = var.domain_name }
}

# --- A Record (alias to ALB) ---
resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# --- Health Check ---
resource "aws_route53_health_check" "app" {
  fqdn              = var.domain_name
  port               = 443
  type               = "HTTPS"
  resource_path      = "/actuator/health"
  failure_threshold  = 3
  request_interval   = 30

  tags = { Name = "${var.domain_name}-health-check" }
}
