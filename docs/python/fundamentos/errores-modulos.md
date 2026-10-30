---
tags:
  - python
  - scripting
---

# Errores, módulos y paquetes

> Manejar excepciones sin esconder fallos, liberar recursos con `with`, repartir el código en módulos y paquetes reutilizables, y conocer la librería estándar que más se usa en scripting.

!!! info "Antes de leer"
    Necesitas saber escribir funciones, condiciones y bucles. Lo tienes en [Control de flujo y funciones](control-flujo-funciones.md).

## ¿Qué es?

Cuando algo sale mal (un archivo que no existe, un JSON mal formado, una conexión rechazada), Python lanza una **exception** (excepción): un objeto que describe el error y detiene el programa si nadie lo captura. En automatización hay que decidir, error por error, si el script puede **recuperarse** (usar un valor por defecto, reintentar) o si debe **fallar de forma clara**, con un mensaje útil y un *exit code* distinto de 0 para que el pipeline se detenga.

Los **módulos** y **paquetes** resuelven otro problema: cuando tienes diez scripts que copian la misma función para comprobar un puerto o leer la configuración, conviene escribirla una vez e importarla.

## Leer un traceback

Si una excepción no se captura, Python muestra un **traceback** (traza de la pila): la cadena de llamadas hasta el error. Se lee **de abajo arriba**: la última línea dice qué pasó y la anterior, dónde.

```text
Traceback (most recent call last):
  File "leer.py", line 2, in <module>
    json.load(open("roto.json"))
  ...
json.decoder.JSONDecodeError: Expecting property name enclosed in double quotes: line 2 column 1 (char 24)
```

| Excepción | Cuándo aparece en scripting |
| --- | --- |
| `FileNotFoundError` / `PermissionError` | Archivo o ruta que no existe, sin permisos (ambas son `OSError`) |
| `KeyError` | Acceder a una clave que no está en un diccionario |
| `IndexError` | Índice fuera de la lista (p. ej. una línea con menos columnas de las esperadas) |
| `ValueError` | Valor con el tipo correcto pero contenido inválido: `int("ssh")` |
| `TypeError` | Tipo incorrecto: `"80" + 1`, argumentos de más o de menos |
| `json.JSONDecodeError` | JSON mal formado (es un `ValueError`) |
| `TimeoutError` / `ConnectionRefusedError` | Problemas de red (también `OSError`) |

## `try` / `except` / `else` / `finally`

```python title="leer_config.py"
import json

POR_DEFECTO = {"region": "us-east-1", "max_instancias": 1}


class ConfigError(Exception):
    """La configuración existe pero no se puede usar."""


def leer_config(ruta: str) -> dict:
    try:
        with open(ruta, encoding="utf-8") as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"No existe {ruta}, uso valores por defecto")
        return POR_DEFECTO
    except json.JSONDecodeError as e:
        raise ConfigError(f"{ruta}: JSON inválido en la línea {e.lineno}") from e
    else:
        print(f"Configuración cargada de {ruta}")
        return config
    finally:
        print("-- fin de leer_config")


print(leer_config("config.json"))
print(leer_config("no-existe.json"))
try:
    leer_config("roto.json")
except ConfigError as e:
    print(f"ERROR: {e}")
```

```text
Configuración cargada de config.json
-- fin de leer_config
{'region': 'us-east-1', 'max_instancias': 5}
No existe no-existe.json, uso valores por defecto
-- fin de leer_config
{'region': 'us-east-1', 'max_instancias': 1}
-- fin de leer_config
ERROR: roto.json: JSON inválido en la línea 2
```

| Bloque | Se ejecuta… | Úsalo para |
| --- | --- | --- |
| `try` | Siempre, hasta que algo falla | Solo las líneas que pueden fallar (cuanto más corto, mejor) |
| `except Tipo` | Si se lanzó esa excepción (o una subclase) | Recuperarte o traducir el error a uno más claro |
| `else` | Si **no** hubo excepción | Lo que depende de que el `try` haya ido bien |
| `finally` | **Siempre**, haya error o no, incluso tras un `return` | Limpieza: cerrar, borrar temporales, liberar un *lock* |

!!! danger "No captures todo"
    `except:` a secas o `except Exception: pass` esconden cualquier fallo, incluidos errores de programación y un Ctrl+C (el `except:` vacío). El script "termina bien" pero no hizo su trabajo, y el pipeline queda en verde. Captura solo las excepciones que sabes tratar. Si necesitas un `except Exception` general (por ejemplo, para seguir con el siguiente servidor de una lista), **registra el error** y haz que el script termine con un exit code distinto de 0.

