#!/usr/bin/env bash
# cerberus-rds-rca-hoop.sh
#
# Read-only Cerberus RDS + Kubernetes correlation for cross-customer RCA.
# Runs AWS CLI and kubectl inside a Hoop k8s-admin session (IRSA hoop-support).
#
# Prerequisites:
#   - hoop login   (or hoop config create + --api-key)
#   - jq (local, for report formatting; remote uses aws/kubectl only)
#
# Example (incident window):
#   ./scripts/cerberus-rds-rca-hoop.sh \
#     --hoop crewai-k8s-admin --stack crewai \
#     --start 2026-10-30T01:00:00Z --end 2026-10-30T02:00:00Z \
#     --out /tmp/cerberus-rca/crewai
#
# Example (baseline only):
#   ./scripts/cerberus-rds-rca-hoop.sh --hoop boosted-k8s-admin --stack boosted --out /tmp/cerberus-rca/boosted
#
set -euo pipefail

LOG_PREFIX="[cerberus-rds-rca]"

HOOP_CONN=""
STACK=""
OUT_DIR=""
START_ISO=""
END_ISO=""
BASELINE_DAYS=90
NAMESPACE="${NAMESPACE:-paragon}"

usage() {
  cat <<'EOF'
cerberus-rds-rca-hoop.sh — collect Cerberus RDS + k8s evidence via Hoop k8s-admin

Required:
  --hoop NAME       Hoop connection (e.g. crewai-k8s-admin)
  --out DIR         Directory to write report artifacts

Optional:
  --stack LABEL     Human label for reports (default: hoop connection name)
  --start ISO8601   Incident window start (UTC), e.g. 2026-10-30T01:00:00Z
  --end ISO8601     Incident window end (UTC)
  --baseline-days N CloudWatch daily freeable-memory lookback (default: 90)
  --namespace NS    Kubernetes namespace (default: paragon)

Output:
  report.md         Summary for PARA-27783 / SEV threads
  rds-instance.json RDS describe-db-instances
  rds-events.json   RDS events (window + last 7d)
  cw-*.json         CloudWatch metric dumps
  k8s-*.txt         Cerberus deployment / HPA / pods / events
  pg-log-snippet.txt Last lines of postgresql error log (if readable)
EOF
}

log() { printf '%s %s\n' "$LOG_PREFIX" "$*"; }
die() { log "ERROR: $*"; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --hoop) HOOP_CONN="$2"; shift 2 ;;
    --stack) STACK="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    --start) START_ISO="$2"; shift 2 ;;
    --end) END_ISO="$2"; shift 2 ;;
    --baseline-days) BASELINE_DAYS="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done

[ -n "$HOOP_CONN" ] || die "--hoop is required"
[ -n "$OUT_DIR" ] || die "--out is required"
[ -x "$(command -v hoop)" ] || die "hoop CLI not found; install and run 'hoop login'"
[ -x "$(command -v jq)" ] || die "jq required locally for report assembly"

STACK="${STACK:-$HOOP_CONN}"
mkdir -p "$OUT_DIR"

# Remote command is fed on stdin to the connection's bash (see migrate-openobserve-password.sh).
hoop_exec() {
  local remote_cmd="$1"
  local err
  err="$(mktemp)"
  hoop exec "$HOOP_CONN" -s -i "$remote_cmd" 2>"$err" || {
    log "hoop exec failed; stderr: $(tr '\n' ' ' <"$err")"
    rm -f "$err"
    return 1
  }
  rm -f "$err"
}

hoop_exec_capture() {
  local remote_cmd="$1"
  local out err
  out="$(mktemp)"
  err="$(mktemp)"
  if ! hoop exec "$HOOP_CONN" -s -i "$remote_cmd" >"$out" 2>"$err"; then
    log "hoop exec failed; stderr: $(tr '\n' ' ' <"$err")"
    rm -f "$out" "$err"
    return 1
  fi
  rm -f "$err"
  cat "$out"
  rm -f "$out"
}

