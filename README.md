# ArteLab SPA — Observabilidad y cumplimiento en un pipeline DevOps (Evaluación Parcial 3)

Dos microservicios Spring Boot (`artelab` y `usuarios`) desplegados en **Kubernetes (minikube) con Istio**, con
monitoreo (Prometheus + Kiali), un dashboard en Grafana, políticas de cumplimiento automatizadas y un pipeline
de GitHub Actions que **se detiene** ante fallas críticas de seguridad o calidad.

> **Sin AWS.** Todo corre en un computador con `minikube`, `kubectl` e `istioctl`. En lugar de CloudWatch se usa
> Prometheus (permitido por la pauta: "Prometheus, AWS CloudWatch o similar").

## 1. Mapa de la evaluación

| Indicador | Qué se pide | Dónde está |
|---|---|---|
| **IE1** Monitoreo (logs, métricas, errores, disponibilidad) | Prometheus u otra herramienta | §4 · `application.properties`, `k8s/*.yaml`, Prometheus/Kiali (addons de Istio), logs JSON + access logs de Envoy |
| **IE2** Despliegue orquestado con monitoreo automatizado | Kubernetes | §3 · `k8s/`, `scripts/04-deploy.sh`, job `deploy-k8s` del pipeline |
| **IE3** Dashboard (despliegue, cobertura, CPU/mem, errores) | Dashboard integrado al CI/CD | §5 · `k8s/monitoring/dashboards/artelab-observabilidad.json`, `scripts/push-ci-metrics.sh` |
| **IE4** Documentación de la integración y decisiones | Documentar | Este README (§6–§8) |
| **IE5** Políticas de cumplimiento | SonarQube / branch protection / scripts de auditoría | §7 · `scripts/audit-compliance.sh`, `k8s/istio/20-*.yaml`, Sonar, Snyk, Trivy, gitleaks, `scripts/configure-branch-protection.sh` |
| **IE6** El pipeline se detiene ante una falla crítica | Demostrarlo | §8 · `scripts/demo-falla-pipeline.sh` |

> Capturas y explicación de cada indicador: [`docs/EVIDENCIAS.md`](docs/EVIDENCIAS.md).

## 2. Arquitectura

```
                      (port-forward 8080)
 navegador/curl ─► istio-ingressgateway ──/usuarios/*──► usuarios (8081) ◄── lookup (solo identidad de artelab)
                    (Gateway+VirtualService) ──/artelab/*──► artelab  (8080) ─────────┘
                          mTLS STRICT + AuthorizationPolicy entre todos los pods (sidecar istio-proxy)

 Prometheus ──scrape──► istio-proxy:15020 (métricas de Envoy + /actuator/prometheus de la app, fusionadas)
 Prometheus ──scrape──► Pushgateway ◄── scripts/push-ci-metrics.sh (cobertura, pruebas, tiempo de despliegue)
 Grafana ──► Prometheus      Kiali ──► Prometheus + API de Kubernetes
```

| Servicio | Puerto | Responsabilidad |
|---|---|---|
| `artelab` | 8080 | Catálogo: productos, categorías, promociones. Llama a `usuarios` en `POST /api/v1/promociones/usuario/{id}` |
| `usuarios` | 8081 | Registro, login y consulta de usuarios |

Rutas por el gateway (ambos servicios tienen `/api/v1/auth/login`, por eso se separan por prefijo):
`/artelab/api/v1/...` y `/usuarios/api/v1/...`.

Tecnologías: Java 25, Spring Boot 4.0.10, SQLite + Flyway, JWT, JaCoCo, Micrometer/Prometheus, Docker, Kubernetes (minikube),
Istio (sidecars), Kiali, Grafana, GitHub Actions, Snyk, SonarCloud, Trivy, gitleaks, Dependabot.

## 3. Despliegue en minikube (IE2)

