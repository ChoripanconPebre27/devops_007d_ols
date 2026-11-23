#!/usr/bin/env bash
# Auditoría automatizada de cumplimiento (política como código). NO necesita cluster ni red.
# Se ejecuta en el pipeline (job "compliance") y localmente. Código de salida 1 = incumplimiento CRÍTICO.
cd "$(dirname "$0")/.." || exit 2
FAIL=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
chk()  { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

echo "[1] Higiene del repositorio"
if git rev-parse --git-dir >/dev/null 2>&1; then
  chk "No hay bases de datos (*.db) versionadas"   '[ -z "$(git ls-files "*.db")" ]'
  chk "No hay archivos .env versionados"           '[ -z "$(git ls-files ".env" "**/.env")" ]'
else
  chk "No hay bases de datos (*.db) en el árbol"   '[ -z "$(find . -name "*.db" -not -path "./.git/*" | head -1)" ]'
fi
chk ".gitignore excluye *.db y .env"              'grep -qx "\*\.db" .gitignore && grep -qx "\.env" .gitignore'

echo "[2] Contenedores"
for s in usuarios artelab; do
  chk "$s/Dockerfile: build multi-stage"          "grep -q 'AS runtime' $s/Dockerfile"
  chk "$s/Dockerfile: no corre como root (USER)"  "grep -Eq '^USER +[0-9a-z]+' $s/Dockerfile && ! grep -Eq '^USER +root' $s/Dockerfile"
  chk "$s/Dockerfile: imagen base con tag fijo"   "grep -E '^FROM ' $s/Dockerfile | grep -vq ':latest'"
done

echo "[3] Manifiestos de Kubernetes"
for f in k8s/10-usuarios.yaml k8s/20-artelab.yaml; do
  chk "$f: imagen con tag explícito y distinto de latest" "grep -E '^\s+image:' $f | grep -Eq ':[A-Za-z0-9._-]+\$' && ! grep -E '^\s+image:' $f | grep -q ':latest'"
  chk "$f: límites de CPU/memoria (limits)"       "grep -q 'limits:' $f"
  chk "$f: readinessProbe y livenessProbe"        "grep -q 'readinessProbe:' $f && grep -q 'livenessProbe:' $f"
  chk "$f: runAsNonRoot y sin escalada de privilegios" "grep -q 'runAsNonRoot: true' $f && grep -q 'allowPrivilegeEscalation: false' $f"
done
chk "No hay Secrets dentro del repositorio"       '! grep -RIl "^kind: Secret" k8s'

echo "[4] Políticas de malla (Istio)"
chk "mTLS en modo STRICT"                          'grep -Rq "mode: STRICT" k8s/istio'
chk "Actuator denegado desde el gateway"           'grep -Rq "action: DENY" k8s/istio && grep -Rq "/actuator/\*" k8s/istio'
chk "Existen políticas ALLOW por servicio"         '[ "$(grep -Rc "action: ALLOW" k8s/istio/20-authorization-policies.yaml)" -ge 2 ]'

echo "[5] Aplicación y pipeline"
for s in usuarios artelab; do
  chk "$s: Actuator no expone todos los endpoints (*)" "! grep -Eq 'exposure.include *= *\*' $s/src/main/resources/application.properties"
  chk "$s: detalle de salud oculto"                    "grep -q 'show-details=never' $s/src/main/resources/application.properties"
  chk "$s: JaCoCo exige >= 80% de líneas"              "grep -q '<minimum>0.80</minimum>' $s/pom.xml"
done
CI=.github/workflows/ci.yml
chk "CI: ningún control de seguridad es 'continue-on-error'" "! grep -n 'continue-on-error' $CI | grep -v '#'"
chk "CI: SonarCloud espera el Quality Gate"        "grep -q 'sonar.qualitygate.wait=true' $CI"
chk "CI: escaneo Trivy de imágenes bloquea (exit-code 1)" "grep -q -- '--exit-code 1' $CI"
chk "CI: el despliegue depende de todos los controles" "grep -Eq 'needs: *\[compliance, *test-usuarios, *test-artelab\]' $CI"

echo
if [ "$FAIL" -gt 0 ]; then printf '\033[31mAUDITORÍA FALLIDA: %d incumplimiento(s)\033[0m\n' "$FAIL"; exit 1; fi
printf '\033[32mAUDITORÍA OK: cumple todas las políticas\033[0m\n'