REMOTE_DISCOVER=$(cat <<'REMOTE'
set -euo pipefail
command -v aws >/dev/null || { echo "NO_AWS"; exit 2; }
command -v kubectl >/dev/null || { echo "NO_KUBECTL"; exit 2; }
REGION="$(aws configure get region 2>/dev/null || true)"
if [ -z "$REGION" ]; then
  REGION="$(curl -fsS --max-time 2 http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || true)"
fi
[ -n "$REGION" ] || { echo "NO_REGION"; exit 2; }
DB_ID="$(aws rds describe-db-instances --region "$REGION" \
  --query "DBInstances[?contains(DBInstanceIdentifier, 'cerberus')].DBInstanceIdentifier | [0]" \
  --output text 2>/dev/null || true)"
if [ -z "$DB_ID" ] || [ "$DB_ID" = "None" ]; then
  DB_ID="$(aws rds describe-db-instances --region "$REGION" \
    --query 'DBInstances[].DBInstanceIdentifier' --output text | tr '\t' '\n' | grep -i cerberus | head -1 || true)"
fi
echo "REGION=${REGION}"
echo "DB_ID=${DB_ID:-NOT_FOUND}"
REMOTE
)

log "discovering region and Cerberus RDS via ${HOOP_CONN}..."
DISCOVER_OUT="$(hoop_exec_capture "$REMOTE_DISCOVER" || true)"
echo "$DISCOVER_OUT" >"$OUT_DIR/discover.txt"
REGION="$(echo "$DISCOVER_OUT" | sed -n 's/^REGION=//p')"
DB_ID="$(echo "$DISCOVER_OUT" | sed -n 's/^DB_ID=//p')"

if [ -z "$REGION" ] || [ "$DB_ID" = "NOT_FOUND" ] || [ -z "$DB_ID" ]; then
  die "could not resolve Cerberus RDS in remote session; see ${OUT_DIR}/discover.txt"
fi
log "region=${REGION} db=${DB_ID}"

# Time bounds for AWS CLI (GNU date)
NOW_EPOCH="$(date -u +%s)"
BASELINE_START="$(date -u -d "@$((NOW_EPOCH - BASELINE_DAYS * 86400))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-"${BASELINE_DAYS}"d +%Y-%m-%dT%H:%M:%SZ)"
SEVEN_D_START="$(date -u -d "@$((NOW_EPOCH - 7 * 86400))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-7d +%Y-%m-%dT%H:%M:%SZ)"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

WIN_START="${START_ISO:-$SEVEN_D_START}"
WIN_END="${END_ISO:-$NOW_ISO}"

REMOTE_RDS=$(cat <<REMOTE
set -euo pipefail
REGION='${REGION}'
DB_ID='${DB_ID}'
WIN_START='${WIN_START}'
WIN_END='${WIN_END}'
SEVEN_D_START='${SEVEN_D_START}'
BASELINE_START='${BASELINE_START}'
NOW_ISO='${NOW_ISO}'

aws rds describe-db-instances --region "\$REGION" --db-instance-identifier "\$DB_ID" > /tmp/rds-instance.json
aws rds describe-events --region "\$REGION" \
  --source-identifier "\$DB_ID" --source-type db-instance \
  --start-time "\$WIN_START" --end-time "\$NOW_ISO" > /tmp/rds-events-window.json
aws rds describe-events --region "\$REGION" \
  --source-identifier "\$DB_ID" --source-type db-instance \
  --start-time "\$SEVEN_D_START" --end-time "\$NOW_ISO" > /tmp/rds-events-7d.json 2>/dev/null || cp /tmp/rds-events-window.json /tmp/rds-events-7d.json

METRICS="CPUUtilization DatabaseConnections FreeableMemory SwapUsage ReadLatency WriteLatency DiskQueueDepth"
for m in \$METRICS; do
  aws cloudwatch get-metric-statistics --region "\$REGION" \
    --namespace AWS/RDS --metric-name "\$m" \
    --dimensions Name=DBInstanceIdentifier,Value="\$DB_ID" \
    --start-time "\$WIN_START" --end-time "\$NOW_ISO" \
    --period 60 --statistics Average Maximum Minimum \
    > "/tmp/cw-\${m}.json"
done

aws cloudwatch get-metric-statistics --region "\$REGION" \
  --namespace AWS/RDS --metric-name FreeableMemory \
  --dimensions Name=DBInstanceIdentifier,Value="\$DB_ID" \
  --start-time "\$BASELINE_START" --end-time "\$NOW_ISO" \
  --period 86400 --statistics Minimum Average \
  > /tmp/cw-FreeableMemory-daily.json

LOGFILE="\$(aws rds describe-db-log-files --region "\$REGION" --db-instance-identifier "\$DB_ID" \
  --query 'DescribeDBLogFiles[?contains(LogFileName, \`error/postgresql\`)].LogFileName | [-1]' --output text 2>/dev/null || true)"
if [ -n "\$LOGFILE" ] && [ "\$LOGFILE" != "None" ]; then
  aws rds download-db-log-file-portion --region "\$REGION" \
    --db-instance-identifier "\$DB_ID" --log-file-name "\$LOGFILE" \
    --number-of-lines 400 > /tmp/pg-log-snippet.txt 2>/dev/null || true
fi

for f in /tmp/rds-instance.json /tmp/rds-events-window.json /tmp/rds-events-7d.json /tmp/cw-*.json /tmp/pg-log-snippet.txt; do
  [ -f "\$f" ] || continue
  echo "__FILE__:\$(basename "\$f")"
  base64 -w0 "\$f" 2>/dev/null || base64 "\$f"
  echo
done
REMOTE
)

