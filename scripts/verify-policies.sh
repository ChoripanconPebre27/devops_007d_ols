#!/usr/bin/env bash
# Verifica las políticas de seguridad EN EL CLUSTER (mTLS estricto + AuthorizationPolicy).
# Requiere el gateway disponible en $GATEWAY_URL (scripts/06-port-forward.sh).
source "$(dirname "$0")/lib.sh"
need kubectl
need curl

FAIL=0
check() { # descripción esperado obtenido
  if [ "$2" = "$3" ]; then
    ok "$1 (esperado $2)"
  else
    warn "FALLA: $1 -> esperado $2, obtenido ${3:-<vacío>}"
    FAIL=1
  fi
}
code() {
  curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$@" || true
}

log "1) Actuator no es accesible desde fuera de la malla"
check "GET /artelab/actuator/prometheus por el gateway" 403 "$(code "$GATEWAY_URL/artelab/actuator/prometheus")"
check "GET /usuarios/actuator/health por el gateway" 403 "$(code "$GATEWAY_URL/usuarios/actuator/health")"

log "2) /lookup de usuarios no es accesible desde el gateway (solo artelab)"
check "GET /usuarios/api/v1/usuarios/1/lookup por el gateway" 403 "$(code "$GATEWAY_URL/usuarios/api/v1/usuarios/1/lookup")"

log "3) mTLS estricto: un pod SIN sidecar no puede conectarse"

# Creamos el pod, esperamos a que termine y leemos
# sus logs una sola vez. La etiqueta fuerza que Istio no inyecte el sidecar.
POD="verify-mtls-${GITHUB_RUN_ID:-local}-$$"
cleanup_mtls() {
  kubectl -n default delete pod "$POD" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup_mtls EXIT

if ! kubectl run "$POD" -n default \
    --image=curlimages/curl:8.10.1 \
    --restart=Never \
    --labels='sidecar.istio.io/inject=false' \
    --command -- sh -c \
    'curl -s -o /dev/null -w "%{http_code}" --max-time 8 "$1" 2>/dev/null || true' \
    sh "http://usuarios.${NS}.svc.cluster.local:8081/actuator/health" \
    >/dev/null; then
  warn "FALLA: no se pudo crear el pod temporal para probar mTLS"
  FAIL=1
else
  CONTAINERS="$(kubectl -n default get pod "$POD" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || true)"
  case " $CONTAINERS " in
    *" istio-proxy "*)
      warn "FALLA: el pod de prueba recibió istio-proxy; no es una prueba válida sin sidecar"
      FAIL=1
      ;;
    *)
      if kubectl -n default wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$POD" --timeout=90s >/dev/null; then
        OUT="$(kubectl -n default logs "$POD" 2>/dev/null | tr -d '\r\n')"
        check "pod sin sidecar -> usuarios" 000 "$OUT"
      else
        warn "FALLA: el pod de prueba no terminó dentro de 90 segundos"
        kubectl -n default describe pod "$POD" 2>/dev/null | tail -15 >&2 || true
        FAIL=1
      fi
      ;;
  esac
fi
cleanup_mtls
trap - EXIT

log "4) El login público sigue funcionando por el gateway (la política no rompe el flujo legítimo)"
c="$(code -X POST "$GATEWAY_URL/usuarios/api/v1/auth/login" -H 'Content-Type: application/json' -d '{"correo":"admin@mail.cl","clave":"admin123"}')"
check "POST /usuarios/api/v1/auth/login" 200 "$c"

[ "$FAIL" = 0 ] && ok "Todas las políticas se cumplen" || { warn "Hay políticas que no se cumplen"; exit 1; }
