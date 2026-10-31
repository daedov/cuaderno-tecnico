---
tags:
  - recursos
  - anatomia
  - github-actions
  - ci-cd
---

# Anatomía de los workflows de GitHub Actions

> Qué significa cada clave de un workflow de GitHub Actions, de un reusable workflow y de una composite action, con un ejemplo completo comentado línea por línea.

!!! info "Cómo leer esta nota"
    Cada línea de los ejemplos lleva su explicación a la derecha, después de `#`. Lo que es obligatorio está marcado con **[obligatorio]**; todo lo demás es opcional. Los números en burbuja (`(1)`) abren una explicación más larga debajo del bloque. Si dudas con la indentación, las listas o los bloques `|`, repasa antes la [sintaxis de YAML](../sintaxis/yml.md). La tabla corta de [sintaxis de GitHub Actions](../sintaxis/github-actions.md) es la guía de sintaxis; esta nota es la versión completa.

## Dónde vive y cómo se organiza

GitHub solo reconoce los workflows dentro de `.github/workflows/` en la raíz del repositorio. El resto de archivos de `.github/` configuran cosas relacionadas: actions propias, actualizaciones automáticas y dueños del código.

```text
lab-devops-app/
├── .github/
│   ├── workflows/                       # [obligatorio] aquí, y solo aquí, viven los workflows
│   │   ├── ci.yml                       # workflow principal: tests, build y despliegue
│   │   └── deploy-reutilizable.yml      # reusable workflow (on: workflow_call)
│   ├── actions/
│   │   └── preparar-python/
│   │       └── action.yml               # composite action propia (se usa con uses: ./.github/actions/…)
│   ├── dependabot.yml                   # actualizaciones de dependencias y de actions (ver otros-archivos.md)
│   └── CODEOWNERS                       # quién debe revisar cambios en cada ruta (también vale en la raíz o docs/)
├── app/                                 # código de la API (FastAPI, puerto 8000)
├── tests/
├── Dockerfile
└── requirements-dev.txt
```

