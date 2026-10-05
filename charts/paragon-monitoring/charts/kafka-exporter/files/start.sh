#!/bin/sh
set -eu
KAFKA_SERVER_ARGS=""
IFS=','
for broker in $MONITOR_MANAGED_SYNC_KAFKA_BROKER_URLS; do
    KAFKA_SERVER_ARGS="$KAFKA_SERVER_ARGS --kafka.server=$broker"
done
IFS=' '

echo "Generated kafka server arguments: $KAFKA_SERVER_ARGS"

# Respect configured mechanism (Azure Event Hubs uses plain + $ConnectionString).
# Normalize dashed SCRAM spellings only; do not force scram-sha512.
MECH="${MONITOR_MANAGED_SYNC_KAFKA_SASL_MECHANISM:-plain}"
case "$MECH" in
  scram-sha-512|SCRAM-SHA-512) MECH=scram-sha512 ;;
  scram-sha-256|SCRAM-SHA-256) MECH=scram-sha256 ;;
  plain|PLAIN) MECH=plain ;;
esac

exec /bin/kafka_exporter $KAFKA_SERVER_ARGS \
  --kafka.version=3.9.0 \
  $(if [ "$MONITOR_MANAGED_SYNC_KAFKA_SSL_ENABLED" = "true" ]; then echo "--sasl.enabled"; fi) \
  --sasl.mechanism="$MECH" \
  --sasl.username="$MONITOR_MANAGED_SYNC_KAFKA_SASL_USERNAME" \
  --sasl.password="$MONITOR_MANAGED_SYNC_KAFKA_SASL_PASSWORD" \
  $(if [ "$MONITOR_MANAGED_SYNC_KAFKA_SSL_ENABLED" = "true" ]; then echo "--tls.enabled"; fi)
