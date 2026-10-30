---
tags:
  - recursos
  - anatomia
  - gitlab-ci
  - ci-cd
---

# Anatomía de `.gitlab-ci.yml`

> Qué significa cada clave del pipeline de GitLab CI/CD (stages, jobs, rules, needs, artifacts, cache, environments, includes y OIDC), con un ejemplo completo comentado línea por línea y su equivalente en GitHub Actions.

!!! info "Cómo leer esta nota"
    Cada línea del ejemplo lleva su explicación a la derecha, después de `#`. Lo obligatorio está marcado con **[obligatorio]**. Los números en burbuja (`(1)`) abren una explicación más larga debajo del bloque. Este archivo usa mucho las **anclas** de YAML (`&`, `*`, `<<:`): repásalas en [sintaxis de YAML](../sintaxis/yml.md#6-anclas-y-reutilizacion) si no las conoces.

## Dónde vive y cómo se organiza

A diferencia de GitHub Actions, GitLab lee **un solo archivo de entrada**: `.gitlab-ci.yml` en la raíz del repositorio (la ruta se puede cambiar en *Settings → CI/CD → General pipelines*). Para dividirlo en varios archivos se usa `include`.

```text
lab-devops-app/
├── .gitlab-ci.yml                 # [obligatorio] punto de entrada del pipeline
├── ci/
│   └── docs.yml                   # trozo del pipeline incluido con include:local
├── app/                           # código de la API (FastAPI, puerto 8000)
├── tests/
├── Dockerfile
└── requirements-dev.txt

mi-grupo/plantillas-ci/            # otro proyecto: plantillas compartidas (include:project)
└── plantillas/
    └── trivy.yml

mi-grupo/componentes/              # proyecto de CI/CD components (include:component)
└── templates/
    └── secret-detection.yml       # cada componente: templates/<nombre>.yml con spec:inputs
```

Jerarquía: un **pipeline** tiene **stages** (etapas) que se ejecutan en orden; cada stage tiene **jobs** que corren en paralelo en **runners**. Con `needs` un job puede empezar antes de que termine su stage anterior (pipeline en forma de grafo, *DAG*).

## Estructura general

```mermaid
flowchart TD
    F[.gitlab-ci.yml] --> G["Claves globales:<br/>include · stages · variables · default · workflow"]
    F --> H["Jobs ocultos (.nombre)<br/>plantillas para extends y anclas"]
    F --> J["Jobs (cualquier otra clave)"]
    J --> K["stage · image · services · script"]
    J --> L["rules · needs · when · allow_failure"]
    J --> M["artifacts · cache · environment · id_tokens"]
```

Cualquier clave de nivel superior que **no** sea una palabra reservada (`stages`, `variables`, `default`, `include`, `workflow`…) es un **job**. Si empieza por punto (`.tests-python`) es un **job oculto**: no se ejecuta, sirve de plantilla.

## `.gitlab-ci.yml` comentado línea por línea

El mismo pipeline de la API `lab-devops-app` que en [Anatomía de GitHub Actions](github-actions.md): lint, tests en matrix, integración con PostgreSQL, build de la imagen en el registry del proyecto y despliegue a AWS con OIDC.

```yaml title=".gitlab-ci.yml"
include:                                       # archivos externos; se evalúan antes que el resto (1)
  - template: Jobs/SAST.gitlab-ci.yml          # plantilla oficial de GitLab (SAST)
  - local: ci/docs.yml                         # archivo del mismo repo y rama
  - project: mi-grupo/plantillas-ci            # archivo de otro proyecto de GitLab…
    ref: v2.3.0                                # …fijado a un tag (o SHA), nunca a una rama
    file: /plantillas/trivy.yml
  - component: $CI_SERVER_FQDN/mi-grupo/componentes/secret-detection@1.2.0  # CI/CD component versionado
    inputs:                                    # parámetros declarados en spec:inputs del componente
      stage: test

stages:                                        # orden de las etapas (por defecto: build, test, deploy)
  - lint
  - test
  - build
  - deploy

variables:                                     # variables globales (todas las jobs las heredan)
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"  # pip guarda la caché dentro del proyecto
  IMAGE: "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA"  # variables predefinidas de GitLab
  SAST_EXCLUDED_PATHS: "tests, .cache"         # configura la plantilla SAST incluida
  NIVEL_LOG:                                   # variable con formulario en "Run pipeline"
    value: info
    options: [info, debug]
    description: "Nivel de log de la app en ejecuciones manuales"

default:                                       # valores por defecto de cada job (si no los define)
  image: python:3.14.9-slim                    # imagen de contenedor del job
  tags: [saas-linux-small-amd64]               # elige runner por etiqueta (2)
  interruptible: true                          # se puede cancelar si llega un commit nuevo
  before_script:                               # comandos antes de script: en cada job
    - python -m pip install -r requirements-dev.txt
  cache: &cache-pip                            # ancla: este mapa se reutiliza más abajo
    key:
      files: [requirements-dev.txt]            # la clave cambia si cambia este archivo
    paths: [.cache/pip]                        # qué carpetas se guardan en la caché

workflow:                                      # ¿se crea el pipeline? y cómo se comporta
  name: "$CI_COMMIT_REF_NAME · $CI_PIPELINE_SOURCE"  # título del pipeline en la UI
  auto_cancel:
    on_new_commit: interruptible               # un commit nuevo cancela los jobs interruptible
  rules:                                       # (3)!
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
    - if: $CI_PIPELINE_SOURCE == "schedule" || $CI_PIPELINE_SOURCE == "web"

.reglas-codigo: &reglas-codigo                 # job oculto con ancla: una lista de rules reutilizable
  - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    changes:                                   # en MR: solo si cambian estos archivos
      - app/**/*
      - tests/**/*
      - requirements*.txt
  - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  - if: $CI_COMMIT_TAG
  - if: $CI_PIPELINE_SOURCE == "schedule" || $CI_PIPELINE_SOURCE == "web"

.postgres-vars: &postgres-vars                 # ancla con un mapa de variables
  POSTGRES_USER: app
  POSTGRES_PASSWORD: app-test                  # base efímera de pruebas: no es un secreto real
  POSTGRES_DB: tareas

lint:                                          # nombre del job (clave libre)
  stage: lint                                  # etapa a la que pertenece (por defecto: test)
  script:                                      # [obligatorio] comandos del job
    - ruff check .
    - ruff format --check .
  cache:
    <<: *cache-pip                             # mismas key y paths que en default…
    policy: pull                               # …pero solo descarga la caché, no la sube
  rules: *reglas-codigo                        # alias: la misma lista que el ancla

.tests-python:                                 # job oculto: plantilla para extends
  stage: test
  image: python:${PYTHON_VERSION}-slim         # la versión sale de una variable
  needs: []                                    # no espera a lint: empieza en cuanto se crea el pipeline
  artifacts:                                   # archivos que se guardan al terminar el job
    when: always                               # también si el job falla
    paths: [reports/]                          # se pueden descargar desde la UI
    reports:
      junit: reports/junit.xml                 # GitLab muestra los tests en el MR
    expire_in: 1 week                          # luego se borran
  rules: *reglas-codigo

test:
  extends: .tests-python                       # hereda la plantilla (fusión profunda de mapas)
  parallel:
    matrix:                                    # un job por cada valor: test: [3.13], test: [3.14]…
      - PYTHON_VERSION: ["3.13", "3.14", "3.15"]
  script:
    - pytest -q --junitxml=reports/junit.xml --cov=app --cov-report=term --cov-report=xml:reports/coverage.xml
  coverage: '/TOTAL.*\s+(\d+%)$/'              # regex que extrae el % de cobertura del log
  artifacts:                                   # se fusiona con artifacts de la plantilla
    reports:
      coverage_report:                         # cobertura línea a línea en el diff del MR
        coverage_format: cobertura
        path: reports/coverage.xml

test-integracion:
  extends: .tests-python
  variables:
    <<: *postgres-vars                         # fusiona aquí las claves del ancla
    PYTHON_VERSION: "3.14"
    DATABASE_URL: postgresql://app:app-test@postgres:5432/tareas
  services:                                    # contenedores auxiliares que viven durante el job
    - name: postgres:18.6-alpine
      alias: postgres                          # hostname con el que lo alcanza el job
  script:
    - pytest -q -m integracion --junitxml=reports/junit.xml
  allow_failure: true                          # si falla, el pipeline sigue (aviso naranja)
  timeout: 15 minutes                          # límite propio del job

build:
  stage: build
  image: docker:29.9.2                         # cliente Docker
  services:
    - docker:29.9.2-dind                       # demonio Docker en un service (Docker-in-Docker)
  variables:
    DOCKER_TLS_CERTDIR: "/certs"               # cliente y dind hablan por TLS
  before_script: []                            # anula el pip install de default
  cache: []                                    # y la caché de pip: aquí no hace falta
  needs: [lint, test]                          # espera solo a estos (todas las variantes de test)
  script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
    - docker build --build-arg APP_VERSION="$CI_COMMIT_SHORT_SHA" -t "$IMAGE" .
    - docker push "$IMAGE"
    - echo "IMAGE_DIGEST=$(docker inspect --format '{{index .RepoDigests 0}}' "$IMAGE")" >> build.env
  artifacts:
    reports:
      dotenv: build.env                        # (4)!
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG

.aws-oidc:                                     # plantilla: credenciales temporales de AWS sin llaves
  image:
    name: amazon/aws-cli:2.38.5
    entrypoint: [""]                           # la imagen tiene ENTRYPOINT aws: lo anulamos
  id_tokens:                                   # (5)!
    AWS_ID_TOKEN:
      aud: https://gitlab.com                  # audiencia que espera el IAM OIDC provider
  variables:
    AWS_DEFAULT_REGION: us-east-1
  cache: []
  before_script:
    - echo "$AWS_ID_TOKEN" > /tmp/web-identity-token
    - export AWS_WEB_IDENTITY_TOKEN_FILE=/tmp/web-identity-token
    - aws sts get-caller-identity              # comprueba qué rol se asumió

deploy-staging:
  extends: .aws-oidc
  stage: deploy
  needs: [build]                               # recibe IMAGE_DIGEST por el dotenv de build
  environment:                                 # registra el despliegue en Operate → Environments
    name: staging
    url: https://staging.ejemplo.com
  script:                                      # AWS_ROLE_ARN: variable CI/CD con scope "staging"
    - echo "Desplegando $IMAGE_DIGEST en $CI_ENVIRONMENT_NAME (log $NIVEL_LOG)"
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

deploy-produccion:
  extends: .aws-oidc
  stage: deploy
  needs: [build]
  environment:
    name: produccion
    url: https://app.ejemplo.com
    deployment_tier: production                # tipo de entorno (para métricas y protección)
  resource_group: produccion                   # un despliegue a la vez en este entorno
  script:
    - echo "Desplegando $IMAGE_DIGEST en $CI_ENVIRONMENT_NAME"
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
      when: manual                             # alguien tiene que pulsar "play"
      allow_failure: false                     # el pipeline queda bloqueado hasta entonces
```

1.  `include` admite cinco orígenes: `local` (mismo repo), `project` (otro proyecto, con `ref` y `file`), `remote` (URL pública), `template` (plantillas que trae GitLab) y `component` (componentes del **CI/CD Catalog**, versionados y con `inputs` tipados). Lo incluido se **fusiona** con tu archivo: si defines un job o una clave con el mismo nombre, gana tu versión. GitLab está migrando muchas plantillas a componentes; para código nuevo, prefiere componentes con versión fija.
2.  `tags` elige el **runner** por etiquetas. En GitLab.com, `saas-linux-small-amd64` es el runner Linux por defecto (se puede omitir); con runners propios usarías las etiquetas que les pusiste al registrarlos (`docker`, `k8s`…). Si ningún runner tiene la etiqueta, el job se queda en *pending*.
3.  `workflow:rules` decide si se crea el pipeline: se evalúan en orden y **gana la primera que coincide**; si ninguna coincide, no hay pipeline. Este es el patrón oficial para evitar **pipelines duplicados**: crea pipeline de MR, no crea pipeline de rama si esa rama tiene un MR abierto, y sí lo crea en la rama por defecto, en tags `vX.Y.Z`, en ejecuciones programadas y en las lanzadas a mano desde la UI.
4.  Un **dotenv report** convierte las líneas `CLAVE=valor` de `build.env` en variables de entorno de los jobs que dependen de este (con `needs` o en etapas posteriores). Es el equivalente de los `outputs` de un job en GitHub Actions.
5.  `id_tokens` pide a GitLab un **JWT OIDC** firmado para este job y lo deja en la variable `AWS_ID_TOKEN`. El AWS CLI lo cambia por credenciales temporales del rol `AWS_ROLE_ARN` (definido como variable CI/CD con *environment scope*, para que cada entorno asuma su propio rol). La *trust policy* del rol debe limitar los claims `sub` (proyecto, rama o tag) y `aud`. Ver [Secretos e identidades](../../devsecops/identidades-y-pipeline/secretos-identidades.md).

### Referencia de elementos

| Elemento | Obligatorio | Qué hace | Valores típicos / ejemplo |
| --- | --- | --- | --- |
| `include` | No | Trae configuración de otros archivos | `local`, `project` + `ref` + `file`, `remote`, `template`, `component` |
| `stages` | No | Orden de las etapas | Por defecto `.pre`, `build`, `test`, `deploy`, `.post` |
| `variables` | No | Variables globales o de job; con `value`/`options`/`description` aparecen en el formulario manual | `IMAGE: "$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA"` |
| `default` | No | Valores por defecto de `image`, `before_script`, `after_script`, `cache`, `artifacts`, `services`, `tags`, `retry`, `interruptible`, `id_tokens`, `hooks` | `image: python:3.14.9-slim` |
| `workflow:rules` | No | Si se crea o no el pipeline | Patrón MR + rama por defecto + tags |
| `workflow:auto_cancel` | No | Cancelación automática ante commits nuevos | `on_new_commit: interruptible` |
| `<job>.stage` | No | Etapa del job | Por defecto `test` |
| `<job>.script` | Sí | Comandos de shell | Lista de strings |
| `<job>.image` | No | Imagen del contenedor del job (`name`, `entrypoint`) | `python:3.14.9-slim` |
| `<job>.services` | No | Contenedores auxiliares (`name`, `alias`) | `postgres:18.6-alpine`, `docker:29.9.2-dind` |
| `<job>.rules` | No | Si el job entra al pipeline y cómo: `if`, `changes`, `exists`, `when`, `allow_failure`, `variables` | `- if: $CI_COMMIT_TAG` |
| `<job>.needs` | No | Dependencias explícitas (DAG); `[]` = empieza ya | `[lint, test]` |
| `<job>.artifacts` | No | Archivos que se conservan (`paths`, `reports`, `expire_in`, `when`) | `reports: junit: …` |
| `<job>.cache` | No | Archivos que se reutilizan entre pipelines (`key`, `paths`, `policy`) | `key: files: [requirements-dev.txt]` |
| `<job>.environment` | No | Entorno del despliegue (`name`, `url`, `deployment_tier`, `on_stop`) | `name: produccion` |
| `<job>.when` | No | `on_success` (por defecto), `manual`, `always`, `on_failure`, `delayed`, `never` | `when: manual` |
| `<job>.allow_failure` | No | Si su fallo no rompe el pipeline | `true` (por defecto en jobs `manual` fuera de `rules`) |
| `<job>.parallel:matrix` | No | Variantes del job por combinación de variables | `- PYTHON_VERSION: ["3.13", "3.14"]` |
| `<job>.extends` | No | Hereda de uno o varios jobs (fusión profunda de mapas; las listas se reemplazan) | `extends: .tests-python` |
| `<job>.id_tokens` | No | JWT OIDC para autenticarse en nubes o Vault | `aud: https://gitlab.com` |
| `<job>.resource_group` | No | Un solo job a la vez con ese nombre (evita despliegues simultáneos) | `produccion` |
| `<job>.timeout` | No | Límite del job | `15 minutes` |
| `<job>.coverage` | No | Regex que extrae el % de cobertura del log | `'/TOTAL.*\s+(\d+%)$/'` |

### `extends` frente a anclas YAML

| | Anclas (`&`, `*`, `<<:`) | `extends` | `!reference` |
| --- | --- | --- | --- |
| Quién lo resuelve | El parser YAML, antes de que GitLab lo vea | GitLab | GitLab |
| Funciona entre archivos incluidos | No (solo dentro del mismo archivo) | Sí | Sí |
| Fusión | `<<:` fusiona solo un nivel de un mapa | Fusión profunda de mapas; listas reemplazadas | Inserta una clave concreta (`!reference [.plantilla, script]`) |
| Úsalo para | Listas reutilizables (como `rules`) dentro de un archivo | Plantillas de jobs | Reutilizar trozos de `script` o `rules` de otro archivo |

## Equivalencias con GitHub Actions

| Concepto | GitLab CI/CD | GitHub Actions |
| --- | --- | --- |
| Archivo | `.gitlab-ci.yml` (uno, con `include`) | `.github/workflows/*.yml` (varios) |
| Cuándo se ejecuta | `workflow:rules` + `rules` de cada job | `on:` + `if:` |
| Etapas | `stages` + `stage` | No existen; se modelan con `needs` |
| Dependencias | `needs` | `needs` |
| Comandos | `script` (+ `before_script`, `after_script`) | `steps[].run` |
| Imagen del job | `image` | `container` |
| Contenedores auxiliares | `services` | `services` |
| Plantillas | `extends`, anclas, `include`, components | Reusable workflows, composite actions |
| Variables y secretos | `variables` + variables CI/CD (*masked*, *protected*, por entorno) | `env`, `vars.*`, `secrets.*` |
| Matrix | `parallel:matrix` | `strategy.matrix` |
| Pasar datos entre jobs | `artifacts` + `reports:dotenv` | `outputs` + `needs.<job>.outputs`, artifacts |
| Caché | `cache` (`key`, `paths`) | `actions/cache` o `cache:` de las actions `setup-*` |
| Entornos | `environment` (+ *protected environments*) | `environment` (+ *required reviewers*) |
| Aprobación manual | `when: manual` (+ *deployment approvals*) | Environment con *required reviewers* |
| Concurrencia | `resource_group`, `interruptible` + `auto_cancel` | `concurrency` |
| Selección de runner | `tags` | `runs-on` |
| OIDC | `id_tokens` | `permissions: id-token: write` |
| Ejecución manual con parámetros | "Run pipeline" + `variables` con `options` (o `spec:inputs`) | `workflow_dispatch.inputs` |
| Programado | *Pipeline schedules* (en la UI) | `on.schedule` (en el YAML) |

## Errores comunes

| Síntoma o mensaje | Causa | Corrección |
| --- | --- | --- |
| `jobs:<job> config should implement the script:, run:, or trigger: keyword` | Job sin `script` (o un job oculto sin el punto inicial) | Añade `script:` o renombra la plantilla a `.nombre` |
| `'build' job needs 'lint' job, but 'lint' does not exist in the pipeline` | El job de `needs` no existe en ese pipeline (sus `rules` no lo añadieron) | Alinea las `rules` o usa `needs: [{job: lint, optional: true}]` |
| `unknown alias: reglas-codigo` | Usas `*alias` antes de definir el `&ancla`, o el ancla está en otro archivo incluido | Define el ancla antes y en el mismo archivo; entre archivos usa `extends` o `!reference` |
| Pipelines duplicados (rama + MR) | `rules` que aceptan `push` y `merge_request_event` a la vez | Usa el patrón de `workflow:rules` del ejemplo |
| `rules:changes` siempre verdadero | En pipelines de tag, schedule o ramas nuevas no hay diff con qué comparar | Añade `compare_to: refs/heads/main` o limita esa regla a MR |
| El job queda en *pending* para siempre | Ningún runner tiene las `tags` pedidas | Revisa las etiquetas de los runners del proyecto |
| `This GitLab CI configuration is invalid: (<unknown>): mapping values are not allowed` | Un `:` seguido de espacio dentro de un comando sin comillas | Encomilla la línea: `- 'echo "clave: valor"'` |
| `Cannot connect to the Docker daemon` en el build | Falta el service `docker:dind` o `DOCKER_TLS_CERTDIR` | Añade ambos, o usa un builder sin daemon (BuildKit rootless, Kaniko) |

## Validar el archivo

```bash
# YAML válido y anclas resueltas (no valida las reglas de GitLab)
yamllint .gitlab-ci.yml
python -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml'))"

# Validación completa con el CLI oficial de GitLab (necesita autenticarte con glab auth login)
glab ci lint
```

- En la web: **Build → Pipeline editor**. Valida al escribir, muestra la **visualización** del grafo de jobs y la pestaña **Full configuration** con los `include`, `extends` y anclas ya resueltos: es la mejor forma de entender qué ejecutará GitLab.
- La API `POST /projects/:id/ci/lint` hace lo mismo desde scripts (con `dry_run=true` simula la creación del pipeline y evalúa `rules`).
- `yamllint` no conoce el tag `!reference`: si lo usas, configura `yamllint` para ignorarlo o valida solo con GitLab.

## Para practicar

- [Integración continua (CI)](../../devops/ci-cd/integracion-continua.md#ejemplos-de-pipeline): otro `.gitlab-ci.yml` corto con build y push de la imagen.
- [Despliegue continuo (CD)](../../devops/ci-cd/despliegue-continuo.md) y [Seguridad del pipeline](../../devsecops/identidades-y-pipeline/seguridad-pipeline.md): environments, aprobaciones y permisos mínimos (los conceptos son los mismos en GitLab).
- [Escaneo de seguridad en el pipeline](../../devsecops/escaneos/escaneo-en-pipeline.md): dónde encajan SAST, SCA y escaneo de imágenes.
- Traduce el workflow del [Lab 07](../../laboratorios/devops/github-actions-ci.md) a GitLab usando la tabla de equivalencias y compáralo con este archivo.

## Referencias

- [Referencia de la sintaxis de `.gitlab-ci.yml`](https://docs.gitlab.com/ci/yaml/)
- [Variables CI/CD predefinidas](https://docs.gitlab.com/ci/variables/predefined_variables/)
- [`rules` y `workflow:rules`: ejemplos](https://docs.gitlab.com/ci/jobs/job_rules/)
- [Optimizar el YAML: anclas, `extends` y `!reference`](https://docs.gitlab.com/ci/yaml/yaml_optimization/)
- [CI/CD components](https://docs.gitlab.com/ci/components/)
- [Autenticación con ID tokens (OIDC)](https://docs.gitlab.com/ci/secrets/id_token_authentication/)
- [Construir imágenes Docker en GitLab CI](https://docs.gitlab.com/ci/docker/using_docker_build/)