## Lanzar excepciones: `raise`

Usa `raise` para fallar a propósito cuando un dato no cumple lo esperado, en vez de seguir con un valor incorrecto:

```python
def validar(config: dict) -> None:
    maximo = config.get("max_instancias")
    if not isinstance(maximo, int) or maximo < 1:
        raise ConfigError(f"max_instancias debe ser un entero >= 1, no {maximo!r}")

validar({"max_instancias": "5"})
# ConfigError: max_instancias debe ser un entero >= 1, no '5'
```

`raise NuevoError(...) from e` encadena la excepción original: el traceback muestra ambas ("The above exception was the direct cause of the following exception"), así no pierdes la causa. `from None` la oculta cuando no aporta nada.

## Excepciones propias

Una excepción propia es una clase que hereda de `Exception` (o de una más concreta, como `ValueError`). Basta con un nombre y un docstring:

```python
class ConfigError(Exception):
    """La configuración existe pero no se puede usar."""
```

Sirven para que quien llama a tus funciones pueda distinguir "tu" error de cualquier otro y decidir qué hacer, sin tener que comparar textos de mensajes.

## Context managers: `with`

Un **context manager** (gestor de contexto) garantiza que un recurso se libera al salir del bloque `with`, aunque haya una excepción en medio. Es la forma correcta de abrir archivos, conexiones o *locks*:

```python
with open("config.json", encoding="utf-8") as f:
    config = json.load(f)
# aquí el archivo ya está cerrado, haya fallado json.load o no
```

Varios módulos de la librería estándar los usan. Por ejemplo, `tempfile.TemporaryDirectory` borra la carpeta temporal al terminar:

```python
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory() as tmp:
    plan = Path(tmp) / "plan.txt"
    plan.write_text("3 to add, 0 to change, 1 to destroy\n", encoding="utf-8")
    print(plan.read_text(encoding="utf-8").strip())
print("¿existe la carpeta temporal?", Path(tmp).exists())
```

```text
3 to add, 0 to change, 1 to destroy
¿existe la carpeta temporal? False
```

Puedes crear el tuyo con `contextlib.contextmanager`: el código antes del `yield` se ejecuta al entrar y el del `finally`, al salir.

```python
import time
from contextlib import contextmanager

@contextmanager
def cronometro(tarea: str):
    inicio = time.perf_counter()
    try:
        yield
    finally:
        print(f"{tarea}: {time.perf_counter() - inicio:.2f}s")

with cronometro("generar plan"):
    time.sleep(0.25)          # aquí iría el trabajo real
```

```text
generar plan: 0.25s
```

## Módulos e `import`

Un **módulo** es simplemente un archivo `.py`. Otro archivo en la misma carpeta puede importarlo:

```python
import json                          # módulo completo: json.load(...)
from pathlib import Path             # un nombre concreto: Path(...)
from collections import Counter, defaultdict
import datetime as dt                # con alias
```

Evita `from modulo import *`: no se sabe de dónde viene cada nombre y puede pisar los tuyos. Por convención (PEP 8) los `import` van al inicio del archivo, agrupados en: librería estándar, paquetes de terceros y módulos propios.

!!! warning "No llames a tu script como un módulo"
    Si guardas tu script como `json.py`, `socket.py` o `requests.py`, `import json` cargará **tu archivo** en vez del módulo real, porque Python busca primero en la carpeta del script. Errores como `AttributeError: module 'json' has no attribute 'load'` suelen venir de aquí.

## `if __name__ == "__main__":`

Al importar un módulo, Python **ejecuta todo su código de nivel superior**. Si `leer_config.py` tiene llamadas de prueba al final, cualquier script que haga `from leer_config import leer_config` las ejecutará también.

La solución es meter el código "de script" bajo esta condición:

```python
def main() -> None:
    ...   # lo que hace el script cuando lo ejecutas directamente

if __name__ == "__main__":
    main()
```

La variable `__name__` vale `"__main__"` cuando el archivo se ejecuta directamente (`python leer_config.py`) y el nombre del módulo (`"leer_config"`) cuando se importa. Así el mismo archivo sirve como script y como módulo reutilizable, y tus pruebas pueden importar las funciones sin disparar acciones.

