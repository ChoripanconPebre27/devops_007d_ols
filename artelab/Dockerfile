# =========================================================
# Etapa 1: BUILD — compilamos con Maven + JDK 25
# =========================================================
FROM maven:3.9-eclipse-temurin-25 AS build
WORKDIR /app

COPY pom.xml .
RUN mvn -B dependency:go-offline

COPY src ./src
RUN mvn -B clean package -DskipTests

# =========================================================
# Etapa 2: RUNTIME — solo el JRE + el .jar
# =========================================================
FROM eclipse-temurin:25-jre AS runtime
WORKDIR /app

# curl: lo necesita el HEALTHCHECK para consultar /actuator/health
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# UID fijo: Kubernetes necesita un UID numerico para runAsNonRoot y fsGroup
RUN useradd --uid 10001 --create-home --shell /bin/bash appuser \
    && mkdir -p /data \
    && chown -R appuser:appuser /app /data

COPY --from=build --chown=appuser:appuser /app/target/*.jar app.jar

USER 10001

EXPOSE 8080

VOLUME ["/data"]

# Limita el heap al 70% de la memoria del contenedor (el limite lo fija Kubernetes)
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70"
ENTRYPOINT ["java", "-jar", "app.jar"]
