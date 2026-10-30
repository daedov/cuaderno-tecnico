---
tags:
  - seguridad
  - contenedores
  - docker
  - ci-cd
---

# Seguridad de contenedores

> Cómo verificar y endurecer imágenes y contenedores: escaneo de vulnerabilidades, imágenes base mínimas, ejecución sin root, secretos en el build y firma.

## ¿Qué es?

Un contenedor empaqueta tu aplicación **con** su sistema de archivos: librerías del sistema operativo, intérprete, dependencias. Todo eso viaja a producción y todo eso puede tener vulnerabilidades. Además, un contenedor comparte el *kernel* (núcleo) del host: si se ejecuta con demasiados privilegios, una vulnerabilidad en la app puede convertirse en un **container escape** (escape del contenedor) hacia el nodo.

La seguridad de contenedores se reparte en tres momentos:

| Momento | Qué se verifica | Ejemplos |
| --- | --- | --- |
| **Build** (construcción) | Qué hay dentro de la imagen | Imagen base mínima, sin secretos, escaneo de CVEs, firma |
| **Registry** (registro) | Que la imagen almacenada siga siendo segura | Escaneo continuo, inmutabilidad de tags, control de acceso |
| **Runtime** (ejecución) | Con qué privilegios corre | Usuario no root, filesystem de solo lectura, sin capabilities |

Para crear imágenes (Dockerfile, multi-stage builds, Compose) ver [Docker](../../devops/contenedores/docker.md); para el *runtime* en Kubernetes, [Seguridad de Kubernetes](seguridad-kubernetes.md).

## Escaneo de imágenes

Un **image scanner** (escáner de imágenes) identifica los paquetes de la imagen (del sistema y de la aplicación) y los cruza con bases de datos de **CVE** (*Common Vulnerabilities and Exposures*, vulnerabilidades públicas catalogadas).

| Herramienta | Notas |
| --- | --- |
| **Trivy** (Aqua Security) | Imágenes, IaC, dependencias, secretos y SBOM en una sola CLI |
| **Grype** (Anchore) | Escáner de vulnerabilidades; suele usarse junto a **Syft**, que genera el SBOM |

```bash
# Trivy: falla solo con críticas y altas que ya tienen parche disponible
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 mi-app:1.4.2

# Grype: falla desde severidad alta
grype mi-app:1.4.2 --fail-on high

# Trivy también detecta secretos y malas configuraciones dentro de la imagen
trivy image --scanners vuln,secret,misconfig mi-app:1.4.2
```

!!! tip "`--ignore-unfixed` con criterio"
    Muchas CVEs del sistema operativo no tienen parche todavía. Ignorarlas evita bloquear el pipeline por algo que no puedes arreglar, pero **revísalas** en el reporte: si una es crítica y explotable, quizá convenga cambiar de imagen base.

### Escaneo en el registry

Escanear solo en el build no basta: una imagen limpia hoy puede tener una CVE nueva mañana. Los registries gestionados pueden re-escanear de forma continua:

| | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Registry | Amazon ECR | Azure Container Registry (ACR) | Artifact Registry |
| Escaneo | **ECR enhanced scanning** con **Amazon Inspector** (continuo, SO y lenguajes); *basic scanning* al hacer push | **Microsoft Defender for Containers** (evaluación de vulnerabilidades en ACR y en ejecución) | **Artifact Analysis** (escaneo automático al subir; re-análisis continuo durante un periodo limitado tras el push) |
| Dónde ver los hallazgos | Inspector y Security Hub | Microsoft Defender for Cloud | Artifact Registry y Security Command Center |

Más servicios gestionados de contenedores en [Contenedores gestionados](../../cloud/computo/contenedores-gestionados.md).

!!! tip "Escaneo en detalle"
    Cómo funciona el escaneo por capas, Docker Scout, la integración en el pipeline con SARIF, el re-escaneo de imágenes ya publicadas y VEX para documentar lo que no es explotable: [Container image scanning](../escaneos/container-scanning.md).

## Imágenes base mínimas

Cuantos menos paquetes, menos CVEs y menos herramientas para un atacante (sin shell no hay `sh -c` que ejecutar).

