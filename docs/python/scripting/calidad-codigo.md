---
tags:
  - python
  - scripting
  - seguridad
  - sast
  - sca
  - ci-cd
---

# Calidad y seguridad de scripts

> Cómo pasar de "funciona en mi máquina" a un script que el equipo puede mantener y confiar: type hints con `mypy`, formato y lint con `ruff`, pruebas con `pytest`, un proyecto pequeño con `pyproject.toml` y los controles de seguridad (secretos, entradas, `pip-audit`, Bandit, pre-commit).

!!! info "Antes de leer"
    Esta nota asume lo visto en [Automatización cloud con SDKs](automatizacion-cloud.md) y el resto del bloque de scripting. Los controles de seguridad se explican a fondo en [Seguridad del código](../../devsecops/codigo-y-dependencias/seguridad-codigo.md) y [Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md); aquí se ven aplicados a scripts de Python.

## ¿Qué es?

Los scripts de automatización tocan producción: borran snapshots, cambian reglas de firewall, leen secretos. Un error de tipeo o una dependencia vulnerable ahí cuesta caro. La buena noticia es que con pocas herramientas, casi todas automáticas, se evita la mayoría de los problemas:

| Herramienta | Qué revisa | Cuándo corre |
| --- | --- | --- |
| **mypy** | Tipos: que no pases un `str` donde va un `int`, que no olvides el caso `None` | Editor, pre-commit, CI |
| **ruff** | Estilo, errores comunes, imports, reglas de seguridad; y formatea el código | Editor, pre-commit, CI |
| **pytest** | Que la lógica haga lo que esperas | Local y CI |
| **pip-audit** | Vulnerabilidades conocidas en tus dependencias (**SCA**) | CI, programado |
| **Bandit** / **Semgrep** | Patrones inseguros en el código (**SAST**) | Pre-commit, CI |
| **pre-commit** | Ejecuta lo anterior antes de cada commit | Local |

## Type hints y mypy

Los **type hints** (ver [Sintaxis y tipos](../fundamentos/sintaxis-tipos.md)) no se comprueban al ejecutar; **mypy** los revisa de forma estática y avisa de errores antes de que el script falle: `mypy src` (con `strict = true` en la configuración exige anotar todo). Empieza anotando las firmas de las funciones; es lo que más rinde.

## Formato y lint con ruff

**ruff** reemplaza en una sola herramienta (y muy rápida) a varias clásicas: el **linter** Flake8 y sus plugins, isort (orden de imports), pyupgrade y, con `ruff format`, el **formatter** Black.

```bash
ruff check .            # lint: errores, malas prácticas, imports sin usar…
ruff check --fix .      # corrige lo que se puede corregir solo
ruff format .           # formatea (estilo compatible con Black)
ruff format --check .   # en CI: falla si algo no está formateado
```

Las reglas se eligen por prefijo en `pyproject.toml` (ver más abajo). Las más útiles para scripts:

| Prefijo | Origen | Qué detecta |
| --- | --- | --- |
| `E`, `W`, `F` | pycodestyle, Pyflakes | Errores de estilo, variables y imports sin usar, nombres no definidos |
| `I` | isort | Orden de imports |
| `B` | flake8-bugbear | Bugs típicos (argumentos por defecto mutables, `except` demasiado amplios…) |
| `UP` | pyupgrade | Sintaxis antigua que tiene versión moderna |
| `S` | flake8-bandit | **Reglas de seguridad de Bandit** dentro de ruff |

## Pruebas con pytest

**pytest** encuentra los archivos `test_*.py`, ejecuta las funciones `test_*` y usa `assert` normales. La clave para probar scripts de infraestructura es la que ya se vio en [Control de flujo y funciones](../fundamentos/control-flujo-funciones.md): separar las funciones que **deciden** (puras, fáciles de probar) de las que **actúan** (llaman a la nube).

```python title="src/herramientas_infra/reglas.py"
"""Detecta reglas de firewall abiertas a internet en puertos sensibles."""

import json
import sys
from pathlib import Path
from typing import TypedDict

PUERTOS_SENSIBLES = {22, 3389, 3306, 5432, 6379, 27017}
ABIERTO = {"0.0.0.0/0", "::/0"}


class Regla(TypedDict):
    puerto: int
    origen: str


def reglas_abiertas(reglas: list[Regla]) -> list[Regla]:
    """Devuelve las reglas que exponen un puerto sensible a cualquier origen."""
    return [r for r in reglas if r["origen"] in ABIERTO and r["puerto"] in PUERTOS_SENSIBLES]


def main() -> int:
    if len(sys.argv) != 2:
        print("Uso: revisar-sg <reglas.json>", file=sys.stderr)
        return 2
    reglas: list[Regla] = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    abiertas = reglas_abiertas(reglas)
    for r in abiertas:
        print(f"Puerto {r['puerto']} abierto a {r['origen']}")
    return 1 if abiertas else 0
```

