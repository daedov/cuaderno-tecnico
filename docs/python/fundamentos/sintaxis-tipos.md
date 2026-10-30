---
tags:
  - python
  - scripting
---

# Sintaxis y tipos

> Indentación, variables, tipos básicos, strings y f-strings, los métodos de string que más se usan para procesar salidas de comandos y logs, conversión de tipos, operadores y type hints básicos.

!!! info "Antes de leer"
    Necesitas tener Python 3.12+ instalado y saber ejecutar un script o abrir el REPL. Lo tienes en [Entorno de trabajo con Python](entorno-python.md).

## ¿Qué es?

La **sintaxis** son las reglas para escribir código válido; los **tipos** (*types*) dicen qué clase de dato guarda cada valor (un número, un texto, verdadero/falso) y qué operaciones admite. En scripting de infraestructura casi todo empieza como **texto**: la salida de un comando, una línea de log, una variable de entorno. Gran parte del trabajo es partir ese texto, limpiarlo y convertirlo al tipo correcto (un puerto a `int`, un porcentaje a `float`) para poder compararlo o calcular.

## Indentación

Python usa la **indentación** (sangría) para delimitar bloques, en lugar de llaves `{}` o `fi`/`done` como Bash. La convención es **4 espacios** por nivel (PEP 8). Una línea que termina en `:` abre un bloque.

```python
if puerto == 22:
    print("SSH abierto")      # dentro del if
    print("revisar origen")   # también dentro
print("fin")                  # fuera del if
```

!!! warning "No mezcles tabuladores y espacios"
    Python 3 da `TabError` si mezclas ambos. Configura el editor para insertar espacios al pulsar Tab (VS Code y Ruff lo hacen por defecto con archivos `.py`).

## Variables y tipos básicos

Una variable es un nombre que apunta a un valor. No se declara el tipo: Python lo deduce del valor (**tipado dinámico**, *dynamic typing*), pero cada valor sí tiene un tipo fijo (**tipado fuerte**, *strong typing*): `"80" + 1` da error en vez de adivinar.

```python
puerto = 443          # int: entero
cpu = 72.5            # float: decimal
host = "web-01"       # str: texto (comillas simples o dobles)
activo = True         # bool: True o False (con mayúscula)
region = None         # None: "sin valor"

print(type(puerto), type(cpu), type(host), type(activo), type(region))
```

```text
<class 'int'> <class 'float'> <class 'str'> <class 'bool'> <class 'NoneType'>
```

Nombres de variables en `snake_case` (minúsculas con guion bajo): `nombre_bucket`, `max_reintentos`. Las **constantes** (valores que no deben cambiar) van en MAYÚSCULAS por convención: `UMBRAL_CPU = 80`. Python no lo impide, pero quien lea el código entiende que no se toca.

`None` se usa para "todavía no hay valor" o "no se encontró", y se compara con `is`: `if region is None:`.

## Strings y f-strings

Un **string** (`str`, cadena de texto) es inmutable: los métodos devuelven un string nuevo, no modifican el original.

Las **f-strings** (cadenas con formato, prefijo `f`) insertan variables y expresiones entre llaves. Son la forma recomendada de construir texto:

```python
servicio = "api"
replicas = 3
uso = 0.8734

print(f"{servicio} tiene {replicas} réplicas")
print(f"Uso de disco: {uso:.1%}")          # porcentaje con 1 decimal
print(f"{'HOST':<10}{'PUERTO':>6}")         # alinear: < izquierda, > derecha
print(f"{host:<10}{puerto:>6}")
print(f"{replicas * 2 = }")                 # depuración: muestra la expresión y su valor
```

```text
api tiene 3 réplicas
Uso de disco: 87.3%
HOST      PUERTO
web-01       443
replicas * 2 = 6
```

Para texto en varias líneas usa triples comillas `"""..."""`. Para rutas de Windows o expresiones regulares, los **raw strings** `r"C:\temp\logs"` evitan que `\t` se interprete como tabulador.

## Métodos de string para scripting

Con estos métodos procesas la mayoría de salidas de comandos y líneas de log:

