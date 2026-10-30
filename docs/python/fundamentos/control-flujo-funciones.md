---
tags:
  - python
  - scripting
---

# Control de flujo y funciones

> Decidir con `if`, repetir con `for` y `while`, recorrer con `range`, `enumerate` y `zip`, y organizar el script en funciones con parámetros por defecto, argumentos con nombre, `*args`/`**kwargs` y retorno múltiple.

!!! info "Antes de leer"
    Necesitas manejar listas, diccionarios y conjuntos, y saber recorrerlos con un `for` sencillo. Lo tienes en [Estructuras de datos](estructuras-datos.md).

## ¿Qué es?

El **control de flujo** (*control flow*) decide qué líneas se ejecutan y cuántas veces: condiciones y bucles. Las **funciones** agrupan pasos con un nombre para reutilizarlos y probarlos por separado. Un script de automatización típico es exactamente esto: recorrer una lista de recursos, decidir qué hacer con cada uno según su estado y reintentar cuando algo falla.

## Condiciones: `if`, `elif`, `else`

```python
def clasificar(uso: float) -> str:
    if uso >= 90:
        return "CRÍTICO"
    elif uso >= 75:
        return "AVISO"
    else:
        return "OK"

for u in (95, 80, 40):
    print(u, clasificar(u))
```

```text
95 CRÍTICO
80 AVISO
40 OK
```

Las condiciones se evalúan en orden y solo se ejecuta el primer bloque verdadero. En una condición, se consideran falsos `False`, `None`, `0`, `""` y las colecciones vacías (`[]`, `{}`, `set()`). Por eso `if tags:` significa "si hay tags".

Para condiciones cortas existe la **expresión condicional**: `estado = "OK" if codigo == 200 else "FALLO"`.

### `match` cuando hay muchos casos

Desde Python 3.10, `match` compara un valor contra varios patrones. Úsalo cuando tendrías una cadena larga de `elif` comparando el mismo valor:

```python
def accion(estado: str) -> str:
    match estado:
        case "running":
            return "nada"
        case "stopped" | "stopping":       # varias opciones
            return "revisar si debe borrarse"
        case _:                            # cualquier otro valor
            return f"estado desconocido: {estado}"

print(accion("stopped"))   # revisar si debe borrarse
print(accion("pending"))   # estado desconocido: pending
```

## Bucles `for`

`for` recorre cualquier **iterable** (lista, tupla, dict, set, string, líneas de un archivo). Tres funciones lo hacen mucho más cómodo:

```python
servidores = ["web-01", "web-02", "db-01"]
ips = ["10.0.1.10", "10.0.1.11", "10.0.2.20"]

for i, srv in enumerate(servidores, start=1):     # índice + valor
    print(f"[{i}/{len(servidores)}] {srv}")

for srv, ip in zip(servidores, ips):              # recorre dos listas en paralelo
    print(srv, "->", ip)

print(list(range(3)), list(range(8000, 8003)), list(range(0, 10, 4)))
```

```text
[1/3] web-01
[2/3] web-02
[3/3] db-01
web-01 -> 10.0.1.10
web-02 -> 10.0.1.11
db-01 -> 10.0.2.20
[0, 1, 2] [8000, 8001, 8002] [0, 4, 8]
```

| Función | Qué da | Ejemplo de uso |
| --- | --- | --- |
| `range(fin)` / `range(inicio, fin, paso)` | Secuencia de números (el `fin` no se incluye) | Rango de puertos, número de reintentos |
| `enumerate(it, start=1)` | Pares `(índice, valor)` | Mostrar progreso `[3/120]`, número de línea de un log |
| `zip(a, b)` | Pares con un elemento de cada lista | Asociar nombres con IPs. Se detiene en la lista más corta; con `strict=True` da error si no miden igual |

!!! tip "No uses `range(len(lista))`"
    `for i in range(len(hosts)): print(hosts[i])` funciona, pero en Python se escribe `for host in hosts:` o, si necesitas el índice, `enumerate(hosts)`.

