#!/usr/bin/env bash
# Configura reglas de protección de rama con GitHub CLI (gh). Requiere permisos de administrador del repo.
#   scripts/configure-branch-protection.sh [rama=main]
# Nota: en repositorios privados con plan gratuito GitHub no permite branch protection (el repo debe ser
# público o el plan de pago). Los nombres de "contexts" son los ids de los jobs de .github/workflows/ci.yml.
source "$(dirname "$0")/lib.sh"
need gh
RAMA="${1:-main}"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
log "Protegiendo ${REPO}@${RAMA}"
gh api -X PUT "repos/${REPO}/branches/${RAMA}/protection" --input - <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["compliance", "test-usuarios", "test-artelab"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": { "required_approving_review_count": 1 },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
ok "Regla aplicada: PR + 1 aprobación + checks obligatorios (compliance, test-usuarios, test-artelab)"
