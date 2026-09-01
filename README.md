# Evaluación Parcial N°1: Ingeniería DevOps
**Proyecto Base:** Microservicio de Gestión de API (Java / Spring Boot)

---

## 1. Introducción y Propósito del Proyecto
Este repositorio contiene la estructura base y la configuración inicial de un microservicio, diseñado para servir como plataforma de prueba para la implementación de un pipeline completo de Integración Continua y Despliegue Continuo (CI/CD). El proyecto se utiliza para demostrar el dominio de estrategias de control de versiones, automatización y documentación técnica bajo estándares de la industria.

---

## 2. Estrategia de Ramificación (Git Flow) y Justificación

Para este proyecto se ha seleccionado e implementado el modelo de ramificación **Git Flow**, justificado por las siguientes razones clave:
* **Control Estricto y Trazabilidad:** Permite separar claramente el código en desarrollo activo (`develop`), las correcciones urgentes en producción (`hotfix/*`), las nuevas características (`feature/*`) y el entorno estable listo para entrega (`main`).
* **Entornos Aislados:** Facilita simular un entorno de trabajo donde múltiples funcionalidades o correcciones se desarrollan en paralelo sin interferir con la estabilidad del sistema base.
* **Alineación con Estándares Empresariales:** Git Flow es idóneo para proyectos que requieren un versionado formal mediante etiquetas (*tags*) y entregas estructuradas.

---

## 3. Guía de Buenas Prácticas y Convenciones

### Naming de Ramas (Convención de Nombres)
Para mantener un orden estricto en el repositorio, se utiliza la siguiente nomenclatura:
* Ramas de características: `feature/<nombre-breve-de-la-funcionalidad>` (Ej: `feature/configuracion-inicial`)
* Ramas de corrección rápida: `hotfix/<nombre-del-error>` (Ej: `hotfix/error-conexion`)
* Ramas de lanzamiento: `release/v<version>` (Ej: `release/v1.0.0`)
* Ramas principales de control: `main` y `develop`.

---

## 4. Automatización con GitHub Actions (CI/CD)

El repositorio cuenta con un pipeline básico configurado en .github/workflows/ci.yml que se encarga de:
* Ejecutarse automáticamente ante cada push o pull_request dirigido a las ramas develop y main.
* Configurar un entorno virtual (ubuntu-latest) con Java (Temurin JDK 17).
* Compilar el proyecto utilizando Maven (mvn clean compile) para asegurar que el código base esté libre de errores sintácticos o de dependencias.

---

## 5. Declaraciones y Uso de Herramientas

Para el desarrollo de la documentación técnica y la estructuración inicial de este repositorio se utilizó como apoyo herramientas de Inteligencia Artificial (IA) para la redacción de guías, pautas de control de versiones y diseño de scripts de automatización, validando y adaptando todo el contenido a los requerimientos de la evaluación.

### Reflexiones Individuales

*José Salas: Siendo sincero crei que sería más facil de lo que creí, pues siento que con el pasar del tiempo se me fueron olvidando cosas y tuve que andar revisitando las clases anteriores y obtener támbien un poco de asistencia directa con IA.