Requisitos: `docker`, `minikube`, `kubectl`, `istioctl`, `curl`, bash (Linux/macOS/WSL/Git Bash). Recomendado: 4 CPU y 6 GB de RAM para minikube.
Los comandos equivalentes uno a uno están en [`docs/DESPLIEGUE_MANUAL.md`](docs/DESPLIEGUE_MANUAL.md).

```bash
scripts/01-cluster.sh          # minikube + Istio (perfil demo) + Prometheus, Grafana y Kiali
scripts/02-observabilidad.sh   # Pushgateway + importa el dashboard en Grafana
scripts/04-deploy.sh           # construye imágenes en minikube, despliega y mide el tiempo de despliegue
scripts/06-port-forward.sh     # (otra terminal) gateway :8080, Kiali :20001, Grafana :3000, Prometheus :9090
scripts/05-generar-trafico.sh  # genera tráfico (incluye errores intencionales) para ver datos
```

Qué incluye el despliegue (`k8s/`):

- Sidecar de Istio inyectado automáticamente (`istio-injection=enabled` en el namespace `artelab`); los pods deben mostrar `READY 2/2`.
- Anotaciones `prometheus.io/*` en los pods: Istio fusiona las métricas de la app con las del proxy y Prometheus las recoge aun con mTLS estricto.
- Sondas `startup/readiness/liveness` contra `/actuator/health/*`, límites de CPU/memoria, usuario no root (UID 10001), sistema de archivos de solo lectura.
- Volumen persistente (PVC) por servicio para SQLite, `replicas: 1` y estrategia `Recreate`.
- Secretos (`*-secrets`) **generados en el despliegue**; no existen en el repositorio.

## 4. Monitoreo y observabilidad (IE1)

| Necesidad | Fuente | Cómo verlo |
|---|---|---|
| **Métricas de uso** (CPU, memoria, JVM) | cAdvisor + Micrometer (`/actuator/prometheus`) | Grafana, panel "Uso de recursos"; `kubectl top pods -n artelab` |
| **Disponibilidad** | `up` de Prometheus, sondas de Kubernetes, tasa de éxito de Istio | Grafana "Disponibilidad"; Kiali → Overview (salud por app) |
| **Errores** | `http_server_requests_seconds_count{status=~"5.."}`, `logback_events_total{level="error"}`, `istio_requests_total{response_code=~"[45].."}` | Grafana "Errores registrados"; Kiali → Graph (aristas en rojo) |
| **Logs** | Logs JSON de la app (formato `logstash`, ver `usuarios/docs/logging-format.md`) y *access logs* de Envoy (`Telemetry`) | `kubectl logs <pod> -c <app>` / `-c istio-proxy`; Kiali → Workloads → Logs |
| **Tráfico entre servicios** | Telemetría de Istio | Kiali → Graph, namespace `artelab` |

Cambios en la aplicación para esto: dependencia `micrometer-registry-prometheus`, exposición de `health,info,prometheus`,
sondas de salud, etiqueta `application=<servicio>` y histograma de latencia (ver `application.properties`).

## 5. Dashboard (IE3)

Archivo: `k8s/monitoring/dashboards/artelab-observabilidad.json` (importado por `scripts/02-observabilidad.sh`).
URL local: `http://localhost:3000/d/artelab-observabilidad`.

| Fila | Paneles | Origen |
|---|---|---|
| CI/CD | Cobertura de líneas, tiempo del último despliegue, pruebas ejecutadas, último despliegue, historiales | Pushgateway (`ci_*`) |
| Disponibilidad | Servicios UP, uptime, tasa de éxito | `up`, `process_uptime_seconds`, Istio |
| Recursos | CPU y memoria por pod, heap de la JVM | cAdvisor, Micrometer |
| Errores | 5xx (Spring), logs ERROR, 4xx/5xx en la malla | Micrometer, Istio |
| Tráfico | RPS y latencia p95 (Spring e Istio) | Micrometer, Istio |

**Integración con el CI/CD.** Las métricas `ci_*` las produce el propio proceso:

