---
tags:
  - laboratorio
  - seguridad
  - escaneo
  - sast
  - sca
---

# Lab 12 (parte 1): Escaneos de seguridad en local y pre-commit

> Siembras fallos de seguridad en la API del Lab 05, bloqueas una credencial falsa con un pre-commit de gitleaks y ejecutas en tu máquina los escaneos de SAST, SCA, imagen e IaC para leer qué encuentra cada uno. En la [parte 2](escaneos-en-pipeline-workflow.md) llevas estos escaneos a un workflow de GitHub Actions con code scanning, bloqueo por severidad y una supresión con fecha de expiración.

| Nivel | Duración | Costo | Requisitos |
| --- | --- | --- | --- |
| Intermedio | ~45 min | Gratis (todo en local) | [Lab 05](../devops/docker-multistage-compose.md); Git, Docker, Python 3.12+ |

!!! info "Qué vas a aprender"
    - Bloquear secretos **antes** del commit con un **pre-commit hook** (gancho previo al commit) de gitleaks.
    - Ejecutar en local los cinco escaneos estáticos (secretos, SAST, SCA, imagen e IaC) y leer su salida.
    - Distinguir qué encuentra cada escáner y por qué el mismo problema puede aparecer en dos de ellos.

!!! warning "Costos y seguridad"
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
- El entorno virtual del Lab 05 con `requirements-dev.txt` instalado.

!!! note "Si no hiciste el Lab 05"
    Crea la app con los Pasos 1, 4 y 5 del [Lab 05](../devops/docker-multistage-compose.md) (código, `.dockerignore` y `Dockerfile`): este lab escanea exactamente esa imagen y sus decisiones (usuario 10001, imagen *slim*) cambian los resultados.

Para la [parte 2](escaneos-en-pipeline-workflow.md) necesitarás además el repositorio en GitHub con el ruleset del [Lab 04](../devops/git-flujo-pull-request.md) y el `ci.yml` del [Lab 07](../devops/github-actions-ci.md); esta parte no los usa.

Teoría recomendada: [Escaneo de seguridad en el pipeline](../../devsecops/escaneos/escaneo-en-pipeline.md) (el mapa de los ocho escaneos) y las notas de [Secret scanning](../../devsecops/escaneos/secret-scanning.md), [SAST](../../devsecops/escaneos/sast.md), [SCA](../../devsecops/escaneos/sca.md), [Container scanning](../../devsecops/escaneos/container-scanning.md) e [IaC scanning](../../devsecops/escaneos/iac-scanning.md).

## Arquitectura

```mermaid
flowchart LR
    dev[Tu equipo] -->|git commit| pc[pre-commit<br/>gitleaks]
    pc -->|sin secretos| commit[Commit en<br/>lab12-escaneos]
    pc -->|secreto| bloq[Commit bloqueado]
    dev -->|escaneos manuales| loc[Tu máquina]
    loc --> s2[SAST<br/>Semgrep]
    loc --> s3[SCA<br/>Trivy fs u OSV-Scanner]
    loc --> s5[Imagen<br/>Trivy image]
    loc --> s4[IaC<br/>Trivy config o Checkov]
```

El pre-commit es la primera red (rápida, automática en cada commit, pero se puede saltar). Los otros cuatro escaneos los lanzas tú a mano para ver qué detecta cada uno y cómo se lee su salida; en la [parte 2](escaneos-en-pipeline-workflow.md) los mismos escaneos pasan a un workflow que nadie puede saltar.

## Paso a paso

### Paso 1: Siembra los fallos en la API

