output "role_arns" {
  description = "Map of environment -> IAM role ARN to put in GitHub Environment secrets as AWS_ROLE_ARN"
  value       = { for env, role in aws_iam_role.github_actions : env => role.arn }
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}
