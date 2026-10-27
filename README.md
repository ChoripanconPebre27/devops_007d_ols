# ArteLab SPA — Microservicios con pipeline CI/CD

Proyecto de dos microservicios Spring Boot para una tienda digital de materiales artísticos, con contenedores Docker, pruebas automatizadas, análisis de seguridad y un pipeline de CI/CD en GitHub Actions que construye, publica y despliega las imágenes de forma automática.

## 1. Descripción

ArteLab quiere posicionarse como una tienda digital de materiales artísticos accesibles y de calidad. El sistema se divide en dos servicios independientes:

| Servicio | Carpeta | Puerto | Responsabilidad |
|---|---|---|---|
| `artelab` | `artelab/` | 8080 | Catálogo: productos, categorías y promociones |
| `usuarios` | `usuarios/` | 8081 | Registro, autenticación y consulta de usuarios |

`artelab` consulta a `usuarios` por HTTP en un único flujo: al crear una promoción asociada a un usuario (`POST /api/v1/promociones/usuario/{usuarioId}`), verifica que el usuario exista llamando a `GET /api/v1/usuarios/{id}/lookup`. Si el usuario no existe responde 404; si `usuarios` no responde o falla, responde 503.

```
   cliente ──► artelab (8080) ──HTTP──► usuarios (8081)
                  │                          │
               SQLite                     SQLite
            (artelab.db)               (usuarios.db)
```

## 2. Tecnologías

| Área | Tecnología |
|---|---|
| Lenguaje y framework | Java 25, Spring Boot 4.0.6 (Web MVC, WebFlux `WebClient`, Data JPA, Security, Validation, HATEOAS, Actuator) |
| Base de datos | SQLite (un archivo por servicio) con migraciones Flyway |
| Autenticación | JWT firmado con HMAC-SHA256, contraseñas con BCrypt |
| Documentación de API | springdoc-openapi (Swagger UI) |
| Pruebas | JUnit 5, Mockito, MockMvc, JaCoCo |
| Contenedores | Docker (multi-stage), Docker Compose |
| CI/CD | GitHub Actions, GitHub Container Registry (`ghcr.io`) |
| Seguridad y calidad | Snyk, SonarCloud, Dependabot |

## 3. Estructura del repositorio

```
devops_007d_ols/
├── .github/
│   ├── dependabot.yml            # actualización automática de dependencias
│   └── workflows/ci.yml          # pipeline CI/CD
├── artelab/                      # microservicio de catálogo
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── pom.xml
│   └── src/ (main, test)
├── usuarios/                     # microservicio de usuarios
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── pom.xml
│   └── src/ (main, test)
├── docker-compose.yml            # ejecución local (construye desde el código)
├── docker-compose.deploy.yml     # despliegue del pipeline (usa imágenes publicadas)
└── README.md
```

Cada servicio sigue la misma organización interna de paquetes: `controller` (rutas HTTP), `service` (reglas de negocio), `repository` (acceso a datos), `model`/`dto` (datos), `security` y `config` (seguridad y configuración) y `exception` (manejo global de errores).

## 4. Cómo ejecutar el proyecto

### 4.1 Con Docker Compose (recomendado)

Requisitos: Docker y Docker Compose (`docker --version`, `docker compose version`).

```bash
docker compose up --build
```

Desde la raíz del repositorio. La primera vez tarda más porque descarga las imágenes base y compila ambos proyectos con Maven.

| Servicio | URL | Swagger UI |
|---|---|---|
| artelab | http://localhost:8080 | http://localhost:8080/doc/swagger-ui.html |
| usuarios | http://localhost:8081 | http://localhost:8081/doc/swagger-ui.html |

Comandos útiles:

```bash
docker compose ps                    # estado y salud de los contenedores
docker compose logs -f artelab-api   # logs de un servicio
docker compose down                  # detiene y elimina los contenedores (los datos se conservan)
docker compose down -v               # además borra los volúmenes (se pierden los datos)
```

En Linux, si Docker responde `permission denied` sobre `/var/run/docker.sock`, agrega tu usuario al grupo `docker` (`sudo usermod -aG docker $USER`) y vuelve a iniciar sesión.

### 4.2 Sin Docker

Requisitos: JDK 25. Levanta primero `usuarios` y después `artelab`, cada uno en su carpeta:

