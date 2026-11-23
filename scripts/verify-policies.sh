#!/usr/bin/env bash
# Verifica las políticas de seguridad EN EL CLUSTER (mTLS estricto + AuthorizationPolicy).
# Sale con código 1 si alguna no se cumple. Requiere el gateway en $GATEWAY_URL (06-port-forward.sh).
source "$(dirname "$0")/lib.sh"
need kubectl; need curl
FAIL=0
check() { # descripción esperado obtenido
  if [ "$2" = "$3" ]; then ok "$1 (esperado $2)"; else warn "FALLA: $1 -> esperado $2, obtenido $3"; FAIL=1; fi
}
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$@" || true; }

log "1) Actuator no es accesible desde fuera de la malla"
check "GET /artelab/actuator/prometheus por el gateway" 403 "$(code "$GATEWAY_URL/artelab/actuator/prometheus")"
check "GET /usuarios/actuator/health por el gateway"    403 "$(code "$GATEWAY_URL/usuarios/actuator/health")"

log "2) /lookup de usuarios no es accesible desde el gateway (solo artelab)"
check "GET /usuarios/api/v1/usuarios/1/lookup por el gateway" 403 "$(code "$GATEWAY_URL/usuarios/api/v1/usuarios/1/lookup")"

log "3) mTLS estricto: un pod SIN sidecar (namespace default) no puede conectarse"
OUT="$(kubectl run verify-mtls -n default --image=curlimages/curl:8.10.1 --restart=Never --rm -i --quiet \
        --command -- curl -s -o /dev/null -w '%{http_code}' --max-time 6 "http://usuarios.${NS}.svc.cluster.local:8081/actuator/health" 2>/dev/null || true)"
check "pod sin sidecar -> usuarios" 000 "${OUT:-000}"

log "4) El login público sigue funcionando por el gateway (la política no rompe el flujo legítimo)"
c="$(code -X POST "$GATEWAY_URL/usuarios/api/v1/auth/login" -H 'Content-Type: application/json' -d '{"correo":"admin@mail.cl","clave":"admin123"}')"
check "POST /usuarios/api/v1/auth/login" 200 "$c"

[ "$FAIL" = 0 ] && ok "Todas las políticas se cumplen" || { warn "Hay políticas que no se cumplen"; exit 1; }