log "collecting RDS metrics and events..."
BUNDLE="$(hoop_exec_capture "$REMOTE_RDS")" || die "remote RDS collection failed"

parse_base64_bundle() {
  local name="" payload=""
  while IFS= read -r line; do
    if [[ "$line" == __FILE__:* ]]; then
      if [ -n "$name" ] && [ -n "$payload" ]; then
        printf '%s' "$payload" | base64 -d >"$OUT_DIR/$name"
      fi
      name="${line#__FILE__:}"
      payload=""
    elif [ -n "$name" ]; then
      payload+="$line"
    fi
  done <<< "$BUNDLE"
  if [ -n "$name" ] && [ -n "$payload" ]; then
    printf '%s' "$payload" | base64 -d >"$OUT_DIR/$name"
  fi
}

parse_base64_bundle

REMOTE_K8S=$(cat <<REMOTE
set -euo pipefail
NS='${NAMESPACE}'
{
  echo "=== deployment/cerberus ==="
  kubectl get deploy cerberus -n "\$NS" -o wide 2>&1 || true
  echo
  echo "=== hpa/cerberus ==="
  kubectl get hpa cerberus -n "\$NS" -o wide 2>&1 || true
  echo
  echo "=== pods (cerberus) ==="
  kubectl get pods -n "\$NS" 2>/dev/null | grep -E '^NAME|cerberus' || kubectl get pods -n "\$NS" -l 'app.kubernetes.io/name=cerberus' 2>&1 || true
  echo
  echo "=== VERSION env ==="
  kubectl get deploy cerberus -n "\$NS" -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' 2>/dev/null | grep -E '^VERSION=' || true
  echo
  echo "=== rollout restart annotation ==="
  kubectl get deploy cerberus -n "\$NS" -o jsonpath='{.spec.template.metadata.annotations.kubectl\.kubernetes\.io/restartedAt}' 2>/dev/null; echo
  echo
  echo "=== warning events (last 40) ==="
  kubectl get events -n "\$NS" --field-selector type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -40 || true
} 2>&1
REMOTE
)

log "collecting Kubernetes cerberus state..."
hoop_exec_capture "$REMOTE_K8S" >"$OUT_DIR/k8s-cerberus.txt" || log "warn: k8s collection partial failure"