```bash
cd usuarios && ./mvnw spring-boot:run
cd artelab  && ./mvnw spring-boot:run
```

### 4.3 Variables de entorno

Docker Compose define estas variables con un valor por defecto, así que el archivo `.env` es **opcional** (y no se versiona: está en `.gitignore`). Para cambiarlas, crea un `.env` en la raíz:

| Variable | Servicio | Descripción | Valor por defecto |
|---|---|---|---|
| `ARTELAB_JWT_SECRET` | artelab | Clave con la que se firman los JWT | secreto de desarrollo |
| `USUARIOS_JWT_SECRET` | usuarios | Clave con la que se firman los JWT | secreto de desarrollo |
| `ADMIN_USER` | artelab | Usuario del login de artelab | `admin` |
| `ADMIN_PASSWORD` | artelab | Clave del login de artelab | `admin123` |

Variables fijas en `docker-compose.yml`: `SPRING_DATASOURCE_URL` (apunta la base SQLite al volumen `/data`), `USUARIOS_SERVICE_BASE_URL` (`http://usuarios-api:8081`, nombre del servicio en la red de Compose) y `SPRING_PROFILES_ACTIVE=dev` en `usuarios` (activa la carga de usuarios de prueba).

Spring Boot convierte cada variable de entorno en la propiedad equivalente (por ejemplo `SPRING_DATASOURCE_URL` en `spring.datasource.url`) y le da prioridad sobre los archivos `application*.properties`.

## 5. API y autenticación

Todas las rutas, salvo las de autenticación, la documentación Swagger y `/actuator/health`, exigen un JWT en la cabecera `Authorization: Bearer <token>`.

| Servicio | Login | Datos de entrada |
|---|---|---|
| artelab | `POST /api/v1/auth/login` | `username` y `password` (usuario en memoria definido por configuración) |
| usuarios | `POST /api/v1/auth/login` | `correo` y `clave` (usuarios guardados en la base de datos) |

Usuarios de prueba que `usuarios` crea al iniciar con el perfil `dev`: `admin@mail.cl / admin123`, `ana@mail.cl / ana123`, `luis@mail.cl / luis123`.

| Recurso | Rutas |
|---|---|
| Categorías (artelab) | `GET/POST /api/v1/categorias`, `GET/PUT/DELETE /api/v1/categorias/{id}` |
| Productos (artelab) | `GET/POST /api/v1/productos`, `GET/PUT/DELETE /api/v1/productos/{id}` |
| Promociones (artelab) | `GET/POST /api/v1/promociones`, `POST /api/v1/promociones/usuario/{usuarioId}`, `GET/PUT/DELETE /api/v1/promociones/{id}` |
| Usuarios (usuarios) | `GET/POST /api/v1/usuarios`, `GET/PUT/DELETE /api/v1/usuarios/{id}`, `GET /api/v1/usuarios/{id}/lookup` |

Los errores se devuelven con un formato único (`GlobalExceptionHandler`): 400 por datos inválidos o reglas de negocio, 401 por credenciales inválidas, 404 si el recurso no existe, 409 por conflictos (por ejemplo, un correo ya registrado) y 503 si falla el servicio remoto.

## 6. Pruebas automatizadas

El proyecto tiene **91 pruebas unitarias** (63 en `artelab` y 28 en `usuarios`), con JUnit 5 y Mockito: servicios con dependencias simuladas y controladores con `MockMvc`.

```bash
cd artelab  && ./mvnw clean verify
cd usuarios && ./mvnw clean verify
```

`verify` corre las pruebas, genera el reporte de cobertura de JaCoCo (`target/site/jacoco/index.html`) y **falla si la cobertura de líneas es menor a 80%**. La regla excluye las clases de aplicación, `config`, `security`, `dto`, `model`, `assemblers` y `exception`. Los resultados de las pruebas quedan en `target/surefire-reports/`.

## 7. Pipeline CI/CD (`.github/workflows/ci.yml`)

### 7.1 Cuándo se ejecuta

En cada `push` a `develop` o `main` y en cada Pull Request hacia esas ramas.

### 7.2 Jobs

```
push / PR a develop o main
   ├── test-usuarios ─┐   (en paralelo)
   └── test-artelab  ─┤
                      └── build-docker ──► deploy   (solo en push)
```