```python title="tests/test_reglas.py"
import json

import pytest

from herramientas_infra.reglas import Regla, main, reglas_abiertas


@pytest.mark.parametrize(
    ("regla", "esperado"),
    [
        ({"puerto": 22, "origen": "0.0.0.0/0"}, True),  # SSH a internet
        ({"puerto": 3389, "origen": "::/0"}, True),  # RDP por IPv6
        ({"puerto": 22, "origen": "10.0.0.0/8"}, False),  # SSH solo interno
        ({"puerto": 443, "origen": "0.0.0.0/0"}, False),  # HTTPS público es normal
    ],
)
def test_reglas_abiertas(regla: Regla, esperado: bool) -> None:
    assert (reglas_abiertas([regla]) == [regla]) is esperado


def test_main_falla_si_hay_reglas_abiertas(tmp_path, monkeypatch, capsys) -> None:
    archivo = tmp_path / "reglas.json"
    archivo.write_text(json.dumps([{"puerto": 22, "origen": "0.0.0.0/0"}]), encoding="utf-8")
    monkeypatch.setattr("sys.argv", ["revisar-sg", str(archivo)])

    assert main() == 1
    assert "Puerto 22 abierto" in capsys.readouterr().out
```

```text
$ pytest -q
.....                                                                    [100%]
5 passed in 0.07s
```

| Pieza de pytest | Para qué |
| --- | --- |
| `@pytest.mark.parametrize` | El mismo test con muchos casos; cada uno aparece como un test separado |
| `tmp_path` | Carpeta temporal única por test, para archivos de prueba |
| `monkeypatch` | Cambiar variables de entorno, `sys.argv` o funciones durante el test (`monkeypatch.setenv("AWS_REGION", "us-east-1")`) |
| `capsys` | Capturar lo que el código escribe en stdout/stderr |
| `pytest.raises(ValueError)` | Comprobar que algo lanza la excepción esperada |

!!! tip "Probar código que llama a la nube sin la nube"
    Para boto3, **`botocore.stub.Stubber`** responde a las llamadas del cliente con respuestas y errores que tú defines; también existe la librería **moto**, que simula servicios de AWS completos. Para Azure y Google Cloud, lo habitual es pasar el cliente como parámetro a la función y sustituirlo en el test por un `unittest.mock.MagicMock`. Así se probaron los ejemplos de [Automatización cloud con SDKs](automatizacion-cloud.md):

    ```python title="tests/test_s3_sin_owner.py"
    from datetime import datetime

    import boto3
    from botocore.stub import Stubber

    from s3_sin_owner import buckets_sin_owner


    def test_detecta_buckets_sin_owner() -> None:
        s3 = boto3.client("s3", region_name="us-east-1",
                          aws_access_key_id="falsa", aws_secret_access_key="falsa")
        fecha = datetime(2025, 1, 1)
        with Stubber(s3) as stub:
            stub.add_response("list_buckets", {"Buckets": [
                {"Name": "logs-prod", "CreationDate": fecha},
                {"Name": "tmp-pruebas", "CreationDate": fecha},
            ]})
            stub.add_response("get_bucket_tagging",
                              {"TagSet": [{"Key": "owner", "Value": "plataforma"}]},
                              {"Bucket": "logs-prod"})
            stub.add_client_error("get_bucket_tagging", service_error_code="NoSuchTagSet",
                                  http_status_code=404, expected_params={"Bucket": "tmp-pruebas"})

            assert buckets_sin_owner(s3) == ["tmp-pruebas"]
    ```

## Un proyecto pequeño con pyproject.toml

Cuando los scripts sueltos se convierten en "las herramientas del equipo", conviene darles estructura de proyecto. **`pyproject.toml`** es el archivo estándar que reúne metadatos, dependencias, comandos y la configuración de las herramientas.

```text
herramientas-infra/
├── pyproject.toml
├── README.md
├── src/
│   └── herramientas_infra/
│       ├── __init__.py
│       └── reglas.py
└── tests/
    └── test_reglas.py
```