| Imagen base | Qué es | Pros | Contras |
| --- | --- | --- | --- |
| **scratch** | Imagen vacía | Superficie mínima; ideal para binarios estáticos (Go, Rust) | Sin certificados CA, zona horaria ni usuarios: hay que copiarlos |
| **Distroless** (Google) | Solo la app y sus dependencias de ejecución, sin shell ni gestor de paquetes | Pocas CVEs; variantes `:nonroot`; basada en Debian | Depurar es más difícil (usa las variantes `:debug` solo en dev) |
| **Alpine** | Distribución mínima con musl libc y `apk` | Muy pequeña, tiene shell y gestor de paquetes | musl puede dar incompatibilidades (Python, glibc); trae shell |
| **Chainguard Images / Wolfi** | Imágenes mínimas, reconstruidas a diario, con SBOM y firma; Wolfi es la distribución base | Muy pocas CVEs, firmadas, con variantes sin shell | Las versiones gratuitas tienen limitaciones (revisa las condiciones actuales) |
| Imagen completa (`debian`, `ubuntu`) | Sistema operativo completo | Cómoda para depurar | Cientos de paquetes que no usas |

!!! info "La versión importa más que el nombre"
    Usa tags concretos (`python:3.13-slim`) y, en producción, fija por **digest** (`@sha256:...`): un tag se puede mover, un digest no. Renueva la base con regularidad (Dependabot o Renovate abren el PR por ti).

## Dockerfile endurecido

```dockerfile title="Dockerfile"
# syntax=docker/dockerfile:1

# --- Etapa de build ---
FROM golang:1.25 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# Binario estático, sin dependencias del sistema
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/app

# --- Etapa final: sin shell, sin gestor de paquetes, sin root ---
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
```

Qué aporta cada decisión:

- **Multi-stage build**: compiladores y código fuente se quedan en la etapa `build`; la imagen final solo lleva el binario.
- **Distroless `:nonroot`**: sin shell y con un usuario sin privilegios (UID 65532) ya creado.
- **`USER`** explícito: aunque la base ya lo traiga, deja claro con qué usuario corre.
- **Puerto alto** (8080): un usuario no root no puede abrir puertos por debajo de 1024 sin capabilities extra.

Si tu base no trae un usuario, créalo:

```dockerfile
RUN addgroup -S app && adduser -S -G app -u 10001 app   # Alpine
USER 10001
```

## Endurecer la ejecución

Las mismas ideas se aplican con `docker run` y con Kubernetes (`securityContext`):

| Control | `docker run` | Kubernetes (`securityContext`) |
| --- | --- | --- |
| No ejecutar como root | `--user 10001` | `runAsNonRoot: true`, `runAsUser: 10001` |
| Filesystem de solo lectura | `--read-only` (+ `--tmpfs /tmp` si escribe temporales) | `readOnlyRootFilesystem: true` (+ volumen `emptyDir`) |
| Quitar **Linux capabilities** (privilegios del kernel divididos en partes) | `--cap-drop=ALL` | `capabilities: { drop: ["ALL"] }` |
| Impedir escalar privilegios (setuid) | `--security-opt=no-new-privileges` | `allowPrivilegeEscalation: false` |
| Perfil seccomp por defecto | Activo por defecto en Docker | `seccompProfile: { type: RuntimeDefault }` |
| Nunca | `--privileged` | `privileged: true` |

```bash
docker run --rm \
  --user 10001 \
  --read-only --tmpfs /tmp \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  -p 8080:8080 \
  mi-app:1.4.2
```

!!! danger "No montes el socket de Docker"
    `-v /var/run/docker.sock:/var/run/docker.sock` da al contenedor control total del daemon de Docker: puede lanzar un contenedor privilegiado que monte el disco del host. Equivale a **root en el host**. Si un pipeline necesita construir imágenes dentro de un contenedor, usa alternativas sin daemon o *rootless* (BuildKit rootless, Buildah, Kaniko o el builder del servicio de CI).

## Secretos en el build

Un `ARG` o `ENV` con un token queda guardado en las **capas** (*layers*) de la imagen y en su historial (`docker history`). Aunque lo borres en una capa posterior, sigue en la anterior.

BuildKit permite montar un secreto **solo durante un `RUN`**, sin que quede en ninguna capa:

```dockerfile title="Dockerfile (fragmento)"
# syntax=docker/dockerfile:1
FROM node:22-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
# El archivo .npmrc con el token solo existe durante este RUN
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
```

```bash
docker build --secret id=npmrc,src=$HOME/.npmrc -t mi-app:1.4.2 .
```