```python
linea = "  2026-10-24 10:15:02 ERROR db-01 conexión rechazada  \n"

limpia = linea.strip()            # quita espacios y saltos de línea en los extremos
partes = limpia.split()           # parte por cualquier espacio en blanco
print(partes)
print(partes[2], partes[3])       # nivel y host (el índice empieza en 0)
print(limpia.startswith("2026-10-24"))
print("ERROR" in limpia)          # ¿contiene el texto?
```

```text
['2026-10-24', '10:15:02', 'ERROR', 'db-01', 'conexión', 'rechazada']
ERROR db-01
True
True
```

| Método | Ejemplo | Resultado |
| --- | --- | --- |
| `split(sep)` | `"web-01,web-02,db-01".split(",")` | `['web-01', 'web-02', 'db-01']` |
| `join(lista)` | `", ".join(["web-01", "web-02"])` | `'web-01, web-02'` |
| `strip()` / `lstrip()` / `rstrip()` | `"  ok \n".strip()` | `'ok'` |
| `replace(a, b)` | `"prod-api-01".replace("prod", "stg")` | `'stg-api-01'` |
| `lower()` / `upper()` | `"Web-01".lower()` | `'web-01'` |
| `startswith` / `endswith` | `"app.log".endswith((".log", ".txt"))` | `True` (acepta una tupla de opciones) |
| `partition(sep)` | `"ip=10.0.1.15".partition("=")` | `('ip', '=', '10.0.1.15')` |
| `removeprefix` / `removesuffix` | `"cpu=87".removeprefix("cpu=")` | `'87'` |

!!! tip "`split()` sin argumentos"
    `split()` sin separador parte por cualquier cantidad de espacios o tabuladores y descarta los vacíos, que es justo lo que necesitas con salidas en columnas como `df -h` o `kubectl get pods`. `split(" ")` en cambio genera elementos vacíos si hay dos espacios seguidos.

## Conversión de tipos

Todo lo que viene de fuera (argumentos, variables de entorno, archivos, `input()`) llega como `str`. Conviértelo antes de operar:

```python
print(int("8080") + 1)        # 8081
print(float("99.5"))          # 99.5
print(str(443) + "/tcp")      # 443/tcp
print(bool(""), bool("no"), bool(0), bool([]))   # False True False False
```

Ojo con `bool()`: cualquier string no vacío es `True`, incluido `"false"` o `"no"`. Para una variable de entorno tipo `DEBUG=false` compara el texto: `debug = valor.lower() in ("1", "true", "yes")`.

Si el texto no es un número válido, la conversión lanza un error:

```python
int("80/tcp")
```

```text
ValueError: invalid literal for int() with base 10: '80/tcp'
```

Limpia antes de convertir (`int("80/tcp".split("/")[0])` da `80`) o captura el error, como verás en [Errores, módulos y paquetes](errores-modulos.md).

## Operadores

| Tipo | Operadores | Ejemplo |
| --- | --- | --- |
| Aritméticos | `+ - * / // % **` | `7 / 2` → `3.5`; `7 // 2` → `3` (división entera); `7 % 2` → `1` (resto); `2 ** 3` → `8` |
| Comparación | `== != < > <= >=` | `1 < 5 <= 5` → `True` (se pueden encadenar) |
| Lógicos | `and or not` | `activo and puerto == 443` |
| Pertenencia | `in`, `not in` | `"ERROR" in linea` |
| Identidad | `is`, `is not` | `region is None` |

Dos detalles prácticos:

- `/` siempre devuelve `float`. Para calcular, por ejemplo, cuántos lotes de 50 hay en 120 instancias, usa `//`.
- Los `float` no son exactos: `0.1 + 0.2` da `0.30000000000000004`. Para mostrar, redondea con `round(x, 2)` o en la f-string (`{x:.2f}`); para dinero usa el módulo `decimal`.

`or` devuelve el primer valor "verdadero", lo que sirve para valores por defecto: `region = region_cli or "us-east-1"`.

## `input` y `print`

`print()` escribe en la salida estándar (*stdout*); `input()` lee una línea del teclado o de una tubería y la devuelve como `str`:

```python title="desplegar.py"
entorno = input("Entorno (dev/prod): ").strip().lower()
print(f"Desplegando en {entorno}")
```

```text
$ echo " PROD " | python desplegar.py
Entorno (dev/prod): Desplegando en prod
```

