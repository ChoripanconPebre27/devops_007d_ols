#!/usr/bin/env bash
# Abre en paralelo los accesos locales (Ctrl+C los cierra todos):
#   Gateway Istio -> http://localhost:8080   (rutas /artelab/... y /usuarios/...)
#   Kiali         -> http://localhost:20001
#   Grafana       -> http://localhost:3000
#   Prometheus    -> http://localhost:9090
source "$(dirname "$0")/lib.sh"
need kubectl
pids=()
trap 'kill "${pids[@]}" 2>/dev/null || true' EXIT INT TERM
fwd() { kubectl -n istio-system port-forward "svc/$1" "$2" >/dev/null 2>&1 & pids+=($!); ok "$1 -> http://localhost:${2%%:*}"; }
fwd istio-ingressgateway 8080:80
kubectl -n istio-system get svc kiali      >/dev/null 2>&1 && fwd kiali 20001:20001
kubectl -n istio-system get svc grafana    >/dev/null 2>&1 && fwd grafana 3000:3000
kubectl -n istio-system get svc prometheus >/dev/null 2>&1 && fwd prometheus 9090:9090
echo "Presiona Ctrl+C para cerrar."; wait
