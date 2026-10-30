---
tags:
  - contenedores
  - docker
  - ci-cd
---

# Docker: imágenes, multi-stage builds y Compose

> Qué es un contenedor, cómo se construye una imagen con un Dockerfile, cómo hacerla pequeña con *multi-stage builds* y cómo levantar varios servicios con Docker Compose.

## ¿Qué es?

Un **container** (contenedor) es un proceso aislado que lleva consigo todo lo que necesita para ejecutarse: el binario de la aplicación, sus librerías y su configuración. Se ejecuta igual en tu portátil, en el runner de CI y en producción, lo que elimina el clásico "en mi máquina funciona".

**Docker** es la herramienta que popularizó los contenedores: construye imágenes, las sube a un registry y las ejecuta. Hoy las imágenes siguen el estándar **OCI** (*Open Container Initiative*), así que una imagen construida con Docker la ejecuta también Kubernetes, Podman o cualquier servicio de contenedores de la nube.

## Contenedor vs máquina virtual

| | Máquina virtual | Contenedor |
| --- | --- | --- |
| Qué virtualiza | El **hardware**: cada VM tiene su propio kernel y sistema operativo | El **sistema operativo**: todos comparten el kernel del host |
| Tamaño típico | GB | MB |
| Arranque | Minutos | Segundos o menos |
| Aislamiento | Fuerte (hipervisor) | Menor (namespaces y cgroups del kernel Linux) |
| Uso típico | Sistemas completos, cargas que necesitan su propio kernel | Aplicaciones y microservicios |

Ver [Máquinas virtuales](../../cloud/computo/maquinas-virtuales.md) para el lado de las VMs.

!!! note "Aislamiento no es seguridad total"
    Como los contenedores comparten kernel, un contenedor mal configurado (ejecutándose como root, con `--privileged`) puede comprometer el host. Ver [Seguridad de contenedores](../../devsecops/infraestructura-y-contenedores/seguridad-contenedores.md).

## Conceptos clave

| Concepto | Qué es |
| --- | --- |
| **Image** (imagen) | Plantilla de solo lectura con el sistema de archivos y la configuración para ejecutar la aplicación |
| **Layer** (capa) | Cada instrucción del Dockerfile que modifica archivos crea una capa; las capas se reutilizan entre imágenes y se guardan en caché |
| **Container** | Una instancia en ejecución de una imagen, con una capa escribible encima que se pierde al borrarlo |
| **Registry** (registro) | Servidor donde se guardan y comparten imágenes: Docker Hub, GitHub Container Registry, Amazon ECR, Azure Container Registry, Artifact Registry |
| **Repository** (repositorio) | Conjunto de versiones de una imagen dentro de un registry (`miempresa/api`) |
| **Tag** (etiqueta) | Nombre legible de una versión: `1.4.2`, `latest` |
| **Digest** | Hash SHA-256 del contenido de la imagen: identifica una versión exacta e inmutable |
| **Volume** (volumen) | Almacenamiento que sobrevive al contenedor (datos de una base de datos, por ejemplo) |

## Dockerfile

El **Dockerfile** describe cómo construir la imagen. Instrucciones principales:

| Instrucción | Para qué sirve |
| --- | --- |
| `FROM` | Imagen base de la que partes |
| `WORKDIR` | Directorio de trabajo para las siguientes instrucciones |
| `COPY` | Copia archivos del **build context** (contexto de build: la carpeta que envías a Docker) a la imagen |
| `RUN` | Ejecuta un comando durante el build (instalar dependencias, compilar) |
| `ENV` | Variables de entorno disponibles en build y en ejecución |
| `ARG` | Variables solo para el build (`--build-arg`) |
| `EXPOSE` | Documenta el puerto en el que escucha la app (no lo publica) |
| `USER` | Usuario con el que se ejecutan las siguientes instrucciones y el contenedor |
| `ENTRYPOINT` / `CMD` | Comando que se ejecuta al arrancar el contenedor; `CMD` da argumentos por defecto que se pueden sobrescribir |
| `HEALTHCHECK` | Comando para comprobar si el contenedor está sano |

!!! tip "Forma exec"
    Escribe `CMD` y `ENTRYPOINT` en **exec form** (forma exec, con corchetes): `CMD ["node", "server.js"]`. Así la aplicación es el proceso principal y recibe las señales de parada (`SIGTERM`) para cerrarse limpiamente.

