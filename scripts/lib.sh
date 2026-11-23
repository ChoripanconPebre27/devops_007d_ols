#!/usr/bin/env bash
# Funciones comunes. Se usa con:  source "$(dirname "$0")/lib.sh"
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS="${NS:-artelab}"
GATEWAY_URL="${GATEWAY_URL:-http://localhost:8080}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m OK\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "No se encontró '$1' en el PATH."; }

# Espera a que una URL responda 2xx (por defecto 60 s)
wait_http() {
  local url="$1" tries="${2:-30}"
  for _ in $(seq 1 "$tries"); do
    curl -fsS -o /dev/null --max-time 2 "$url" 2>/dev/null && return 0
    sleep 2
  done
  return 1
}