- **Local:** `scripts/04-deploy.sh` mide el tiempo de despliegue y llama a `scripts/push-ci-metrics.sh`, que lee la cobertura de
  `target/site/jacoco/jacoco.csv` (mismas exclusiones que el gate del `pom.xml`) y las pruebas de `surefire-reports`
  (ejecuta antes `./mvnw clean verify` en cada servicio) y las envía al Pushgateway (`env=minikube`).
- **GitHub Actions:** cada job de pruebas genera `ci-metrics-<servicio>.prom`; `deploy-k8s` los consolida con el tiempo de despliegue
  en el artefacto `ci-metrics`. Un runner no puede alcanzar tu minikube, así que se importa a mano:
  `scripts/push-ci-metrics.sh ci-metrics.prom` (queda como `env=github-actions`).

## 6. Cómo se integran las herramientas en el pipeline (IE4)

```
push / PR a develop o main
 ├─ compliance ─ audit-compliance.sh (políticas como código) + gitleaks (secretos)
 ├─ test-usuarios ─ Snyk(critical) → ./mvnw verify (pruebas + JaCoCo ≥80%) → ci-metrics → SonarCloud (Quality Gate)
 ├─ test-artelab  ─ (igual)
 └─ build-docker (needs: los 3 anteriores, solo push) ─ build → Trivy(CRITICAL, bloquea) → push a ghcr.io (tags latest y SHA)
     └─ deploy-k8s ─ minikube + Istio en el runner → despliega el SHA → verify-policies.sh → ci-metrics.prom
```

| Herramienta | Qué pregunta responde | Decisión técnica que habilita |
|---|---|---|
| Prometheus + Micrometer | ¿Está arriba? ¿Cuánto CPU/RAM/heap usa? ¿Cuántos 5xx hay? | Ajustar `requests/limits` y `MaxRAMPercentage`; decidir un rollback si suben los 5xx tras un despliegue |
| Kiali | ¿Quién llama a quién? ¿Dónde falla la cadena? ¿La config de Istio es válida? | Ubicar el servicio culpable de un error; detectar rutas/políticas mal configuradas antes de que fallen |
| Grafana (CI/CD) | ¿Empeora el tiempo de despliegue? ¿Baja la cobertura? | Frenar la entrega si la cobertura cae; revisar el tiempo de build/arranque si crece |
| JaCoCo / SonarCloud | ¿Las pruebas cubren lo suficiente? ¿Hay bugs/vulnerabilidades/deuda? | Aceptar o rechazar un PR por calidad objetiva (Quality Gate) |
| Snyk / Trivy / gitleaks | ¿Hay dependencias, imágenes o credenciales vulnerables? | Actualizar dependencias (Dependabot), cambiar imagen base, rotar secretos |
| Istio (mTLS + AuthorizationPolicy) | ¿Solo quien debe puede llamar a quién? | Reducir la superficie de ataque entre servicios |

Al revisar las métricas del dashboard sobre los datos de testeo, se llevó a la conclusión que no era necesario hacer cambios debido a que la cobertura supera en ambos casos el 80% (96,8 y 100%) y los servicios se mantuvieron en UP, por lo tanto no se necesitó de ajustes.

## 7. Políticas de cumplimiento (IE5)

| Política | Herramienta | Dónde se aplica |
|---|---|---|
| Higiene del repo, contenedores no root, manifiestos con probes/limits/tag fijo, sin Secrets en el repo, mTLS STRICT, Actuator denegado por el gateway, CI sin `continue-on-error` | `scripts/audit-compliance.sh` (script de auditoría) | Job `compliance`, y local |
| Cobertura de líneas ≥ 80% (excluye config, security, dto, model, assemblers, exception) | JaCoCo (`pom.xml`) | `./mvnw verify` |
| Calidad y seguridad del código (Quality Gate) | SonarCloud, con `sonar.qualitygate.wait=true` | `main` y PR hacia `main` |
| Dependencias con vulnerabilidades **críticas** | Snyk (`--severity-threshold=critical`) | Jobs `test-*` |
| Imágenes con vulnerabilidades **críticas** con corrección | Trivy (`--exit-code 1`) antes de publicar | Job `build-docker` |
| Secretos en el código | gitleaks (+ `.gitleaks.toml`) | Job `compliance` |
| Quién puede llamar a quién en tiempo de ejecución | `PeerAuthentication` STRICT + `AuthorizationPolicy` | Cluster; se prueba con `scripts/verify-policies.sh` |
| Cambios solo por PR con checks y 1 aprobación | Branch protection (`scripts/configure-branch-protection.sh`) | GitHub (`main`) |
| Actualización de dependencias | Dependabot | Semanal, hacia `develop` |