```toml title="pyproject.toml"
[project]
name = "herramientas-infra"
version = "0.1.0"
description = "Scripts de automatización del equipo de plataforma"
requires-python = ">=3.12"
dependencies = [
    "boto3>=1.35",
    "requests>=2.32",
]

[project.optional-dependencies]
dev = ["pytest", "ruff", "mypy", "bandit", "pip-audit"]

[project.scripts]
revisar-sg = "herramientas_infra.reglas:main"     # crea el comando `revisar-sg`

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "B", "UP", "S"]   # S = reglas de seguridad (las de Bandit)

[tool.ruff.lint.per-file-ignores]
"tests/*" = ["S101"]                           # en los tests, assert está bien

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.mypy]
strict = true
```

```bash
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"      # instala el proyecto en modo editable + herramientas de desarrollo
revisar-sg reglas.json       # el comando definido en [project.scripts]
```

- **`src/` layout**: el código vive en `src/<paquete>/`, lo que obliga a instalarlo para importarlo y evita que los tests pasen "por casualidad" importando archivos sueltos.
- **`[project.scripts]`** crea un comando ejecutable que llama a `main()`; el exit code que devuelve `main()` es el del comando.
- Con **uv** (ver [Entorno de trabajo con Python](../fundamentos/entorno-python.md)), `uv sync` crea el entorno y un `uv.lock` con versiones exactas, que es lo que quieres para que el pipeline instale siempre lo mismo.

## Seguridad de los scripts

### No hardcodear secretos

