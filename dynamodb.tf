# Fase 4 — database-per-service para os serviços que persistem estado próprio.
resource "aws_dynamodb_table" "service" {
  for_each = var.dynamodb_services

  name         = "${local.name}-${each.key}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = each.value.partition_key
  range_key    = each.value.sort_key

  attribute {
    name = each.value.partition_key
    type = "S"
  }

  dynamic "attribute" {
    for_each = each.value.sort_key == null ? [] : [each.value.sort_key]
    content {
      name = attribute.value
      type = "S"
    }
  }

  point_in_time_recovery {
    enabled = var.dynamodb_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  deletion_protection_enabled = var.environment == "prod"

  tags = merge(local.tags, {
    Name    = "${local.name}-${each.key}"
    Service = each.key
  })
}
