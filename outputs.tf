# Contrato mínimo ADR-008 (consumido por infra-k8s via remote_state)

output "db_endpoint" {
  description = "Hostname RDS MySQL"
  value       = module.rds.endpoint
}

output "db_port" {
  description = "Porta MySQL"
  value       = module.rds.port
}

output "db_sg_id" {
  description = "Security group do RDS (adicionar regras EKS/Lambda no infra-k8s)"
  value       = module.rds.security_group_id
}

output "db_secret_arn" {
  description = "ARN do secret JSON (host/port/username/password/dbname + DATABASE_URL)"
  value       = aws_secretsmanager_secret.db.arn
  sensitive   = true
}

output "db_name" {
  value = var.db_name
}

output "db_username" {
  value = var.db_username
}

# Networking compartilhado (necessário porque VPC vive neste stack)

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}
