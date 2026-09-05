#!/usr/bin/env bash
# Bootstrap one-shot do state remoto (ADR-008) + bucket policy least-privilege.
# Uso:
#   STATE_ADMIN_ROLE_ARN=arn:aws:iam::ACCOUNT:role/github-oidc-infra-db \
#     ./scripts/bootstrap-state.sh [region]
#
# STATE_ADMIN_ROLE_ARN (obrigatório para policy): role OIDC CI e/ou admin que
# pode ler/escrever o state (contém senha RDS — tier-0).
set -euo pipefail

REGION="${1:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="autoservicemanager-tfstate-${ACCOUNT_ID}"
TABLE="autoservicemanager-tflock"
STATE_ADMIN_ROLE_ARN="${STATE_ADMIN_ROLE_ARN:-}"

echo "Account: ${ACCOUNT_ID}"
echo "Region:  ${REGION}"
echo "Bucket:  ${BUCKET}"
echo "Lock:    ${TABLE}"

if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "Bucket já existe: ${BUCKET}"
else
  if [[ "${REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi
  aws s3api put-bucket-versioning \
    --bucket "${BUCKET}" \
    --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption \
    --bucket "${BUCKET}" \
    --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  aws s3api put-public-access-block \
    --bucket "${BUCKET}" \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  echo "Bucket criado: ${BUCKET}"
fi

if [[ -z "${STATE_ADMIN_ROLE_ARN}" ]]; then
  echo "AVISO: STATE_ADMIN_ROLE_ARN não definido — bucket policy NÃO aplicada."
  echo "Reexecute com STATE_ADMIN_ROLE_ARN=arn:aws:iam::${ACCOUNT_ID}:role/<oidc-ci-role>"
else
  # Deny object ops unless principal is the CI/admin role (tier-0: state has DB password).
  POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyStateObjectAccessExceptAdminRoles",
      "Effect": "Deny",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObjectVersion",
        "s3:DeleteObjectVersion"
      ],
      "Resource": "arn:aws:s3:::${BUCKET}/*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalArn": [
            "${STATE_ADMIN_ROLE_ARN}"
          ]
        }
      }
    },
    {
      "Sid": "AllowAdminRoleListBucket",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${STATE_ADMIN_ROLE_ARN}"
      },
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:ListBucketVersions"
      ],
      "Resource": "arn:aws:s3:::${BUCKET}"
    },
    {
      "Sid": "AllowAdminRoleObjectRW",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${STATE_ADMIN_ROLE_ARN}"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObjectVersion",
        "s3:DeleteObjectVersion"
      ],
      "Resource": "arn:aws:s3:::${BUCKET}/*"
    }
  ]
}
EOF
)
  aws s3api put-bucket-policy --bucket "${BUCKET}" --policy "${POLICY}"
  echo "Bucket policy aplicada (allow: ${STATE_ADMIN_ROLE_ARN})"
fi

if aws dynamodb describe-table --table-name "${TABLE}" --region "${REGION}" >/dev/null 2>&1; then
  echo "Tabela DynamoDB já existe: ${TABLE}"
else
  aws dynamodb create-table \
    --table-name "${TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"
  aws dynamodb wait table-exists --table-name "${TABLE}" --region "${REGION}"
  echo "Tabela criada: ${TABLE}"
fi

cat <<EOF

Próximos passos:
  cp backend.hcl.example backend.hcl
  # edite bucket = "${BUCKET}"
  # keys: db/homolog/terraform.tfstate | db/prod/terraform.tfstate
  terraform init -backend-config=backend.hcl
  TF_VAR_environment=homolog terraform plan
  TF_VAR_environment=homolog terraform apply

EOF