# Local report
INSTANCE_CLASS="$(jq -r '.DBInstances[0].DBInstanceClass // "unknown"' "$OUT_DIR/rds-instance.json" 2>/dev/null || echo unknown)"
ENGINE="$(jq -r '.DBInstances[0].EngineVersion // "unknown"' "$OUT_DIR/rds-instance.json" 2>/dev/null || echo unknown)"
MULTI_AZ="$(jq -r '.DBInstances[0].MultiAZ // false' "$OUT_DIR/rds-instance.json" 2>/dev/null || echo false)"
PI_ID="$(jq -r '.DBInstances[0].DbiResourceId // "unknown"' "$OUT_DIR/rds-instance.json" 2>/dev/null || echo unknown)"

FREE_MEM_MIN_WIN="$(jq '[.Datapoints[].Minimum // .Datapoints[].Average] | min // empty' "$OUT_DIR/cw-FreeableMemory.json" 2>/dev/null || true)"
FREE_MEM_MIN_BASELINE="$(jq '[.Datapoints[].Minimum] | min // empty' "$OUT_DIR/cw-FreeableMemory-daily.json" 2>/dev/null || true)"
SWAP_MAX="$(jq '[.Datapoints[].Maximum] | max // 0' "$OUT_DIR/cw-SwapUsage.json" 2>/dev/null || echo 0)"
CONN_MAX="$(jq '[.Datapoints[].Maximum] | max // 0' "$OUT_DIR/cw-DatabaseConnections.json" 2>/dev/null || echo 0)"
CPU_MAX="$(jq '[.Datapoints[].Maximum] | max // 0' "$OUT_DIR/cw-CPUUtilization.json" 2>/dev/null || echo 0)"

bytes_to_mb() {
  local b="${1:-}"
  [ -n "$b" ] && [ "$b" != "null" ] || { echo "n/a"; return; }
  awk -v x="$b" 'BEGIN { printf "%.0f", x / 1048576 }'
}

PANIC_LINES=""
if [ -f "$OUT_DIR/pg-log-snippet.txt" ]; then
  PANIC_LINES="$(grep -E 'PANIC|spinlock|critically low|worker took too long' "$OUT_DIR/pg-log-snippet.txt" | tail -10 || true)"
fi

EVENTS_TEXT="$(jq -r '.Events[]? | "\(.Date) \(.Message)"' "$OUT_DIR/rds-events-window.json" 2>/dev/null | head -30 || true)"

{
  echo "# Cerberus RDS RCA — ${STACK}"
  echo
  echo "- **Hoop connection:** \`${HOOP_CONN}\`"
  echo "- **Collected (UTC):** ${NOW_ISO}"
  echo "- **Window:** ${WIN_START} → ${WIN_END}"
  echo "- **RDS identifier:** \`${DB_ID}\` (${REGION})"
  echo
  echo "## Instance"
  echo "- Class: \`${INSTANCE_CLASS}\`"
  echo "- Engine: PostgreSQL ${ENGINE}"
  echo "- Multi-AZ: ${MULTI_AZ}"
  echo "- Performance Insights resource: \`${PI_ID}\`"
  echo
  echo "## CloudWatch (window)"
  echo "- FreeableMemory min: **$(bytes_to_mb "$FREE_MEM_MIN_WIN") MB**"
  echo "- FreeableMemory daily min (${BASELINE_DAYS}d): **$(bytes_to_mb "$FREE_MEM_MIN_BASELINE") MB**"
  echo "- SwapUsage max: **${SWAP_MAX}** bytes"
  echo "- DatabaseConnections max: **${CONN_MAX}**"
  echo "- CPUUtilization max: **${CPU_MAX}%**"
  echo
  echo "## RDS events (window)"
  echo '```'
  echo "${EVENTS_TEXT:-none}"
  echo '```'
  echo
  if [ -n "$PANIC_LINES" ]; then
    echo "## PostgreSQL log signals"
    echo '```'
    echo "$PANIC_LINES"
    echo '```'
    echo
  fi
  echo "## Kubernetes (excerpt)"
  echo '```'
  head -80 "$OUT_DIR/k8s-cerberus.txt" 2>/dev/null || true
  echo '```'
  echo
  echo "Artifacts: \`$(basename "$OUT_DIR")\` directory (json + k8s-cerberus.txt)."
} >"$OUT_DIR/report.md"

log "wrote ${OUT_DIR}/report.md"
cat "$OUT_DIR/report.md"
