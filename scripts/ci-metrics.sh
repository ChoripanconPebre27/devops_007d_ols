#!/usr/bin/env bash
# Imprime (a stdout) métricas del proceso CI/CD en formato texto de Prometheus, para los
# servicios indicados:  scripts/ci-metrics.sh usuarios artelab
#  - ci_test_line_coverage_ratio : cobertura de líneas de JaCoCo (mismas exclusiones que el gate del pom)
#  - ci_tests_total              : pruebas ejecutadas según surefire
# Sin líneas "# TYPE" a propósito: así se pueden concatenar varios archivos sin duplicar familias.
set -euo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for svc in "$@"; do
  csv="$ROOT/$svc/target/site/jacoco/jacoco.csv"
  if [ -f "$csv" ]; then
    awk -F, -v s="$svc" 'NR>1 && $2 !~ /\.(config|security|dto|model|assemblers|exception)(\.|$)/ && $3 !~ /Application$/ { m+=$8; c+=$9 }
         END { if (m+c>0) printf "ci_test_line_coverage_ratio{service=\"%s\"} %.4f\n", s, c/(m+c) }' "$csv"
  else
    echo "# sin reporte JaCoCo para $svc (ejecuta ./mvnw clean verify)" >&2
  fi
  if ls "$ROOT/$svc"/target/surefire-reports/TEST-*.xml >/dev/null 2>&1; then
    grep -ho ' tests="[0-9]*"' "$ROOT/$svc"/target/surefire-reports/TEST-*.xml \
      | grep -o '[0-9]*' | awk -v s="$svc" '{t+=$1} END {printf "ci_tests_total{service=\"%s\"} %d\n", s, t}'
  fi
done
