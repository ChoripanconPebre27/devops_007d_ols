#!/usr/bin/env bash
# Construye las dos imágenes DENTRO de minikube (no se necesita registro ni cuenta en la nube).
# Deja el tag usado en .last-tag para que 04-deploy.sh lo reutilice.
source "$(dirname "$0")/lib.sh"
need minikube

TAG="${TAG:-dev-$(date +%Y%m%d%H%M%S)}"
for svc in usuarios artelab; do
  log "Construyendo artelab-${svc}:${TAG}"
  minikube image build -t "artelab-${svc}:${TAG}" "$ROOT/${svc}"
done
echo "$TAG" > "$ROOT/.last-tag"
ok "Imágenes listas con tag ${TAG}"
