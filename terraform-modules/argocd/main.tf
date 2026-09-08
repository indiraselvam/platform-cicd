# ---------------------------------------------------------------------------
# ArgoCD, installed the same way as modules/alb-controller and
# modules/karpenter in this stack: Helm via the helm provider, IRSA for
# anything that needs AWS permissions, deployed per environment cluster.
#
# This module installs ArgoCD itself only. It does NOT create any
# Application/AppProject resources — those live in the platform-cicd repo
# as plain YAML and are applied once via scripts/bootstrap.sh, after which
# ArgoCD manages itself (app-of-apps) and Terraform never touches them
# again. Keeping that split avoids Terraform and ArgoCD fighting over the
# same resources.
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# IRSA role for the ArgoCD repo-server / applicationset-controller to pull
# from a private GitOps repo without a long-lived deploy key, if you're
# using GitHub App auth via AWS Secrets Manager, or to assume roles for
# multi-account deployments. If your gitops repo is public or you're using
# a simple SSH deploy key secret instead, this role is optional — see
# var.create_repo_irsa_role.
resource "aws_iam_role" "argocd_repo_server" {
  count = var.create_repo_irsa_role ? 1 : 0

  name = "${var.environment}-argocd-repo-server-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url}:sub" = "system:serviceaccount:argocd:argocd-repo-server"
          "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "argocd_repo_server_secrets" {
  count = var.create_repo_irsa_role ? 1 : 0

  name = "${var.environment}-argocd-secretsmanager-read"
  role = aws_iam_role.argocd_repo_server[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.repo_credentials_secret_arn != null ? [var.repo_credentials_secret_arn] : ["*"]
    }]
  })
}

locals {
  oidc_provider_url = replace(var.cluster_oidc_issuer_url, "https://", "")
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = kubernetes_namespace.argocd.metadata[0].name
  create_namespace = false

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      environment          = var.environment
      ha_enabled           = var.ha_enabled
      repo_server_role_arn = var.create_repo_irsa_role ? aws_iam_role.argocd_repo_server[0].arn : ""
      ingress_enabled      = var.ingress_enabled
      ingress_host         = var.ingress_host
      alb_certificate_arn  = var.alb_certificate_arn
    })
  ]

  # sso/admin bootstrap password, repo credentials, etc — never inline
  # plaintext here. Reference the same External Secrets pattern used for
  # application secrets (see gitops repo README).
  set_sensitive = var.admin_password_bcrypt_hash != null ? [
    {
      name  = "configs.secret.argocdServerAdminPassword"
      value = var.admin_password_bcrypt_hash
    }
  ] : []

  depends_on = [kubernetes_namespace.argocd]
}
