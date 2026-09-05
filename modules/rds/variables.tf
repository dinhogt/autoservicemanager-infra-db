variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDRs temporários (ex.: VPC). Preferir regras SG→SG no infra-k8s."
  default     = []
}

variable "database_name" {
  type    = string
  default = "autoservicemanager"
}

variable "master_username" {
  type = string
}

variable "master_password" {
  type      = string
  sensitive = true
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "engine_version" {
  type    = string
  default = "8.0"
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "deletion_protection" {
  type        = bool
  description = "Habilitar em prod para evitar destroy acidental"
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