En automatización casi no se usa `input()`: un script que pregunta bloquea el pipeline. Los datos se pasan por argumentos o variables de entorno ([Scripts de línea de comandos](../scripting/scripts-cli.md)), y en lugar de `print` para mensajes de estado se usa `logging`.

## Comentarios y docstrings

```python
# Comentario de una línea: explica el porqué, no el qué
UMBRAL_CPU = 80  # por encima de esto, el autoscaling ya debería haber actuado

def etiqueta(host: str, puerto: int = 443) -> str:
    """Devuelve 'host:puerto' para usar en logs y mensajes."""
    return f"{host}:{puerto}"
```

El **docstring** (cadena de documentación) es el string entre triples comillas justo debajo de un `def`, una clase o al inicio del archivo. Lo muestran `help(etiqueta)` y los editores al pasar el ratón. Pon uno al inicio de cada script diciendo qué hace y cómo se usa.

## Type hints básicos

Los **type hints** (anotaciones de tipo) indican qué tipo esperas. Python **no los comprueba al ejecutar**; los usan el editor (autocompletado, avisos) y herramientas como `mypy` para detectar errores antes de que el script falle en producción.

```python
puerto: int = 443
hosts: list[str] = ["web-01", "web-02"]
region: str | None = None        # str o None (sintaxis de Python 3.10+)

def etiqueta(host: str, puerto: int = 443) -> str:
    return f"{host}:{puerto}"
```

En scripts cortos basta con anotar las funciones (parámetros y retorno). Las funciones se ven en [Control de flujo y funciones](control-flujo-funciones.md).

## Mini-ejercicio: leer una línea de métricas

Un agente de monitoreo deja líneas como esta:

```text
  web-01 | 10.0.1.15 | cpu=87.256 | estado=Running 
```

Extrae el nombre, la IP, el porcentaje de CPU como `float` y el estado en minúsculas, y muestra una línea alineada más si supera el umbral de 80 %.

??? success "Solución"

    ```python title="leer_metrica.py"
    """Lee una línea de métricas en texto y muestra un resumen formateado."""

    UMBRAL_CPU: float = 80.0

    linea = "  web-01 | 10.0.1.15 | cpu=87.256 | estado=Running \n"

    partes = linea.split("|")
    nombre = partes[0].strip()
    ip = partes[1].strip()
    cpu = float(partes[2].strip().removeprefix("cpu="))
    estado = partes[3].strip().split("=")[1].lower()

    print(f"{nombre:<8} {ip:<12} CPU {cpu:5.1f}%  estado={estado}")
    print(f"¿Supera el umbral de {UMBRAL_CPU:.0f}%? {cpu > UMBRAL_CPU}")
    ```

    ```text
    web-01   10.0.1.15    CPU  87.3%  estado=running
    ¿Supera el umbral de 80%? True
    ```

    Fíjate en el orden: primero `split("|")`, después `strip()` en cada parte, y solo al final la conversión a `float`. Si conviertes antes de limpiar, falla con `ValueError`.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| DevOps (la automatización) | El mismo procesamiento de texto que harías con `cut`, `awk` o `sed` en Bash | [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md) |
| DevSecOps (la verificación) | Todo lo que llega de fuera es texto no confiable: validar y convertir antes de usarlo | [Seguridad del código](../../devsecops/codigo-y-dependencias/seguridad-codigo.md) |
| Python (la herramienta) | Agrupar muchos valores en listas y diccionarios | [Estructuras de datos](estructuras-datos.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 03: Script en Python para analizar logs](../../laboratorios/fundamentos/python-analizar-logs.md) |

## Referencias

- [Tutorial de Python: introducción informal (números y cadenas)](https://docs.python.org/es/3/tutorial/introduction.html)
- [Tipos integrados: métodos de las cadenas](https://docs.python.org/es/3/library/stdtypes.html#string-methods)
- [Formato de cadenas literales (f-strings)](https://docs.python.org/es/3/reference/lexical_analysis.html#f-strings)
- [Especificación de formato (format spec mini-language)](https://docs.python.org/es/3/library/string.html#formatspec)
- [PEP 8: guía de estilo](https://peps.python.org/pep-0008/)
- [typing: soporte para type hints](https://docs.python.org/es/3/library/typing.html)

Siguiente: [Estructuras de datos](estructuras-datos.md)
