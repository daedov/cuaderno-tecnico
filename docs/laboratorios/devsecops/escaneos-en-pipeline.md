---
tags:
  - laboratorio
  - seguridad
  - escaneo
  - sast
  - sca
  - github-actions
---

# Lab 12: Escaneos de seguridad en el pipeline

> Siembras fallos de seguridad en la API del Lab 05, los bloqueas con un pre-commit de gitleaks y con un workflow `security.yml` que convive con el `ci.yml` del Lab 07: SAST, SCA, escaneo de imagen e IaC scanning, resultados en SARIF en code scanning, bloqueo por severidad y una supresión con fecha de expiración.

| Nivel | Duración | Costo | Requisitos |
| --- | --- | --- | --- |
| Intermedio | ~90 min | Gratis (repositorio público en GitHub) | [Lab 04](../devops/git-flujo-pull-request.md), [Lab 05](../devops/docker-multistage-compose.md) y [Lab 07](../devops/github-actions-ci.md); Git, Docker, Python 3.12+, una cuenta de GitHub |

!!! info "Qué vas a aprender"
    - Bloquear secretos **antes** del commit con un **pre-commit hook** (gancho previo al commit) de gitleaks.
    - Ejecutar en local los cinco escaneos estáticos (secretos, SAST, SCA, imagen e IaC) y leer su salida.
    - Montar un workflow de GitHub Actions que sube cada resultado en **SARIF** a **code scanning**, separado del pipeline de CI.
    - Configurar el **gating** (bloqueo) por severidad y comprobar que un pull request vulnerable no puede fusionarse.
    - Corregir cada hallazgo en el origen y gestionar un riesgo aceptado con una **supresión** documentada que **caduca**.