Para correr la auditoría local: `scripts/audit-compliance.sh` (no necesita cluster). Con el cluster arriba y el gateway abierto:
`scripts/verify-policies.sh` comprueba que Actuator y `/lookup` dan 403 desde el gateway, que un pod sin sidecar no se conecta (mTLS) y que el login legítimo sigue funcionando.

## 8. Demostración: el pipeline se detiene (IE6)

Cada comando crea una rama `demo/falla-*` (nunca toca `main`), la sube, y al abrir el Pull Request el pipeline queda en rojo y los jobs siguientes se omiten:

| Comando | Falla provocada | Job que debe detenerse |
|---|---|---|
| `scripts/demo-falla-pipeline.sh latest` | Manifiesto con imagen `:latest` | `compliance` |
| `scripts/demo-falla-pipeline.sh secreto` | Credencial en el código | `compliance` (gitleaks) |
| `scripts/demo-falla-pipeline.sh pruebas` | Prueba unitaria que falla | `test-usuarios` |

Evidencia a capturar: pestaña *Actions* con el job rojo y `build-docker`/`deploy-k8s` en *skipped*; el PR con el merge bloqueado
(si activaste branch protection); y la corrida verde en `main` para contrastar. Se limpia con `scripts/demo-falla-pipeline.sh limpiar` y cerrando el PR.

Falla en **ejecución** (observabilidad): `scripts/simular-falla-usuarios.sh` baja `usuarios` a 0 réplicas; verás 503, logs ERROR y 5xx en Grafana y la arista en rojo en Kiali.

## 9. Ejecución y pruebas de las aplicaciones

```bash
cd usuarios && ./mvnw clean verify     # pruebas + cobertura (falla bajo 80%) -> target/site/jacoco/index.html
cd artelab  && ./mvnw clean verify
docker compose up --build              # alternativa sin Kubernetes (usa docker-compose.yml)
```

Usuarios de prueba (perfil `dev` de `usuarios`): `admin@mail.cl / admin123`, `ana@mail.cl / ana123`, `luis@mail.cl / luis123`.
Documentación de la API: Swagger UI en `/doc/swagger-ui.html` de cada servicio (con `kubectl port-forward -n artelab svc/<servicio> <puerto>:<puerto>`).

Secretos del pipeline (GitHub → Settings → Secrets): `SNYK_TOKEN`, `SONAR_TOKEN_U`, `SONAR_TOKEN_A`; `GITHUB_TOKEN` lo entrega GitHub.
Si el repositorio pertenece a una **organización**, `gitleaks-action` puede exigir el secreto `GITLEAKS_LICENSE`.

## 10. Uso de Inteligencia Artificial

(Escrito por José Ignacio Salas)

Para este repositorio, la Inteligencia Artificial se utilizó como una herramienta de apoyo para la revisión y explicación del contenido ya entregado, facilitación de conocimiento extra y recomendaciones, consulta y corrección de errores de código, y para la redacción, estructuración y generación final del archivo README.md. Todas las decisiones de arquitectura, despliegue de Kubernetes e Istio, monitoreo y observabilidad, dashboard y todos los scripts fueron realizadas y comprobadas directamente por mi mismo.

## 11. Limitaciones conocidas

