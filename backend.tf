# Backend remoto (ADR-008). Valores via `terraform init -backend-config=backend.hcl`
# Bootstrap: scripts/bootstrap-state.sh

terraform {
  backend "s3" {
    # bucket         = "autoservicemanager-tfstate-<account-id>"
    # key            = "db/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "autoservicemanager-tflock"
    # encrypt        = true
  }
}
