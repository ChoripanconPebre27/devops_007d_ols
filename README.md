# Docker — ArteLab SPA

Este documento explica cómo está dockerizado el proyecto: qué archivos se agregaron, cómo están conectados los dos microservicios y cómo levantar todo localmente.

## Arquitectura

El proyecto está compuesto por dos microservicios independientes, cada uno con su propia imagen Docker y su propia base de datos SQLite:

| Servicio | Carpeta | Puerto | Depende de |
|---|---|---|---|
| `usuarios-api` | `usuarios/` | 8081 | — |
| `artelab-api` | `artelab/` | 8080 | `usuarios-api` (vía HTTP/WebClient) |

`artelab-api` consulta a `usuarios-api` para validar/buscar usuarios. Por eso, en `docker-compose.yml`, `artelab-api` **espera a que `usuarios-api` esté saludable** antes de arrancar (ver sección Healthchecks).

## Estructura de archivos agregados

```
ArteLab-SPA-3/
├── docker-compose.yml      # orquesta ambos servicios
├── .env                    # secretos y credenciales (NO se sube al repo)
├── .env.example            # plantilla del .env, sí se sube al repo
├── artelab/
│   ├── Dockerfile
│   └── .dockerignore
└── usuarios/
    ├── Dockerfile
    └── .dockerignore
```

Cada `Dockerfile` es un **build multi-stage**:

1. **Etapa `build`** (`maven:3.9-eclipse-temurin-25`): compila el proyecto con Maven y genera el `.jar`. Esta imagen es pesada pero no llega a producción.
2. **Etapa `runtime`** (`eclipse-temurin:25-jre`): copia solo el `.jar` ya compilado, instala `curl` (lo usa el healthcheck) y corre la app con un usuario sin privilegios de root (`appuser`).

## Variables de entorno

Se definen en `.env` (copiado desde `.env.example`) y Docker Compose las inyecta en cada contenedor:

| Variable | Servicio | Descripción |
|---|---|---|
| `ARTELAB_JWT_SECRET` | artelab | Clave usada para firmar/validar los JWT de artelab |
| `USUARIOS_JWT_SECRET` | usuarios | Clave usada para firmar/validar los JWT de usuarios |
| `ADMIN_USER` / `ADMIN_PASSWORD` | artelab | Credenciales del usuario en memoria de artelab (`POST /api/v1/auth/login`) |

Otras variables van fijas en `docker-compose.yml` (no son secretas):

| Variable | Servicio | Valor |
|---|---|---|
| `SPRING_DATASOURCE_URL` | ambos | Apunta el archivo SQLite al volumen persistente (`/data/...`) |
| `SPRING_PROFILES_ACTIVE` | usuarios | `dev` — activa el `DataLoader` que siembra usuarios de prueba |
| `USUARIOS_SERVICE_BASE_URL` | artelab | `http://usuarios-api:8081` — nombre del servicio, resuelto por la red interna de Compose |

Los usuarios de prueba sembrados en `usuarios` (fijos en el código, no configurables por `.env`):

```
admin@mail.cl / admin123
ana@mail.cl   / ana123
luis@mail.cl  / luis123
```

## Persistencia de datos

Cada servicio tiene su propio volumen nombrado, para que la base SQLite sobreviva aunque se borre y recree el contenedor:

- `artelab-data` → montado en `/data` dentro de `artelab-api`
- `usuarios-data` → montado en `/data` dentro de `usuarios-api`

## Healthchecks y orden de arranque

Ambos servicios exponen `/actuator/health` (Spring Boot Actuator), público (sin JWT), y cada uno tiene un `healthcheck` en `docker-compose.yml`:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:PUERTO/actuator/health"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

`artelab-api` usa `depends_on` con `condition: service_healthy` sobre `usuarios-api`:

```yaml
depends_on:
  usuarios-api:
    condition: service_healthy
```

Esto asegura que `artelab-api` no arranque hasta que `usuarios-api` responda "healthy" — no solo que su contenedor esté creado.

## Cómo levantar el proyecto

Requisitos: Docker y Docker Compose instalados (`docker --version`, `docker compose version`).

```bash
# 1. Ubicarte en la raíz del repo (donde está docker-compose.yml)
cd ArteLab-SPA-3

# 2. Copiar y completar el archivo de variables de entorno (si no existe aún)
cp .env.example .env

# 3. Construir las imágenes y levantar ambos contenedores
docker compose up --build
```

La app queda disponible en:
- `artelab-api` → http://localhost:8080 (Swagger: http://localhost:8080/doc/swagger-ui.html)
- `usuarios-api` → http://localhost:8081 (Swagger: http://localhost:8081/doc/swagger-ui.html)

## Comandos útiles

```bash
docker compose ps            # estado de los contenedores (incluye healthy/unhealthy)
docker compose logs -f       # logs en vivo de ambos servicios
docker compose logs -f artelab-api   # logs de un solo servicio
docker compose down          # detener y eliminar contenedores (los volúmenes quedan)
docker compose down -v       # detener y borrar también los volúmenes (pierdes los datos)
```

## Notas de seguridad

- Los contenedores corren con un usuario sin privilegios de root (`appuser`), no como `root`.
- `.env` está en `.gitignore` y nunca debe subirse al repositorio; solo `.env.example` (con valores de ejemplo, no reales) se versiona.
- `/actuator/health` es el único endpoint de Actuator expuesto, y sin detalle (`show-details=never`), para no filtrar información interna del sistema.
