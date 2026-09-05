variable "aws_region" {
  type        = string
  description = "Região AWS"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Prefixo de nomes de recursos"
  default     = "autoservicemanager"
}

variable "environment" {
  type        = string
  description = "Ambiente (dev|homolog|prod)"
  default     = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "single_nat_gateway" {
  type        = bool
  description = "Um NAT (menor custo acadêmico)"
  default     = true
}

variable "db_name" {
  type    = string
  default = "autoservicemanager"
}

variable "db_username" {
  type    = string
  default = "app"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_engine_version" {
  type    = string
  default = "8.0"
}

variable "db_skip_final_snapshot" {
  type        = bool
  description = "true em demo/dev; false em prod"
  default     = true
}

variable "db_allowed_cidr_blocks" {
  type        = list(string)
  description = "Break-glass: CIDRs com ingress 3306. Default vazio — só SG→SG no infra-k8s."
  default     = []
}
