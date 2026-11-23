#!/usr/bin/env bash
# Envía métricas del CI/CD al Pushgateway del cluster (de ahí las lee Prometheus y las muestra Grafana).
#   scripts/push-ci-metrics.sh                 -> calcula cobertura/pruebas locales (+ tiempo de despliegue si DEPLOY_DURATION está definido)
#   scripts/push-ci-metrics.sh ci-metrics.prom -> envía un archivo generado por GitHub Actions (artefacto "ci-metrics")
# METRICS_ENV (por defecto "minikube") separa las series locales de las de GitHub Actions.
source "$(dirname "$0")/lib.sh"
need kubectl; need curl

METRICS_ENV="${METRICS_ENV:-minikube}"
if [ "${1:-}" != "" ]; then
  [ -f "$1" ] || die "No existe el archivo $1"
  BODY="$(cat "$1")"; METRICS_ENV="${METRICS_ENV_FILE:-github-actions}"
else
  BODY="$("$ROOT/scripts/ci-metrics.sh" usuarios artelab || true)"
  if [ -n "${DEPLOY_DURATION:-}" ]; then
    BODY="${BODY}
ci_deploy_duration_seconds ${DEPLOY_DURATION}
ci_last_deploy_timestamp_seconds $(date +%s)"
  fi
fi
[ -n "$BODY" ] || die "No hay métricas que enviar (¿ejecutaste ./mvnw clean verify?)."

kubectl -n monitoring port-forward svc/pushgateway 9091:9091 >/dev/null 2>&1 &
PF=$!; trap 'kill $PF 2>/dev/null || true' EXIT
wait_http "http://localhost:9091/-/ready" 20 || die "Pushgateway no respondió (¿corriste scripts/02-observabilidad.sh?)"

printf '%s\n' "$BODY" | curl -fsS --data-binary @- "http://localhost:9091/metrics/job/ci_cd/env/${METRICS_ENV}"
ok "Métricas enviadas (env=${METRICS_ENV}):"; printf '%s\n' "$BODY"
