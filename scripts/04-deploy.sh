#!/usr/bin/env bash
# Construye (opcional) y despliega ArteLab en minikube con Istio, midiendo el tiempo de despliegue.
#   scripts/04-deploy.sh              -> construye imágenes + despliega
#   scripts/04-deploy.sh --sin-build  -> reutiliza el tag de .last-tag
source "$(dirname "$0")/lib.sh"
need kubectl

START=$(date +%s)
if [ "${1:-}" != "--sin-build" ]; then "$ROOT/scripts/03-build-images.sh"; fi
TAG="$(cat "$ROOT/.last-tag" 2>/dev/null)" || die "No hay .last-tag: ejecuta scripts/03-build-images.sh"

rand() { openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

log "Namespace y secretos (se crean una sola vez; no viven en el repositorio)"
kubectl apply -f "$ROOT/k8s/00-namespace.yaml"
kubectl -n "$NS" get secret usuarios-secrets >/dev/null 2>&1 || \
  kubectl -n "$NS" create secret generic usuarios-secrets --from-literal=jwt-secret="$(rand)"
kubectl -n "$NS" get secret artelab-secrets >/dev/null 2>&1 || \
  kubectl -n "$NS" create secret generic artelab-secrets \
    --from-literal=jwt-secret="$(rand)" \
    --from-literal=auth-username="${ADMIN_USER:-admin}" \
    --from-literal=auth-password="${ADMIN_PASSWORD:-$(rand | cut -c1-20)}"

log "Políticas de malla (mTLS estricto, autorización, telemetría)"
kubectl apply -f "$ROOT/k8s/istio/00-peer-authentication.yaml" -f "$ROOT/k8s/istio/30-telemetry.yaml"

log "Desplegando microservicios con el tag ${TAG}"
for svc in usuarios artelab; do
  f="$(ls "$ROOT"/k8s/[12]0-${svc}.yaml)"
  sed "s|artelab-${svc}:local|artelab-${svc}:${TAG}|" "$f" | kubectl apply -f -
done
kubectl apply -f "$ROOT/k8s/istio/10-gateway.yaml" -f "$ROOT/k8s/istio/20-authorization-policies.yaml"

for svc in usuarios artelab; do
  kubectl -n "$NS" rollout status "deployment/${svc}" --timeout=300s
done
DEPLOY_DURATION=$(( $(date +%s) - START ))
kubectl -n "$NS" get pods -o wide
ok "Despliegue completo en ${DEPLOY_DURATION}s (tag ${TAG})"

if kubectl -n monitoring get svc pushgateway >/dev/null 2>&1; then
  DEPLOY_DURATION="$DEPLOY_DURATION" "$ROOT/scripts/push-ci-metrics.sh" || warn "No se pudieron enviar las métricas (ver mensaje anterior)."
else
  warn "Pushgateway no instalado: ejecuta scripts/02-observabilidad.sh para ver el tiempo de despliegue en Grafana."
fi
