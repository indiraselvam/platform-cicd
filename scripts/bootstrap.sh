#!/usr/bin/env bash
# One-time, run by hand from your machine (not CI) after ArgoCD has been
# installed by terraform-modules/argocd. Applies the AppProjects and the
# root Application (app-of-apps) for one environment. After this, never
# run kubectl apply against argocd/ again — ArgoCD reconciles itself.
set -euo pipefail

ENV="${1:?usage: bootstrap.sh <dev|staging|production>}"

aws eks update-kubeconfig --name "${ENV}-eks" --region ap-south-1 --profile indira-admin

kubectl apply -f "argocd/projects/${ENV}-project.yaml"
kubectl apply -f "argocd/bootstrap/${ENV}-root-app.yaml"

echo "Bootstrapped. Check: kubectl get applications -n argocd"
echo "Initial admin password (until SSO is wired up):"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