- Cada archivo `.yml` o `.yaml` de `.github/workflows/` es un **workflow** independiente; los subdirectorios dentro de `workflows/` no se leen.
- Las **actions** locales pueden vivir en cualquier carpeta, pero `.github/actions/<nombre>/action.yml` es la convención.
- El formato de `dependabot.yml` está comentado en [Otros archivos de configuración](otros-archivos.md#githubdependabotyml-comentado). `CODEOWNERS` se explica en [Seguridad del pipeline](../../devsecops/identidades-y-pipeline/seguridad-pipeline.md#codeowners).

## Estructura general

Un workflow tiene unas pocas claves de nivel superior. Lo que pongas a nivel de workflow (`permissions`, `env`, `defaults`, `concurrency`) es el valor por defecto que cada job puede sobrescribir.

```mermaid
flowchart TD
    W[workflow .yml] --> N[name / run-name]
    W --> O["on: eventos que lo disparan"]
    W --> P["permissions · env · defaults · concurrency<br/>(valores por defecto)"]
    W --> J[jobs]
    J --> J1["job_id"]
    J1 --> R["runs-on · needs · if · environment<br/>strategy · services · container · outputs"]
    J1 --> S[steps]
    S --> U["uses: action@SHA + with"]
    S --> X["run: comandos de shell"]
```

Jerarquía de ejecución: un **workflow** tiene uno o más **jobs**; cada job corre en un **runner** (máquina) nuevo y tiene una lista de **steps** que se ejecutan en orden en esa misma máquina. Los jobs corren en paralelo salvo que declares `needs`.

## Workflow principal comentado línea por línea

Es el pipeline de la API `lab-devops-app` del [Lab 07](../../laboratorios/devops/github-actions-ci.md), ampliado para que aparezcan todas las claves habituales. Los SHA son reales y se obtuvieron con `git ls-remote` (ver [Validar el archivo](#validar-el-archivo)).

```yaml title=".github/workflows/ci.yml"
name: ci                                     # nombre en la pestaña Actions y en los checks
run-name: "ci · ${{ github.ref_name }} · ${{ github.event_name }}"  # (1)!

on:                                          # [obligatorio] eventos que disparan el workflow
  push:                                      # al hacer push…
    branches: [main, "release/**"]           # …a main o a ramas release/… (glob)
    tags: ["v*.*.*"]                         # …o al subir un tag de versión (v1.2.3)
    paths:                                   # solo si cambia alguno de estos archivos (2)
      - "app/**"
      - "tests/**"
      - "requirements*.txt"
      - "Dockerfile"
      - ".github/**"
  pull_request:                              # PR abiertos contra…
    branches: [main]                         # …main (es la rama de destino, no la de origen)
    types: [opened, synchronize, reopened]   # actividades del PR (estas tres son el valor por defecto)
  workflow_dispatch:                         # botón "Run workflow" (ejecución manual)
    inputs:                                  # parámetros del formulario manual
      forzar-despliegue:                     # id del input → ${{ inputs.forzar-despliegue }}
        description: "Desplegar en staging aunque no sea un push"
        type: boolean                        # boolean | choice | string | number | environment
        default: false
      nivel-log:
        description: "Nivel de log de la app"
        type: choice                         # lista desplegable
        options: [info, debug]
        default: info
        required: true
  schedule:                                  # ejecución programada (cron)
    - cron: "30 6 * * 1"                     # (3)!

permissions:                                 # permisos del GITHUB_TOKEN para todos los jobs
  contents: read                             # solo leer el código; cada job pide más si lo necesita

env:                                         # variables de entorno para todos los jobs y steps
  APP_NAME: lab-devops-app
  LOG_LEVEL: ${{ inputs.nivel-log || 'info' }}   # inputs vacío si no es manual → 'info'

defaults:                                    # opciones por defecto de los steps run:
  run:
    shell: bash                              # bash también en runners Windows
    working-directory: .                     # carpeta donde se ejecuta cada run:

concurrency:                                 # una sola ejecución activa por grupo
  group: ${{ github.workflow }}-${{ github.ref }}   # grupo = workflow + rama/tag
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}  # en PR cancela la anterior

jobs:                                        # [obligatorio] mapa de jobs
  test:                                      # job_id: único, letras, números, - y _
    name: test (${{ matrix.os }}, py${{ matrix.python }})  # nombre visible del check
    runs-on: ${{ matrix.os }}                # [obligatorio] runner; aquí sale de la matrix
    timeout-minutes: 15                      # mata el job si se cuelga (por defecto 360)
    continue-on-error: ${{ matrix.experimental == true }}  # un fallo aquí no marca el workflow en rojo
    strategy:
      fail-fast: false                       # si falla una variante, no cancela las demás
      max-parallel: 4                        # como mucho 4 variantes a la vez
      matrix:                                # (4)!
        os: [ubuntu-latest, windows-latest]
        python: ["3.13", "3.14", "3.15"]     # entre comillas: 3.10 sin comillas sería 3.1
        exclude:                             # quita combinaciones del producto cartesiano
          - os: windows-latest
            python: "3.13"
        include:                             # añade una combinación extra (o claves extra)
          - os: ubuntu-latest
            python: "3.16"
            experimental: true               # clave nueva, solo existe en esta variante
    steps:                                   # [obligatorio] lista de pasos, en orden
      - name: Descargar el código            # nombre visible del step
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:                                # entradas (inputs) de la action
          persist-credentials: false         # no deja el token en .git/config

      - name: Preparar Python
        uses: ./.github/actions/preparar-python   # composite action local (ver más abajo)
        with:
          python-version: ${{ matrix.python }}

      - name: Lint (solo una variante)
        if: matrix.os == 'ubuntu-latest' && matrix.python == '3.14'  # step condicional
        run: |                               # run multilínea: cada línea es un comando
          ruff check .
          ruff format --check .

      - name: Tests
        id: tests                            # id para leer sus outputs o su resultado
        run: pytest -q --junitxml=reports/junit.xml

      - name: Guardar el reporte de tests
        if: always()                         # se ejecuta aunque fallen los tests
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: junit-${{ matrix.os }}-${{ matrix.python }}  # nombre único por variante
          path: reports/
          retention-days: 7

  integracion:
    name: integración (PostgreSQL)
    needs: test                              # espera a que todas las variantes de test acaben bien
    runs-on: ubuntu-latest
    timeout-minutes: 15
    container:                               # los steps corren dentro de este contenedor
      image: python:3.14.9-slim
    services:                                # contenedores auxiliares durante el job
      postgres:                              # nombre del service = hostname dentro de la red
        image: postgres:18.6-alpine
        env:
          POSTGRES_USER: app
          POSTGRES_PASSWORD: app-test        # base efímera de pruebas: no es un secreto real
          POSTGRES_DB: tareas
        options: >-                          # (5)!
          --health-cmd "pg_isready -U app"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    env:                                     # variables solo para este job
      DATABASE_URL: postgresql://app:app-test@postgres:5432/tareas
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - run: pip install -r requirements-dev.txt
      - run: pytest -q -m integracion        # solo los tests marcados como de integración

  build:
    needs: [test, integracion]               # lista: espera a los dos
    if: github.event_name != 'schedule'      # la ejecución semanal solo prueba, no construye
    runs-on: ubuntu-latest
    timeout-minutes: 20
    permissions:                             # sustituye (no suma) a los permisos del workflow
      contents: read
      packages: write                        # publicar en GHCR; solo este job
    outputs:                                 # salidas del job para otros jobs (needs.build.outputs.*)
      version: ${{ steps.version.outputs.version }}
      digest: ${{ steps.publicar.outputs.digest }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0                     # historial completo y tags, para git describe
          persist-credentials: false

      - name: Calcular la versión
        id: version
        run: |                               # (6)!
          VERSION="$(git describe --tags --always)"
          echo "version=${VERSION#v}" >> "$GITHUB_OUTPUT"
          echo "APP_VERSION=${VERSION#v}" >> "$GITHUB_ENV"
          echo "### Versión construida: \`${VERSION#v}\`" >> "$GITHUB_STEP_SUMMARY"

      - name: Construir y publicar la imagen
        id: publicar
        env:                                 # variables solo para este step
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}       # token automático de la ejecución
          PUBLICAR: ${{ github.event_name != 'pull_request' }}  # en PR solo construye
        run: |
          IMAGE="ghcr.io/${GITHUB_REPOSITORY,,}:${APP_VERSION}"
          docker build --build-arg APP_VERSION="$APP_VERSION" -t "$IMAGE" .
          if [ "$PUBLICAR" = "true" ]; then
            echo "$GH_TOKEN" | docker login ghcr.io -u "$GITHUB_ACTOR" --password-stdin
            docker push "$IMAGE"
            echo "digest=$(docker inspect --format '{{index .RepoDigests 0}}' "$IMAGE")" >> "$GITHUB_OUTPUT"
          fi

  deploy-staging:
    needs: build
    if: >-                                   # (7)!
      github.ref == 'refs/heads/main' &&
      (github.event_name == 'push' || inputs.forzar-despliegue)
    runs-on: ubuntu-latest
    timeout-minutes: 10
    environment:                             # environment de GitHub: reglas, secretos y variables propios
      name: staging
      url: ${{ vars.APP_URL }}               # enlace que aparece en la ejecución y en Deployments
    permissions:
      contents: read
      id-token: write                        # pedir el token OIDC para la nube
    steps:
      - name: Credenciales temporales de AWS (OIDC)
        uses: aws-actions/configure-aws-credentials@e1253824e5c10ff9df46874f81ed3ec929e19cfd # v6.3.0
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}   # variable del environment, no un secreto
          aws-region: ${{ vars.AWS_REGION }}
      - name: Desplegar
        env:
          IMAGEN: ${{ needs.build.outputs.digest }}  # salida de otro job
        run: echo "Desplegando ${IMAGEN} con nivel de log ${LOG_LEVEL}"
      - name: Avisar si falla
        if: failure()                        # solo si algún step anterior falló
        continue-on-error: true              # si el aviso falla, no cambia el resultado
        env:
          WEBHOOK: ${{ secrets.SLACK_WEBHOOK_URL }}  # secreto del repo o del environment
        run: >-
          curl -fsS -X POST -H 'Content-Type: application/json'
          -d "{\"text\":\"Falló el despliegue de ${APP_NAME} en staging\"}" "$WEBHOOK"

  deploy-produccion:
    needs: build                             # en un tag, deploy-staging no corre (skipped)
    if: startsWith(github.ref, 'refs/tags/v')   # solo con tags de versión
    permissions:                             # techo de permisos para el reusable workflow
      contents: read
      id-token: write
    uses: ./.github/workflows/deploy-reutilizable.yml  # job que llama a un reusable workflow
    with:                                    # inputs del reusable workflow
      entorno: produccion
      imagen: ${{ needs.build.outputs.digest }}
    secrets:                                 # secretos que le pasas (o secrets: inherit)
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

1.  `run-name` es el título de **cada ejecución** en la lista de Actions. Puede usar los contextos `github` e `inputs`. Si no lo pones, GitHub usa el mensaje del commit o el título del PR.
2.  Con `paths`, el workflow solo se dispara si el push toca alguno de esos archivos. Ojo: los filtros de rutas **no se evalúan en los push de tags**, y si un workflow que es *required status check* no se dispara por `paths`, el PR se queda esperando ese check. Existe también `paths-ignore` (no se combinan los dos en el mismo evento).
3.  Los cinco campos de cron son **minuto, hora, día del mes, mes, día de la semana**. `30 6 * * 1` = los lunes a las 06:30. Por defecto la hora es **UTC**; puedes añadir `timezone: "America/Santiago"` (zona IANA) al mismo elemento. El intervalo mínimo es de 5 minutos, solo corre en la **rama por defecto** y, en horas de mucha carga, puede retrasarse o saltarse. GitHub desactiva los schedules de repos públicos sin actividad durante 60 días.
4.  La **matrix** genera una variante del job por cada combinación: 2 sistemas × 3 versiones = 6, menos 1 por `exclude` = 5, más 1 por `include` = 6 jobs. Dentro del job lees los valores con `${{ matrix.os }}` y `${{ matrix.python }}`. Un `include` que no coincide con ninguna combinación existente añade una variante nueva; si coincide, solo le añade claves.
5.  `options` son flags de `docker create`. El **health check** hace que el job espere a que PostgreSQL acepte conexiones antes del primer step. Como el job corre en un `container`, el service se alcanza por su nombre (`postgres:5432`). Si el job corriera directamente en el runner, tendrías que publicar el puerto (`ports: ["5432:5432"]`) y conectar a `localhost`.
6.  Tres archivos especiales que el runner lee al terminar el step: lo que escribes en **`$GITHUB_OUTPUT`** (`clave=valor`) se convierte en `steps.version.outputs.clave`; lo que escribes en **`$GITHUB_ENV`** queda como variable de entorno para **los steps siguientes** (no para el actual); y el Markdown que escribes en **`$GITHUB_STEP_SUMMARY`** aparece en la página de resumen de la ejecución. Sustituyen a los antiguos comandos `::set-output` (obsoleto) y `::set-env` (deshabilitado); si los ves en un ejemplo, está desactualizado.
7.  En `if:` de job o de step no hace falta envolver en `${{ }}` (GitHub lo evalúa como expresión). `>-` permite partir una condición larga en varias líneas. `inputs.forzar-despliegue` es `true` solo en una ejecución manual con la casilla marcada; en un push está vacío y cuenta como falso.

### Referencia de elementos del workflow

| Elemento | Obligatorio | Qué hace | Valores típicos / ejemplo |
| --- | --- | --- | --- |
| `name` | No | Nombre del workflow en la UI | `ci`, `deploy` |
| `run-name` | No | Título de cada ejecución | `"ci · ${{ github.ref_name }}"` |
| `on` | Sí | Eventos que lo disparan | `push`, `pull_request`, `workflow_dispatch`, `schedule`, `workflow_call`, `release`, `merge_group` |
| `on.push.branches` / `tags` / `paths` | No | Filtros del evento (glob) | `[main]`, `["v*.*.*"]`, `["app/**"]`; variantes `-ignore` |
| `on.workflow_dispatch.inputs` | No | Formulario de ejecución manual | `type: choice` con `options` |
| `on.schedule[].cron` | No | Programación en UTC (o `timezone`) | `"30 6 * * 1"` |
| `permissions` | No (muy recomendado) | Permisos del `GITHUB_TOKEN`; lo no listado queda en `none` | `{}`, `contents: read`, `id-token: write` |
| `env` | No | Variables de entorno (workflow, job o step; gana la más interna) | `APP_NAME: lab-devops-app` |
| `defaults.run` | No | `shell` y `working-directory` por defecto de los `run:` | `shell: bash` |
| `concurrency` | No | Una ejecución activa por grupo; `cancel-in-progress` cancela la anterior; `queue: max` encola en vez de reemplazar | `group: deploy-${{ github.ref }}` |
| `jobs.<id>` | Sí | Cada job; el id es la clave | `test`, `build` |
| `runs-on` | Sí (salvo `uses:`) | Runner: etiqueta hosted, `self-hosted` o grupo | `ubuntu-latest`, `ubuntu-24.04`, `windows-latest`, `[self-hosted, linux]` |
| `needs` | No | Dependencias entre jobs | `build`, `[test, integracion]` |
| `if` | No | Condición del job o del step | `github.ref == 'refs/heads/main'`, `failure()` |
| `environment` | No | Environment con reglas de protección, secretos y `url` | `name: produccion` |
| `timeout-minutes` | No | Límite de tiempo (job o step) | `10`–`30`; por defecto 360 en el job |
| `continue-on-error` | No | Un fallo no marca el job/workflow como fallido | `true`, `${{ matrix.experimental == true }}` |
| `strategy.matrix` | No | Variantes del mismo job; `include`/`exclude` | `python: ["3.13", "3.14"]` |
| `strategy.fail-fast` | No | Cancelar el resto de variantes si una falla (por defecto `true`) | `false` |
| `container` | No | Imagen donde corren los steps del job (solo runners Linux) | `image: python:3.14.9-slim` |
| `services` | No | Contenedores auxiliares (bases de datos, colas) | `postgres`, `redis` |
| `outputs` (job) | No | Valores para otros jobs vía `needs.<job>.outputs` | `${{ steps.x.outputs.y }}` |
| `steps[].uses` | Uno de `uses`/`run` | Ejecuta una action | `owner/repo@<SHA> # vX.Y.Z`, `./ruta-local` |
| `steps[].with` | No | Inputs de la action | `persist-credentials: false` |
| `steps[].run` | Uno de `uses`/`run` | Comandos de shell (una línea o bloque literal) | `pytest -q` |
| `steps[].id` | No | Identificador para `steps.<id>.outputs` / `.outcome` | `version` |
| `steps[].env` | No | Variables solo para ese step | `IMAGEN: ${{ needs.build.outputs.digest }}` |

### Contextos y funciones que más vas a usar

| Expresión | Qué devuelve |
| --- | --- |
| `github.event_name` | Evento que disparó la ejecución: `push`, `pull_request`, `schedule`… |
| `github.ref` / `github.ref_name` | Ref completa (`refs/heads/main`, `refs/tags/v1.2.0`) / solo el nombre (`main`, `v1.2.0`) |
| `github.sha`, `github.actor`, `github.repository` | Commit, usuario que lo lanzó, `owner/repo` |
| `secrets.NOMBRE` | Secreto del repo, de la organización o del environment (enmascarado en los logs) |
| `vars.NOMBRE` | Variable de configuración (no secreta) del repo, organización o environment |
| `inputs.nombre` | Inputs de `workflow_dispatch` o `workflow_call` |
| `matrix.clave` | Valor de la variante actual de la matrix |
| `needs.<job>.outputs.<clave>` / `needs.<job>.result` | Salidas y resultado (`success`, `failure`, `skipped`, `cancelled`) de un job anterior |
| `steps.<id>.outputs.<clave>` / `steps.<id>.outcome` | Salidas y resultado de un step anterior del mismo job |
| `success()`, `failure()`, `always()`, `cancelled()` | Funciones de estado para `if:` (por defecto todo step lleva `success()`) |
| `startsWith()`, `contains()`, `format()`, `toJSON()`, `fromJSON()`, `hashFiles()` | Funciones de expresión |

!!! warning "Nunca interpoles datos del evento dentro de `run:`"
    `run: echo "${{ github.event.pull_request.title }}"` inserta el título del PR **como código de shell** antes de ejecutarlo (*script injection*). Pásalo siempre por `env:` y usa la variable (`"$TITULO"`), como hacen los steps del ejemplo. Ver [Seguridad del pipeline](../../devsecops/identidades-y-pipeline/seguridad-pipeline.md#ataques-tipicos).

## Reusable workflow comentado

Un **reusable workflow** (workflow reutilizable) es un workflow que otro workflow llama como si fuera un job. Sirve para tener un único "despliegue estándar" para muchos repos o entornos.

```yaml title=".github/workflows/deploy-reutilizable.yml"
name: deploy-reutilizable

on:
  workflow_call:                             # [obligatorio] lo convierte en reutilizable
    inputs:                                  # parámetros que recibe (with: en el llamador)
      entorno:
        description: "Environment de GitHub donde desplegar"
        type: string                         # [obligatorio] string | boolean | number
        required: true
      imagen:
        description: "Imagen a desplegar, por digest"
        type: string
        required: true
    secrets:                                 # secretos que acepta (secrets: en el llamador)
      SLACK_WEBHOOK_URL:
        required: false
    outputs:                                 # salidas para el workflow que lo llama
      url:
        description: "URL publicada"
        value: ${{ jobs.desplegar.outputs.url }}   # sale de un job de este workflow

permissions: {}                              # nada por defecto; el job pide lo suyo

jobs:
  desplegar:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    environment:
      name: ${{ inputs.entorno }}            # el environment lo decide el llamador
      url: ${{ steps.publicar.outputs.url }} # la url puede salir de un step del job
    permissions:                             # nunca puede superar lo que dio el llamador
      contents: read
      id-token: write
    outputs:
      url: ${{ steps.publicar.outputs.url }}
    steps:
      - uses: aws-actions/configure-aws-credentials@e1253824e5c10ff9df46874f81ed3ec929e19cfd # v6.3.0
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}   # vars del environment elegido
          aws-region: ${{ vars.AWS_REGION }}
      - name: Desplegar
        id: publicar
        env:
          IMAGEN: ${{ inputs.imagen }}
          ENTORNO: ${{ inputs.entorno }}
          APP_URL: ${{ vars.APP_URL }}
        run: |
          echo "Desplegando ${IMAGEN} en ${ENTORNO}"
          echo "url=${APP_URL}" >> "$GITHUB_OUTPUT"
      - name: Avisar si falla
        if: failure()
        env:
          WEBHOOK: ${{ secrets.SLACK_WEBHOOK_URL }}
          ENTORNO: ${{ inputs.entorno }}     # por env:, nunca ${{ }} dentro de run:
        run: >-
          curl -fsS -X POST -H 'Content-Type: application/json'
          -d "{\"text\":\"Falló el despliegue en ${ENTORNO}\"}" "$WEBHOOK"
```

| Elemento | Obligatorio | Qué hace | Ejemplo |
| --- | --- | --- | --- |
| `on.workflow_call` | Sí | Permite llamarlo desde otro workflow | Puede convivir con otros eventos (`workflow_dispatch`) |
| `workflow_call.inputs.<id>.type` | Sí | Tipo del input | `string`, `boolean`, `number` |
| `workflow_call.secrets` | No | Secretos que acepta; el llamador también puede usar `secrets: inherit` | `SLACK_WEBHOOK_URL` |
| `workflow_call.outputs.<id>.value` | Sí, si declaras outputs | Expone la salida de un job interno | `${{ jobs.desplegar.outputs.url }}` |
| Job llamador: `uses` | Sí | Ruta local (`./.github/workflows/x.yml`) u `owner/repo/.github/workflows/x.yml@<SHA>` | Ver `deploy-produccion` en `ci.yml` |
| Job llamador: `with` / `secrets` | Según inputs | Pasa los inputs y secretos | `entorno: produccion` |

Un job que llama a un reusable workflow **no tiene `runs-on` ni `steps`**: solo admite `name`, `uses`, `with`, `secrets`, `needs`, `if`, `permissions`, `strategy` y `concurrency`. El `environment` se declara dentro del reusable workflow. Las variables de entorno (`env`) del llamador **no** se propagan.

## Composite action comentada

Una **composite action** (action compuesta) agrupa varios steps en uno reutilizable. A diferencia de un reusable workflow, corre **dentro del job** que la usa (mismo runner, mismos archivos).

```yaml title=".github/actions/preparar-python/action.yml"
name: Preparar Python                        # [obligatorio] nombre de la action
description: Instala Python con caché de pip y las dependencias del proyecto  # [obligatorio]
inputs:                                      # parámetros (with: en quien la usa)
  python-version:
    description: "Versión de Python"         # [obligatorio] en cada input
    required: false
    default: "3.14"
  requirements:
    description: "Archivo de dependencias"
    required: false
    default: requirements-dev.txt
outputs:                                     # salidas (steps.<id>.outputs.* en quien la usa)
  python-path:
    description: "Ruta del intérprete instalado"
    value: ${{ steps.setup.outputs.python-path }}  # [obligatorio] en composite: de dónde sale
runs:                                        # [obligatorio] cómo se ejecuta
  using: composite                           # [obligatorio] composite | node24 | docker
  steps:
    - id: setup
      uses: actions/setup-python@6d4fd22b20465ccc0f7354476588e8df7c9ca0e0 # v7.1.0
      with:
        python-version: ${{ inputs.python-version }}
        allow-prereleases: true              # acepta versiones beta (la 3.16 de la matrix)
        cache: pip                           # caché de pip con clave basada en el archivo
        cache-dependency-path: ${{ inputs.requirements }}
    - name: Instalar dependencias
      shell: bash                            # [obligatorio] en cada run: de una composite
      env:
        REQUIREMENTS: ${{ inputs.requirements }}
      run: python -m pip install -r "$REQUIREMENTS"
```

| | Reusable workflow | Composite action |
| --- | --- | --- |
| Archivo | `.github/workflows/*.yml` con `on: workflow_call` | `action.yml` en cualquier carpeta |
| Se usa en | Un **job** (`jobs.<id>.uses`) | Un **step** (`steps[].uses`) |
| Puede tener | Varios jobs, `environment`, runners propios, `secrets` | Solo steps; usa el runner y el workspace del job |
| Secretos | Declarados en `workflow_call.secrets` | No accede a `secrets`; se le pasan como inputs |
| Ideal para | Pipelines completos estándar (deploy, release) | Bloques repetidos de pasos (preparar entorno, login) |

## Errores comunes

| Síntoma o mensaje | Causa | Corrección |
| --- | --- | --- |
| `Invalid workflow file: You have an error in your yaml syntax on line N` | Tabuladores o indentación inconsistente | Solo espacios (2 por nivel); revisa la línea indicada con un editor que muestre espacios |
| `Unexpected value 'step'` / `'run-on'` | Clave mal escrita (`step` en vez de `steps`, `run-on` en vez de `runs-on`) | Corrige el nombre; `actionlint` lo detecta antes del push |
| `Required property is missing: runs-on` | Job sin runner | Añade `runs-on:` (salvo que el job tenga `uses:`) |
| La matrix ejecuta Python `3.1` en vez de `3.10` | `3.10` sin comillas es el número 3.1 | Escribe las versiones entre comillas: `"3.10"` |
| `Unrecognized named-value: 'secrets'` en un `if:` | `secrets` no está disponible en condiciones `if:` | Pásalo a `env:` y compara `env.VAR != ''` |
| El workflow no aparece o no se dispara | Archivo fuera de `.github/workflows/`, filtro `branches`/`paths` que no coincide, o `schedule` en una rama que no es la por defecto | Revisa la ruta y los filtros |
| `Resource not accessible by integration` | El `GITHUB_TOKEN` no tiene el permiso necesario | Añade el permiso al bloque `permissions` del job (por ejemplo `packages: write`) |
| `Unable to resolve action ... unable to find version` | SHA mal copiado o incompleto | Copia los 40 caracteres desde `git ls-remote` |
| Un step no ve una variable escrita en `$GITHUB_ENV` | Se escribió en el mismo step | `$GITHUB_ENV` vale desde el **siguiente** step; en el mismo usa la variable de shell |
| `Context access might be invalid: digest` | Lees un output que no declaraste en `outputs:` del job | Declara el output a nivel de job |

## Validar el archivo

```bash
# Sintaxis y semántica de todos los workflows (claves, expresiones, tipos de inputs, cron, needs)
actionlint

# Solo YAML válido, sin reglas de GitHub
yamllint .github/workflows/

# Seguridad de los workflows: injection, permisos, actions sin fijar
zizmor .github/workflows/

# SHA del commit al que apunta un tag (si aparece una línea con ^{}, usa esa)
git ls-remote --tags https://github.com/actions/checkout.git | grep 'v7.0.1'
```

- **actionlint** es un solo binario (Go) y, si encuentra `shellcheck` en el PATH, revisa también el contenido de los `run:`.
- En el editor, la extensión oficial *GitHub Actions* de VS Code valida claves y expresiones mientras escribes.
- Para probar el workflow sin hacer push existe **act** (ejecuta los jobs en Docker local), con limitaciones: no reproduce exactamente los runners de GitHub ni sus servicios (OIDC, environments).
- Mantén los SHA al día con Dependabot (ecosistema `github-actions`), que actualiza el SHA y el comentario de versión: [`dependabot.yml` comentado](otros-archivos.md#githubdependabotyml-comentado).

## Para practicar

- [Lab 07: Pipeline de CI con GitHub Actions](../../laboratorios/devops/github-actions-ci.md): el workflow de esta nota, paso a paso.
- [Lab 12: Escaneos de seguridad en el pipeline](../../laboratorios/devsecops/escaneos-en-pipeline.md) y [Lab 13: OIDC entre GitHub Actions y AWS](../../laboratorios/devsecops/oidc-github-aws.md).
- Teoría: [Integración continua](../../devops/ci-cd/integracion-continua.md), [Despliegue continuo](../../devops/ci-cd/despliegue-continuo.md) y [Seguridad del pipeline](../../devsecops/identidades-y-pipeline/seguridad-pipeline.md).
- El mismo pipeline en GitLab: [Anatomía de `.gitlab-ci.yml`](gitlab-ci.md#equivalencias-con-github-actions).

## Referencias

- [Sintaxis de flujos de trabajo de GitHub Actions](https://docs.github.com/es/actions/reference/workflows-and-actions/workflow-syntax)
- [Eventos que desencadenan flujos de trabajo](https://docs.github.com/es/actions/reference/workflows-and-actions/events-that-trigger-workflows)
- [Contextos](https://docs.github.com/es/actions/reference/workflows-and-actions/contexts) y [expresiones](https://docs.github.com/es/actions/reference/workflows-and-actions/expressions)
- [Comandos de flujo de trabajo (`GITHUB_OUTPUT`, `GITHUB_ENV`, `GITHUB_STEP_SUMMARY`)](https://docs.github.com/es/actions/reference/workflows-and-actions/workflow-commands)
- [Reutilizar flujos de trabajo](https://docs.github.com/es/actions/how-tos/reuse-automations/reuse-workflows)
- [Sintaxis de metadatos de actions (`action.yml`)](https://docs.github.com/es/actions/reference/workflows-and-actions/metadata-syntax)
- [actionlint](https://github.com/rhysd/actionlint)