### `break`, `continue` y `else`

- `continue` salta al siguiente elemento.
- `break` termina el bucle.
- Un `else` después del `for` se ejecuta solo si el bucle terminó **sin** `break`: útil para "busqué y no lo encontré".

```python
lineas = ["INFO arranque", "WARN lento", "ERROR disco lleno", "INFO otra"]
for linea in lineas:
    if linea.startswith("INFO"):
        continue                     # ignora lo informativo
    print("relevante:", linea)
    if linea.startswith("ERROR"):
        print("primer error encontrado, paro")
        break

for puerto in (22, 80, 443):
    if puerto == 3389:
        print("RDP abierto")
        break
else:
    print("RDP no está en la lista")
```

```text
relevante: WARN lento
relevante: ERROR disco lleno
primer error encontrado, paro
RDP no está en la lista
```

## Bucles `while`

`while` repite mientras una condición sea verdadera. En infraestructura su uso clásico es **esperar o reintentar**: hasta que un servicio responda, hasta que un recurso pase a `available`. Siempre con un límite, o el script puede quedarse colgado en el pipeline.

```python title="esperar_servicio.py"
import time

respuestas = iter([False, False, True])   # simula: falla dos veces y luego responde

def servicio_responde() -> bool:
    return next(respuestas)

intento = 1
espera = 1
MAX_INTENTOS = 5
while not servicio_responde():
    if intento == MAX_INTENTOS:
        raise SystemExit("el servicio no responde")
    print(f"intento {intento} fallido, reintento en {espera}s")
    time.sleep(espera)
    intento += 1
    espera *= 2                            # exponential backoff: 1, 2, 4, 8...
print(f"servicio listo tras {intento} intentos")
```

```text
intento 1 fallido, reintento en 1s
intento 2 fallido, reintento en 2s
servicio listo tras 3 intentos
```

Esta estrategia se llama **exponential backoff** (espera exponencial): duplicar la espera entre intentos para no saturar un servicio que ya está con problemas. La verás aplicada a APIs en [APIs y HTTP](../scripting/apis-http.md).

## Funciones

Una **función** se define con `def`, recibe **parámetros** y devuelve un valor con `return` (si no hay `return`, devuelve `None`).

### Parámetros por defecto y argumentos con nombre

```python
def nombre_recurso(app: str, entorno: str = "dev", indice: int = 1) -> str:
    return f"{app}-{entorno}-{indice:02d}"

print(nombre_recurso("api"))                       # api-dev-01
print(nombre_recurso("api", "prod"))               # api-prod-01
print(nombre_recurso("api", indice=3))             # api-dev-03   (keyword argument)
print(nombre_recurso(entorno="stg", app="worker")) # worker-stg-01
```

Los **keyword arguments** (argumentos con nombre) hacen la llamada legible y permiten saltarse parámetros con valor por defecto. Si pones un `*` en la definición, todo lo que va detrás **solo** se puede pasar por nombre. Es buena práctica para opciones que cambian el comportamiento:

```python
def crear_bucket(nombre: str, *, region: str, cifrado: bool = True) -> str:
    return f"{nombre} en {region} (cifrado={cifrado})"

crear_bucket("logs-dani", region="eu-west-1")   # 'logs-dani en eu-west-1 (cifrado=True)'
crear_bucket("logs-dani", "eu-west-1")
# TypeError: crear_bucket() takes 1 positional argument but 2 were given
```

!!! danger "Nunca uses una lista o un dict como valor por defecto"
    El valor por defecto se crea **una sola vez**, al definir la función, y se comparte entre llamadas:

    ```python
    def agregar_host(host, lista=[]):
        lista.append(host)
        return lista

    print(agregar_host("web-01"))   # ['web-01']
    print(agregar_host("web-02"))   # ['web-01', 'web-02']  <- arrastra la llamada anterior
    ```

    Usa `None` y crea la lista dentro: `def agregar_host(host: str, lista: list[str] | None = None)` y luego `if lista is None: lista = []`.

