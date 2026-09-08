variable "tfstate_bucket" {
  type        = string
  description = "S3 bucket holding terraform state, e.g. my-tfstate-indira"
}

variable "environments" {
  description = <<-EOT
    One entry per environment that gets its own GitHub Actions IAM role.

    subject_claims: list of OIDC "sub" patterns (StringLike, so wildcards
      work) allowed to assume this role. Keep production's list to the
      GitHub Environment-gated subject only, e.g.:
      "repo:indiraselvam/terraform:environment:production"

    provisioning_policy_arn: an IAM policy ARN with the actual AWS
      permissions this role needs (EKS/VPC/IAM/KMS/S3/EC2 create/update).
      Create one policy per environment and pass its ARN here rather than
      attaching AdministratorAccess.
  EOT
  type = map(object({
    subject_claims          = list(string)
    provisioning_policy_arn = string
  }))
}
