# Spacelift (state-migration interim)

This branch supports running **infra** and **paragon** workspaces directly from
Spacelift (no Argo CD). Operator procedure (TFC → S3, contexts, plan/apply):

**[`enterprise-deployments` `docs/aws-state-migration-runbook.md`](https://github.com/useparagon-internal/enterprise-deployments/blob/chore/PARA-25072/state-migration/docs/aws-state-migration-runbook.md)**

| Stack | `project_root` | `before_init` |
|-------|----------------|---------------|
| `<customer>` | `aws/workspaces/infra` | [`scripts/spacelift/before_init-infra.sh`](scripts/spacelift/before_init-infra.sh) |
| `<customer>-paragon` | `aws/workspaces/paragon` | [`scripts/spacelift/before_init-paragon.sh`](scripts/spacelift/before_init-paragon.sh) |

Stack definitions live in [`useparagon-internal/enterprise-deployments`](https://github.com/useparagon-internal/enterprise-deployments) under `spacelift/`.

## Auth

Prefer ambient credentials from the Spacelift AWS integration plus:

```hcl
TF_VAR_aws_assume_role_arn = "arn:aws:iam::ACCOUNT:role/paragon-terraform-role-<customer>"
```

(Readable context var — not write-only.) Static `aws_access_key_id` /
`aws_secret_access_key` remain supported for local legacy applies (both optional
when assume-role is set).

The customer role must allow `secretsmanager:*` on `paragon/<workspace>/*`
(already in `enterprise-deployments` bootstrap `tf-role-aws.yaml`).

## Infra → paragon handoff

Omit `infra_json` / `infra_json_path`. Infra writes Secrets Manager secrets;
paragon reads them (`infra_secrets.tf`). Keep `organization` /
`migrated_workspace` aligned on both stacks.

## Paragon Helm values and charts

| Need | Spacelift |
|------|-----------|
| Charts + `service-inputs.json` | `before_init-paragon.sh` runs `./prepare.sh -p aws -t "$PARAGON_CHART_TAG"`, then deletes placeholder `vars.auto.tfvars` so Spacelift `TF_VAR_*` wins |
| Helm values (`VERSION`, `LICENSE`, …) | Mounted file `paragon-values.yaml` → `/mnt/workspace/paragon-values.yaml` + **`TF_VAR_helm_yaml_path`** (Spacelift forbids newlines in env vars). |
| Feature flags | Omit for git-backed Flipt, or mount / set **`TF_VAR_feature_flags_yaml`**. |

## Backend env vars (both stacks)

Set on each stack (context or env) by `migrate:spacelift-prep`:

- `SPACELIFT_STATE_BUCKET`
- `SPACELIFT_STATE_KEY` — `<id>/infra.tfstate` or `<id>/paragon.tfstate`
- `SPACELIFT_STATE_REGION`
- `SPACELIFT_STATE_DYNAMODB_TABLE`
- `SPACELIFT_STATE_ROLE_ARN` — **omit** when the Spacelift AWS integration
  already assumes `terraform-backend-access-<tier>` (self-assume fails).
- Paragon only: `PARAGON_CHART_TAG`, `TF_VAR_helm_yaml_path`

Commands: `pnpm run migrate:spacelift-prep` and `pnpm run migrate:state-copy`
in enterprise-deployments.
