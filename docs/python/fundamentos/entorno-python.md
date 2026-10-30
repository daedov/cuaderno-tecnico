---
tags:
  - python
  - scripting
  - automatizacion
---

# Entorno de trabajo con Python

> Instalar Python, usar el intérprete, ejecutar scripts y aislar dependencias con `venv`, `pip`, `uv` y `pipx` para que tus scripts de automatización funcionen igual en tu equipo, en un servidor y en el pipeline.

!!! info "Antes de leer"
    Esta es la primera nota de la sección. Solo necesitas saber abrir una terminal y moverte entre carpetas (`cd`, `ls`/`dir`). Si vienes de Bash, mira antes cuándo conviene pasar a Python en [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md#python-para-automatizacion).

## ¿Qué es?

**Python** es un lenguaje interpretado: escribes un archivo `.py` y el **intérprete** (*interpreter*) lo ejecuta línea a línea, sin compilar antes. En DevOps, Cloud y DevSecOps se usa para **pegar sistemas**: leer el JSON que devuelve una API o `terraform output`, recorrer recursos de la nube con su SDK, revisar logs, generar reportes o validar configuraciones en un pipeline.

El problema típico no es el lenguaje sino el **entorno**: qué versión de Python se ejecuta y qué librerías tiene instaladas. Un script que funciona en tu equipo y falla en el *runner* de CI casi siempre es un problema de entorno. Esta nota resuelve eso antes de entrar al lenguaje.

## Instalar Python y comprobar la versión

Usa **Python 3.12 o superior**. Python 2 dejó de tener soporte en 2020 y las versiones 3.x antiguas van quedando sin parches de seguridad; revisa qué versiones siguen soportadas en el calendario oficial (enlace en Referencias).

=== "Linux"

    La mayoría de distribuciones ya traen `python3`. Comprueba la versión e instala lo que falte con el gestor de paquetes:

    ```bash
    python3 --version
    sudo apt install python3 python3-venv python3-pip   # Debian/Ubuntu
    ```

    No uses `sudo pip install` sobre el Python del sistema: lo usa el propio sistema operativo y puedes romperlo. Las distribuciones recientes lo bloquean a propósito (error *externally-managed-environment*, PEP 668). Usa siempre un entorno virtual.

=== "macOS"

    ```bash
    brew install python@3.12
    python3 --version
    ```

=== "Windows"

    Instala desde python.org (marca "Add python.exe to PATH") o con `winget`. Windows incluye el **Python launcher** `py`, que elige entre versiones instaladas:

    ```powershell
    py --version        # versión por defecto
    py -0               # lista las versiones instaladas
    py -3.12 script.py  # ejecuta con una versión concreta
    ```

En Linux y macOS el comando suele ser `python3`; en Windows, `python` o `py`. En el resto de la sección se escribe `python` por brevedad.

!!! tip "Qué Python estás usando de verdad"
    Si tienes varias versiones, comprueba cuál se ejecuta con `python -c "import sys; print(sys.executable)"`. Muchos errores de "instalé el paquete pero no lo encuentra" vienen de instalar con un Python y ejecutar con otro.

## El intérprete interactivo (REPL)

Si escribes `python` sin argumentos entras al **REPL** (*Read-Eval-Print Loop*, bucle leer-evaluar-imprimir): escribes una expresión y ves el resultado al momento. Sirve para probar algo rápido antes de ponerlo en un script.

```text
$ python
>>> 2 ** 10
1024
>>> "web-01".upper()
'WEB-01'
>>> exit()
```

Para una sola línea desde la terminal o desde un paso de CI, usa `-c`:

```bash
python -c "import json; print(json.dumps({'ok': True}))"
```

Y `-m` ejecuta un **módulo** como programa. Es la forma recomendada de llamar a herramientas como `pip` o `venv`, porque garantiza que usan el mismo intérprete:

```bash
python -m pip --version
python -m venv .venv
python -m http.server 8000   # servidor web de prueba en el directorio actual
```

## Ejecutar scripts

Un script es un archivo `.py`. Se ejecuta pasándolo al intérprete:

```bash
python revisar_puertos.py
```

En Linux y macOS también puedes hacerlo ejecutable con un **shebang** (`#!/usr/bin/env python3` en la primera línea) y `chmod +x`, igual que un script de Bash. Lo ves en detalle en [Scripts de línea de comandos](../scripting/scripts-cli.md).

## Entornos virtuales con `venv`

Un **virtual environment** (entorno virtual) es una carpeta con su propio intérprete y sus propias librerías, separada del Python del sistema y de otros proyectos. Así el proyecto A puede usar `boto3` de una versión y el proyecto B de otra sin conflicto.

```bash
python -m venv .venv          # crea el entorno en la carpeta .venv
```

Actívalo para que `python` y `pip` apunten a él:

=== "Linux / macOS"

    ```bash
    source .venv/bin/activate
    ```

=== "Windows (PowerShell)"

    ```powershell
    .venv\Scripts\Activate.ps1
    ```

El prompt muestra `(.venv)` mientras está activo. Para salir, `deactivate`. No hace falta activarlo si llamas al intérprete por su ruta (`.venv/bin/python script.py`), algo útil en *cron jobs* y en CI.

!!! warning "La carpeta `.venv` no va a Git"
    Añade `.venv/` al `.gitignore`. El entorno se **recrea** a partir de la lista de dependencias; nunca se copia ni se versiona (contiene rutas absolutas de tu máquina).

## `pip` y `requirements.txt`

**pip** es el instalador de paquetes estándar. Descarga librerías de **PyPI** (*Python Package Index*, el repositorio público de paquetes).

```bash
python -m pip install requests             # instala la última versión
python -m pip install "requests>=2.32,<3"  # acota un rango de versiones
python -m pip list                         # qué hay instalado
python -m pip freeze > requirements.txt    # guarda versiones exactas
python -m pip install -r requirements.txt  # reproduce el entorno en otra máquina
```

El archivo `requirements.txt` es la lista de dependencias del proyecto, una por línea:

```text title="requirements.txt"
requests==2.32.5
PyYAML==6.0.3
```

!!! note "Fija versiones"
    Las versiones de ejemplo son orientativas: cambian a menudo. Lo importante es la práctica de **version pinning** (fijar versiones): con versiones exactas, el pipeline instala hoy lo mismo que instalaste tú, y un cambio de dependencia pasa por un *pull request* que se revisa. Es parte de la seguridad de la [cadena de suministro](../../devsecops/codigo-y-dependencias/cadena-suministro.md).

## `uv`: la alternativa moderna

**uv** (de Astral) es un gestor de paquetes y proyectos escrito en Rust, mucho más rápido que `pip`, que además instala versiones de Python. Tiene dos formas de uso.

**1. Como sustituto directo de `pip` y `venv`** (no cambia tu forma de trabajar):

```bash
uv venv                              # crea .venv
uv pip install -r requirements.txt   # instala en el .venv del directorio
uv pip freeze
```

**2. Como gestor de proyecto** (con `pyproject.toml` y un **lockfile** `uv.lock` con versiones exactas):

```bash
uv init inventario          # crea el proyecto con pyproject.toml
cd inventario
uv add requests pyyaml      # añade dependencias y actualiza uv.lock
uv run main.py              # ejecuta dentro del entorno del proyecto (lo crea si hace falta)
uv sync                     # en otra máquina o en CI: instala exactamente lo del lockfile
uv python install 3.12      # descarga e instala esa versión de Python
```

Instalación (comprueba el comando vigente en la documentación oficial):

=== "Linux / macOS"

    ```bash
    curl -LsSf https://astral.sh/uv/install.sh | sh
    ```

=== "Windows"

    ```powershell
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    # o bien: winget install --id=astral-sh.uv -e
    ```

!!! tip "¿pip o uv?"
    Aprende `venv` + `pip` porque están en todas partes (imágenes Docker, servidores, documentación). Usa `uv` cuando puedas elegir: es más rápido en CI y el lockfile hace los entornos reproducibles. Los dos usan PyPI, así que los paquetes son los mismos.

## `pipx` y `uv tool` para herramientas CLI

Algunas herramientas escritas en Python se usan como comandos, no como librerías: `ansible`, `checkov`, `pre-commit`, `ruff`, `awscli` v1… Instalarlas con `pip` en el sistema mezcla sus dependencias. **pipx** instala cada herramienta en su propio entorno aislado y deja el comando disponible en el `PATH`:

```bash
pipx install pre-commit     # instala la herramienta aislada
pipx run cowsay -t hola     # la ejecuta una vez sin instalarla
pipx upgrade pre-commit
pipx list
```

`uv` hace lo mismo con `uv tool install checkov` y `uvx ruff check .` (equivalente a `pipx run`). Usa uno de los dos, no ambos.

| Necesidad | Herramienta |
| --- | --- |
| Librerías que importa tu script (`requests`, `boto3`) | `venv` + `pip`, o `uv` |
| Comandos que usas en la terminal (`pre-commit`, `checkov`) | `pipx` o `uv tool` |
| Una versión concreta de Python | Gestor del sistema, `py` en Windows, o `uv python install` |

## Editor y extensiones

Cualquier editor sirve. Con **Visual Studio Code**, instala la extensión **Python** de Microsoft (incluye Pylance para autocompletado y revisión de tipos) y selecciona el intérprete del `.venv` con *Python: Select Interpreter*. Así el editor ve las mismas librerías que tu script. Para formato y *lint* (revisión de estilo y errores), la extensión de **Ruff**; lo ves en [Calidad y seguridad de scripts](../scripting/calidad-codigo.md).

## Estructura mínima de una carpeta de scripts

```text
scripts-infra/
├── .gitignore            # incluye .venv/, __pycache__/, .env
├── .venv/                # entorno virtual (no se versiona)
├── README.md             # qué hace cada script y cómo ejecutarlo
├── requirements.txt      # o pyproject.toml + uv.lock si usas uv
├── revisar_tags.py
└── limpiar_snapshots.py
```

Cuando los scripts empiecen a compartir funciones, se agrupan en un paquete (ver [Errores, módulos y paquetes](errores-modulos.md)).

## Mini-ejercicio: comprobar el entorno

Escribe `info_entorno.py`, que muestre la versión de Python, la ruta del intérprete y si se está ejecutando dentro de un entorno virtual. Es el típico primer paso de depuración cuando un script se comporta distinto en CI. Pista: dentro de un `venv`, `sys.prefix` es distinto de `sys.base_prefix`.

??? success "Solución"

    ```python title="info_entorno.py"
    import platform
    import sys


    def en_entorno_virtual() -> bool:
        return sys.prefix != sys.base_prefix


    print(f"Python {platform.python_version()} en {platform.system()}")
    print(f"Ejecutable: {sys.executable}")
    print(f"Entorno virtual activo: {en_entorno_virtual()}")
    ```

    Ejecutado primero con el Python del sistema y después con el del `.venv` (Windows):

    ```text
    > py -3.12 info_entorno.py
    Python 3.12.0 en Windows
    Ejecutable: C:\Users\dani\AppData\Local\Programs\Python\Python312\python.exe
    Entorno virtual activo: False

    > .venv\Scripts\python info_entorno.py
    Python 3.12.0 en Windows
    Ejecutable: C:\Users\dani\scripts-infra\.venv\Scripts\python.exe
    Entorno virtual activo: True
    ```

    Añade estas tres líneas al inicio de un paso de CI que falle de forma misteriosa y sabrás qué intérprete se usa.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Runtimes de Python en funciones serverless y cómo se empaquetan las dependencias | [Serverless](../../cloud/computo/serverless.md) |
| DevOps (la automatización) | Instalar dependencias en el runner de CI y crear imágenes con Python | [Integración continua](../../devops/ci-cd/integracion-continua.md), [Docker](../../devops/contenedores/docker.md), [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md) |
| DevSecOps (la verificación) | Fijar versiones, lockfiles y auditar dependencias de PyPI | [Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md) |
| Python (la herramienta) | El lenguaje que vas a usar en este entorno | [Sintaxis y tipos](sintaxis-tipos.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 00: Preparar el entorno de laboratorio](../../laboratorios/fundamentos/preparar-entorno.md), [Lab 03: Script en Python para analizar logs](../../laboratorios/fundamentos/python-analizar-logs.md), [Lab 10: Configurar servidores con Ansible](../../laboratorios/devops/ansible-configuracion.md) |

## Referencias

- [Python: documentación oficial en español](https://docs.python.org/es/3/)
- [Status of Python versions (calendario de soporte)](https://devguide.python.org/versions/)
- [venv: creación de entornos virtuales](https://docs.python.org/es/3/library/venv.html)
- [Python Packaging User Guide: instalar paquetes con pip y venv](https://packaging.python.org/en/latest/guides/installing-using-pip-and-virtual-environments/)
- [uv: documentación](https://docs.astral.sh/uv/)
- [pipx: instalación](https://pipx.pypa.io/stable/how-to/install-pipx.html)
- [Python en Visual Studio Code](https://code.visualstudio.com/docs/python/python-tutorial)

Siguiente: [Sintaxis y tipos](sintaxis-tipos.md)
