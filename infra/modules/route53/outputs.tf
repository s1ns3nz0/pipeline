output "zone_id" {
  description = "Route 53 hosted zone ID"
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "Route 53 name servers"
  value       = aws_route53_zone.this.name_servers
}

output "health_check_id" {
  description = "Route 53 health check ID"
  value       = aws_route53_health_check.app.id
}