### `*args` y `**kwargs`

`*args` recoge cualquier cantidad de argumentos posicionales en una tupla; `**kwargs` recoge argumentos con nombre en un diccionario. Los nombres `args` y `kwargs` son convención; lo que importa son los asteriscos.

```python
def log(nivel: str, *mensajes: str, **contexto: str) -> None:
    extra = " ".join(f"{k}={v}" for k, v in contexto.items())
    print(f"[{nivel}] {' '.join(mensajes)} {extra}".rstrip())

log("INFO", "despliegue", "completado", servicio="api", version="1.4.2")
log("WARN", "disco al 80%")
```

```text
[INFO] despliegue completado servicio=api version=1.4.2
[WARN] disco al 80%
```

Al **llamar**, los asteriscos hacen lo contrario: desempaquetan. `print(*hosts)` pasa cada host como argumento separado, y `f(**config)` pasa un diccionario como argumentos con nombre. Es habitual con los SDK de la nube, donde construyes un diccionario de parámetros y lo pasas con `cliente.metodo(**params)`.

### Retorno múltiple

Una función puede devolver varios valores separados por comas; en realidad devuelve una tupla, que desempaquetas al recibirla:

```python
def separar_endpoint(endpoint: str) -> tuple[str, int]:
    host, _, puerto = endpoint.rpartition(":")
    return host, int(puerto)

host, puerto = separar_endpoint("db.interna.example.com:5432")
print(host, puerto)    # db.interna.example.com 5432
```

El `_` es la convención para "este valor no me interesa".

### Alcance de variables

Las variables creadas dentro de una función son **locales**: no existen fuera y no pisan las de fuera. Una función puede **leer** una variable global, pero si le asigna un valor, Python la trata como local:

```python
contador = 0
def incrementar() -> None:
    contador += 1

incrementar()
# UnboundLocalError: cannot access local variable 'contador' where it is not associated with a value
```

Existe `global contador`, pero casi nunca es la solución. Pasa los datos como parámetros y devuelve el resultado: `contador = incrementar(contador)`.

### Funciones puras y funciones con efectos

- Una **función pura** (*pure function*) solo calcula: mismo resultado para los mismos argumentos, sin tocar nada fuera (`clasificar(uso)`, `separar_endpoint(texto)`). Son fáciles de probar y reutilizar.
- Una **función con efectos** (*side effects*, efectos secundarios) cambia algo fuera: escribe un archivo, llama a una API, borra un recurso, imprime.

Un buen script separa ambas: funciones puras que **deciden** (qué discos están llenos, qué snapshots sobran) y unas pocas funciones con efectos que **actúan** al final. Así puedes ofrecer un modo `--dry-run` (simulación) que muestra lo que haría sin hacerlo, y probar la lógica con [pytest](../scripting/calidad-codigo.md) sin tocar la nube.

### Lambdas

Una **lambda** es una función de una sola expresión, sin nombre. Úsala solo como argumento corto de otra función, sobre todo en `key=` de `sorted`, `min` o `max`:

```python
sorted(discos, key=lambda d: d[1], reverse=True)
```

Si necesitas reutilizarla o tiene lógica, escribe un `def` con nombre.

## Mini-ejercicio: alertas de disco a partir de `df -h`

Escribe tres funciones:

