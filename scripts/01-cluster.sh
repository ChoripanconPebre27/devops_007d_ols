#!/usr/bin/env bash
# Prepara minikube + Istio (istioctl) + Prometheus, Grafana y Kiali (addons oficiales de Istio).
# Variables opcionales: CPUS (4), MEMORY (6144 MB), ISTIO_PROFILE (demo), ADDONS ("prometheus grafana kiali")
source "$(dirname "$0")/lib.sh"
need minikube; need kubectl; need istioctl

CPUS="${CPUS:-4}"; MEMORY="${MEMORY:-6144}"
ISTIO_PROFILE="${ISTIO_PROFILE:-demo}"
ADDONS="${ADDONS:-prometheus grafana kiali}"

if minikube status >/dev/null 2>&1; then
  ok "minikube ya está corriendo"
else
  log "Iniciando minikube (${CPUS} CPU, ${MEMORY} MB)"
  minikube start --cpus "$CPUS" --memory "$MEMORY"
fi
minikube addons enable metrics-server >/dev/null && ok "metrics-server habilitado (kubectl top)"
kubectl get nodes

log "Instalando Istio (perfil ${ISTIO_PROFILE}) con requests mínimos de recursos"
istioctl install -y \
  --set profile="${ISTIO_PROFILE}" \
  --set values.pilot.resources.requests.memory=256Mi \
  --set values.pilot.resources.requests.cpu=100m \
  --set values.global.proxy.resources.requests.cpu=50m \
  --set values.global.proxy.resources.requests.memory=128Mi

# Los addons deben ser de la misma versión menor que istioctl (p. ej. 1.26.2 -> release-1.26)
ISTIO_VERSION="$(istioctl version --remote=false 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
MINOR="${ADDONS_RELEASE:-$(echo "$ISTIO_VERSION" | cut -d. -f1,2)}"
[ -n "$MINOR" ] || die "No pude detectar la versión de istioctl. Define ADDONS_RELEASE=1.26 (por ejemplo)."
log "Instalando addons (${ADDONS}) desde istio release-${MINOR}"
for a in $ADDONS; do
  kubectl apply -f "https://raw.githubusercontent.com/istio/istio/release-${MINOR}/samples/addons/${a}.yaml"
done

for a in $ADDONS; do
  kubectl -n istio-system rollout status "deployment/${a}" --timeout=300s
done
kubectl -n istio-system rollout status deployment/istio-ingressgateway --timeout=300s
ok "Cluster listo. Siguiente paso: scripts/02-observabilidad.sh"
