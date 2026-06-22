# SUP-1688: Workday interim image patch commands

Use these commands to update flagged container images **before** a full Paragon upgrade.
After patching, re-run the DRDRE security scan to confirm high/critical counts are resolved.

**Namespace:** `paragon` (adjust if your deployment uses a different namespace)

## Target image tags

| Image | Current (flagged) | Interim target | Ticket |
| --- | --- | --- | --- |
| `public.ecr.aws/zinclabs/openobserve` | `v0.20.1` | `v0.90.3` | [PARA-22208](https://useparagon.atlassian.net/browse/PARA-22208) |
| `docker.io/openfga/openfga` | `v1.11.1` | `v1.17.1` | [PARA-22209](https://useparagon.atlassian.net/browse/PARA-22209) |
| `docker.io/alpine/kubectl` | `1.33.4` | `1.35.4` | [PARA-22209](https://useparagon.atlassian.net/browse/PARA-22209) |
| `docker.io/groundnuty/k8s-wait-for` | `v2.0` | `no-root-v1.7` | [PARA-22209](https://useparagon.atlassian.net/browse/PARA-22209) |

> **Note:** OpenObserve `v0.90.3` still reports 1 HIGH CVE (OpenSSL) on Trivy. A stable release with that fix is expected soon; `v0.91.0-rc2` scans clean on High/Critical if DRDRE requires zero HIGH findings.

---

## 1. OpenObserve

```bash
kubectl -n paragon set image statefulset/openobserve \
  openobserve=public.ecr.aws/zinclabs/openobserve:v0.90.3

kubectl -n paragon rollout status statefulset/openobserve --timeout=600s
```

---

## 2. OpenFGA (managed-sync)

```bash
kubectl -n paragon set image deployment/openfga \
  openfga=docker.io/openfga/openfga:v1.17.1

kubectl -n paragon rollout status deployment/openfga --timeout=600s
```

If OpenFGA runs as a StatefulSet in your cluster:

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

`k8s-wait-for` is used as an init container across managed-sync workloads. Patch each deployment/statefulset that references it:

```bash
# List pods using the old image
kubectl -n paragon get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.initContainers[*]}{.image}{" "}{end}{"\n"}{end}' \
  | grep k8s-wait-for

# Patch a deployment (repeat for each affected resource)
kubectl -n paragon patch deployment <DEPLOYMENT_NAME> --type=json -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/initContainers/0/image",
    "value": "docker.io/groundnuty/k8s-wait-for:no-root-v1.7"
  }
]'
```

Adjust the init container index (`initContainers/0`) if `k8s-wait-for` is not the first init container.

---

## Verify

```bash
# Confirm updated images
kubectl -n paragon get statefulset,deployment,cronjob -o jsonpath='{range .items[*]}{.kind}/{.metadata.name}{": "}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{range .spec.template.spec.initContainers[*]}{.image}{" "}{end}{"\n"}{end}' \
  | grep -E 'openobserve|openfga|kubectl|k8s-wait-for'
```

Re-submit the updated images to DRDRE for approval.