## Multi-stage builds

Un **multi-stage build** (build en varias etapas) usa una imagen grande con compiladores y herramientas para construir, y copia **solo el resultado** a una imagen final pequeña. La imagen final no lleva el compilador, el código fuente ni las dependencias de desarrollo: pesa menos y tiene menos vulnerabilidades.

=== "Go"

    ```dockerfile title="Dockerfile"
    # Etapa 1: compilar
    FROM golang:1.23 AS build
    WORKDIR /src

    # Primero las dependencias, para aprovechar la caché
    COPY go.mod go.sum ./
    RUN go mod download

    COPY . .
    RUN CGO_ENABLED=0 GOOS=linux go build -o /out/api ./cmd/api

    # Etapa 2: imagen final mínima, sin shell y sin root
    FROM gcr.io/distroless/static-debian12:nonroot
    COPY --from=build /out/api /api
    EXPOSE 8080
    USER nonroot:nonroot
    ENTRYPOINT ["/api"]
    ```

=== "Node.js"

    ```dockerfile title="Dockerfile"
    # Etapa 1: dependencias y build
    FROM node:22-alpine AS build
    WORKDIR /app
    COPY package.json package-lock.json ./
    RUN npm ci
    COPY . .
    RUN npm run build

    # Etapa 2: solo dependencias de producción
    FROM node:22-alpine AS deps
    WORKDIR /app
    COPY package.json package-lock.json ./
    RUN npm ci --omit=dev

    # Etapa 3: imagen final
    FROM node:22-alpine
    ENV NODE_ENV=production
    WORKDIR /app
    COPY --from=deps /app/node_modules ./node_modules
    COPY --from=build /app/dist ./dist
    USER node
    EXPOSE 3000
    CMD ["node", "dist/server.js"]
    ```

Las versiones de las imágenes base son de ejemplo: usa las versiones soportadas en el momento en que construyas.

## .dockerignore

El `.dockerignore` excluye archivos del build context. Hace el build más rápido y evita meter en la imagen cosas que no deben estar ahí (secretos, `.git`).

```text title=".dockerignore"
.git
node_modules
dist
*.log
.env
.env.*
Dockerfile
docker-compose*.yml
coverage/
```

!!! danger "Nunca metas secretos en la imagen"
    Cualquiera que pueda descargar la imagen puede leer todas sus capas, incluso un archivo que borraste en una capa posterior. Para secretos durante el build usa `RUN --mount=type=secret`; en ejecución, inyéctalos como variables de entorno o archivos desde un gestor de secretos.

## Tags y digests

```bash
docker build -t registry.ejemplo.com/miempresa/api:1.4.2 .
docker push registry.ejemplo.com/miempresa/api:1.4.2
```

- Un **tag** es **mutable**: alguien puede volver a subir `1.4.2` con otro contenido. `latest` no significa "la más reciente", es solo el tag por defecto.
- Un **digest** (`@sha256:...`) es **inmutable**: siempre apunta exactamente al mismo contenido.

```dockerfile
# Fijar la imagen base por digest: reproducible y a prueba de cambios
FROM node:22-alpine@sha256:<digest>
```

Estrategia habitual de tags en CI: el **SHA del commit** (`api:3f9c2ab`) para trazabilidad y la **versión semántica** (`api:1.4.2`) para releases. En producción, despliega por digest o activa la **tag immutability** (inmutabilidad de tags) en el registry.

## Docker Compose

**Docker Compose** define y levanta varios contenedores que trabajan juntos (aplicación, base de datos, caché) con un solo archivo. Es ideal para desarrollo local y pruebas; para producción se usan orquestadores como Kubernetes o servicios gestionados.

```yaml title="compose.yaml"
services:
  api:
    build: .
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: postgres://app:${DB_PASSWORD}@db:5432/app
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:17
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: app
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      retries: 5

volumes:
  db-data:
```

```bash
docker compose up -d --build   # construir y levantar
docker compose logs -f api     # ver logs
docker compose down            # parar (añade -v para borrar los volúmenes)
```

- Los servicios se encuentran por su **nombre** (`db`) gracias a la red que crea Compose.
- `${DB_PASSWORD}` se toma del entorno o de un archivo `.env` (que no se sube a Git).
- `depends_on` con `service_healthy` espera a que la base de datos esté lista, no solo arrancada.

## Buenas prácticas de build

