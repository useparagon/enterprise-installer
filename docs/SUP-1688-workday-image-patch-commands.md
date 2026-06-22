# SUP-1688: Workday interim image patch commands

Workday's DRDRE scan blocked four container images (SUP-1688). Use these commands to patch running workloads **before** a full Paragon upgrade so security can re-scan and approve `datalake-prod`.

**Namespace:** `paragon` (adjust if your deployment uses a different namespace)

## Strategy

| Audience | OpenObserve target | When |
| --- | --- | --- |
| **Workday (interim patch)** | `v0.91.0-rc3` | Now — passes DRDRE with 0 HIGH/CRITICAL on Trivy while we validate internally |
| **Paragon chart (PARA-22208)** | `v0.91.0` stable | When Zinc Labs publishes GA — official bump in `enterprise`, not an RC |

Do **not** pin the RC in the Helm chart. The chart bump waits for stable `v0.91.0`.

---

## Target image tags (all four flagged images)

| Image | Current (flagged) | Interim patch target | Official chart bump |
| --- | --- | --- | --- |
| `public.ecr.aws/zinclabs/openobserve` | `v0.20.1` | **`v0.91.0-rc3`** | `v0.91.0` stable ([PARA-22208](https://useparagon.atlassian.net/browse/PARA-22208)) |
| `docker.io/openfga/openfga` | `v1.11.1` | `v1.17.1` | [PARA-22209](https://useparagon.atlassian.net/browse/PARA-22209) |
| `docker.io/alpine/kubectl` | `1.33.4` | `1.35.4` | [PARA-22209](https://useparagon.atlassian.net/browse/PARA-22209) |
| `docker.io/groundnuty/k8s-wait-for` | `v2.0` | `no-root-v1.7` | [PARA-22209](https://useparagon.atlassian.net/browse/PARA-22209) |

---

## 1. OpenObserve (interim — use RC3)

Trivy on `v0.91.0-rc3`: **0 HIGH, 0 CRITICAL** (vs 3 Critical + 24 High on `v0.20.1`).

```bash
kubectl -n paragon set image statefulset/openobserve \
  openobserve=public.ecr.aws/zinclabs/openobserve:v0.91.0-rc3

kubectl -n paragon rollout status statefulset/openobserve --timeout=600s
```

After DRDRE approves, upgrade to stable `v0.91.0` when Paragon ships the official chart bump.

---

## 2. OpenFGA (managed-sync)

```bash
kubectl -n paragon set image deployment/openfga \
  openfga=docker.io/openfga/openfga:v1.17.1

kubectl -n paragon rollout status deployment/openfga --timeout=600s
```

If OpenFGA runs as a StatefulSet:

```bash
kubectl -n paragon set image statefulset/openfga \
  openfga=docker.io/openfga/openfga:v1.17.1

kubectl -n paragon rollout status statefulset/openfga --timeout=600s
```

---

## 3. alpine/kubectl (restart CronJob)

```bash
kubectl -n paragon set image cronjob/restart-paragon-pods-cronjob \
  restart-pods=alpine/kubectl:1.35.4
```

---

## 4. groundnuty/k8s-wait-for (init containers)

```bash
kubectl -n paragon get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.initContainers[*]}{.image}{" "}{end}{"\n"}{end}' \
  | grep k8s-wait-for

kubectl -n paragon patch deployment <DEPLOYMENT_NAME> --type=json -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/initContainers/0/image",
    "value": "docker.io/groundnuty/k8s-wait-for:no-root-v1.7"
  }
]'
```

Adjust the init container index if `k8s-wait-for` is not the first init container.

---

## Verify and re-scan

```bash
kubectl -n paragon get statefulset,deployment,cronjob -o jsonpath='{range .items[*]}{.kind}/{.metadata.name}{": "}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{range .spec.template.spec.initContainers[*]}{.image}{" "}{end}{"\n"}{end}' \
  | grep -E 'openobserve|openfga|kubectl|k8s-wait-for'
```

Re-submit the patched images to DRDRE for approval.
