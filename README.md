# platform-cicd

GitHub Actions + ArgoCD CI/CD platform for the `terraform` EKS infra
(dev / staging / production), replacing Jenkins end to end.

## Why a separate repo

Three repos, three jobs, three blast radii:

| repo                | owns                                | who/what has write access to the cluster |
|----------------------|-------------------------------------|-------------------------------------------|
| `terraform` (yours)  | VPC, EKS, IRSA, Karpenter, ArgoCD install | GitHub Actions, via OIDC role, `terraform apply` only |
| `platform-cicd` (this repo) | reusable GH Actions workflows + ArgoCD GitOps manifests | **nothing** — ArgoCD pulls from it, nothing pushes to the cluster from here |
| app repos             | application source + Dockerfile     | GH Actions builds/pushes image, opens a PR here — never touches the cluster |

The only thing with permission to change what's running on the cluster is
**ArgoCD**, reconciling from Git. GitHub Actions never runs `kubectl apply`
or `helm upgrade` against a live cluster — the old Jenkins pipeline's
biggest risk (a Jenkins agent holding a long-lived kubeconfig / AWS keys)
goes away entirely.

## Layout

```
.github/workflows/          Reusable workflows (workflow_call) — terraform
                             plan/apply, docker build/push, gitops bump
terraform-modules/argocd/   Drop into your terraform repo as modules/argocd
terraform-modules/github-oidc/  Drop in as modules/github-oidc — creates the
                             AWS OIDC federation GitHub Actions authenticates
                             with (no static AWS keys, ever)
argocd/bootstrap/           One root Application per cluster (app-of-apps)
argocd/projects/            AppProject per environment (RBAC + repo/resource
                             allow-lists)
argocd/apps/<env>/          Application manifests ArgoCD discovers per env
charts/example-app/         Sample Helm chart + per-env values, wired for
                             image-tag bumps from app CI
wrapper-workflows-for-infra-repo/  Thin workflow files to paste into your
                             `terraform` repo's .github/workflows — they just
                             call the reusable ones in this repo
scripts/bootstrap.sh        One-time: apply the ArgoCD root Applications
```

## End-to-end flow

**Infra change (this repo's `terraform-modules/` fed into your `terraform`
repo):**
1. PR against `terraform` repo → wrapper workflow calls
   `platform-cicd/.github/workflows/terraform-plan.yml` → plan posted as a
   PR comment, `tflint`/`checkov` gate the PR
2. Merge to `main` → wrapper workflow calls `terraform-apply.yml` →
   `production` requires a GitHub Environment reviewer approval before it
   runs

**App change:**
1. App repo pushes to `main` → calls `docker-build-push.yml` (builds,
   pushes to ECR with the commit SHA as tag, OIDC — no ECR keys)
2. Calls `bump-gitops-image.yml` → opens a PR against **this repo**,
   `charts/example-app/values-<env>.yaml` image tag bumped
3. You (or auto-merge for dev) merge the PR
4. ArgoCD, already watching this repo, syncs the change to the cluster —
   dev/staging auto-sync, production is manual-sync/gated (see
   `argocd/apps/production/example-app.yaml`)

No step in either flow gives a CI runner `kubectl` access to a live
cluster.

## First-time setup order

1. Apply `terraform-modules/github-oidc` in your `terraform` repo's
   `global/` stack — creates the OIDC provider + one IAM role per
   environment, trust-scoped to `repo:<org>/terraform:*` and
   `repo:<org>/platform-cicd:*` (edit the `subject_claims` to match your
   org/repo names before applying).
2. Apply `terraform-modules/argocd` per environment (same pattern as your
   `alb_controller`/`karpenter` modules) — installs ArgoCD via Helm.
3. `scripts/bootstrap.sh` — one-time `kubectl apply` (from your own
   machine, not CI) of `argocd/bootstrap/<env>-root-app.yaml`. After this,
   ArgoCD manages itself from Git; you never hand-apply again.
4. Copy `wrapper-workflows-for-infra-repo/*.yml` into your `terraform`
   repo's `.github/workflows/`.
5. Set repo/environment secrets (see each workflow's `# secrets:` header
   comment) — all are role ARNs, not credentials.
