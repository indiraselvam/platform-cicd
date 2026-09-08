# ---------------------------------------------------------------------------
# GitHub Actions -> AWS federation via OIDC. Replaces static AWS access
# keys in GitHub secrets (and replaces whatever credential a Jenkins agent
# was holding) with short-lived, per-workflow-run tokens.
#
# One provider per AWS account (create this once, in global/), one role
# per environment so a compromised/misconfigured dev workflow can't touch
# the production role.
# ---------------------------------------------------------------------------

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = {
    ManagedBy = "Terraform"
  }
}

# ---------------------------------------------------------------------------
# One role per environment. subject_claims controls exactly which repo,
# branch, and (for the terraform apply role) environment name is allowed
# to assume it — this is the whole security boundary, get it tight.
#
# Examples of what var.environments["production"].subject_claims should
# contain:
#   "repo:indiraselvam/terraform:environment:production"   (apply role — only
#     runs that went through the GitHub Environment approval gate)
#   "repo:indiraselvam/terraform:ref:refs/heads/main"       (plan-only role, any
#     PR building against main)
#   "repo:indiraselvam/platform-cicd:ref:refs/heads/main"   (this repo's own
#     workflows, e.g. an argocd diff job)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "github_actions" {
  for_each = var.environments

  name = "github-actions-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = each.value.subject_claims
        }
      }
    }]
  })

  max_session_duration = 3600

  tags = {
    Environment = each.key
    ManagedBy   = "Terraform"
    Purpose     = "github-actions-oidc"
  }
}

# Scope this down further per environment in your account — this starter
# policy covers what terraform plan/apply needs for the modules in this
# repo (EKS, VPC, IAM, KMS, S3, EC2, Helm-managed add-ons) plus the S3
# state backend. It is deliberately NOT AdministratorAccess.
resource "aws_iam_role_policy" "terraform_state" {
  for_each = var.environments

  name = "terraform-state-access"
  role = aws_iam_role.github_actions[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "StateBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.tfstate_bucket}",
          "arn:aws:s3:::${var.tfstate_bucket}/eks-poc/${each.key}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "infra_provisioning" {
  for_each = var.environments

  role       = aws_iam_role.github_actions[each.key].name
  policy_arn = each.value.provisioning_policy_arn
}
