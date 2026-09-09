locals {
  name = "${var.project_name}-${var.environment}"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "infra-db"
  }
}

# VPC no stack db para respeitar ordem ADR-008: infra-db apply → infra-k8s apply.
# infra-k8s consome vpc_* + db_* via terraform_remote_state.
module "vpc" {
  source = "./modules/vpc"

  name                 = local.name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
  tags                 = local.tags
}

resource "random_password" "db" {
  length  = 32
  special = false # URL-safe para DATABASE_URL / Prisma
}

module "rds" {
  source = "./modules/rds"

  name                = local.name
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  allowed_cidr_blocks = var.db_allowed_cidr_blocks
  master_username     = var.db_username
  master_password     = random_password.db.result
  database_name       = var.db_name
  instance_class      = var.db_instance_class
  allocated_storage   = var.db_allocated_storage
  engine_version      = var.db_engine_version
  skip_final_snapshot = var.environment == "prod" ? false : var.db_skip_final_snapshot
  deletion_protection = var.environment == "prod"
  tags                = local.tags
}

# Contrato Lambda (DB_SECRET_ARN): host/port/username/password/dbname
# + DATABASE_URL para Prisma / Job migrate
resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name}/db"
  description             = "Credenciais RDS MySQL (Lambda + app)"
  recovery_window_in_days = 0
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host     = module.rds.endpoint
    port     = module.rds.port
    username = var.db_username
    password = random_password.db.result
    dbname   = var.db_name
    engine   = "mysql"
    DATABASE_URL = format(
      "mysql://%s:%s@%s:%s/%s",
      var.db_username,
      random_password.db.result,
      module.rds.endpoint,
      module.rds.port,
      var.db_name,
    )
  })
}
