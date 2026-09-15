# =========================================================
# Etapa 1: BUILD
# Compilamos el proyecto con Maven dentro de un contenedor
# que ya trae JDK 25 + Maven. Esta imagen es pesada, pero
# NO viaja a producción: solo la usamos para generar el .jar
# =========================================================
FROM maven:3.9-eclipse-temurin-25 AS build

WORKDIR /app

# 1) Copiamos primero SOLO el pom.xml.
#    Truco de cache de Docker: si el pom.xml no cambia,
#    Docker reutiliza la capa con las dependencias ya
#    descargadas y no vuelve a bajarlas en cada build.
COPY pom.xml .
RUN mvn -B dependency:go-offline

# 2) Ahora sí copiamos el código fuente
COPY src ./src

# 3) Compilamos y empaquetamos como .jar
#    -DskipTests: los tests deberían correr en el pipeline de CI,
#    no en cada build de la imagen (así es más rápido)
RUN mvn -B clean package -DskipTests


# =========================================================
# Etapa 2: RUNTIME
# Imagen final, liviana: solo el JRE (no el JDK completo)
# y el .jar ya compilado. Aquí es donde corre la app.
# =========================================================
FROM eclipse-temurin:25-jre AS runtime

WORKDIR /app

# Creamos un usuario sin privilegios de root.
# Buena práctica: la app no debería correr como root dentro del contenedor.
RUN useradd --create-home --shell /bin/bash appuser \
    && mkdir -p /data \
    && chown -R appuser:appuser /app /data

# Copiamos SOLO el .jar generado en la etapa "build"
# (el resto de la imagen de Maven se descarta por completo)
COPY --from=build --chown=appuser:appuser /app/target/*.jar app.jar

USER appuser

# Puerto en el que escucha Spring Boot (server.port en application.properties)
EXPOSE 8080

# Carpeta donde vamos a persistir el archivo de SQLite (ver docker-compose.yml)
VOLUME ["/data"]

ENTRYPOINT ["java", "-jar", "app.jar"]
