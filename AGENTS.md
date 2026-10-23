# Agents

## Cursor Cloud specific instructions

### Overview

This is a **Paragon Enterprise** self-hosted deployment repository — an infrastructure-as-code (IaC) toolkit for deploying Paragon microservices to Kubernetes on AWS, Azure, or GCP. It contains **no application source code**; only Helm charts, Terraform configs, and Node.js helper scripts.

### Repository layout

- `charts/` — Cloud-agnostic Helm charts (`paragon-onprem`, `paragon-monitoring`, `paragon-logging`, `paragon-templates`)
- `aws/`, `azure/`, `gcp/` — Cloud-specific Terraform workspaces (`infra` and `paragon` each)
- `scripts/` — Node.js ESM helpers (`update-charts.mjs`, `generate-tfvars.mjs`) with pnpm for dev deps
- `prepare.sh` — Main entry-point: copies charts, generates tfvars, hashes chart versions

### Required tools

| Tool | Purpose |
|------|---------|
| Node.js (v22+) | Runs helper scripts in `scripts/` |
| pnpm | Installs dev dependencies in `scripts/` |
| Terraform (~1.9) | Validates and applies IaC configs |
| Helm (v3) | Lints and packages Kubernetes charts |
| rsync | Used by `prepare.sh` to copy chart files |

### Key development commands

- **Install script deps**: `cd scripts && pnpm install`
- **Prepare charts** (hello-world for this repo): `./prepare.sh -p <aws|azure|gcp> -t <GIT_TAG>`
- **Terraform validate** (per workspace): `cd <provider>/workspaces/<infra|paragon> && terraform init -backend=false && terraform validate`
- **Helm lint** (on prepared charts): `helm lint <provider>/workspaces/paragon/charts/paragon-logging`
- **Generate tfvars**: `node scripts/generate-tfvars.mjs <variables.tf> <output.tfvars>`

### Gotchas

- `prepare.sh` uses OS-aware in-place `sed` (BSD on macOS, GNU on Linux) and fails if `__PARAGON_VERSION__` placeholders remain. It also falls back to `scripts/update-charts.py` / `tar` / `sha256sum` when `node` / `rsync` / `shasum` are missing, which is the case on Spacelift's Alpine runner. `scripts/update-charts.py` must stay byte-identical in output to `scripts/update-charts.mjs` — the chart directory hash feeds the Helm chart version. Spacelift `before_init-paragon.sh` reads `global.env.VERSION` from the mounted values, fetches that git tag’s `charts/files/service-inputs.json`, runs `prepare.sh -p <cloud>`, and removes placeholder `vars.auto.tfvars` so `TF_VAR_*` from context is not overridden. Per-cloud entrypoints: `<cloud>/workspaces/{infra,paragon}/spacelift-before-init.sh`.
- The source Helm charts in `charts/` contain `__PARAGON_VERSION__` placeholders and will fail `helm lint`. Always lint the **prepared** charts under `<provider>/workspaces/paragon/charts/` after running `prepare.sh`.
- Helm lint on `paragon-onprem` and `paragon-monitoring` will show errors about missing `paragon-templates` dependency — this is expected since the library chart dependency is resolved by `helm dependency build` during Terraform-driven deployment.
- `terraform init -backend=false` is required for local validation since backend configs reference remote state stores.
- Files under `.secure/`, `main.tf`, and `*.tfvars` are gitignored. `prepare.sh` generates them from templates/examples.
- There are no automated tests or lint scripts in this repo. Validation = `terraform validate` + `helm lint` + running `prepare.sh`.
- OCS custom-code on-prem uses the knative HTTP runner (`charts/paragon-onprem/charts/ocs-code-runner`), not AWS Lambda. Image is Docker Hub `useparagon/ocs-code-runner-knative` (not ECR). The chart emits a cluster-local `serving.knative.dev/v1` Service named `ocs-code-runner-ksvc` plus a ClusterIP `ocs-code-runner` (port 80) so workers can resolve `http://ocs-code-runner` — Knative's own Service for a ksvc is ExternalName to Kourier, which Node `getaddrinfo` reports as ENOTFOUND. Default `minScale: 1` so that ClusterIP has endpoints. The runner ServiceAccount `ocs-code-runner` is bound to the same object-storage identity as other Paragon workloads (EKS Pod Identity S3 role on AWS; GKE Workload Identity on GCP) so Knative execute can omit envelope access keys. Paragon terraform installs Knative Serving + Kourier (operator + `KnativeServing` CR, ClusterIP) before `paragon-on-prem`. The same `docker-cfg` pull secret is copied into `knative-serving` (`spec.registry.imagePullSecrets`) and listed on the runner ServiceAccount so the revision controller can authenticate to Docker Hub; Hub tag-to-digest is skipped because Serving 1.23 uses HTTP HEAD which Hub rejects with 401 for private repos. Workers receive `WORKER_SHARED_OCS_KNATIVE_SERVICE_URL`; payload offload uses existing `CLOUD_STORAGE_*` (same contract as platform `createOcsRuntime`). The companion ClusterIP must target queue-proxy `8012` (not user-port `8080`) or worker traffic bypasses queue-proxy and request/concurrency metrics stay at 0. KnativeServing `config.observability` sets `metrics-protocol` and `request-metrics-protocol` to `prometheus` (Serving 1.23 defaults to OTLP); Knative components only read it at startup, so restart them after changing it. Serving 1.23 exports OpenTelemetry names (`kn_revision_*` from the autoscaler, `kn_serving_invocation_duration_seconds_*` / `kn_serving_queue_depth` from queue-proxy `:9091` `http-usermetric`), not `revision_request_count` / `autoscaler_*`; queue-proxy `:9090` is the autoscaler's protobuf feed.
- Monitoring images are built from `platform-monorepo`: `useparagon/prometheus` is VictoriaMetrics single-node (scrape config `monitors/prometheus/src/prometheus.k8s.tpl.yml`, rendered to `/usr/src/app/prometheus.yml` at start; jobs `knative_serving` and `knative_revisions` cover Knative), and `useparagon/grafana` renders dashboards from `monitors/grafana/templates` on every container start (`knative-ocs` is `templates/dashboards/knative-ocs.json`). Live edits to either are lost on restart; only dashboards imported through the Grafana API persist (SQLite on the PVC), and provisioned uids reject API saves. kube-state-metrics runs without `--metric-labels-allowlist`, so `kube_pod_labels` does not exist — do not build dashboard variables on it. When writing files into pods with `kubectl exec -i` (kubectl 1.36), use `cat > f && wc -c < f`: a silent remote command is killed on stdin EOF and leaves an empty file.
