# Wiring this into your existing `terraform` repo

## 1. Add the kubernetes provider

`terraform-modules/argocd` creates a `kubernetes_namespace`, so add the
provider alongside your existing `helm`/`kubectl` blocks in each
environment's `providers.tf` (same `data.aws_eks_cluster.existing` +
`aws eks get-token` pattern you already use):

```hcl
provider "kubernetes" {
  host                   = data.aws_eks_cluster.existing.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.existing.name, "--region", var.aws_region, "--profile", "indira-admin"]
  }
}
```

And add `kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }`
to `versions.tf`, next to your existing `helm`/`kubectl` entries.

## 2. Copy the modules in

```
cp -r terraform-modules/argocd      <terraform-repo>/modules/argocd
cp -r terraform-modules/github-oidc <terraform-repo>/modules/github-oidc
```

## 3. Wire `modules/argocd` into each environment

In `environments/<env>/main.tf`, add right after your `alb_controller`
block (same dependency shape):

```hcl
module "argocd" {
  source = "../../modules/argocd"

  environment              = var.environment
  cluster_oidc_issuer_url  = module.eks.cluster_oidc_issuer_url
  oidc_provider_arn        = module.irsa.oidc_provider_arn

  ha_enabled          = var.environment == "production"
  ingress_host        = "argocd.${var.environment}.yourcompany.com"
  alb_certificate_arn = var.argocd_alb_certificate_arn

  depends_on = [module.eks, module.irsa, module.alb_controller]
}
```

Add `argocd_alb_certificate_arn` to that environment's `variables.tf` and
`terraform.tfvars` (an ACM cert covering the ArgoCD hostname).

## 4. Wire `modules/github-oidc` — once, in `global/`

You already have a `global/backend-bootstrap` stack for account-level
one-offs; add a sibling `global/github-oidc`:

```hcl
module "github_oidc" {
  source = "../../modules/github-oidc"

  tfstate_bucket = "my-tfstate-indira"

  environments = {
    dev = {
      subject_claims          = ["repo:indiraselvam/terraform:*", "repo:indiraselvam/platform-cicd:*"]
      provisioning_policy_arn = aws_iam_policy.dev_provisioning.arn
    }
    staging = {
      subject_claims          = ["repo:indiraselvam/terraform:*"]
      provisioning_policy_arn = aws_iam_policy.staging_provisioning.arn
    }
    production = {
      # only the run that went through the GitHub Environment approval
      # gate may assume this role
      subject_claims          = ["repo:indiraselvam/terraform:environment:production-apply"]
      provisioning_policy_arn = aws_iam_policy.production_provisioning.arn
    }
  }
}

output "github_actions_role_arns" {
  value = module.github_oidc.role_arns
}
```

Apply this once by hand (`indira-admin` profile) — it's the chicken-and-egg
piece CI can't create for itself. Take the three ARNs from
`github_actions_role_arns` and put them in GitHub as
`AWS_ROLE_ARN_DEV` / `AWS_ROLE_ARN_STAGING` / `AWS_ROLE_ARN_PRODUCTION`,
scoped to each environment's GitHub Environment secrets, not repo-level
secrets — that keeps the dev workflow from being able to read the
production role ARN at all.

## 5. GitHub Environments to create (Settings → Environments)

| Environment name        | Required reviewers | Used by |
|--------------------------|--------------------|---------|
| `dev-plan` / `staging-plan` / `production-plan` | none | terraform-plan.yml |
| `dev-apply` / `staging-apply` | none (or a light gate) | terraform-apply.yml |
| `production-apply`       | **yes — at least 1** | terraform-apply.yml — this is the whole gate |
| `dev` / `staging` / `production` (app repos) | staging/production: yes | docker-build-push.yml |

## 6. `admin_principal_arns`

You already have this variable on `module.eks` — add whichever IAM role
runs `bootstrap.sh` (your `indira-admin` profile's role) so it has cluster
access to apply the one-time root Application.
