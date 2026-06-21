#!/usr/bin/env bash
set -euo pipefail

# Path to the docker-compose file
COMPOSE_FILE="/home/bbsebb/Programmation/vps-config/observability/docker-compose.yml"

echo "=== Cleaning up any existing containers ==="
docker compose -f "$COMPOSE_FILE" down -v --remove-orphans || true

echo "=== Starting docker-compose stack ==="
# Export dummy credentials for Grafana to avoid warnings
export GF_SECURITY_ADMIN_USER=admin
export GF_SECURITY_ADMIN_PASSWORD=adminpassword

docker compose -f "$COMPOSE_FILE" up -d

# Cleanup function on exit
cleanup() {
    echo "=== Cleaning up and stopping containers ==="
    docker compose -f "$COMPOSE_FILE" down -v
}
trap cleanup EXIT

echo "=== Waiting for services to start and stabilize ==="
# Wait up to 50 seconds, checking every 5 seconds
max_attempts=10
attempt=1
all_healthy=false

while [ $attempt -le $max_attempts ]; do
    echo "Attempt $attempt of $max_attempts..."
    sleep 5
    
    # Check status/health of services
    states=$(docker compose -f "$COMPOSE_FILE" ps --format json)
    echo "Current states:"
    echo "$states"
    
    # We want to check if any container is in exited state or restarting/failing
    exited_count=$(docker compose -f "$COMPOSE_FILE" ps --filter "status=exited" --format json | grep -c "exited" || echo "0")
    restarting_count=$(docker compose -f "$COMPOSE_FILE" ps | grep -E -c "Restarting|restarting" || echo "0")
    if [ "$exited_count" -gt 0 ] || [ "$restarting_count" -gt 0 ]; then
        echo "Warning: Some containers have exited or are restarting!"
        docker compose -f "$COMPOSE_FILE" ps
        docker compose -f "$COMPOSE_FILE" logs
        exit 1
    fi
    
    # Check if we can reach the health endpoints
    # Prometheus health
    prom_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy || echo "failed")
    # Loki readiness
    loki_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3100/ready || echo "failed")
    # Grafana health
    grafana_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health || echo "failed")
    # Tempo status
    tempo_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3200/status || echo "failed")
    
    echo "Health statuses: Prometheus=$prom_status, Loki=$loki_status, Grafana=$grafana_status, Tempo=$tempo_status"
    
    if [ "$prom_status" = "200" ] && [ "$loki_status" = "200" ] && [ "$grafana_status" = "200" ] && [ "$tempo_status" = "200" ]; then
        all_healthy=true
        break
    fi
    
    attempt=$((attempt + 1))
done

if [ "$all_healthy" = "true" ]; then
    if docker compose -f "$COMPOSE_FILE" logs otel-collector | grep -i "deprecated" > /dev/null; then
        echo "=== FAILURE: Deprecation warnings found in otel-collector logs! ==="
        docker compose -f "$COMPOSE_FILE" logs otel-collector
        exit 1
    fi

    echo "=== Testing log propagation to Loki ==="
    current_time_ns=$(date +%s000000000)
    json_payload=$(cat <<EOF
{
  "resourceLogs": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": {
              "stringValue": "test-service"
            }
          }
        ]
      },
      "scopeLogs": [
        {
          "logRecords": [
            {
              "timeUnixNano": "${current_time_ns}",
              "body": {
                "stringValue": "This is a test log message from Antigravity!"
              },
              "attributes": [
                {
                  "key": "log.type",
                  "value": {
                    "stringValue": "test"
                  }
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
EOF
)

    echo "Sending test log to otel-collector OTLP HTTP endpoint..."
    curl -s -X POST -H "Content-Type: application/json" -d "$json_payload" http://localhost:4318/v1/logs

    echo "Waiting for log to propagate..."
    sleep 6

    echo "Querying Loki..."
    loki_response=$(curl -s -G "http://localhost:3100/loki/api/v1/query_range" --data-urlencode 'query={service_name="test-service"}')
    echo "Loki response: $loki_response"

    if echo "$loki_response" | grep -F "This is a test log message from Antigravity!" > /dev/null; then
        echo "=== SUCCESS: Log successfully ingested and queried from Loki! ==="
    else
        echo "=== FAILURE: Log propagation failed! ==="
        echo "otel-collector logs:"
        docker compose -f "$COMPOSE_FILE" logs otel-collector
        echo "Loki logs:"
        docker compose -f "$COMPOSE_FILE" logs loki
        exit 1
    fi

    echo "=== SUCCESS: All services are healthy and responding! ==="
    exit 0
else
    echo "=== FAILURE: Services failed to become healthy in time ==="
    echo "Container status:"
    docker compose -f "$COMPOSE_FILE" ps
    echo "Logs from stack:"
    docker compose -f "$COMPOSE_FILE" logs
    exit 1
fi
