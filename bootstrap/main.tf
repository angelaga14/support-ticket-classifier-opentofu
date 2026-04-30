# bootstrap/main.tf
# Crea la infraestructura que el proyecto principal necesita:
#   - Bucket S3 + tabla DynamoDB para state remoto
#   - OIDC provider de GitHub
#   - Rol IAM que GHA asume

terraform {
  required_version = ">= 1.8"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # State LOCAL a proposito. Esto es la infra de la infra,
  # no puede vivir en un bucket que aun no existe.
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# State backend: bucket S3 + tabla DynamoDB para locks
# -----------------------------------------------------------------------------

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "state" {
  bucket = "${var.project_name}-state-${random_id.suffix.hex}"

  # No queremos que se borre por accidente. Si quieres destruir el
  # bootstrap, primero pon force_destroy = true y aplica de nuevo.
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "locks" {
  name         = "${var.project_name}-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# -----------------------------------------------------------------------------
# OIDC provider de GitHub
# -----------------------------------------------------------------------------

# Si ya existe en la cuenta (creado por otro proyecto), comenta esto y
# usa data "aws_iam_openid_connect_provider" en su lugar.
# resource "aws_iam_openid_connect_provider" "github" {
#   url             = "https://token.actions.githubusercontent.com"
#   client_id_list  = ["sts.amazonaws.com"]
#   # Thumbprints publicos de GitHub. Han cambiado historicamente; AWS
#   # recomienda incluirlos pero la verificacion la hace por chain ahora.
#   thumbprint_list = [
#     "6938fd4d98bab03faadb97b34396831e3780aea1",
#     "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
#   ]
# }

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# -----------------------------------------------------------------------------
# Rol IAM que GitHub Actions asume
# -----------------------------------------------------------------------------

# Trust policy: solo el repo configurado puede asumir el rol.
# Puedes restringir mas: por branch, por tag, por environment.
data "aws_iam_policy_document" "gha_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    # Audience claim: literal de GitHub OIDC
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Subject claim: limita QUE puede asumir. Permitimos main + cualquier PR.
    # En produccion querrias separar: solo main puede applicar, PRs solo plan.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:pull_request",
      ]
    }
  }
}

resource "aws_iam_role" "gha" {
  name               = "${var.project_name}-gha"
  assume_role_policy = data.aws_iam_policy_document.gha_assume.json
}

# Permisos del rol GHA: para esta DEMO le damos PowerUserAccess.
# En produccion: politica curada con solo lo que tu Tofu necesita
# (lambda:*, apigateway:*, dynamodb:*, s3:*, iam:CreateRole, etc).
resource "aws_iam_role_policy_attachment" "gha_power" {
  role       = aws_iam_role.gha.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# PowerUserAccess no incluye iam:*. Lo necesitamos porque el proyecto
# principal crea roles para la Lambda. Esta es una politica restringida
# a IAM solo para roles con el prefijo del proyecto.
data "aws_iam_policy_document" "gha_iam" {
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
    ]
    resources = [
      "arn:aws:iam::*:role/${var.main_project_name}-*",
      "arn:aws:iam::*:policy/${var.main_project_name}-*",
    ]
  }
}

resource "aws_iam_policy" "gha_iam" {
  name   = "${var.project_name}-gha-iam"
  policy = data.aws_iam_policy_document.gha_iam.json
}

resource "aws_iam_role_policy_attachment" "gha_iam" {
  role       = aws_iam_role.gha.name
  policy_arn = aws_iam_policy.gha_iam.arn
}