1. `parsear_df(salida)`: recibe el texto de `df -h` y devuelve una lista de tuplas `(punto_de_montaje, uso_en_%)`.
2. `clasificar(uso, aviso=75, critico=90)`: devuelve `"OK"`, `"AVISO"` o `"CRÍTICO"`.
3. `alertas(discos, **umbrales)`: devuelve los mensajes de los discos que no están OK, del más lleno al menos lleno, permitiendo cambiar los umbrales.

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/root        30G   28G  2.0G  94% /
tmpfs           3.9G     0  3.9G   0% /dev/shm
/dev/nvme1n1    100G   79G   21G  79% /var/lib/docker
/dev/nvme2n1     50G   10G   40G  20% /data
```

??? success "Solución"

    ```python title="alertas_disco.py"
    SALIDA_DF = """\
    Filesystem      Size  Used Avail Use% Mounted on
    /dev/root        30G   28G  2.0G  94% /
    tmpfs           3.9G     0  3.9G   0% /dev/shm
    /dev/nvme1n1    100G   79G   21G  79% /var/lib/docker
    /dev/nvme2n1     50G   10G   40G  20% /data
    """


    def parsear_df(salida: str) -> list[tuple[str, int]]:
        """Devuelve (punto de montaje, % de uso) por cada línea de `df -h`."""
        resultado = []
        for linea in salida.splitlines()[1:]:          # salta la cabecera
            columnas = linea.split()
            uso = int(columnas[4].rstrip("%"))
            resultado.append((columnas[5], uso))
        return resultado


    def clasificar(uso: int, aviso: int = 75, critico: int = 90) -> str:
        if uso >= critico:
            return "CRÍTICO"
        if uso >= aviso:
            return "AVISO"
        return "OK"


    def alertas(discos: list[tuple[str, int]], **umbrales: int) -> list[str]:
        mensajes = []
        for montaje, uso in sorted(discos, key=lambda d: d[1], reverse=True):
            nivel = clasificar(uso, **umbrales)
            if nivel != "OK":
                mensajes.append(f"{nivel:<8} {montaje} al {uso}%")
        return mensajes


    for mensaje in alertas(parsear_df(SALIDA_DF)):
        print(mensaje)
    print("--")
    for mensaje in alertas(parsear_df(SALIDA_DF), aviso=80, critico=95):
        print(mensaje)
    ```

    ```text
    CRÍTICO  / al 94%
    AVISO    /var/lib/docker al 79%
    --
    AVISO    / al 94%
    ```

    Las tres funciones son puras: no leen el disco ni envían alertas, solo transforman datos. En un script real, otra función obtendría la salida con `subprocess` ([Sistema y procesos](../scripting/sistema-procesos.md)) y otra enviaría los mensajes. Fíjate en que `**umbrales` reenvía `aviso` y `critico` a `clasificar` sin que `alertas` tenga que conocerlos.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Esperar a que un recurso esté disponible y reintentar ante límites de la API | [Resiliencia](../../cloud/operacion-y-gobierno/resiliencia.md) |
| DevOps (la automatización) | Umbrales de alerta y comprobaciones de salud que luego hace el sistema de monitoreo | [Observabilidad](../../devops/operacion/observabilidad.md), [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md) |
| DevSecOps (la verificación) | Separar la lógica que decide de la que actúa para poder probarla y simular (`--dry-run`) antes de tocar producción | [Seguridad del pipeline](../../devsecops/identidades-y-pipeline/seguridad-pipeline.md) |
| Python (la herramienta) | Qué pasa cuando algo falla dentro de una función y cómo repartir el código en módulos | [Errores, módulos y paquetes](errores-modulos.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 03: Script en Python para analizar logs](../../laboratorios/fundamentos/python-analizar-logs.md) |

## Referencias

- [Tutorial de Python: más herramientas para control de flujo](https://docs.python.org/es/3/tutorial/controlflow.html)
- [La sentencia match (referencia)](https://docs.python.org/es/3/reference/compound_stmts.html#the-match-statement)
- [Funciones integradas: enumerate, zip, range, sorted](https://docs.python.org/es/3/library/functions.html)
- [Preguntas frecuentes: valores por defecto compartidos entre llamadas](https://docs.python.org/es/3/faq/programming.html#why-are-default-values-shared-between-objects)

Siguiente: [Errores, módulos y paquetes](errores-modulos.md)
