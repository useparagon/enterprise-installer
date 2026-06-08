# enterprise-installer

Terraform + Helm monorepo that provisions and deploys the Paragon embedded integration platform on AWS (EKS), Azure (AKS), and GCP (GKE). The same infrastructure pattern exists across all three providers; keep them in sync unless a change is genuinely cloud-specific.

## Two-workspace model

Every provider has two Terraform workspaces that must be applied in order:

```
<provider>/workspaces/
├── infra/    # VPC, cluster, Postgres, Redis, storage, Kafka — provisions cloud resources
└── paragon/  # Helm releases, ESO, DNS, monitoring — deploys the application
```

`infra` outputs flow to `paragon` via **AWS Secrets Manager / Azure Key Vault / GCP Secret Manager** (new, ArgoCD path) or a JSON file at `.secure/infra-output.json` (legacy, ~40 existing deployments still use this).

## ArgoCD / GitOps path (this branch: `chore/PARA-18824/argocd-support`)

The branch replaces the `paragon` Terraform workspace with GitOps driven by ArgoCD. The model:

1. **`infra` workspace** writes all secrets to the cloud secret store (nested JSON infra secrets + a flat `env` secret pre-merged with all app env vars).
2. **ArgoCD bootstrap module** (`argocd/`) installs ArgoCD, configures External Secrets Operator via a `ClusterSecretStore`, and creates a gitops-bridge cluster secret with cloud metadata annotations. It also wires the app-of-apps Application.
3. **enterprise-deployments repo** (separate) drives Spacelift to apply Terraform and ArgoCD sync.

### Feature flag

All new behavior is gated on `var.argocd_enabled` (bool, default `false`). This allows 40+ existing deployments to keep using the legacy paragon workspace while new and migrating deployments opt in on their own schedule.

### Secret naming conventions (cloud-native)

| Provider | Store | Secret path pattern |
|---|---|---|
| AWS | Secrets Manager | `paragon/{workspace}/env`, `/postgres`, `/redis`, `/storage`, `/kafka` |
| Azure | Key Vault | `env`, `postgres`, `redis`, `storage`, `kafka` (short names; vault scoped to workspace) |
| GCP | Secret Manager | `{workspace}-env`, `-postgres`, `-redis`, `-storage`, `-kafka` |

Helm charts consume secrets via ExternalSecret resources — the ESO provider and path differ per cloud, but the resulting Kubernetes Secret shape is identical.

## Provider-specific ArgoCD components

### AWS (complete on this branch)
- ESO installed by `eks-blueprints-addons` (IRSA/OIDC auth, scoped to secret ARNs)
- Ingress: AWS Load Balancer Controller + external-dns (Route 53)
- ACM cert + Route 53 zone + Cloudflare NS delegation in `argocd_acm.tf`
- ClusterSecretStore: JWT service-account auth against Secrets Manager