- **Ordena por frecuencia de cambio**: primero lo que cambia poco (dependencias), después el código. Si cambias una línea de código, Docker reutiliza la caché de la capa de dependencias.
- **Imágenes base pequeñas**: `-slim`, `alpine` o **distroless** (sin shell ni gestor de paquetes). Menos tamaño, menos vulnerabilidades.
- **Una responsabilidad por contenedor**: un proceso principal, no "app + base de datos + cron".
- **No ejecutes como root**: añade `USER`.
- **Combina comandos** de instalación y limpia en el mismo `RUN` (por ejemplo, `apt-get install ... && rm -rf /var/lib/apt/lists/*`).
- **Caché en CI**: con BuildKit/Buildx puedes reutilizar capas entre ejecuciones (`--cache-from`, `--cache-to`, o la caché de GitHub Actions con `docker/build-push-action`).
- **Multiplataforma**: `docker buildx build --platform linux/amd64,linux/arm64` para ejecutar en x86 y ARM (Graviton, Cobalt, Axion).
- **Escanea, firma y genera SBOM** en el pipeline: ver [Escaneo de seguridad en el pipeline](../../devsecops/escaneos/escaneo-en-pipeline.md) y [Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md).

## Registry de cada nube

| | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Servicio | **Amazon ECR** (*Elastic Container Registry*) | **Azure Container Registry** (ACR) | **Artifact Registry** |

Autenticar Docker contra cada registry:

```bash
# AWS
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin <cuenta>.dkr.ecr.eu-west-1.amazonaws.com

# Azure
az acr login --name <registry>

# Google Cloud
gcloud auth configure-docker us-central1-docker.pkg.dev
```

Más en [Contenedores gestionados](../../cloud/computo/contenedores-gestionados.md). Comandos frecuentes en la [guía de comandos de Docker](../../recursos/comandos/docker.md).

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Dónde se guardan y ejecutan las imágenes: ECR/ACR/Artifact Registry, ECS, Container Apps, Cloud Run | [Contenedores gestionados](../../cloud/computo/contenedores-gestionados.md) |
| DevOps (la automatización) | Build de la imagen en CI, orquestación y despliegue | [Integración continua](../ci-cd/integracion-continua.md), [Kubernetes](kubernetes.md), [Despliegue continuo](../ci-cd/despliegue-continuo.md) |
| DevSecOps (la verificación) | Escaneo de imágenes, ejecución sin root, firma y SBOM | [Seguridad de contenedores](../../devsecops/infraestructura-y-contenedores/seguridad-contenedores.md), [Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 00: Preparar el entorno de laboratorio](../../laboratorios/fundamentos/preparar-entorno.md), [Lab 05: Imagen multi-stage y Docker Compose](../../laboratorios/devops/docker-multistage-compose.md), [Lab 06: Desplegar una app en Kubernetes local con kind](../../laboratorios/devops/kubernetes-local-kind.md), [Lab 07: Pipeline de CI con GitHub Actions](../../laboratorios/devops/github-actions-ci.md), [Lab 10: Configurar servidores con Ansible](../../laboratorios/devops/ansible-configuracion.md), [Lab 11: Observabilidad con Prometheus y Grafana](../../laboratorios/devops/observabilidad-prometheus-grafana.md), [Lab 12: Escaneos de seguridad en el pipeline](../../laboratorios/devsecops/escaneos-en-pipeline.md), [Lab 15: DAST con OWASP ZAP sobre OWASP Juice Shop](../../laboratorios/devsecops/dast-zap-juice-shop.md), [Lab 20: Google Cloud: desplegar un contenedor en Cloud Run](../../laboratorios/cloud/gcp-cloud-run.md), [Lab 21: Game day: incidente simulado, troubleshooting y postmortem](../../laboratorios/operacion/game-day-incidente.md), [Lab 22: Endurecer un servidor Linux con Ansible y medirlo con Lynis y OpenSCAP](../../laboratorios/devsecops/hardening-linux-ansible.md) |

## Referencias

- [Documentación de Docker](https://docs.docker.com/)
- [Referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/)
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Buenas prácticas de build](https://docs.docker.com/build/building/best-practices/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Build secrets](https://docs.docker.com/build/building/secrets/)
- [Imágenes distroless](https://github.com/GoogleContainerTools/distroless)
- [Guía de comandos de Docker](../../recursos/comandos/docker.md)