| Job | Qué hace |
|---|---|
| `test-usuarios` y `test-artelab` | Escaneo de dependencias con Snyk, pruebas con cobertura (`./mvnw clean verify`), análisis de SonarCloud y publicación de reportes como artefactos |
| `build-docker` | Construye las dos imágenes (`linux/amd64` y `linux/arm64`) y las publica en `ghcr.io`. Solo corre si ambos jobs de prueba pasaron |
| `deploy` | Descarga las imágenes publicadas, las levanta con Docker Compose, espera a que estén saludables, ejecuta una verificación y destruye el entorno |

### 7.3 Secretos del repositorio

| Secreto | Uso |
|---|---|
| `SNYK_TOKEN` | Autenticación de Snyk |
| `SONAR_TOKEN_U` / `SONAR_TOKEN_A` | Autenticación de SonarCloud (proyectos `usuarios` y `artelab`) |
| `GITHUB_TOKEN` | Lo entrega GitHub automáticamente; se usa para publicar y descargar imágenes de `ghcr.io` |

Los tres primeros se cargan también como secretos de Dependabot, porque los Pull Requests que abre Dependabot no reciben los secretos de Actions.

## 8. Seguridad y calidad del código

| Herramienta | Tipo de análisis | Cómo se usa en el pipeline |
|---|---|---|
| **Snyk** | Dependencias de terceros (SCA) | `snyk test` con umbral de severidad alta, en modo reporte (no detiene el pipeline), y `snyk monitor`, que envía una copia de las dependencias a la cuenta de Snyk para vigilarlas en el tiempo |
| **SonarCloud** | Código propio (SAST) y cobertura | Se ejecuta en push a `main` y en Pull Requests hacia `main`; recibe el reporte de JaCoCo. Proyectos: `devops-grupo7_sonar-usuarios` y `devops-grupo7_sonar-artelab` |
| **Dependabot** | Actualización de dependencias | Cada semana revisa las librerías Maven de ambos servicios, las acciones de GitHub y las imágenes base de Docker, y abre Pull Requests hacia `develop` |

Otras medidas: los contenedores se ejecutan con un usuario sin privilegios de root (`appuser`), la imagen final solo incluye el JRE, los secretos se guardan en GitHub Secrets y no en el código, y Actuator solo expone `/actuator/health`, sin detalle.

## 9. Contenedores y orquestación

**Dockerfile (multi-stage).** La etapa `build` (`maven:3.9-eclipse-temurin-25`) copia primero el `pom.xml` y descarga las dependencias para aprovechar la caché de capas, y luego compila el `.jar` sin ejecutar las pruebas (ya corrieron en el pipeline). La etapa `runtime` (`eclipse-temurin:25-jre`) solo contiene el `.jar`, instala `curl` para el healthcheck y corre como `appuser`.

**Docker Compose.** Define dos servicios (`usuarios-api` y `artelab-api`) con:

- **Healthcheck** en ambos: `curl -f http://localhost:<puerto>/actuator/health` cada 10 s, con 5 reintentos y 30 s de gracia inicial (`start_period`).
- **Orden de arranque:** `artelab-api` usa `depends_on` con `condition: service_healthy` sobre `usuarios-api`, de modo que no arranca hasta que `usuarios-api` responde saludable.
- **Persistencia:** un volumen nombrado por servicio (`artelab-data` y `usuarios-data`) montado en `/data`, donde vive la base SQLite.
- **Red:** los contenedores se comunican por el nombre del servicio (`http://usuarios-api:8081`).
- **Reinicio automático:** `restart: unless-stopped`.

## 10. Despliegue automático (entorno simulado)

El job `deploy` simula un entorno cloud con Docker Compose dentro del runner de GitHub Actions. Usa `docker-compose.deploy.yml`, que es el mismo stack que `docker-compose.yml` pero con las imágenes ya publicadas en `ghcr.io` en lugar de `build:`. Los pasos son: descargar las imágenes, `docker compose up -d --wait` (espera los healthchecks), `docker compose ps`, una verificación que consulta `/actuator/health` de ambos servicios y exige `"status":"UP"`, y por último `docker compose down -v`. Si un paso falla, se imprimen los logs. El entorno es efímero: se destruye al terminar.

## 11. Trazabilidad y calidad