- SQLite en archivo: un solo pod por servicio; el despliegue usa `Recreate`, por lo que hay una breve interrupción al actualizar.
- Pushgateway sin persistencia: si su pod se reinicia, los paneles CI/CD quedan vacíos hasta el próximo despliegue o `push-ci-metrics.sh`.
- Kiali no muestra trazas distribuidas (no se instala Jaeger); la trazabilidad se apoya en logs, access logs y métricas.
- `/api/v1/usuarios/{id}/lookup` no exige JWT en la app (artelab no envía uno); el acceso lo restringe la `AuthorizationPolicy` a la identidad de artelab. Fuera de Istio (por ejemplo `docker compose`) ese endpoint queda abierto.
- Valores por defecto de desarrollo en `application*.properties` y `docker-compose.yml`; en Kubernetes los secretos se generan al desplegar.

## 12. Solución de problemas

| Síntoma | Qué revisar |
|---|---|
| Pods `READY 1/2` o sin sidecar | `kubectl get ns artelab --show-labels` (debe tener `istio-injection=enabled`); recrear los pods |
| Pod en `CrashLoopBackOff` por escritura | `kubectl -n artelab logs <pod> -c <app>`; el contenedor tiene raíz de solo lectura (solo `/data` y `/tmp` son escribibles) |
| Grafana/Kiali sin datos | Generar tráfico (`05-generar-trafico.sh`); revisar el rango de tiempo; `istioctl dashboard prometheus` → Status → Targets |
| Panel CI/CD vacío | Ejecutar `./mvnw clean verify` en ambos servicios y luego `scripts/push-ci-metrics.sh` |
| `minikube image build` falla | `minikube status`; probar `eval $(minikube docker-env)` y `docker build -t artelab-usuarios:v1 ./usuarios` |
| `istioctl analyze -n artelab` con avisos | Leer el mensaje: normalmente es un host/puerto mal escrito en `VirtualService` o `AuthorizationPolicy` |

## 13. Conclusiones y reflexiones individuales

(Escrito por José Ignacio Salas)

Luego de haber comprobado cada detalle en este nuevo avance del proyecto para la tercera evaluación, tanto en el despliegue de Kubernetes e Istio y sus configuraciones, como el monitoreo y observabilidad a través de Prometheus, Grafana y Kiali, que presentan múltiples formas de mostrar datos del proyecto, además de todos los scripts que ayudan en este proceso, puedo concluir que he podido desarrollarme de una manera más completa en el entendimiento de todos estos contenidos presentados en clases y que fueron aplicados debida y cuidadosamente para complementar los productos que ya estaban presentes en las evaluaciones anteriores.

En comparación con la evaluación anterior, los problemas no fueron varios. Lo que más pudo complicar el desarrollo en relación con el tiempo, fue mi dificultad para organizarme en cuanto al contenido. Una vez pude comprometerme con el aprendizaje, logré entenderlo y seguir adelante con el proyecto. Una vez atravesada esta barrera la construcción de todo fue un poco más simple de lo que creía, y llegué a disfrutar del proceso.

Aún así aparecieron más problemas en el camino. Por ejemplo, tuve que observar cuales eran los problemas al comprobar que, al seguir los pasos para armar todo localmente, a veces tenía problemas para generar el tráfico. También ocurrió que, incluso después de haber resuelto todos mis problemas locales y solucionado los inconvenientes para que todo el monitoreo funcionara, seguía encontrando más trabas con los Actions de GitHub (quitar bases de datos, actualizar la versión de Spring Boot o también actualizar la versión de Maven).

Siento que estas nuevas experiencias serán muy importantes para mi futuro porque, con ellas, podré desarrollar aplicaciones sin tener miedo a preguntarme si algo fallará. Con estos sistemas, puedo identificar errores, monitorear la disponibilidad, revisar métricas y observar la comunicación entre microservicios. Gracias a todo lo anterior, puedo tener la seguridad de que la automatización me permitirá identificar problemas de manera anticipada, para que puedan resolverse a la brevedad y así generar mayor seguridad para todos los usuarios que utilicen mi servicio.

Si hay algo que siento que podría mejorar, sería hacer que la simulación de fallas no sea manual, sino que también se ejecute de manera automática.