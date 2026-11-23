#!/usr/bin/env bash
# Despliega el Pushgateway (métricas del CI/CD) e importa el dashboard en Grafana.
source "$(dirname "$0")/lib.sh"
need kubectl; need curl

log "Desplegando Pushgateway en el namespace monitoring"
kubectl apply -f "$ROOT/k8s/monitoring/pushgateway.yaml"
kubectl -n monitoring rollout status deployment/pushgateway --timeout=120s

if ! kubectl -n istio-system get svc grafana >/dev/null 2>&1; then
  warn "Grafana no está instalado (ADDONS sin grafana): se omite la importación del dashboard."
  exit 0
fi

log "Importando dashboard en Grafana"
kubectl -n istio-system port-forward svc/grafana 3000:3000 >/dev/null 2>&1 &
PF=$!; trap 'kill $PF 2>/dev/null || true' EXIT
wait_http "http://localhost:3000/api/health" 30 || die "Grafana no respondió en localhost:3000"

DASH="$ROOT/k8s/monitoring/dashboards/artelab-observabilidad.json"
curl -fsS -X POST -H "Content-Type: application/json" \
  -d "{\"dashboard\": $(cat "$DASH"), \"overwrite\": true, \"folderId\": 0}" \
  "http://localhost:3000/api/dashboards/db" && echo
ok "Dashboard importado: http://localhost:3000/d/artelab-observabilidad (con scripts/06-port-forward.sh activo)"
