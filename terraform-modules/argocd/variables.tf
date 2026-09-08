variable "environment" {
  type = string
}

variable "cluster_oidc_issuer_url" {
  type        = string
  description = "From module.eks.cluster_oidc_issuer_url"
}

variable "oidc_provider_arn" {
  type        = string
  description = "From module.irsa.oidc_provider_arn"
}

variable "chart_version" {
  type    = string
  default = "7.8.4" # pin explicitly, same as your other helm_release modules
}

variable "ha_enabled" {
  type        = bool
  description = "Use the HA manifest set (redis-ha, 3x controller/repo-server/server). Recommended for staging/production."
  default     = false
}

variable "ingress_enabled" {
  type    = bool
  default = true
}

variable "ingress_host" {
  type        = string
  description = "e.g. argocd.dev.yourcompany.com — routed via the ALB controller module you already have"
  default     = null
}

variable "alb_certificate_arn" {
  type        = string
  description = "ACM cert ARN for the ArgoCD ingress ALB listener"
  default     = null
}

variable "create_repo_irsa_role" {
  type        = bool
  description = "Create an IRSA role for argocd-repo-server (only needed if it must call AWS, e.g. reading repo creds from Secrets Manager)"
  default     = false
}

variable "repo_credentials_secret_arn" {
  type    = string
  default = null
}

variable "admin_password_bcrypt_hash" {
  type        = string
  description = "bcrypt hash for the initial admin password. Leave null to use the chart's auto-generated one (read via `argocd admin initial-password`), then disable local admin auth once SSO is wired up."
  default     = null
  sensitive   = true
}
