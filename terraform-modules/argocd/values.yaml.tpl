## Rendered by templatefile() in main.tf — environment=${environment}

global:
  # Terraform manages the initial install only; ArgoCD app-of-apps takes
  # over from here (see argocd/bootstrap in the platform-cicd repo).
  additionalLabels:
    environment: ${environment}

configs:
  params:
    server.insecure: false # TLS terminated at the ALB below; keep internal traffic on TLS too where possible

  cm:
    # Auto-detect Application manifests dropped anywhere under the
    # gitops repo's argocd/apps/<env>/ directory
    resource.compareoptions: |
      ignoreAggregatedRoles: true
    # Restrict ArgoCD to only ever apply resources declared in an
    # AppProject's allow-list (see argocd/projects/*.yaml) — a compromised
    # gitops PR can't sneak a ClusterRoleBinding into a namespace it
    # doesn't own.

server:
  ingress:
%{ if ingress_enabled ~}
    enabled: true
    ingressClassName: alb
    annotations:
      alb.ingress.kubernetes.io/scheme: internal # keep the ArgoCD UI off the public internet
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/certificate-arn: "${alb_certificate_arn}"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    hosts:
      - ${ingress_host}
    tls: []
%{ else ~}
    enabled: false
%{ endif ~}

controller:
  replicas: ${ha_enabled ? 3 : 1}

repoServer:
  replicas: ${ha_enabled ? 3 : 1}
%{ if repo_server_role_arn != "" ~}
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "${repo_server_role_arn}"
%{ endif ~}

redis-ha:
  enabled: ${ha_enabled}
redis:
  enabled: ${ha_enabled ? false : true}

applicationSet:
  replicas: ${ha_enabled ? 2 : 1}

notifications:
  enabled: true
  # Slack webhook wired via a Secret from External Secrets Operator, not
  # inlined here — see gitops repo README "Notifications" section.
