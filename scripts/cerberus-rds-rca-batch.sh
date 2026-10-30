#!/usr/bin/env bash
# Run cerberus-rds-rca-hoop.sh across known Enterprise stacks from SEV-1337 correlation work.
#
# Usage:
#   hoop login
#   ./scripts/cerberus-rds-rca-batch.sh /tmp/cerberus-rca-batch
#
# Edit STACKS below if Hoop connection names differ for your org prefix.
set -euo pipefail

ROOT_OUT="${1:-./cerberus-rca-out}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RCA="${SCRIPT_DIR}/cerberus-rds-rca-hoop.sh"

[ -x "$RCA" ] || chmod +x "$RCA"

# connection_name|stack_label|optional_incident_start|optional_incident_end
STACKS=(
  "crewai-k8s-admin|crewai|2026-10-30T01:00:00Z|2026-10-30T02:00:00Z"
  "boosted-k8s-admin|boosted|2026-10-18T14:00:00Z|2026-10-18T16:00:00Z"
  "appsmith-k8s-admin|appsmith|2026-10-25T21:50:00Z|2026-10-25T23:00:00Z"
  "copyai-k8s-admin|copyai|2026-10-27T04:00:00Z|2026-10-27T05:00:00Z"
  "pipedrive-us-k8s-admin|pipedrive-us|2026-10-27T04:00:00Z|2026-10-27T05:00:00Z"
)

mkdir -p "$ROOT_OUT"
SUMMARY="${ROOT_OUT}/SUMMARY.md"
echo "# Cerberus RDS batch RCA" >"$SUMMARY"
echo >>"$SUMMARY"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$SUMMARY"
echo >>"$SUMMARY"

for entry in "${STACKS[@]}"; do
  IFS='|' read -r hoop stack start end <<<"$entry"
  out="${ROOT_OUT}/${stack}"
  log="[batch] ${stack} (${hoop})"
  echo "$log"
  args=(--hoop "$hoop" --stack "$stack" --out "$out")
  [ -n "$start" ] && args+=(--start "$start")
  [ -n "$end" ] && args+=(--end "$end")
  if ! "$RCA" "${args[@]}"; then
    echo "- **${stack}**: FAILED (see logs)" >>"$SUMMARY"
    continue
  fi
  echo "- **${stack}**: [report.md](${stack}/report.md)" >>"$SUMMARY"
done

echo >>"$SUMMARY"
echo "Done. Open ${SUMMARY}" >&2