**Trazabilidad.** Cada imagen se publica con dos etiquetas: `latest` y el SHA del commit que la originó (`${{ github.sha }}`). El job `deploy` despliega exactamente la imagen de ese SHA, no `latest`.

```
commit (SHA) ─► pruebas + análisis ─► imágenes  ghcr.io/<dueño>/devops_007d_ols/<servicio>:<SHA>
                                              └─► despliegue de ese mismo <SHA>
```

| Qué se quiere saber | Dónde verlo |
|---|---|
| De qué commit salió una imagen | La etiqueta de la imagen en la sección Packages del repositorio |
| Qué pruebas se ejecutaron y su resultado | Artefactos `usuarios-test-results` y `artelab-test-results` de cada ejecución |
| Qué cobertura tuvo el código | Artefactos `usuarios-jacoco-report` y `artelab-jacoco-report`, y el panel de SonarCloud |
| Qué dependencias se analizaron | Log del paso de Snyk y el proyecto en la cuenta de Snyk |
| Qué se desplegó y si quedó saludable | Job `deploy` de la ejecución |

**Calidad.** Se garantiza con tres controles: las pruebas deben pasar y la cobertura de líneas debe ser de al menos 80% (el job falla si no), las imágenes solo se construyen y despliegan si ambos jobs de prueba pasaron, y el despliegue solo termina bien si ambos servicios quedan saludables.

## 12. Limitaciones conocidas

- Cada servicio usa SQLite en un archivo local, por lo que no se puede escalar horizontalmente (varias réplicas no comparten la base).
- Snyk funciona en modo reporte: las vulnerabilidades encontradas se informan pero no detienen el pipeline.
- SonarCloud solo analiza la rama principal y los Pull Requests hacia ella, y no espera el resultado del Quality Gate.
- El despliegue es una simulación efímera en el runner, no una aplicación corriendo de forma permanente en un servidor.
- Los valores por defecto de contraseñas y secretos del compose son de desarrollo y deben reemplazarse en un entorno real.

## 13. Uso de Inteligencia Artificial

(Escrito por José Ignacio Salas)

Para este repositorio, la Inteligencia Articifial se utilizó como una herramienta de apoyo para la revisión y explicación del contenido ya entregado, facilitación de conocimiento extra, consulta y corrección de errores de código, y para la redacción, estructuración y generación final del archivo README.md. Todas las decisiones de arquitectura, desarrollo de los microservicios, implementación del pipeline de CI/CD y validaciones técnicas fueron realizadas y comprobadas directamente por mi mismo.

## 14. Conclusiones y reflexiones individuales

(Escrito por José Ignacio Salas)

Después de haber trabajado en todo este proyecto solo, sea en la configuración de los Dockers, el armado de los workflows de GitHub Actions y conexion con Snyk y SonarCloud que incluyo creación de secrets por parte de GitHub, y solucionando todos los problemas que convenian con todo ese armado, puedo concluir que gracias a estas clases he podido aprender a trabajar con todas estas nuevas herramientas que conectan con conocimiento que ya tenia previamente (Java, Spring Boot y microservicios).

Tuve constantes problemas debido a mi dificultad de entender las cosas al principio, pero con ayuda externa y corrección constante de errores pude salir adelante y terminar la mayoría de cosas que tenía que hacer. Algunos ejemplos como lo de mis problemas con Java en el ci.yml, el cual tuve que mover para que Snyk funcionara, o cuanto atrasé la creación del dependabot.yml debido a que no tenía idea de como crearlo hasta que lo investigué.

Creo que esto será muy importante para el futuro porque me ayudará a crear tecnologías que esten bien separadas con sus funciones, que se ejecuten automaticamente en distintos entornos de forma segura y que se actualicen cada vez que se generen cambios, comprobando que sus funcionalidades siempre esten operando como deben y en caso de que no sea asi, poder identificar sus vulnerabilidades y defectos para poder arreglarlos a la brevedad.

Si tuviera que tomar en cuenta que es lo que debo mejorar después de realizar todo esto, diría que para la próxima ocasión, en véz de simplemente permitir que todo pase para ver que la información llega a SonarCloud y Snyk, debería arreglar los errores que se me indican para que no hayan errores críticos o graves al momento de otra entrega porque seguramente ocurriría en un entorno más serio y que necesite resultados limpios.