Ningún token, contraseña o access key en el código, en los tests ni en el `README`. Variables de entorno, el gestor de secretos o, mejor, identidades sin secreto (roles, managed identities, OIDC). Lo viste en [Archivos y formatos](archivos-formatos.md#variables-de-entorno-y-env) y en [Automatización cloud con SDKs](automatizacion-cloud.md#credenciales-nunca-en-el-codigo). Un detector como **gitleaks** en pre-commit y en CI atrapa lo que se escape.

### Validar las entradas

Todo lo que llega de fuera (argumentos, archivos, respuestas de APIs, variables de entorno) se valida con **allowlist** antes de usarlo:

| Entrada | Cómo validarla |
| --- | --- |
| Entorno, región, acción | `argparse` con `choices=[...]` |
| IP o CIDR | `ipaddress.ip_address()` / `ip_network()` (lanzan `ValueError`) |
| Nombres de recursos o archivos | `re.fullmatch(r"[a-z0-9-]{3,63}", nombre)` |
| Rutas | `resolve()` y comprobar que quedan dentro del directorio base |
| Comandos | Lista de argumentos, nunca `shell=True` (ver [Sistema y procesos](sistema-procesos.md#nunca-shelltrue-con-entradas-externas)) |
| YAML | `yaml.safe_load`, nunca `yaml.load` con el loader completo |

### SAST con Bandit y Semgrep

**Bandit** (de PyCQA) es el **SAST** clásico de Python: busca patrones inseguros como `shell=True`, `yaml.load`, `pickle`, contraseñas en el código o peticiones sin timeout. Con este script lleno de malas prácticas:

```python title="backup_malo.py"
import subprocess
import sys

import requests
import yaml

DB_PASSWORD = "S3cr3t0-Pr0d!"

config = yaml.load(open("config.yaml"), Loader=yaml.Loader)
host = sys.argv[1]
subprocess.run(f"pg_dump -h {host} -U admin app > /tmp/backup.sql", shell=True)
requests.post("https://hooks.ejemplo.com/backup", json={"ok": True})
```

```text
$ bandit -q backup_malo.py
>> Issue: [B404:blacklist] Consider possible security implications associated with the subprocess module.
>> Issue: [B105:hardcoded_password_string] Possible hardcoded password: 'S3cr3t0-Pr0d!'
>> Issue: [B506:yaml_load] Use of unsafe yaml load. Allows instantiation of arbitrary objects. Consider yaml.safe_load().
>> Issue: [B602:subprocess_popen_with_shell_equals_true] subprocess call with shell=True identified, security issue.
>> Issue: [B113:request_without_timeout] Call to requests without timeout
```

Las mismas reglas están en ruff con el prefijo `S` (`ruff check --select S` reporta `S105`, `S506`, `S602` y `S113` en este archivo), así que si ya usas ruff no necesitas Bandit aparte. **Semgrep** y **CodeQL** van más allá con análisis de flujo de datos y reglas propias; ver [Seguridad del código](../../devsecops/codigo-y-dependencias/seguridad-codigo.md#sast).

!!! note "B404 es informativo"
    Importar `subprocess` no es un fallo; Bandit lo marca con severidad baja para que revises cómo se usa. Silencia hallazgos concretos con un comentario `# nosec B404` (Bandit) o `# noqa: S404` (ruff) **con una justificación**, nunca desactivando reglas enteras.

### Dependencias con pip-audit

**pip-audit** (de PyPA) compara tus dependencias con las bases de datos de vulnerabilidades de PyPI y OSV:

```bash
pip-audit                          # el entorno virtual activo
pip-audit -r requirements.txt      # un archivo de requisitos
pip-audit .                        # un proyecto local con pyproject.toml
pip-audit --fix                    # intenta actualizar a versiones corregidas
```

Combínalo con **version pinning** (lockfile o `requirements.txt` con versiones exactas) y con Dependabot o Renovate para recibir las actualizaciones como *pull requests*. Revisa también el nombre de cada paquete que añades: el **typosquatting** (`reqeusts` en vez de `requests`) es un ataque real. Ver [Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md).

### pre-commit

Con **pre-commit** (ver [Seguridad del código](../../devsecops/codigo-y-dependencias/seguridad-codigo.md#pre-commit-hooks)) los controles corren antes de cada commit:

```yaml title=".pre-commit-config.yaml"
# Las versiones (rev) son de ejemplo: actualízalas con `pre-commit autoupdate`
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.17.2
    hooks:
      - id: ruff-check
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.24.2
    hooks:
      - id: gitleaks
```

Y en CI se repiten, porque los hooks locales se pueden saltar:

```yaml title=".github/workflows/calidad.yml (fragmento)"
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -e ".[dev]"
      - run: ruff check . && ruff format --check .
      - run: mypy src
      - run: pytest -q
      - run: pip-audit .
```

## Mini-ejercicio: probar un validador de CIDR

Un script de auditoría necesita saber si el origen de una regla de firewall es público. Escribe `es_cidr_publico(cidr: str) -> bool` con el módulo `ipaddress` y sus tests con `pytest`:

- `0.0.0.0/0`, `::/0` y `8.8.8.8/32` son públicos; `10.0.0.0/8`, `172.16.5.0/24` y `192.168.1.10/32` no.
- `10.0.1.5/16` (con bits de host) debe aceptarse como la red `10.0.0.0/16`.
- Entradas inválidas (`""`, `10.0.0.0/33`, `no-es-ip`, `300.1.1.1/32`) deben lanzar `ValueError`.
- Que pase `ruff check` y `ruff format --check`.

??? success "Solución"

    ```python title="redes.py"
    import ipaddress


    def es_cidr_publico(cidr: str) -> bool:
        """True si el rango incluye direcciones de internet (no privadas)."""
        red = ipaddress.ip_network(cidr, strict=False)  # ValueError si no es válido
        return not red.is_private
    ```

    ```python title="test_redes.py"
    import pytest

    from redes import es_cidr_publico


    @pytest.mark.parametrize(
        ("cidr", "esperado"),
        [
            ("0.0.0.0/0", True),
            ("::/0", True),
            ("8.8.8.8/32", True),
            ("10.0.0.0/8", False),
            ("172.16.5.0/24", False),
            ("192.168.1.10/32", False),
            ("10.0.1.5/16", False),  # bits de host: strict=False lo acepta
        ],
    )
    def test_es_cidr_publico(cidr: str, esperado: bool) -> None:
        assert es_cidr_publico(cidr) is esperado


    @pytest.mark.parametrize("cidr", ["", "10.0.0.0/33", "no-es-ip", "300.1.1.1/32"])
    def test_cidr_invalido(cidr: str) -> None:
        with pytest.raises(ValueError):
            es_cidr_publico(cidr)
    ```

    ```text
    $ pytest -q
    ...........                                                              [100%]
    11 passed in 0.04s
    $ ruff check --select E,F,I,B,UP,S --per-file-ignores "test_*.py:S101" . && ruff format --check .
    All checks passed!
    2 files already formatted
    ```

    Ojo con los casos raros que los tests ayudan a descubrir: para `ipaddress`, rangos reservados como el de documentación `203.0.113.0/24` cuentan como `is_private`, y el espacio de CGNAT `100.64.0.0/10` no es ni privado ni global. Si tu auditoría depende de esos rangos, decide qué quieres y añade un test que lo fije. Para la teoría de rangos privados, ver [Direccionamiento IP](../../networking/basico/direccionamiento-ip.md).

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| DevOps (la automatización) | El pipeline que ejecuta lint, tests y auditorías en cada cambio | [Integración continua](../../devops/ci-cd/integracion-continua.md), [Pruebas de infraestructura](../../devops/iac/pruebas-infraestructura.md) |
| DevSecOps (la verificación) | SAST, secretos, pre-commit, SCA y cadena de suministro aplicados a scripts | [Seguridad del código](../../devsecops/codigo-y-dependencias/seguridad-codigo.md), [Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md), [Escaneo de seguridad en el pipeline](../../devsecops/escaneos/escaneo-en-pipeline.md) |
| Networking (la base) | Rangos privados y públicos que valida el ejercicio | [Direccionamiento IP](../../networking/basico/direccionamiento-ip.md) |
| Python (la herramienta) | Type hints, funciones puras y paquetes | [Sintaxis y tipos](../fundamentos/sintaxis-tipos.md), [Control de flujo y funciones](../fundamentos/control-flujo-funciones.md), [Errores, módulos y paquetes](../fundamentos/errores-modulos.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 03: Script en Python para analizar logs](../../laboratorios/fundamentos/python-analizar-logs.md), [Lab 05: Imagen multi-stage y Docker Compose](../../laboratorios/devops/docker-multistage-compose.md), [Lab 07: Pipeline de CI con GitHub Actions](../../laboratorios/devops/github-actions-ci.md), [Lab 12: Escaneos de seguridad en el pipeline](../../laboratorios/devsecops/escaneos-en-pipeline.md), [Lab 18: AWS: API serverless con Lambda, API Gateway y DynamoDB](../../laboratorios/cloud/aws-serverless-api.md) |

## Referencias

- [mypy documentation](https://mypy.readthedocs.io/)
- [Ruff: linter](https://docs.astral.sh/ruff/linter/) y [reglas](https://docs.astral.sh/ruff/rules/)
- [Ruff: formatter](https://docs.astral.sh/ruff/formatter/)
- [pytest documentation](https://docs.pytest.org/)
- [Python Packaging User Guide: escribir `pyproject.toml`](https://packaging.python.org/en/latest/guides/writing-pyproject-toml/)
- [Bandit](https://bandit.readthedocs.io/)
- [pip-audit](https://github.com/pypa/pip-audit)
- [Botocore Stubber](https://botocore.amazonaws.com/v1/documentation/api/latest/reference/stubber.html)
- [ipaddress: manipulación de direcciones IPv4/IPv6](https://docs.python.org/es/3/library/ipaddress.html)
- [pre-commit](https://pre-commit.com/)

## Repaso del recorrido

Con esta nota termina la sección de Python. El camino completo, en orden:

**Fundamentos (el lenguaje)**

1. [Entorno de trabajo con Python](../fundamentos/entorno-python.md): instalar Python, `venv`, `pip`, `uv` y `pipx`.
2. [Sintaxis y tipos](../fundamentos/sintaxis-tipos.md): variables, strings, f-strings, conversión de tipos y type hints.
3. [Estructuras de datos](../fundamentos/estructuras-datos.md): list, tuple, dict, set, comprehensions y `collections`.
4. [Control de flujo y funciones](../fundamentos/control-flujo-funciones.md): condicionales, bucles y funciones puras vs con efectos.
5. [Errores, módulos y paquetes](../fundamentos/errores-modulos.md): excepciones, `with`, `import` y la librería estándar.

**Scripting (aplicarlo a automatizar)**

6. [Archivos y formatos](archivos-formatos.md): `pathlib`, CSV, JSON, YAML, `.env` y `terraform output -json`.
7. [Scripts de línea de comandos](scripts-cli.md): `argparse`, exit codes, stdin/stdout/stderr y `logging`.
8. [Sistema y procesos](sistema-procesos.md): `subprocess`, `os`, `shutil`, cron y systemd timers.
9. [APIs y HTTP](apis-http.md): `requests`, tokens, timeouts, reintentos y paginación.
10. [Automatización cloud con SDKs](automatizacion-cloud.md): boto3, Azure SDK y Google Cloud con credenciales sin claves.
11. [Calidad y seguridad de scripts](calidad-codigo.md): `mypy`, `ruff`, `pytest`, `pyproject.toml`, Bandit y `pip-audit`.

Desde aquí, el siguiente paso natural es llevar estos scripts al pipeline ([Integración continua](../../devops/ci-cd/integracion-continua.md)) o volver al [mapa de relaciones](../../mapa-de-relaciones.md) para ver dónde encajan en Cloud, DevOps y DevSecOps.
