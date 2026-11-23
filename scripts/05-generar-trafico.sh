#!/usr/bin/env bash
# Genera tráfico a través del gateway para que aparezca en Kiali, Prometheus y Grafana.
#   scripts/05-generar-trafico.sh [iteraciones=40] [--sin-errores]
# Requiere el gateway accesible (scripts/06-port-forward.sh en otra terminal) en $GATEWAY_URL.
source "$(dirname "$0")/lib.sh"
need curl; need kubectl

N=40; ERRORES=1
for a in "$@"; do case "$a" in --sin-errores) ERRORES=0 ;; *[0-9]*) N="$a" ;; esac; done

wait_http "$GATEWAY_URL/usuarios/api/v1/auth/login" 2 >/dev/null 2>&1 || true
curl -s -o /dev/null --max-time 5 "$GATEWAY_URL/" || die "El gateway no responde en $GATEWAY_URL. Ejecuta scripts/06-port-forward.sh en otra terminal."

token() { sed -n 's/.*"token":"\([^"]*\)".*/\1/p'; }
ADMIN_USER_V="$(kubectl -n "$NS" get secret artelab-secrets -o jsonpath='{.data.auth-username}' | base64 -d)"
ADMIN_PASS_V="$(kubectl -n "$NS" get secret artelab-secrets -o jsonpath='{.data.auth-password}' | base64 -d)"

TA="$(curl -s -X POST "$GATEWAY_URL/artelab/api/v1/auth/login" -H 'Content-Type: application/json' \
      -d "{\"username\":\"$ADMIN_USER_V\",\"password\":\"$ADMIN_PASS_V\"}" | token)"
TU="$(curl -s -X POST "$GATEWAY_URL/usuarios/api/v1/auth/login" -H 'Content-Type: application/json' \
      -d '{"correo":"admin@mail.cl","clave":"admin123"}' | token)"
[ -n "$TA" ] && [ -n "$TU" ] || die "No pude obtener los tokens (¿pods Ready? ¿DataLoader cargó los usuarios de prueba?)"

CAT="$(curl -s "$GATEWAY_URL/artelab/api/v1/categorias" -H "Authorization: Bearer $TA" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)"
CAT="${CAT:-1}"
declare -A cuenta
req() { # metodo ruta token [cuerpo]
  local code
  if [ -n "${4:-}" ]; then
    code=$(curl -s -o /dev/null -w '%{http_code}' -X "$1" "$GATEWAY_URL$2" -H "Authorization: Bearer $3" -H 'Content-Type: application/json' -d "$4")
  else
    code=$(curl -s -o /dev/null -w '%{http_code}' -X "$1" "$GATEWAY_URL$2" ${3:+-H "Authorization: Bearer $3"})
  fi
  cuenta[$code]=$(( ${cuenta[$code]:-0} + 1 ))
}
PROMO="{\"des\":\"Demo observabilidad\",\"fechaIni\":\"2026-01-01\",\"fechaTer\":\"2026-12-31\",\"descuento\":10,\"categoria\":{\"id\":$CAT}}"

log "Generando $N iteraciones contra $GATEWAY_URL (errores intencionales: $ERRORES)"
for i in $(seq 1 "$N"); do
  req GET  /artelab/api/v1/categorias   "$TA"
  req GET  /artelab/api/v1/productos    "$TA"
  req GET  /artelab/api/v1/promociones  "$TA"
  req GET  /usuarios/api/v1/usuarios    "$TU"
  req POST /artelab/api/v1/promociones/usuario/1 "$TA" "$PROMO"   # artelab -> usuarios (arista en Kiali)
  if [ "$ERRORES" = 1 ]; then
    req POST /artelab/api/v1/auth/login ""  '{"username":"x","password":"mala"}'        # 401
    req GET  /artelab/api/v1/productos/99999 "$TA"                                      # 404
    req POST /artelab/api/v1/promociones/usuario/99999 "$TA" "$PROMO"                   # 404 (lookup)
    req GET  /artelab/api/v1/productos                                                  # sin token: 401/403
    req GET  /artelab/actuator/prometheus                                               # 403 (política de Istio)
  fi
  sleep 0.3
done
log "Resumen de códigos HTTP:"; for c in "${!cuenta[@]}"; do printf '  %s : %s\n' "$c" "${cuenta[$c]}"; done | sort
