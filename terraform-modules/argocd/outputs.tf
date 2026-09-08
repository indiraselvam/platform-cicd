output "namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "repo_server_role_arn" {
  value = var.create_repo_irsa_role ? aws_iam_role.argocd_repo_server[0].arn : null
}