Vas a introducir a propósito un fallo de cada tipo en la app real para ver a cada escáner detectarlo; en el [Paso 10](escaneos-en-pipeline-workflow.md#paso-10-corrige-los-hallazgos-y-gestiona-un-riesgo-aceptado) (parte 2) los corriges.

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

!!! tip "Sigue en la parte 2"
    No corrijas nada todavía: la [parte 2](escaneos-en-pipeline-workflow.md) sube la rama `lab12-escaneos` con estos fallos, comprueba que el workflow de seguridad los bloquea y después los corrige.

## Verificación

| Comprobación | Resultado esperado |
| --- | --- |
| `pytest -q` con los fallos sembrados | `4 passed`: los tests no buscan vulnerabilidades |
| `git commit` de un archivo con la credencial falsa | `Detect hardcoded secrets....Failed` y el commit no se crea |
| `semgrep scan --config p/default --metrics off --severity ERROR --error app/` | `2 findings` (SQL con f-string y `shell=True`), código de salida 1 |
| `trivy fs --scanners vuln --severity HIGH,CRITICAL --exit-code 1 .` | Las CVE de `python-multipart` 0.0.6, código de salida 1 |
| `trivy image --severity HIGH,CRITICAL --ignore-unfixed lab-api:lab12` | 0 en `debian`; HIGH en `python-multipart` y en las librerías internas de pip |
| `trivy config --severity HIGH,CRITICAL --exit-code 1 .` | 6 hallazgos en `infra/main.tf` y `DS-0002` en `Dockerfile.simple`, código de salida 1 |
| `git log --oneline -2` en `lab12-escaneos` | `lab12: pre-commit con gitleaks` y `lab12: siembra fallos de seguridad`, sin `app/config.py` |

Las bases de vulnerabilidades cambian a diario: tu salida de SCA y de imagen puede tener más filas que las de este lab.

## Retos extra

1. Añade al `.pre-commit-config.yaml` un hook de Semgrep y otro de Trivy para IaC, y mide cuánto tarda cada commit. Pista: lo lento va mejor en el pipeline.
2. Activa en Semgrep el escaneo **solo de lo nuevo** con `--baseline-commit` y compara con el escaneo completo ([SAST](../../devsecops/escaneos/sast.md#umbrales-y-cuando-fallar-el-build)).
3. Genera un SBOM de la imagen con `trivy image --format cyclonedx` y escanéalo después con `trivy sbom` ([Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md#sbom)).

## Limpieza

No creaste recursos en la nube. **Si vas a seguir con la [parte 2](escaneos-en-pipeline-workflow.md), no limpies nada**: parte de la rama `lab12-escaneos`, del hook instalado y de la imagen `lab-api:lab12`.

Si lo dejas aquí, para dejar el repositorio como estaba:

```bash
pre-commit uninstall                  # quita el hook de .git/hooks
git switch main
git branch -D lab12-escaneos          # descarta la rama con los fallos sembrados
docker image rm lab-api:lab12
```

## Problemas comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| El hook no hace nada al hacer commit | Falta `pre-commit install` en ese clon | Ejecútalo en cada clon; `pre-commit run --all-files` lo prueba sin commit |
| El primer commit con el hook tarda minutos | pre-commit compila gitleaks (y descarga Go si no lo tienes) | Normal la primera vez; queda en la caché de pre-commit |
| gitleaks no detecta tu secreto de prueba | Usaste un valor de la allowlist (`...EXAMPLE`) o con formato incorrecto | Usa un valor falso con la longitud y el formato reales |
| `pip install` falla en el CI tras sembrar la dependencia | Elegiste una versión antigua sin *wheel* para tu versión de Python y pip intenta compilarla (en la prueba de este lab, PyYAML 5.3.1 no compiló con Python 3.12) | Siembra una librería de Python puro, como `python-multipart` |
| Semgrep no encuentra la inyección SQL | Usas `p/python`, que no incluye esa regla | Usa `p/default` (Paso 4) |
| Semgrep tarda o falla sin red | Los *rulesets* `p/...` se descargan del registro de Semgrep | Ejecuta con conexión o usa reglas locales (`--config .semgrep/`) |

Los problemas del workflow, de code scanning y de la supresión están en los [Problemas comunes de la parte 2](escaneos-en-pipeline-workflow.md#problemas-comunes).

## Información complementaria

- **Shift-left**: cuanto antes detectas, más barato corriges; el pre-commit es lo más a la izquierda posible ([Fundamentos de DevSecOps](../../devsecops/fundamentos-devsecops.md#shift-left-y-shift-right)).
- **Deduplicar**: la CVE de `python-multipart` apareció en SCA y en container scanning; es un solo problema y se corrige una vez, en el `requirements.txt` ([Gestión de hallazgos](../../devsecops/escaneos/escaneo-en-pipeline.md#gestion-de-hallazgos)).
- **Imagen base mínima**: la base *slim* del Lab 05 deja el sistema operativo sin hallazgos HIGH con parche; con la imagen completa serían cientos ([Seguridad de contenedores](../../devsecops/infraestructura-y-contenedores/seguridad-contenedores.md#imagenes-base-minimas)).
- **Validar tus reglas**: sembrar un fallo conocido, como aquí, es la forma de comprobar que la configuración de un escáner detecta lo que crees ([Escaneo de seguridad en el pipeline](../../devsecops/escaneos/escaneo-en-pipeline.md)).

## Documentación oficial

- [pre-commit](https://pre-commit.com/)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [Semgrep: CLI reference](https://semgrep.dev/docs/cli-reference)
- [OSV-Scanner](https://google.github.io/osv-scanner/)
- [Checkov](https://www.checkov.io/)

## Preguntas para verificar el aprendizaje

??? question "1. ¿Por qué repetir en el pipeline el escaneo de secretos si ya está en pre-commit?"
    Porque el pre-commit es opcional: se salta con `--no-verify` y no existe en clones donde nadie ejecutó `pre-commit install`. El pipeline es el control que no depende de la disciplina de cada persona.

??? question "2. ¿Por qué SCA y container scanning reportaron la misma CVE de `python-multipart`, y por qué el escaneo de imagen encontró además `urllib3`?"
    El SCA lee `requirements.txt` y el container scanning encuentra el paquete instalado dentro de la imagen: es el mismo problema en dos artefactos y se corrige una vez, en el manifest. `urllib3` no está en tu manifest: es una librería interna de pip que existe en la imagen. Por eso hace falta el escaneo de imagen aunque ya tengas SCA.

??? question "3. ¿Qué hace `ignore-unfixed: true` y qué riesgo tiene?"
    Excluye las vulnerabilidades sin versión corregida, para no bloquear por algo que no puedes arreglar. El riesgo es olvidarlas: conviene revisarlas en el escaneo programado y valorar mitigaciones. Ojo: no excluyó las de pip, porque esas sí tienen versión corregida (aunque pip todavía no la incluya).

??? question "4. ¿Por qué el ID de la regla de Semgrep menciona SQLAlchemy si la app usa `sqlite3`?"
    Porque las reglas buscan un **patrón** de código (`.execute()` con un string formateado), no una librería concreta. Lee el mensaje del hallazgo, no solo el ID de la regla.

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

**DevOps**

- [Docker: imágenes, multi-stage builds y Compose](../../devops/contenedores/docker.md)

**Python**

- [Calidad y seguridad de scripts](../../python/scripting/calidad-codigo.md)

**Labs**

- Base de este lab: [Lab 05: Imagen multi-stage y Docker Compose](../devops/docker-multistage-compose.md)
- Lab anterior: [Lab 11 (parte 2): Logs con Loki y dashboards en Grafana](../devops/observabilidad-logs-grafana.md)
- Siguiente parte: [Lab 12 (parte 2): Workflow de seguridad, gating y riesgo aceptado](escaneos-en-pipeline-workflow.md)
