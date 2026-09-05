# autoservicemanager-infra-db

Terraform do stack **dados** (Fase 3): VPC compartilhada, RDS MySQL 8, Secrets Manager e state remoto S3+DynamoDB (ADR-008).

Este diretório vive no monorepo até a cisão do repo GitHub `autoservicemanager-infra-db`.

**Docs:** [RFC-002](../docs/architecture/rfc-002-mysql-rds.md) · [ADR-008](../docs/architecture/adr-008-terraform-remote-state.md) · [ER](../docs/architecture/er-diagram.md) · [runbook](../docs/runbook.md)

## Escopo

| Recurso | Detalhe |
|---------|---------|
| VPC | Subnets públicas/privadas + NAT único (custo acadêmico) |
| RDS MySQL 8 | `db.t3.micro`, privado, storage criptografado |
| SG RDS | **Sem ingress por default**; EKS/Lambda só via regras SG→SG no `infra-k8s` |
| Secrets Manager | `${project}-${env}/db` — JSON compatível com Lambda `DB_SECRET_ARN` |
| State | `db/homolog/terraform.tfstate` \| `db/prod/terraform.tfstate` |

**Por que VPC aqui?** Ordem de apply ADR-008 é `infra-db` → `infra-k8s`. O RDS precisa de subnets; o stack k8s consome `vpc_*` + `db_*` via `terraform_remote_state`.

**State = tier-0:** o tfstate contém a senha RDS. Leitura do objeto S3 = posse da credencial. Bootstrap aplica bucket policy least-privilege.

## Contrato de outputs (ADR-008)

| Output | Consumidor |
|--------|------------|
| `db_endpoint` | Lambda, app, ConfigMaps |
| `db_port` | Security groups |
| `db_sg_id` | Regras de ingress EKS/Lambda (SG→SG) |
| `db_secret_arn` | IRSA / env Lambda e Job migrate |
| `vpc_id`, `private_subnet_ids`, `public_subnet_ids`, `vpc_cidr` | Stack `infra-k8s` |

**Nota:** após adicionar outputs (`db_sg_id`, `db_port`), re-aplique este stack para atualizar o state remoto antes do `infra-k8s`.

Formato do secret (`db_secret_arn`):

```json
{
  "host": "...",
  "port": 3306,
  "username": "app",
  "password": "...",
  "dbname": "autoservicemanager",
  "engine": "mysql",
  "DATABASE_URL": "mysql://app:...@host:3306/autoservicemanager"
}
```

## Pré-requisitos

- Terraform >= 1.5
- AWS CLI autenticado
- Bootstrap do state (uma vez por conta) com role OIDC/admin:

```bash
chmod +x scripts/bootstrap-state.sh
STATE_ADMIN_ROLE_ARN=arn:aws:iam::ACCOUNT:role/github-oidc-infra-db \
  ./scripts/bootstrap-state.sh us-east-1
```

## Apply local

```bash
cp backend.hcl.example backend.hcl
# edite ACCOUNT_ID e key (homolog|prod)
cp terraform.tfvars.example terraform.tfvars

terraform init -backend-config=backend.hcl
TF_VAR_environment=homolog terraform plan
TF_VAR_environment=homolog terraform apply
```

Break-glass (não usar em CI): `TF_VAR_db_allowed_cidr_blocks='["10.0.0.0/16"]'`.

Sem remote state (só validação):

```bash
terraform init -backend=false
terraform validate
```

## CI/CD (OIDC)

Workflow monorepo: [`.github/workflows/infra-db-ci-cd.yml`](../.github/workflows/infra-db-ci-cd.yml)

| Evento | Ação |
|--------|------|
| PR (`infra-db/**`) | `fmt` + `init -backend=false` + `validate` — **sem AWS / OIDC** |
| Push `develop` | OIDC → `plan -out=tfplan` → `apply tfplan`; key `db/homolog/`; `TF_VAR_environment=homolog` |
| Push `master` | Idem; key `db/prod/`; `TF_VAR_environment=prod` |

Plan com state real **só pós-merge** (mesmo padrão de [`auth-lambda-ci-cd.yml`](../.github/workflows/auth-lambda-ci-cd.yml)).

Secrets GitHub: `AWS_ROLE_ARN` (role OIDC com permissões RDS/VPC/Secrets + S3/DynamoDB do state — ADR-009). Variável opcional: `TF_STATE_BUCKET`.

## Destroy

```bash
TF_VAR_environment=homolog terraform destroy
```

Ordem global: destruir **`infra-k8s` primeiro**, depois **`infra-db`**.

## Próximo todo

Concluído: [`infra-k8s/`](../infra-k8s/) — ver [docs/infrastructure/repo-infra-k8s.md](../docs/infrastructure/repo-infra-k8s.md). Seguinte no plano: `observability`.