## Paquetes y `__init__.py`

Un **paquete** (*package*) es una carpeta de módulos. Con un archivo `__init__.py` dentro (puede estar vacío o tener solo un docstring), Python la trata como paquete normal:

```text
scripts-infra/
├── infra/
│   ├── __init__.py
│   └── red.py              # funciones compartidas
└── revisar_servicios.py    # script que las usa
```

```python title="infra/red.py"
"""Funciones de red reutilizables."""
import socket


def puerto_abierto(host: str, puerto: int, timeout: float = 2.0) -> bool:
    """True si se puede abrir una conexión TCP a host:puerto."""
    try:
        with socket.create_connection((host, puerto), timeout=timeout):
            return True
    except OSError:          # conexión rechazada, timeout, host que no resuelve
        return False
```

```python title="revisar_servicios.py"
from infra.red import puerto_abierto

SERVICIOS = {"web": ("localhost", 8080), "db": ("localhost", 5432)}

for nombre, (host, puerto) in SERVICIOS.items():
    estado = "OK" if puerto_abierto(host, puerto, timeout=1) else "CAÍDO"
    print(f"{nombre:<4} {host}:{puerto} {estado}")
```

Con un servidor de prueba escuchando en el 8080 (`python -m http.server 8080`) y nada en el 5432:

```text
web  localhost:8080 OK
db   localhost:5432 CAÍDO
```

Ejecuta los scripts desde la carpeta raíz (`scripts-infra/`) para que Python encuentre el paquete `infra`. También puedes ejecutar un módulo del paquete como script con `python -m infra.red`. Cuando el paquete crezca, se instala como proyecto con `pyproject.toml` ([Calidad y seguridad de scripts](../scripting/calidad-codigo.md)).

## Librería estándar más útil para scripting

Python trae "pilas incluidas" (*batteries included*): muchas tareas no necesitan instalar nada, lo que simplifica el entorno y reduce dependencias que auditar.