### Azure (to implement)
- ESO via Workload Identity (AKS OIDC + federated credential on managed identity — **no Service Principal keys**)
- Ingress: Application Gateway for Containers (Azure's managed ingress, successor to AGIC) + external-dns with Azure DNS provider
- TLS: cert-manager with Let's Encrypt (same as existing paragon workspace)
- ClusterSecretStore: `azureWorkloadIdentity` provider against Key Vault
- ArgoCD bootstrap: equivalent of `aws/workspaces/infra/argocd/` for AKS

### GCP (to implement)
- ESO via Workload Identity (GKE Workload Identity binding on GSA — pattern already in `gcp/workspaces/paragon/eso.tf`, move to infra)
- Ingress: GKE Gateway API with Google-managed certificates (native GCP, no cert-manager needed)
- DNS: Cloud DNS with external-dns GCP provider
- ClusterSecretStore: `gcpWorkloadIdentity` provider against Secret Manager
- ArgoCD bootstrap: equivalent of AWS module, using `google_container_cluster` OIDC endpoint

## Workspace naming

All resources are prefixed with a stable workspace name derived at plan time:

```
paragon-{organization}-{first8_of_sha256(cloud_account_id)}
```

Override with `migrated_workspace` variable. This name is the primary key for every cloud resource.

## Validation workflow

After any change to variables, outputs, providers, or resources, run all four tools against each affected workspace. After a cross-cutting change, run against all six:

```bash
for provider in aws azure gcp; do
  for ws in infra paragon; do
    echo "=== $provider/$ws ==="
    dir="/Users/ted/Projects/enterprise-installer/$provider/workspaces/$ws"
    cd "$dir"
    terraform init -backend=false -upgrade 2>&1 | tail -3
    terraform validate
    tflint --init 2>/dev/null; tflint
    terraform-docs markdown table --output-file README.md --output-mode inject .
  done
done
```

Format check: `terraform fmt -check -recursive` from repo root (or `terraform fmt -recursive` to fix in place).

No backend credentials are needed for `init -backend=false`. `terraform plan` requires real cloud credentials and is an operator responsibility.

## Key conventions

- **Conditional resources**: `count = var.some_flag ? 1 : 0` (single resource) or `for_each` (maps). Feature flags are `bool` with `default = false`. Access array module outputs as `module.foo[0].output`.
- **Sensitive values**: mark with `sensitive = true` on variables and outputs.
- **No hardcoded creds**: credentials always come from variables or data sources.
- **Cross-provider symmetry**: if you add a variable or pattern to one provider, add it to all three unless it's provider-specific. Note the difference in label casing: AWS/Azure use PascalCase tags; GCP requires lowercase labels.
- **Managed Sync (Kafka)**: all Kafka/Event Hubs/GMK resources are `count = var.managed_sync_enabled ? 1 : 0`. The flat `env` secret also gets Kafka env vars when enabled.
- **`argocd_enabled` is the gate**: all ArgoCD/GitOps infrastructure is `count = var.argocd_enabled ? 1 : 0`. Never create ArgoCD resources unconditionally.

## Module sources

- All modules are local (`source = "./network"` etc). No shared cross-provider modules.
- AWS uses several external registry modules (`terraform-aws-modules/eks`, `cloudposse/acm-request-certificate`, `lablabs/eks-cluster-autoscaler`).
- Azure and GCP use native provider resources directly for most things.

## Helm charts

Charts live in `charts/` and are copied into `<provider>/workspaces/paragon/charts/` by `prepare.sh`. Never edit the copies — edit source in `charts/`.

The five charts:
- `bootstrap/` — initial K8s secret seeding (legacy path)
- `paragon-onprem/` — all 26 Paragon microservices
- `paragon-monitoring/` — Prometheus, Grafana, PgAdmin, exporters
- `paragon-logging/` — OpenObserve + Fluent-bit
- `paragon-templates/` — shared template library (not deployed directly)

## Files that are gitignored

- `main.tf` (generated from `main.tf.example` by `prepare.sh`)
- `vars.auto.tfvars` (generated; operators fill in values)
- `.secure/` directories (infra JSON output, values.yaml with secrets)
- `charts/` under paragon workspaces (copied by `prepare.sh`)

## PR checklist

- [ ] `terraform fmt -check -recursive` clean
- [ ] `terraform validate` passes all 6 workspaces
- [ ] `tflint` passes all modified workspaces
- [ ] `terraform-docs markdown table --output-file README.md --output-mode inject .` run on all workspaces with changed variables/outputs/providers
- [ ] New `argocd_*` vars added to all three providers with `argocd_enabled` guard
- [ ] Sensitive outputs marked `sensitive = true`
- [ ] New resources follow `${local.workspace}-*` naming
- [ ] Kafka resources gated on `managed_sync_enabled`
- [ ] No Service Principal keys or static credentials introduced (prefer Workload Identity)
