# =============================================================================
# Production Environment Configuration
# =============================================================================

aws_region   = "us-east-1"
project_name = "pipeline"
environment  = "prod"

# --- Networking ---
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# --- DNS / TLS ---
domain_name         = "app.example.com"
acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/REPLACE-ME"

# --- ECS ---
ecs_instance_type    = "t3.large"
ecs_min_size         = 2
ecs_max_size         = 8
ecs_desired_capacity = 3
container_port       = 8080
container_cpu        = 512
container_memory     = 1024
service_desired_count = 3

# --- RDS ---
db_instance_class    = "db.r6g.large"
db_allocated_storage = 100
db_name              = "pipeline"
# db_username is provided via TF_VAR_db_username env var or -var flag (never in tfvars)

# --- WAF ---
waf_rate_limit = 2000
