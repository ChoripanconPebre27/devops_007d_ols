#!/usr/bin/env bash
# Simula la caída del servicio "usuarios": artelab responde 503 en las promociones por usuario,
# suben los 5xx y los logs ERROR en el dashboard. Al final restaura el servicio.
#   scripts/simular-falla-usuarios.sh [segundos=90]
source "$(dirname "$0")/lib.sh"
need kubectl
SEG="${1:-90}"
trap 'log "Restaurando usuarios"; kubectl -n "$NS" scale deploy/usuarios --replicas=1 >/dev/null; kubectl -n "$NS" rollout status deploy/usuarios --timeout=300s' EXIT
log "Escalando usuarios a 0 réplicas"
kubectl -n "$NS" scale deploy/usuarios --replicas=0
sleep 5
log "Generando tráfico durante ${SEG}s (verás 503 y errores en Grafana/Kiali)"
END=$(( $(date +%s) + SEG ))
while [ "$(date +%s)" -lt "$END" ]; do "$(dirname "$0")/05-generar-trafico.sh" 3 >/dev/null 2>&1 || true; done
