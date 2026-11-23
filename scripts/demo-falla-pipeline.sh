#!/usr/bin/env bash
# DEMOSTRACIÓN (IE6): provoca a propósito una falla en una rama NUEVA y la sube a GitHub para que
# el pipeline se detenga. Nunca toca main. Después abre un Pull Request y muestra la ejecución en rojo.
#   scripts/demo-falla-pipeline.sh latest    -> imagen con tag :latest   (falla el job "compliance")
#   scripts/demo-falla-pipeline.sh secreto   -> credencial en el código  (falla gitleaks, job "compliance")
#   scripts/demo-falla-pipeline.sh pruebas   -> prueba unitaria que falla (falla "test-usuarios")
#   scripts/demo-falla-pipeline.sh limpiar   -> vuelve a la rama anterior y borra la rama de demo local
cd "$(dirname "$0")/.." || exit 2
set -euo pipefail
TIPO="${1:-latest}"
if [ "$TIPO" = "limpiar" ]; then
  git checkout - && git branch -D "$(git branch --list 'demo/falla-*' | head -1 | tr -d ' *')" || true; exit 0
fi
[ -z "$(git status --porcelain)" ] || { echo "Hay cambios sin commitear: haz commit o stash antes."; exit 1; }
RAMA="demo/falla-${TIPO}-$(date +%Y%m%d%H%M%S)"
git checkout -b "$RAMA"
case "$TIPO" in
  latest)
    sed -i.bak 's|artelab-usuarios:local|artelab-usuarios:latest|' k8s/10-usuarios.yaml && rm -f k8s/10-usuarios.yaml.bak
    MSG="demo: imagen con tag latest (debe fallar la auditoría)" ;;
  secreto)
    printf 'aws_access_key_id = AKIAQWERTYUIOP234567\naws_secret_access_key = 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\n' > usuarios/credenciales-demo.txt
    MSG="demo: credencial en el código (debe fallar gitleaks)" ;;
  pruebas)
    cat > usuarios/src/test/java/dsy/artelab/usuarios/DemoFallaTest.java <<'JAVA'
package dsy.artelab.usuarios;

import static org.junit.jupiter.api.Assertions.assertEquals;
import org.junit.jupiter.api.Test;

class DemoFallaTest {
    @Test
    void fallaIntencional() {
        assertEquals(1, 2, "Falla intencional para demostrar que el pipeline se detiene");
    }
}
JAVA
    MSG="demo: prueba unitaria que falla (debe detener el pipeline)" ;;
  *) echo "Tipo inválido: latest | secreto | pruebas | limpiar"; exit 1 ;;
esac
echo "--- Auditoría local (debería fallar para 'latest'):"; ./scripts/audit-compliance.sh || true
git add -A && git commit -m "$MSG"
git push -u origin "$RAMA"
echo
echo "Listo. Abre un Pull Request de '$RAMA' hacia develop/main y muestra:"
echo "  - la pestaña Actions con el job en rojo y los jobs siguientes (build-docker, deploy-k8s) omitidos"
echo "  - el PR con el merge bloqueado (si configuraste scripts/configure-branch-protection.sh)"
