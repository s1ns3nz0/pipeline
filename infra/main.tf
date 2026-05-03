locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  name_prefix    = local.name_prefix
  s3_bucket_arn  = module.s3.bucket_arn
  ecr_repo_arn   = module.ecr.repository_arn
  aws_region     = var.aws_region
}

# -----------------------------------------------------------------------------
# ECR
# -----------------------------------------------------------------------------
module "ecr" {
  source = "./modules/ecr"

  name_prefix = local.name_prefix
}

# -----------------------------------------------------------------------------
# ALB
# -----------------------------------------------------------------------------
module "alb" {
  source = "./modules/alb"

  name_prefix         = local.name_prefix
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  acm_certificate_arn = var.acm_certificate_arn
  container_port      = var.container_port
  alb_log_bucket      = module.s3.log_bucket_name
}

# -----------------------------------------------------------------------------
# ECS (EC2 launch type)
# -----------------------------------------------------------------------------
module "ecs" {
  source = "./modules/ecs"

  name_prefix            = local.name_prefix
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  instance_type          = var.ecs_instance_type
  min_size               = var.ecs_min_size
  max_size               = var.ecs_max_size
  desired_capacity       = var.ecs_desired_capacity
  target_group_arn       = module.alb.target_group_arn
  container_image        = var.container_image != "" ? var.container_image : "${module.ecr.repository_url}:latest"
  container_port         = var.container_port
  container_cpu          = var.container_cpu
  container_memory       = var.container_memory
  service_desired_count  = var.service_desired_count
  execution_role_arn     = module.iam.ecs_execution_role_arn
  task_role_arn          = module.iam.ecs_task_role_arn
  instance_profile_name  = module.iam.ecs_instance_profile_name
  alb_security_group_id  = module.alb.security_group_id
  db_secret_arn          = module.rds.db_secret_arn
  aws_region             = var.aws_region
}

# -----------------------------------------------------------------------------
# RDS MySQL
# -----------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_class     = var.db_instance_class
  allocated_storage  = var.db_allocated_storage
  db_name            = var.db_name
  db_username        = var.db_username
  ecs_security_group_id = module.ecs.ecs_instances_security_group_id
}

# -----------------------------------------------------------------------------
# S3 (documents + logging)
# -----------------------------------------------------------------------------
module "s3" {
  source = "./modules/s3"

  name_prefix = local.name_prefix
}

# -----------------------------------------------------------------------------
# WAF
# -----------------------------------------------------------------------------
module "waf" {
  source = "./modules/waf"

  name_prefix  = local.name_prefix
  alb_arn      = module.alb.alb_arn
  rate_limit   = var.waf_rate_limit
}

# -----------------------------------------------------------------------------
# Route 53
# -----------------------------------------------------------------------------
module "route53" {
  source = "./modules/route53"

  domain_name    = var.domain_name
  alb_dns_name   = module.alb.alb_dns_name
  alb_zone_id    = module.alb.alb_zone_id
}