!!! warning "Costos y seguridad"
    - Todo es gratis en un **repositorio público**. En uno privado, code scanning necesita GitHub Code Security (de pago): los escaneos y el bloqueo funcionan igual, pero la subida del SARIF falla.
    - Las vulnerabilidades y la credencial de este lab son **falsas y sembradas a propósito**. Nunca uses una credencial real para "probar" un escáner: si llega a un commit, considérala filtrada y rótala (ver [Seguridad del código](../../devsecops/codigo-y-dependencias/seguridad-codigo.md#si-se-filtra-un-secreto)).
    - Las rutas `/diagnostico/*` del Paso 1 son vulnerables de verdad: no publiques esa versión de la imagen ni la expongas fuera de tu máquina. No apliques el Terraform de este lab.

## Antes de empezar

| Herramienta | Versión probada | Instalación |
| --- | --- | --- |
| pre-commit | 4.7.0 | `pipx install pre-commit` |
| gitleaks | 8.30.1 | Binario de la página de releases o `brew install gitleaks` |
| Semgrep | 1.182.0 | `pipx install semgrep` (o la imagen `semgrep/semgrep:1.182.0`) |
| Trivy | 0.76.1 | Binario de la página de releases o `brew install trivy` |
| OSV-Scanner (opcional) | 2.7.0 | Binario de la página de releases o `brew install osv-scanner` |
| Checkov (opcional) | 3.3.30 | `pipx install checkov` |

Si descargas binarios de GitHub, comprueba el SHA-256 contra el archivo de *checksums* de la misma release (`sha256sum` en Linux/macOS, `Get-FileHash` en PowerShell).

Trabajas sobre el repositorio `lab-devops-app` de los labs anteriores, con todo esto ya en `main`:

- La API de tareas con FastAPI del [Lab 05](../devops/docker-multistage-compose.md): `app/main.py`, `app/storage.py`, `tests/test_api.py`, `requirements.txt`, `requirements-dev.txt`, el `Dockerfile` multi-stage que corre sin root, `Dockerfile.simple` y `compose.yaml`.
- El ruleset `proteger-main` del [Lab 04](../devops/git-flujo-pull-request.md) y el workflow `.github/workflows/ci.yml` del [Lab 07](../devops/github-actions-ci.md) (`lint`, `test`, `build`).
- El entorno virtual del Lab 05 con `requirements-dev.txt` instalado.

!!! note "Si no hiciste el Lab 05"
    Crea la app con los Pasos 1, 4 y 5 del [Lab 05](../devops/docker-multistage-compose.md) (código, `.dockerignore` y `Dockerfile`): este lab escanea exactamente esa imagen y sus decisiones (usuario 10001, imagen *slim*) cambian los resultados. Sin el `ci.yml` del Lab 07 el lab funciona igual; solo no verás los dos workflows lado a lado.

Teoría recomendada: [Escaneo de seguridad en el pipeline](../../devsecops/escaneos/escaneo-en-pipeline.md) (el mapa de los ocho escaneos) y las notas de [Secret scanning](../../devsecops/escaneos/secret-scanning.md), [SAST](../../devsecops/escaneos/sast.md), [SCA](../../devsecops/escaneos/sca.md), [Container scanning](../../devsecops/escaneos/container-scanning.md) e [IaC scanning](../../devsecops/escaneos/iac-scanning.md).

## Arquitectura

```mermaid
flowchart LR
    dev[Tu equipo] -->|git commit| pc[pre-commit<br/>gitleaks]
    pc -->|push + PR| gh[GitHub Actions]
    gh --> ci[ci.yml del Lab 07<br/>lint · test · build]
    gh --> sec[security.yml]
    sec --> s1[secretos<br/>gitleaks]
    sec --> s2[sast<br/>Semgrep]
    sec --> s3[sca<br/>Trivy fs]
    sec --> s4[iac<br/>Trivy config]
    sec --> s5[imagen<br/>Trivy image]
    s1 & s2 & s3 & s4 & s5 -->|SARIF| cs[Code scanning<br/>pestaña Security y PR]
    ci & s1 & s2 & s3 & s4 & s5 -->|required checks| gate{Ruleset de main}
    gate -->|alguno en rojo| bloq[Merge bloqueado]
    gate -->|todos en verde| ok[Merge permitido]
```

El pre-commit es la primera red (rápida, en tu máquina); el workflow es la red que no se puede saltar. Cada job de `security.yml` falla si encuentra algo HIGH o CRITICAL y, pase lo que pase, sube su SARIF para que veas el detalle en GitHub. El ruleset de `main` exige los checks de los dos workflows.

## Paso a paso

### Paso 1: Siembra los fallos en la API

Vas a introducir a propósito un fallo de cada tipo en la app real para ver a cada escáner detectarlo; en el Paso 10 los corriges.

```bash
cd lab-devops-app
git switch main && git pull
git switch -c lab12-escaneos
mkdir -p infra
```

**Código vulnerable.** Un módulo nuevo con dos rutas de "diagnóstico": una construye SQL con un f-string y la otra ejecuta un comando con `shell=True` y la entrada del usuario. Son los dos errores clásicos de [inyección](../../devsecops/codigo-y-dependencias/seguridad-codigo.md#usar-consultas-parametrizadas).

```python title="app/diagnostico.py"
"""Endpoints de diagnóstico. VULNERABLES A PROPÓSITO (Lab 12): no los copies."""

import sqlite3
import subprocess

from fastapi import APIRouter

router = APIRouter(prefix="/diagnostico", tags=["diagnostico"])


def _conexion() -> sqlite3.Connection:
    """Base de datos en memoria con dos usuarios de ejemplo."""
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE usuarios (id INTEGER PRIMARY KEY, nombre TEXT)")
    conn.executemany("INSERT INTO usuarios (nombre) VALUES (?)", [("ana",), ("luis",)])
    return conn


@router.get("/usuarios")
def buscar_usuario(nombre: str) -> dict:
    conn = _conexion()
    # VULNERABLE: SQL construido con f-string a partir de la entrada del usuario
    consulta = f"SELECT id, nombre FROM usuarios WHERE nombre = '{nombre}'"
    filas = conn.execute(consulta).fetchall()
    return {"resultados": filas}


@router.get("/ping")
def ping(host: str = "127.0.0.1") -> dict:
    # VULNERABLE: comando con shell=True y entrada del usuario
    salida = subprocess.run(
        f"ping -c 1 {host}",
        shell=True,
        capture_output=True,
        text=True,
        timeout=5,
        check=False,
    )
    return {"host": host, "codigo": salida.returncode}
```

Registra el router en `app/main.py` (dos líneas nuevas, resaltadas):

```python title="app/main.py (fragmento)" hl_lines="1 7"
from app.diagnostico import router as diagnostico_router
from app.storage import crear_storage

# ...

app = FastAPI(title="Lab API", version=VERSION)
app.include_router(diagnostico_router)
```

Y añade un test de la ruta nueva al final de `tests/test_api.py`, para que el CI siga probando lo que existe:

```python title="tests/test_api.py (al final)"
def test_diagnostico_busca_usuario():
    respuesta = client.get("/diagnostico/usuarios", params={"nombre": "ana"})
    assert respuesta.status_code == 200
    assert respuesta.json() == {"resultados": [[1, "ana"]]}
```

**Dependencia vulnerable.** Añade una línea al `requirements.txt` del Lab 05. `python-multipart` es la librería que FastAPI usa para leer formularios; la 0.0.6 tiene varias CVE HIGH corregidas en versiones posteriores. Es Python puro, así que se instala igual en tu máquina, en el CI y en la imagen.

```text title="requirements.txt" hl_lines="4"
fastapi==0.162.0
uvicorn==0.54.0
psycopg[binary]==3.3.6
python-multipart==0.0.6
```

**Infraestructura mal configurada.** Un Terraform pequeño con un bucket sin bloqueo de acceso público y un Security group con SSH abierto a internet:

```hcl title="infra/main.tf"
# MAL CONFIGURADO A PROPÓSITO (Lab 12): no lo apliques
resource "aws_s3_bucket" "datos" {
  bucket = "lab12-datos-ejemplo"
}

resource "aws_s3_bucket_public_access_block" "datos" {
  bucket                  = aws_s3_bucket.datos.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_security_group" "web" {
  name        = "lab12-web"
  description = "SG del Lab 12"

  ingress {
    description = "SSH desde cualquier lugar"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Comprueba que la app sigue funcionando (es lo mismo que hará el `ci.yml` del Lab 07) y haz commit **antes** de instalar el hook, para que el siguiente paso pruebe solo el secreto:

```bash
pip install -r requirements-dev.txt
ruff check . && ruff format --check . && pytest -q
git add -A && git commit -m "lab12: siembra fallos de seguridad"
```

```text
All checks passed!
6 files already formatted
....                                                                     [100%]
4 passed in 2.31s
```

Los escáneres de seguridad no sustituyen a los tests: los cuatro tests pasan aunque la app tenga una inyección SQL.

### Paso 2: Instala el pre-commit con gitleaks

El hook corre en tu máquina en cada `git commit` y revisa solo lo que está en *staging*. Por qué en pre-commit: un secreto que nunca llega al historial no hay que rotarlo ni reescribir commits ([Secret scanning](../../devsecops/escaneos/secret-scanning.md#historial-completo-vs-solo-cambios)).

```yaml title=".pre-commit-config.yaml"
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1          # fija la versión; actualízala con `pre-commit autoupdate`
    hooks:
      - id: gitleaks
```

```bash
pre-commit install            # escribe .git/hooks/pre-commit
git add .pre-commit-config.yaml && git commit -m "lab12: pre-commit con gitleaks"
```

```text
pre-commit installed at .git/hooks/pre-commit
[INFO] Initializing environment for https://github.com/gitleaks/gitleaks.
[INFO] Installing environment for https://github.com/gitleaks/gitleaks.
[INFO] This may take a few minutes...
Detect hardcoded secrets.................................................Passed
```

La primera ejecución tarda unos minutos (en la prueba de este lab, unos 3,5): pre-commit compila gitleaks desde el código fuente y, si no tienes Go, descarga también el toolchain. Las siguientes ejecuciones tardan menos de un segundo.

### Paso 3: Siembra un secreto falso y mira cómo lo bloquea

Crea un archivo con una credencial **inventada** con el formato de una access key de AWS:

```python title="app/config.py"
# Lab 12: credencial FALSA sembrada a propósito para probar la detección
AWS_ACCESS_KEY_ID = "AKIALAB2FAKEKEYZQXW7"
AWS_SECRET_ACCESS_KEY = "Lab12+Falsa/q8vN3kT1pR6sW9yB2eH5jM0cF4gL"
```

```bash
git add app/config.py
git commit -m "config"
```

Salida (abreviada; el hook usa `--redact`, así que el secreto no se imprime):

```text
Detect hardcoded secrets.................................................Failed
- hook id: gitleaks
- exit code: 1

Finding:     ...WS_ACCESS_KEY_ID = "REDACTED
RuleID:      aws-access-token
Entropy:     3.584184
File:        app/config.py
Line:        2
Fingerprint: app/config.py:aws-access-token:2

Finding:     AWS_SECRET_ACCESS_KEY = "REDACTED"
RuleID:      generic-api-key
Entropy:     4.953056
File:        app/config.py
Line:        3
Fingerprint: app/config.py:generic-api-key:3

INF 0 commits scanned.
WRN leaks found: 2
```

El commit **no se crea**. Quita el archivo del staging y bórralo; en la app real, las credenciales van en un gestor de secretos o se montan como archivo, como hiciste con `DB_PASSWORD_FILE` en el Lab 05 ([Secretos e identidades](../../devsecops/identidades-y-pipeline/secretos-identidades.md)).

=== "Linux/macOS"

    ```bash
    git rm --cached app/config.py && rm app/config.py
    ```

=== "Windows (PowerShell)"

    ```powershell
    git rm --cached app/config.py; Remove-Item app/config.py
    ```

!!! tip "¿Por qué no usar la clave de ejemplo de la documentación de AWS?"
    `AKIAIOSFODNN7EXAMPLE` (y su secreto `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`) están en la *allowlist* de gitleaks y de Trivy: con esa clave ambos responden "no leaks found". Para probar un escáner necesitas un valor falso con el formato real.

!!! note "El pre-commit se puede saltar"
    `git commit --no-verify` ignora los hooks, y quien no ejecutó `pre-commit install` no los tiene. Por eso el mismo escaneo se repite en el pipeline, donde nadie puede saltarlo.

### Paso 4: SAST con Semgrep

El **SAST** (*Static Application Security Testing*, análisis estático) lee tu código sin ejecutarlo y busca patrones peligrosos, como una entrada del usuario que llega a una consulta SQL ([SAST](../../devsecops/escaneos/sast.md)).

```bash
semgrep scan --config p/default --metrics off --severity ERROR --error app/
```

Salida (abreviada):

```text
Ran 128 rules on 4 files: 2 findings.

    app\diagnostico.py
   ❯❯❱ python.sqlalchemy.security.sqlalchemy-execute-raw-query.sqlalchemy-execute-raw-query
          ❰❰ Blocking ❱❱
          Avoiding SQL string concatenation: untrusted input concatenated with raw SQL query
          can result in SQL Injection. [...]
           24┆ filas = conn.execute(consulta).fetchall()

   ❯❯❱ python.lang.security.audit.subprocess-shell-true.subprocess-shell-true
          ❰❰ Blocking ❱❱
          Found 'subprocess' function 'run' with 'shell=True'. [...]
           33┆ shell=True,
```

- `--error` hace que el comando devuelva código 1 si hay hallazgos: es lo que usará el pipeline para bloquear. `--severity ERROR` deja fuera los avisos menores; sin él verías además `python.lang.security.audit.formatted-sql-query` (WARNING) en la misma línea 24.
- El ID de la primera regla menciona SQLAlchemy aunque la app usa `sqlite3`: las reglas buscan un **patrón** de código (`.execute()` con un string formateado), no una librería. Lee el mensaje, no solo el ID.

!!! info "¿Por qué `p/default` y no `p/python`?"
    Con este código, `p/python` solo detecta el `shell=True`; la regla del SQL con f-string está en `p/default`. `p/fastapi` no detecta ninguno de los dos. Los *rulesets* cambian con el tiempo: cuando adoptes Semgrep, siembra un fallo conocido como aquí y comprueba que tu configuración lo encuentra.

### Paso 5: SCA de dependencias con Trivy u OSV-Scanner

El **SCA** (*Software Composition Analysis*) compara tus dependencias con bases de datos de vulnerabilidades ([SCA](../../devsecops/escaneos/sca.md)).

=== "Trivy"

    ```bash
    trivy fs --scanners vuln --severity HIGH,CRITICAL --exit-code 1 .
    ```

    ```text
    requirements.txt (pip)
    ======================
    Total: 5 (HIGH: 5, CRITICAL: 0)

    │     Library      │ Vulnerability  │ Severity │ Status │ Installed Version │ Fixed Version │
    │ python-multipart │ CVE-2024-24762 │ HIGH     │ fixed  │ 0.0.6             │ 0.0.7         │
    │                  │ CVE-2024-53981 │          │        │                   │ 0.0.18        │
    │                  │ CVE-2026-24486 │          │        │                   │ 0.0.22        │
    │                  │ CVE-2026-42561 │          │        │                   │ 0.0.27        │
    │                  │ CVE-2026-53539 │          │        │                   │ 0.0.30        │
    ```

=== "OSV-Scanner"

    ```bash
    osv-scanner scan source --no-resolve -L requirements.txt
    ```

    ```text
    Total 1 package affected by 9 known vulnerabilities (0 Critical, 5 High, 1 Medium, 3 Low, 0 Unknown) from 1 ecosystem.
    9 vulnerabilities can be fixed.

    | OSV URL                         | CVSS | ECOSYSTEM | PACKAGE          | VERSION | FIXED VERSION | SOURCE           |
    | https://osv.dev/PYSEC-2026-1850 | 7.5  | PyPI      | python-multipart | 0.0.6   | 0.0.7         | requirements.txt |
    | https://osv.dev/PYSEC-2026-1851 | 8.7  | PyPI      | python-multipart | 0.0.6   | 0.0.18        | requirements.txt |
    ...
    ```

    `--no-resolve` evita que OSV-Scanner intente adivinar las dependencias transitivas de un `requirements.txt` sin lockfile: sin esa opción, en la prueba de este lab añadió versiones antiguas de `anyio`, `h11` o `idna` que la app no instala.

Fíjate en la columna `Fixed Version`: cada CVE se corrige en una versión distinta, y la que las corrige **todas** es la mayor (0.0.30). Esa es la versión mínima a la que debes subir. Las bases de datos cambian a diario, así que tu salida puede tener más filas.

### Paso 6: Escanea la imagen con Trivy

El container scanning revisa los paquetes del sistema operativo y las librerías **dentro** de la imagen, incluidas las que no están en tu `requirements.txt` ([Container scanning](../../devsecops/escaneos/container-scanning.md)). Construye la imagen con el `Dockerfile` del Lab 05:

```bash
docker build -t lab-api:lab12 .
trivy image --severity HIGH,CRITICAL --ignore-unfixed lab-api:lab12
```

Salida (abreviada; la tabla real lista también, con 0, cada paquete del virtualenv):

```text
│ lab-api:lab12 (debian 13.7) │   debian   │ 0 │
│ Python                      │ python-pkg │ 4 │
│ .../python_multipart-0.0.6.dist-info/METADATA │ python-pkg │ 5 │

Python (python-pkg)
Total: 9 (HIGH: 9, CRITICAL: 0)
│ msgpack                     │ GHSA-6v7p-g79w-8964 │ HIGH │ fixed │ 1.1.2  │ 1.2.1  │
│ python-multipart (METADATA) │ CVE-2024-24762      │      │       │ 0.0.6  │ 0.0.7  │
│                             │ ... (las 5 del Paso 5)                              │
│ setuptools                  │ CVE-2025-47273      │      │       │ 70.3.0 │ 78.1.1 │
│ urllib3                     │ CVE-2026-97687      │      │       │ 2.7.0  │ 2.8.0  │
│                             │ CVE-2026-97689      │      │       │        │        │
```

Hay dos orígenes:

- **python-multipart**: el mismo problema que vio el SCA, ahora dentro de la imagen.
- **msgpack, setuptools y urllib3** no están en tu `requirements.txt`: son librerías **internas de pip** (`pip/_vendor`). pip publica un SBOM de lo que incluye (`bom.cdx.json`) y Trivy lo lee; por eso aparecen bajo el objetivo `Python`. pip está dos veces en la imagen: en la base `python:3.14.9-slim` y en `/opt/venv`, que se creó con pip para instalar las dependencias.

`--ignore-unfixed` oculta lo que no tiene parche. Para ver por qué el Lab 05 eligió una base *slim*, compara las bases (resultados al escribir el lab, solo HIGH y CRITICAL del sistema operativo):

| Imagen base | Sin `--ignore-unfixed` | Con `--ignore-unfixed` |
| --- | --- | --- |
| `python:3.14.9` | 455 HIGH + 24 CRITICAL | 3 HIGH |
| `python:3.14.9-slim` | 44 HIGH | 0 |

Menos paquetes es menos superficie que parchear ([Seguridad de contenedores](../../devsecops/infraestructura-y-contenedores/seguridad-contenedores.md#imagenes-base-minimas)).

### Paso 7: IaC scanning con Trivy o Checkov

El IaC scanning lee el Terraform **antes** de aplicarlo y encuentra malas configuraciones ([IaC scanning](../../devsecops/escaneos/iac-scanning.md)). Escanear `.` (y no solo `infra/`) incluye también los Dockerfiles.

=== "Trivy"

    ```bash
    trivy config --severity HIGH,CRITICAL --exit-code 1 .
    ```

    ```text
    │ Dockerfile        │ dockerfile │ 0 │
    │ Dockerfile.simple │ dockerfile │ 1 │
    │ infra             │ terraform  │ 0 │
    │ infra/main.tf     │ terraform  │ 6 │

    Dockerfile.simple (dockerfile)
    Failures: 1 (HIGH: 1, CRITICAL: 0)
    DS-0002 (HIGH): Specify at least 1 USER command in Dockerfile with non-root user as argument

    infra/main.tf (terraform)
    Failures: 6 (HIGH: 6, CRITICAL: 0)
    AWS-0086 (HIGH): Public access block does not block public ACLs
    AWS-0087 (HIGH): Public access block does not block public policies
    AWS-0091 (HIGH): Public access block does not ignore public ACLs
    AWS-0093 (HIGH): Public access block does not restrict public buckets
    AWS-0107 (HIGH): Security group rule allows unrestricted ingress from any IP address.
    AWS-0132 (HIGH): Bucket does not encrypt data with a customer managed key.
    ```

    Sin `--severity` aparecen además `AWS-0090` (MEDIUM, versionado desactivado) y `AWS-0089` (LOW, logging desactivado) en el bucket, y `DS-0026` (LOW, sin `HEALTHCHECK`) en `Dockerfile.simple`. El `Dockerfile` del Lab 05 sale limpio: corre como el usuario 10001 y tiene `HEALTHCHECK`.

=== "Checkov"

    ```bash
    checkov -d infra --framework terraform --compact --quiet
    ```

    ```text
    terraform scan results:
    Passed checks: 9, Failed checks: 13, Skipped checks: 0
    Check: CKV_AWS_53: "Ensure S3 bucket has block public ACLS enabled"
        FAILED for resource: aws_s3_bucket_public_access_block.datos
    Check: CKV_AWS_24: "Ensure no security groups allow ingress from 0.0.0.0:0 to port 22"
        FAILED for resource: aws_security_group.web
    ...
    ```

    Checkov reporta más hallazgos porque incluye por defecto buenas prácticas (logging, versionado, replicación, notificaciones) y no clasifica por severidad en la versión open source.

Trivy encontró también el `Dockerfile.simple` del Lab 05, la imagen "ingenua" que corre como root: lo creaste solo para comparar tamaños y ya no lo necesitas.

### Paso 8: El workflow de seguridad, junto al CI

Ahora lleva todo al pipeline. Este lab usa un **workflow aparte**, `security.yml`, en lugar de añadir jobs al `ci.yml` del Lab 07:

| Criterio | `ci.yml` (Lab 07) | `security.yml` (Lab 12) |
| --- | --- | --- |
| Pregunta que responde | ¿Funciona y se puede publicar? | ¿Es seguro? |
| Disparadores | PR, push a `main`, tags `v*` | PR, push a `main` y **semanal** (CVE nuevas sin cambios de código) |
| Permisos | `packages: write` solo en `build` | `security-events: write` en cada job, nunca `packages` |
| Si falla | No se publica la imagen | El ruleset bloquea el merge |

Separarlos permite el escaneo programado sin relanzar tests ni publicar imágenes, mantiene cada `GITHUB_TOKEN` con lo mínimo y deja que un equipo de seguridad sea dueño (CODEOWNERS) de su workflow. El costo es que la imagen se construye dos veces en cada PR (en `build` y en `imagen`). Si en tu proyecto prefieres que **nada se publique** sin escanear, la alternativa es añadir los jobs a `ci.yml` y poner `needs:` en `build`; aquí basta con que el ruleset exija ambos workflows antes del merge.

Cada job pide solo sus permisos, falla con HIGH o CRITICAL (`exit-code: 1`, `--error`) y sube su SARIF aunque falle (`!cancelled()`). Las actions de terceros van **fijadas por SHA** con la versión en un comentario ([Seguridad del pipeline](../../devsecops/identidades-y-pipeline/seguridad-pipeline.md#pinning-de-actions-por-sha)).

```yaml title=".github/workflows/security.yml"
name: security

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  schedule:
    - cron: "0 6 * * 1" # lunes 06:00 UTC: CVE nuevas sin cambios de código

# Sin permisos por defecto: cada job pide solo lo que necesita
permissions: {}

concurrency:
  group: security-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

env:
  TRIVY_VERSION: v0.76.1

jobs:
  secretos:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: read
      security-events: write # subir SARIF a code scanning
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          fetch-depth: 0 # todo el historial: un secreto borrado sigue en commits viejos
          persist-credentials: false
      - name: Gitleaks (historial completo)
        run: |
          docker run --rm \
            --user "$(id -u):$(id -g)" \
            -e GIT_CONFIG_COUNT=1 \
            -e GIT_CONFIG_KEY_0=safe.directory \
            -e GIT_CONFIG_VALUE_0=/repo \
            -v "$PWD:/repo" \
            ghcr.io/gitleaks/gitleaks:v8.30.1 \
            git /repo --redact --exit-code 1 \
            --report-format sarif --report-path /repo/gitleaks.sarif
      - uses: github/codeql-action/upload-sarif@9b3254085494b55a0f7c4c2b3d2d52cc712ce370 # v4.39.1
        if: ${{ !cancelled() && hashFiles('gitleaks.sarif') != '' }}
        with:
          sarif_file: gitleaks.sarif
          category: gitleaks

  sast:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Semgrep
        run: |
          docker run --rm -v "$PWD:/src" -w /src semgrep/semgrep:1.182.0 \
            semgrep scan --config p/default --metrics off \
            --severity ERROR --error --sarif --output semgrep.sarif
      - uses: github/codeql-action/upload-sarif@9b3254085494b55a0f7c4c2b3d2d52cc712ce370 # v4.39.1
        if: ${{ !cancelled() && hashFiles('semgrep.sarif') != '' }}
        with:
          sarif_file: semgrep.sarif
          category: semgrep

  sca:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Trivy fs (dependencias)
        uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0
        with:
          version: ${{ env.TRIVY_VERSION }}
          scan-type: fs
          scanners: vuln
          severity: HIGH,CRITICAL
          ignore-unfixed: true
          format: sarif
          output: trivy-sca.sarif
          limit-severities-for-sarif: true
          exit-code: 1
      - uses: github/codeql-action/upload-sarif@9b3254085494b55a0f7c4c2b3d2d52cc712ce370 # v4.39.1
        if: ${{ !cancelled() && hashFiles('trivy-sca.sarif') != '' }}
        with:
          sarif_file: trivy-sca.sarif
          category: trivy-sca

  iac:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Trivy config (IaC y Dockerfile)
        uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0
        with:
          version: ${{ env.TRIVY_VERSION }}
          scan-type: config
          scan-ref: .
          severity: HIGH,CRITICAL
          trivyignores: .trivyignore.yaml
          format: sarif
          output: trivy-iac.sarif
          limit-severities-for-sarif: true
          exit-code: 1
      - uses: github/codeql-action/upload-sarif@9b3254085494b55a0f7c4c2b3d2d52cc712ce370 # v4.39.1
        if: ${{ !cancelled() && hashFiles('trivy-iac.sarif') != '' }}
        with:
          sarif_file: trivy-iac.sarif
          category: trivy-iac

  imagen:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: Build de la etapa runtime (sin publicar)
        run: docker build --target runtime -t lab-api:${{ github.sha }} .
      - name: Trivy image
        uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0
        with:
          version: ${{ env.TRIVY_VERSION }}
          scan-type: image
          image-ref: lab-api:${{ github.sha }}
          scanners: vuln
          severity: HIGH,CRITICAL
          ignore-unfixed: true
          format: sarif
          output: trivy-imagen.sarif
          limit-severities-for-sarif: true
          exit-code: 1
      - uses: github/codeql-action/upload-sarif@9b3254085494b55a0f7c4c2b3d2d52cc712ce370 # v4.39.1
        if: ${{ !cancelled() && hashFiles('trivy-imagen.sarif') != '' }}
        with:
          sarif_file: trivy-imagen.sarif
          category: trivy-imagen
```

Detalles que importan:

- **`concurrency` con su propio grupo** (`security-…`): si compartiera el grupo `ci-…` del Lab 07, un workflow cancelaría al otro.
- **Gitleaks en contenedor**: `--user "$(id -u):$(id -g)"` ejecuta gitleaks con el mismo usuario del runner (el dueño del checkout), así el SARIF no queda como archivo de root; las variables `GIT_CONFIG_*` declaran `/repo` como `safe.directory`. Sin eso, si el usuario del contenedor no es el dueño del repo montado, git lo rechaza por *dubious ownership* y gitleaks termina con `0 commits scanned` y **código 0**: un check verde que no revisó nada (ver Problemas comunes).
- **`limit-severities-for-sarif: true`** es imprescindible en `trivy-action` v0.36.0: sin él, la action quita el filtro `severity` cuando el formato es SARIF y el job fallaría también por MEDIUM y LOW. Con él, el SARIF solo lleva HIGH y CRITICAL.
- **`version`** fija la versión de Trivy que instala la action (por defecto, la v0.36.0 usa la v0.70.0).
- **`hashFiles(...) != ''`** evita un segundo error confuso si el escaneo falló antes de escribir el SARIF (por ejemplo, al no poder descargar la imagen).
- Los inputs (`version`, `scanners`, `trivyignores`, `ignore-unfixed`, `limit-severities-for-sarif`) están en el `action.yaml` de la v0.36.0; `trivyignores` acepta un único `.trivyignore.yaml` y falla si el archivo no existe.

Verifica los SHA tú misma, como en el Lab 07 (los tags son anotados: usa la línea `^{}`):

```bash
git ls-remote --tags https://github.com/aquasecurity/trivy-action.git | grep 'v0.36.0'
git ls-remote --tags https://github.com/github/codeql-action.git | grep 'v4.39.1'
```

```text
a9c7b0f06e461e9d4b4d1711f154ee024b8d7ab8    refs/tags/v0.36.0
ed142fd0673e97e23eac54620cfb913e5ce36c25    refs/tags/v0.36.0^{}
8498dc4c2b27cdd99baf0f87955b29ebbf30c78d    refs/tags/v4.39.1
9b3254085494b55a0f7c4c2b3d2d52cc712ce370    refs/tags/v4.39.1^{}
```

El job `iac` lee `.trivyignore.yaml`, que completarás en el Paso 10; hasta entonces créalo con tu editor con esta única línea (en PowerShell, `echo ... >` escribe UTF-16 y Trivy no lo lee):

```yaml title=".trivyignore.yaml"
misconfigurations: []
```

Si tienes `actionlint` (el reto 2 del Lab 07), valida el workflow antes de subirlo; no debe mostrar nada:

```bash
actionlint .github/workflows/security.yml .github/workflows/ci.yml
```

```bash
git add .github/workflows/security.yml .trivyignore.yaml
git commit -m "lab12: workflow de seguridad"
git push -u origin lab12-escaneos
```

Abre un pull request hacia `main`. Resultado esperado:

| Workflow | Job | Estado | Por qué |
| --- | --- | --- | --- |
| `ci` | `lint`, `test (3.13)`, `test (3.14)`, `build` | Verde | El código funciona: los tests no buscan vulnerabilidades |
| `security` | `secretos` | Verde | El hook impidió que la credencial falsa llegara al historial |
| `security` | `sast` | Rojo | SQL con f-string y `shell=True` |
| `security` | `sca` | Rojo | `python-multipart` 0.0.6 |
| `security` | `iac` | Rojo | 6 hallazgos en `infra/main.tf` y `DS-0002` en `Dockerfile.simple` |
| `security` | `imagen` | Rojo | `python-multipart` y las librerías internas de pip |

Si te saltaste el hook y la credencial llegó a un commit, `secretos` también falla: así lo ves desde el otro lado.

### Paso 9: Lee los resultados en code scanning y activa el bloqueo

1. En la pestaña **Security > Code scanning** del repositorio verás las alertas agrupadas por herramienta (`category`). Abre una: muestra el archivo, la línea y la regla.
2. En el PR, la pestaña **Files changed** muestra las alertas nuevas anotadas en la línea exacta.
3. Edita el ruleset `proteger-main` del Lab 04 (**Settings > Rules > Rulesets**) y, en **Require status checks to pass**, añade `secretos`, `sast`, `sca`, `iac` e `imagen` junto a los checks del Lab 07. Ahora el botón de merge queda bloqueado mientras falle cualquiera.

Este es el **gating por severidad**: Critical y High bloquean. Con esta configuración, Medium y Low ni bloquean ni llegan a code scanning (`limit-severities-for-sarif: true` y `--severity ERROR` filtran también el SARIF). Si quieres verlos sin bloquear, añade un segundo paso de Trivy con `exit-code: 0`, sin el límite de severidad y con otra `category`. Para cambiar el umbral se toca `severity` en Trivy y `--severity` en Semgrep, no el código.

### Paso 10: Corrige los hallazgos y gestiona un riesgo aceptado

Corrige cada fallo **en el origen**. El código: consulta parametrizada y, para el comando, una lista de valores permitidos más una lista de argumentos sin shell ([Nunca `shell=True` con entradas externas](../../python/scripting/sistema-procesos.md#nunca-shelltrue-con-entradas-externas)).

```python title="app/diagnostico.py"
"""Endpoints de diagnóstico, corregidos en el Lab 12."""

import sqlite3
import subprocess

from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/diagnostico", tags=["diagnostico"])

HOSTS_PERMITIDOS = {"localhost", "127.0.0.1"}


def _conexion() -> sqlite3.Connection:
    """Base de datos en memoria con dos usuarios de ejemplo."""
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE usuarios (id INTEGER PRIMARY KEY, nombre TEXT)")
    conn.executemany("INSERT INTO usuarios (nombre) VALUES (?)", [("ana",), ("luis",)])
    return conn


@router.get("/usuarios")
def buscar_usuario(nombre: str) -> dict:
    conn = _conexion()
    # Consulta parametrizada: el driver trata `nombre` como dato, nunca como SQL
    filas = conn.execute(
        "SELECT id, nombre FROM usuarios WHERE nombre = ?", (nombre,)
    ).fetchall()
    return {"resultados": filas}


@router.get("/ping")
def ping(host: str = "127.0.0.1") -> dict:
    # Lista de valores permitidos + lista de argumentos, sin shell
    if host not in HOSTS_PERMITIDOS:
        raise HTTPException(status_code=400, detail="host no permitido")
    try:
        salida = subprocess.run(
            ["ping", "-c", "1", host],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except FileNotFoundError:  # la imagen slim no trae ping
        raise HTTPException(status_code=501, detail="ping no disponible") from None
    return {"host": host, "codigo": salida.returncode}
```

Añade dos tests que prueban la corrección (si los ejecutas con el código del Paso 1, **fallan**: la inyección devuelve los dos usuarios y el host malicioso responde 200):

```python title="tests/test_api.py (al final)"
def test_diagnostico_no_permite_inyeccion_sql():
    respuesta = client.get("/diagnostico/usuarios", params={"nombre": "x' OR '1'='1"})
    assert respuesta.status_code == 200
    assert respuesta.json() == {"resultados": []}


def test_diagnostico_rechaza_host_no_permitido():
    respuesta = client.get("/diagnostico/ping", params={"host": "127.0.0.1; id"})
    assert respuesta.status_code == 400
```

El resto:

- En `requirements.txt`, sube a `python-multipart==0.0.32` (la última al escribir el lab; como mínimo, la 0.0.30 del Paso 5).
- En `infra/main.tf`, pon los cuatro `block_*`/`ignore_*`/`restrict_*` en `true` y cambia el `cidr_blocks` del SSH a una red interna, por ejemplo `["10.0.0.0/16"]`.
- Borra `Dockerfile.simple` (`git rm Dockerfile.simple`): era solo para comparar en el Lab 05.
- Quita pip de la imagen final. Solo hace falta para **construir** (etapa `build`), y en la etapa `runtime` trae sus librerías internas vulnerables. En el `Dockerfile`, justo después del `COPY --from=build`:

```dockerfile title="Dockerfile (etapa runtime)" hl_lines="2-4"
COPY --from=build /opt/venv /opt/venv
# pip solo hace falta para construir: fuera de la imagen final (con sus librerías internas)
RUN /usr/local/bin/python -m pip uninstall -y pip \
    && /opt/venv/bin/python -m pip uninstall -y pip
COPY app/ ./app/
```

Se desinstala dos veces porque hay dos pip: el de la imagen base (`/usr/local`) y el del virtualenv. La ruta completa importa: como `/opt/venv/bin` va primero en el `PATH`, un `python -m pip` a secas borraría el del virtualenv dos veces y fallaría.

Comprueba en local:

```bash
pytest -q
semgrep scan --config p/default --metrics off --severity ERROR --error app/
trivy fs --scanners vuln --severity HIGH,CRITICAL --exit-code 1 .
docker build -t lab-api:lab12 . && trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 lab-api:lab12
trivy config --severity HIGH,CRITICAL --exit-code 1 .
```

```text
6 passed in 1.46s
Ran 128 rules on 4 files: 0 findings.
│ requirements.txt │ pip │ 0 │
│ lab-api:lab12 (debian 13.7) │ debian │ 0 │      (y ningún paquete de Python con hallazgos)

infra/main.tf (terraform)
Failures: 1 (HIGH: 1, CRITICAL: 0)
AWS-0132 (HIGH): Bucket does not encrypt data with a customer managed key.
```

Queda `AWS-0132`: el bucket no usa una clave KMS gestionada por ti (CMK). Supón que tu equipo decidió que para este bucket de laboratorio, sin datos sensibles, el cifrado por defecto SSE-S3 es suficiente. No vas a corregirlo, así que lo **suprimes con motivo, responsable y fecha de expiración**:

```yaml title=".trivyignore.yaml"
misconfigurations:
  - id: AWS-0132
    paths:
      - "infra/main.tf"          # relativo al directorio escaneado (aquí, la raíz)
    statement: "Bucket de laboratorio sin datos sensibles: SSE-S3 basta. Ticket SEC-12. Aprobó: Dani"
    expired_at: 2027-01-31
```

=== "Linux/macOS"

    ```bash
    trivy config --ignorefile .trivyignore.yaml --severity HIGH,CRITICAL --exit-code 1 .
    echo $?        # 0: ya no bloquea
    ```

=== "Windows (PowerShell)"

    ```powershell
    trivy config --ignorefile .trivyignore.yaml --severity HIGH,CRITICAL --exit-code 1 .
    $LASTEXITCODE  # 0: ya no bloquea
    ```

Prueba la expiración: cambia `expired_at` a una fecha pasada (por ejemplo `2026-01-31`) y repite. El hallazgo **vuelve a aparecer** y el comando devuelve 1. Así, ninguna supresión se queda olvidada para siempre ([Container scanning](../../devsecops/escaneos/container-scanning.md#supresiones-con-fecha-de-expiracion)). Trivy no carga `.trivyignore.yaml` solo: en local necesita `--ignorefile` y en el workflow, el input `trivyignores`.

!!! note "Falso positivo o riesgo aceptado"
    En sentido estricto, AWS-0132 no es un falso positivo (el hallazgo es cierto) sino un **riesgo aceptado** (*risk acceptance*) en tu contexto. El mecanismo es el mismo para ambos: supresión acotada a un archivo, con motivo, quién lo aprobó y caducidad. gitleaks (`.gitleaksignore` con el *fingerprint*) y Semgrep (`# nosemgrep: <regla>`) no tienen caducidad: deja el ticket y la fecha de revisión en un comentario.

```bash
ruff check . && ruff format --check .
git add -A && git commit -m "lab12: corrige hallazgos y documenta la supresión"
git push
```

## Verificación

| Comprobación | Resultado esperado |
| --- | --- |
| `git commit` de un archivo con la credencial falsa | `Detect hardcoded secrets....Failed` y el commit no se crea |
| `pytest -q` tras corregir | `6 passed` (los dos tests nuevos fallaban con el código del Paso 1) |
| `semgrep scan --config p/default --severity ERROR --error app/` | `0 findings`, código de salida 0 |
| `trivy fs --scanners vuln --severity HIGH,CRITICAL --exit-code 1 .` | Código de salida 0 |
| `trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 lab-api:lab12` | Código de salida 0 (imagen sin pip) |
| `trivy config --ignorefile .trivyignore.yaml --severity HIGH,CRITICAL --exit-code 1 .` | Código de salida 0; con `expired_at` en el pasado, 1 |
| Checks del PR tras el último push | Los cuatro de `ci` y los cinco de `security` en verde; merge permitido |
| Security > Code scanning | Las alertas corregidas pasan a *Closed* (*Fixed*) |

Las bases de vulnerabilidades cambian a diario: si una CVE nueva aparece en Debian o en otra librería, `imagen` o `sca` pueden volver a rojo sin que cambies nada. Es justo lo que debe detectar el escaneo programado de los lunes.

## Retos extra

1. Añade al `.pre-commit-config.yaml` un hook de Semgrep y otro de Trivy para IaC, y mide cuánto tarda cada commit. Pista: lo lento va mejor en el pipeline.
2. Activa en Semgrep el escaneo **solo de lo nuevo** con `--baseline-commit` y compara con el escaneo completo ([SAST](../../devsecops/escaneos/sast.md#umbrales-y-cuando-fallar-el-build)).
3. Genera un SBOM de la imagen con `trivy image --format cyclonedx` y escanéalo después con `trivy sbom` ([Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md#sbom)).
4. Mueve los escaneos `sca` e `imagen` al `ci.yml` y haz que `build` dependa de ellos (`needs:`). ¿Qué ganas y qué pierdes frente al workflow separado? Pista: piensa en el `schedule` y en los permisos.

## Limpieza

No creaste recursos en la nube. Para dejar el repositorio como estaba:

```bash
pre-commit uninstall                  # quita el hook de .git/hooks
git switch main
git branch -D lab12-escaneos          # si no fusionaste el PR
docker image rm lab-api:lab12
```

Si fusionaste el PR, puedes quedarte con el workflow y el hook: es justo lo que querrías en un proyecto real. Lo que no deberías conservar es la versión vulnerable de `/diagnostico/*`: si no la quieres en la API, borra `app/diagnostico.py`, sus dos líneas en `app/main.py` y sus tests. Cierra o descarta en code scanning las alertas que queden del lab.

## Problemas comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| El hook no hace nada al hacer commit | Falta `pre-commit install` en ese clon | Ejecútalo en cada clon; `pre-commit run --all-files` lo prueba sin commit |
| El primer commit con el hook tarda minutos | pre-commit compila gitleaks (y descarga Go si no lo tienes) | Normal la primera vez; queda en la caché de pre-commit |
| gitleaks no detecta tu secreto de prueba | Usaste un valor de la allowlist (`...EXAMPLE`) o con formato incorrecto | Usa un valor falso con la longitud y el formato reales |
| `secretos` en verde, pero el log dice `detected dubious ownership` y `0 commits scanned` | El usuario del contenedor no es el dueño del repo montado y git se niega a leerlo; gitleaks no lo trata como error | Ejecuta el contenedor con el usuario del runner y `safe.directory` (las líneas `--user` y `GIT_CONFIG_*` del workflow); revisa siempre que el log diga cuántos commits escaneó |
| `Report path is not writable: /repo/gitleaks.sarif` | Quedó un SARIF de una ejecución anterior creado como root (pasa en runners *self-hosted*) | Bórralo o limpia el workspace; con `--user` del runner no se vuelve a crear como root |
| `ERROR: cannot find ignorefile '.trivyignore.yaml'` en el job `iac` | El archivo no existe en el repo | Súbelo, aunque sea con `misconfigurations: []` |
| El job `iac` falla por hallazgos MEDIUM o LOW | Falta `limit-severities-for-sarif: true`: con formato SARIF la action ignora `severity` | Añade el input (ver Paso 8) |
| `Resource not accessible by integration` al subir el SARIF | Falta `security-events: write`, el PR viene de un fork o el repo es privado sin Code Security | Revisa los permisos del job; en forks el escaneo corre pero no sube |
| La supresión de `.trivyignore.yaml` no se aplica | `paths` es relativo al directorio escaneado, o falta `--ignorefile` (el YAML no se carga solo) | Escanea `.` con `infra/main.tf`, o `infra` con `main.tf`; pasa `--ignorefile` |
| El job `imagen` sigue en rojo tras subir `python-multipart` | Las librerías internas de pip (`msgpack`, `setuptools`, `urllib3`) o paquetes del sistema operativo | Quita pip de la etapa `runtime` (Paso 10) y reconstruye; si es del SO y no hay parche, `ignore-unfixed` ya lo excluye |
| `pip install` falla en el CI tras sembrar la dependencia | Elegiste una versión antigua sin *wheel* para tu versión de Python y pip intenta compilarla (en la prueba de este lab, PyYAML 5.3.1 no compiló con Python 3.12) | Siembra una librería de Python puro, como `python-multipart` |
| Semgrep no encuentra la inyección SQL | Usas `p/python`, que no incluye esa regla | Usa `p/default` (Paso 4) |
| Semgrep tarda o falla sin red | Los *rulesets* `p/...` se descargan del registro de Semgrep | Ejecuta con conexión o usa reglas locales (`--config .semgrep/`) |

Para errores de los jobs en general, sigue el método de [Troubleshooting](../../devops/operacion/troubleshooting.md#cicd).

## Información complementaria

- **Shift-left**: cuanto antes detectas, más barato corriges; el pre-commit es lo más a la izquierda posible ([Fundamentos de DevSecOps](../../devsecops/fundamentos-devsecops.md#shift-left-y-shift-right)).
- **SARIF**: formato estándar de resultados que GitHub, GitLab y DefectDojo entienden; permite un único lugar para todos los hallazgos ([SAST](../../devsecops/escaneos/sast.md#sarif-el-formato-comun)).
- **Gating**: empieza informando y endurece después; activar el bloqueo de golpe en un repo con historia hace que el equipo desactive el escaneo ([Criterios comunes de gating](../../devsecops/escaneos/escaneo-en-pipeline.md#criterios-comunes-de-gating)).
- **Deduplicar**: la CVE de `python-multipart` apareció en SCA y en container scanning; es un solo problema y se corrige una vez, en el `requirements.txt` ([Gestión de hallazgos](../../devsecops/escaneos/escaneo-en-pipeline.md#gestion-de-hallazgos)).
- **Imagen mínima**: lo que no está en la imagen no hay que parchearlo; quitar pip eliminó cuatro hallazgos sin tocar tu código ([Seguridad de contenedores](../../devsecops/infraestructura-y-contenedores/seguridad-contenedores.md#imagenes-base-minimas)).
- **Checks obligatorios**: los jobs solo bloquean si el ruleset los exige ([Branch protection y rulesets](../../devsecops/identidades-y-pipeline/seguridad-pipeline.md#branch-protection-y-rulesets)).
- **En el trabajo real**: estos cinco jobs son el mínimo habitual de un repositorio; la parte difícil no es instalarlos sino el *triage* (clasificación) de hallazgos con dueño y SLA ([Detección y respuesta](../../devsecops/gobierno-y-respuesta/deteccion-respuesta.md)).

## Documentación oficial

- [pre-commit](https://pre-commit.com/)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [Semgrep: CLI reference](https://semgrep.dev/docs/cli-reference)
- [Trivy: filtrado y supresión de hallazgos](https://trivy.dev/latest/docs/configuration/filtering/)
- [aquasecurity/trivy-action](https://github.com/aquasecurity/trivy-action)
- [OSV-Scanner](https://google.github.io/osv-scanner/)
- [Checkov](https://www.checkov.io/)
- [Git: `safe.directory`](https://git-scm.com/docs/git-config#Documentation/git-config.txt-safedirectory)
- [GitHub: subir un archivo SARIF a code scanning](https://docs.github.com/es/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github)
- [GitHub: rulesets](https://docs.github.com/es/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)

## Preguntas para verificar el aprendizaje

??? question "1. ¿Por qué repetir en el pipeline el escaneo de secretos si ya está en pre-commit?"
    Porque el pre-commit es opcional: se salta con `--no-verify` y no existe en clones donde nadie ejecutó `pre-commit install`. El pipeline es el control que no depende de la disciplina de cada persona.

??? question "2. Un secreto real llegó a un commit y lo borraste en el commit siguiente. ¿Está resuelto?"
    No. Sigue en el historial (y en cualquier clon o fork); por eso el job `secretos` hace checkout con `fetch-depth: 0`. Hay que **rotarlo** (revocar y emitir uno nuevo) de inmediato; reescribir el historial es secundario.

??? question "3. ¿Qué pasaría si quitas `!cancelled()` de la condición del paso de subida del SARIF?"
    Cuando el escaneo encuentra algo y falla con `exit-code: 1`, los pasos siguientes no se ejecutan: el check queda en rojo pero no subes el SARIF, así que no ves **qué** falló en code scanning.

??? question "4. ¿Por qué SCA y container scanning reportaron la misma CVE de `python-multipart`, y por qué el escaneo de imagen encontró además `urllib3`?"
    El SCA lee `requirements.txt` y el container scanning encuentra el paquete instalado dentro de la imagen: es el mismo problema en dos artefactos y se corrige una vez, en el manifest. `urllib3` no está en tu manifest: es una librería interna de pip que existe en la imagen. Por eso hace falta el escaneo de imagen aunque ya tengas SCA.

??? question "5. ¿Por qué el job `secretos` podría quedar en verde sin haber revisado nada?"
    Si git rechaza el repo montado por *dubious ownership* (el usuario del contenedor no es su dueño), gitleaks escanea 0 commits y termina con código 0. Un check verde no prueba que el escaneo funcionó: hay que configurarlo bien (`--user` y `safe.directory`) y revisar el log de vez en cuando, o sembrar un secreto falso a propósito como en este lab.

??? question "6. ¿Qué hace `ignore-unfixed: true` y qué riesgo tiene?"
    Excluye las vulnerabilidades sin versión corregida, para no bloquear por algo que no puedes arreglar. El riesgo es olvidarlas: conviene revisarlas en el escaneo programado y valorar mitigaciones. Ojo: no excluyó las de pip, porque esas sí tienen versión corregida (aunque pip todavía no la incluya).

??? question "7. ¿Por qué la supresión lleva `expired_at`?"
    Para que la decisión se revise: al caducar, el hallazgo vuelve a bloquear y alguien tiene que renovar la justificación o corregirlo. Sin caducidad, las supresiones se acumulan y nadie recuerda por qué existen.

??? question "8. ¿Qué diferencia hay entre un falso positivo y un riesgo aceptado?"
    Un falso positivo es un hallazgo incorrecto (no hay problema real). Un riesgo aceptado es un hallazgo correcto que decides no corregir por contexto, con aprobación. Ambos se documentan, pero el segundo debe tener un responsable que lo asuma.

??? question "9. ¿Por qué `security.yml` es un workflow aparte en vez de jobs dentro de `ci.yml`?"
    Porque tiene otro disparador (el escaneo semanal, que no debe relanzar tests ni publicar imágenes), otros permisos (`security-events: write` y nunca `packages: write`) y puede tener otro dueño. El precio es construir la imagen dos veces; el ruleset que exige ambos workflows mantiene el bloqueo del merge.

??? question "10. Si marcas `secretos` como required check y el job falla por un hallazgo en un commit antiguo de `main`, ¿qué opciones tienes?"
    Rotar el secreto y añadir su *fingerprint* a `.gitleaksignore` (ya no es explotable), o limitar el escaneo de PR a los commits nuevos (`--log-opts`) y dejar el historial completo para un escaneo programado.

## Notas relacionadas

**DevSecOps**

- [Escaneo de seguridad en el pipeline](../../devsecops/escaneos/escaneo-en-pipeline.md)
- [Secret scanning](../../devsecops/escaneos/secret-scanning.md)
- [SAST](../../devsecops/escaneos/sast.md)
- [SCA](../../devsecops/escaneos/sca.md)
- [Container scanning](../../devsecops/escaneos/container-scanning.md)
- [IaC scanning](../../devsecops/escaneos/iac-scanning.md)
- [DAST](../../devsecops/escaneos/dast.md)
- [KSPM](../../devsecops/escaneos/kspm.md)
- [CSPM](../../devsecops/escaneos/cspm.md)
- [Fundamentos de DevSecOps](../../devsecops/fundamentos-devsecops.md)
- [Seguridad del código](../../devsecops/codigo-y-dependencias/seguridad-codigo.md)
- [Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md)
- [Seguridad de contenedores](../../devsecops/infraestructura-y-contenedores/seguridad-contenedores.md)
- [Seguridad de IaC](../../devsecops/infraestructura-y-contenedores/seguridad-iac.md)
- [Secretos e identidades](../../devsecops/identidades-y-pipeline/secretos-identidades.md)
- [Seguridad del pipeline](../../devsecops/identidades-y-pipeline/seguridad-pipeline.md)
- [Detección y respuesta](../../devsecops/gobierno-y-respuesta/deteccion-respuesta.md)

**DevOps**

- [Integración continua](../../devops/ci-cd/integracion-continua.md)
- [Docker: imágenes, multi-stage builds y Compose](../../devops/contenedores/docker.md)
- [Troubleshooting](../../devops/operacion/troubleshooting.md)

**Python**

- [Sistema y procesos](../../python/scripting/sistema-procesos.md)
- [Calidad y seguridad de scripts](../../python/scripting/calidad-codigo.md)

**Labs**

- Base de este lab: [Lab 05: Imagen multi-stage y Docker Compose](../devops/docker-multistage-compose.md) y [Lab 07: Pipeline de CI con GitHub Actions](../devops/github-actions-ci.md)
- Lab anterior: [Lab 11: Observabilidad con Prometheus y Grafana](../devops/observabilidad-prometheus-grafana.md)
- Lab siguiente: [Lab 13: Desplegar en AWS desde GitHub Actions con OIDC](oidc-github-aws.md)