| Módulo | Para qué |
| --- | --- |
| [`pathlib`](https://docs.python.org/es/3/library/pathlib.html) | Rutas, recorrer carpetas, leer y escribir archivos |
| [`os`](https://docs.python.org/es/3/library/os.html) | Variables de entorno (`os.environ`), información del sistema |
| [`sys`](https://docs.python.org/es/3/library/sys.html) | Argumentos (`sys.argv`), salir con código (`sys.exit`), stdin/stdout/stderr |
| [`subprocess`](https://docs.python.org/es/3/library/subprocess.html) | Ejecutar comandos (`git`, `kubectl`, `terraform`) |
| [`shutil`](https://docs.python.org/es/3/library/shutil.html) | Copiar, mover, comprimir; `shutil.which("kubectl")` |
| [`json`](https://docs.python.org/es/3/library/json.html) / [`csv`](https://docs.python.org/es/3/library/csv.html) / [`tomllib`](https://docs.python.org/es/3/library/tomllib.html) | Formatos de datos (`tomllib` solo lee) |
| [`argparse`](https://docs.python.org/es/3/library/argparse.html) | Argumentos y opciones de línea de comandos |
| [`logging`](https://docs.python.org/es/3/library/logging.html) | Mensajes con niveles en lugar de `print` |
| [`re`](https://docs.python.org/es/3/library/re.html) | Expresiones regulares |
| [`datetime`](https://docs.python.org/es/3/library/datetime.html) / [`time`](https://docs.python.org/es/3/library/time.html) | Fechas, antigüedad de recursos, esperas |
| [`ipaddress`](https://docs.python.org/es/3/library/ipaddress.html) | Validar IPs, redes CIDR, si una IP pertenece a una subred |
| [`socket`](https://docs.python.org/es/3/library/socket.html) | Conexiones de red de bajo nivel, resolución DNS |
| [`urllib.request`](https://docs.python.org/es/3/library/urllib.request.html) | HTTP básico sin dependencias (para algo más cómodo, `requests`) |
| [`hashlib`](https://docs.python.org/es/3/library/hashlib.html) | Checksums (SHA-256) para verificar descargas |
| [`tempfile`](https://docs.python.org/es/3/library/tempfile.html) | Archivos y carpetas temporales que se limpian solos |
| [`concurrent.futures`](https://docs.python.org/es/3/library/concurrent.futures.html) | Ejecutar tareas en paralelo (p. ej. revisar 200 hosts a la vez) |

## Mini-ejercicio: validar puertos de una configuración

Escribe `validar_puertos.py` con:

1. Una excepción propia `PuertoInvalido` (que herede de `ValueError`).
2. `parsear_puerto(texto)`: acepta `"443"`, `" 22 "` o `"80/tcp"`, devuelve un `int` y lanza `PuertoInvalido` si no es un número o está fuera de 1–65535.
3. `main(entradas)`: valida todas, muestra cada error en *stderr* sin detenerse, y devuelve `1` si hubo errores o `0` si no.
4. El bloque `if __name__ == "__main__":` que termine el script con ese código, para que un pipeline falle si la configuración es inválida.

Prueba con `["443", "80/tcp", "70000", "ssh", " 22 "]`.

??? success "Solución"

    ```python title="validar_puertos.py"
    """Valida una lista de puertos tal como llega de un archivo de configuración."""
    import sys


    class PuertoInvalido(ValueError):
        """El valor no es un puerto TCP/UDP válido."""


    def parsear_puerto(texto: str) -> int:
        valor = texto.strip().removesuffix("/tcp").removesuffix("/udp")
        try:
            puerto = int(valor)
        except ValueError:
            raise PuertoInvalido(f"{texto!r} no es un número") from None
        if not 1 <= puerto <= 65535:
            raise PuertoInvalido(f"{puerto} está fuera del rango 1-65535")
        return puerto


    def main(entradas: list[str]) -> int:
        validos = []
        errores = 0
        for entrada in entradas:
            try:
                validos.append(parsear_puerto(entrada))
            except PuertoInvalido as e:
                print(f"ERROR: {e}", file=sys.stderr)
                errores += 1
        print(f"Puertos válidos: {sorted(validos)}")
        return 1 if errores else 0


    if __name__ == "__main__":
        sys.exit(main(["443", "80/tcp", "70000", "ssh", " 22 "]))
    ```

    ```text
    $ python validar_puertos.py; echo "exit code: $?"
    ERROR: 70000 está fuera del rango 1-65535
    ERROR: 'ssh' no es un número
    Puertos válidos: [22, 80, 443]
    exit code: 1
    ```

    Y como tiene el bloque `__main__`, otro script puede reutilizar la función sin ejecutar la validación de ejemplo:

    ```text
    $ python -c "from validar_puertos import parsear_puerto; print(parsear_puerto('53/udp'))"
    53
    ```

    Que `PuertoInvalido` herede de `ValueError` permite que quien ya capturaba `ValueError` siga funcionando. En la siguiente nota leerás la lista de puertos desde un archivo real en lugar de escribirla en el código.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| DevOps (la automatización) | El exit code decide si un paso del pipeline pasa o falla | [Integración continua](../../devops/ci-cd/integracion-continua.md), [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md#exit-codes-codigos-de-salida) |
| DevSecOps (la verificación) | Errores silenciados que ocultan fallos, mensajes de error que filtran secretos, dependencias de más | [Seguridad del código](../../devsecops/codigo-y-dependencias/seguridad-codigo.md), [Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md) |
| Networking (la base) | Conexión rechazada vs timeout al comprobar un puerto con `socket` | [Capa de transporte](../../networking/intermedio/capa-transporte.md), [Troubleshooting de red](../../networking/avanzado/troubleshooting-red.md) |
| Python (la herramienta) | Aplicar todo esto a archivos, JSON y YAML reales | [Archivos y formatos](../scripting/archivos-formatos.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 03: Script en Python para analizar logs](../../laboratorios/fundamentos/python-analizar-logs.md), [Lab 18: AWS: API serverless con Lambda, API Gateway y DynamoDB](../../laboratorios/cloud/aws-serverless-api.md) |

## Referencias

- [Tutorial de Python: errores y excepciones](https://docs.python.org/es/3/tutorial/errors.html)
- [Excepciones incorporadas (jerarquía)](https://docs.python.org/es/3/library/exceptions.html)
- [La sentencia with y contextlib](https://docs.python.org/es/3/library/contextlib.html)
- [Tutorial de Python: módulos y paquetes](https://docs.python.org/es/3/tutorial/modules.html)
- [`__main__`: entorno de código de nivel superior](https://docs.python.org/es/3/library/__main__.html)
- [La biblioteca estándar de Python](https://docs.python.org/es/3/library/index.html)

Siguiente: [Archivos y formatos](../scripting/archivos-formatos.md)