!!! warning "Revisa también lo que copias"
    `COPY . .` puede meter en la imagen `.env`, claves SSH o el directorio `.git`. Usa un `.dockerignore` y deja que el escáner de secretos lo confirme (`trivy image --scanners secret`). Ver [Seguridad del código](../codigo-y-dependencias/seguridad-codigo.md).

## Firma y verificación

Escanear dice *qué hay* en la imagen; firmar garantiza *quién la construyó* y que no cambió desde entonces. El flujo habitual:

1. El pipeline construye la imagen y genera el **SBOM** (*Software Bill of Materials*, lista de componentes).
2. La firma con **cosign** (Sigstore), idealmente *keyless* con la identidad OIDC del pipeline.
3. El clúster solo admite imágenes firmadas por esa identidad (Kyverno, Gatekeeper o Ratify; ver [Seguridad de Kubernetes](seguridad-kubernetes.md)).

```bash
cosign sign registry.example.com/mi-app@sha256:<digest>
cosign verify registry.example.com/mi-app@sha256:<digest> \
  --certificate-identity-regexp 'https://github.com/mi-org/mi-app/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Detalles de SBOM, SLSA y Sigstore en [Software supply chain](../codigo-y-dependencias/cadena-suministro.md).

## Checklist rápido

- [ ] Imagen base mínima y fijada por digest en producción.
- [ ] Multi-stage build: nada de compiladores ni código fuente en la imagen final.
- [ ] `USER` no root y puerto mayor que 1024.
- [ ] `.dockerignore` y secretos solo con `--mount=type=secret`.
- [ ] Escaneo en CI que falla con críticas, y escaneo continuo en el registry.
- [ ] Ejecución con `--read-only`, `--cap-drop=ALL` y `no-new-privileges`.
- [ ] Sin `--privileged` ni socket de Docker montado.
- [ ] Imagen firmada y verificada antes del despliegue.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Registries gestionados, ECS/EKS, AKS, GKE y Cloud Run donde corren las imágenes | [Contenedores gestionados](../../cloud/computo/contenedores-gestionados.md) |
| DevOps (la automatización) | Cómo se construyen y publican las imágenes que aquí se escanean | [Docker](../../devops/contenedores/docker.md), [Integración continua](../../devops/ci-cd/integracion-continua.md) |
| DevSecOps (la verificación) | Escaneo en CI, firma y políticas en el clúster | [Escaneo de seguridad en el pipeline](../escaneos/escaneo-en-pipeline.md), [Container image scanning](../escaneos/container-scanning.md), [Software supply chain](../codigo-y-dependencias/cadena-suministro.md), [Seguridad de Kubernetes](seguridad-kubernetes.md), [CVE en contenedores y Kubernetes](../vulnerabilidades/cve-contenedores-kubernetes.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 05: Imagen multi-stage y Docker Compose](../../laboratorios/devops/docker-multistage-compose.md), [Lab 12: Escaneos de seguridad en el pipeline](../../laboratorios/devsecops/escaneos-en-pipeline.md), [Lab 14: Endurecer un clúster: Pod Security, NetworkPolicy y Kyverno](../../laboratorios/devsecops/seguridad-kubernetes.md), [Lab 20: Google Cloud: desplegar un contenedor en Cloud Run](../../laboratorios/cloud/gcp-cloud-run.md), [Lab 22: Endurecer un servidor Linux con Ansible y medirlo con Lynis y OpenSCAP](../../laboratorios/devsecops/hardening-linux-ansible.md) |

## Referencias

- [Trivy: escaneo de imágenes](https://trivy.dev/latest/docs/target/container_image/)
- [Grype](https://github.com/anchore/grype)
- [Distroless images](https://github.com/GoogleContainerTools/distroless)
- [Chainguard Images](https://edu.chainguard.dev/chainguard/chainguard-images/overview/)
- [Docker: build secrets](https://docs.docker.com/build/building/secrets/)
- [Docker: seguridad del daemon y rootless mode](https://docs.docker.com/engine/security/)
- [Amazon ECR: escaneo de imágenes](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)
- [Microsoft Defender for Containers](https://learn.microsoft.com/es-es/azure/defender-for-cloud/defender-for-containers-introduction)
- [Artifact Analysis](https://cloud.google.com/artifact-analysis/docs/artifact-analysis)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Comandos de Docker](../../recursos/comandos/docker.md)
