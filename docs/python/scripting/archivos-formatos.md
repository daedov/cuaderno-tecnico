---
tags:
  - python
  - scripting
  - automatizacion
  - iac
---

# Archivos y formatos

> Rutas con `pathlib`, lectura y escritura de texto en UTF-8, archivos grandes línea a línea y los formatos que más vas a tocar en infraestructura: CSV, JSON, YAML, variables de entorno y la salida de `terraform output -json`.

!!! info "Antes de leer"
    Esta nota asume lo visto en [Errores, módulos y paquetes](../fundamentos/errores-modulos.md): `try`/`except`, el bloque `with` (*context manager*) e `import`. Es la primera nota del bloque de scripting.

## ¿Qué es?

Buena parte del trabajo de automatización es **leer un archivo, transformarlo y escribir otro**: un log que hay que resumir, un CSV de inventario, el `values.yaml` de Helm, el JSON que devuelve una API o Terraform, un `.env` con configuración. Python trae casi todo en la **standard library** (librería estándar); solo YAML y `.env` necesitan paquetes externos.

| Formato | Módulo | ¿Viene con Python? | Dónde aparece |
| --- | --- | --- | --- |
| Rutas y archivos | `pathlib` | Sí | Todo script que toque disco |
| Texto plano / logs | `open()`, `Path.read_text()` | Sí | Logs, plantillas, listas de hosts |
| CSV | `csv` | Sí | Inventarios, exportes de costos, reportes |
| JSON | `json` | Sí | APIs, `terraform output -json`, `aws ... --output json`, `kubectl -o json` |
| YAML | `yaml` (paquete **PyYAML**) | No: `pip install pyyaml` | Kubernetes, Helm, Ansible, GitHub Actions, Docker Compose |
| Variables de entorno | `os.environ` | Sí | Configuración y secretos inyectados por el pipeline |
| `.env` | `dotenv` (paquete **python-dotenv**) | No: `pip install python-dotenv` | Desarrollo local |

## Rutas con pathlib

**`pathlib`** representa las rutas como objetos `Path` en lugar de strings. Une rutas con el operador `/`, funciona igual en Linux, macOS y Windows, y trae métodos para leer, escribir, buscar y borrar. Es la forma moderna; `os.path` sigue existiendo, pero en código nuevo usa `pathlib`.

```python title="rutas.py"
from pathlib import Path

base = Path("proyecto")
config = base / "config" / "app.yaml"
print(config)                                # proyecto/config/app.yaml
print(config.name, config.stem, config.suffix)   # app.yaml app .yaml
print(config.parent)                         # proyecto/config

config.parent.mkdir(parents=True, exist_ok=True)   # como `mkdir -p`
config.write_text("entorno: dev\n", encoding="utf-8")
print(config.exists(), config.is_file())     # True True

print(sorted(p.name for p in base.glob("logs/*.log")))   # solo esa carpeta
print(sorted(p.as_posix() for p in base.rglob("*.yaml")))  # recursivo

(base / "logs" / "viejo.log").unlink(missing_ok=True)   # borrar sin fallar si no existe
```

| Operación | `pathlib` | Equivalente en Bash |
| --- | --- | --- |
| Unir rutas | `Path("a") / "b" / "c.txt"` | `a/b/c.txt` |
| Ruta absoluta | `p.resolve()` | `realpath p` |
| Directorio actual / home | `Path.cwd()`, `Path.home()` | `pwd`, `~` |
| ¿Existe? ¿Archivo? ¿Carpeta? | `p.exists()`, `p.is_file()`, `p.is_dir()` | `[[ -e p ]]`, `-f`, `-d` |
| Crear carpeta | `p.mkdir(parents=True, exist_ok=True)` | `mkdir -p p` |
| Listar | `p.iterdir()`, `p.glob("*.tf")`, `p.rglob("*.tf")` | `ls`, `find p -name "*.tf"` |
| Borrar archivo / carpeta vacía | `p.unlink()`, `p.rmdir()` | `rm`, `rmdir` |
| Renombrar / mover | `p.rename(destino)` | `mv` |
| Tamaño y fecha | `p.stat().st_size`, `p.stat().st_mtime` | `stat` |

!!! note "Borrar carpetas con contenido y copiar"
    `pathlib` no borra carpetas con contenido ni copia árboles. Para eso está `shutil` (`shutil.rmtree`, `shutil.copytree`), que se ve en [Sistema y procesos](sistema-procesos.md).

## Leer y escribir texto

Para archivos pequeños, `read_text()` y `write_text()` bastan. Para más control, `open()` dentro de un `with`, que cierra el archivo aunque haya un error.

```python
from pathlib import Path

ruta = Path("hosts.txt")
ruta.write_text("web-01\nweb-02\n", encoding="utf-8")       # sobrescribe

with ruta.open("a", encoding="utf-8") as f:                  # "a" = append (añadir al final)
    f.write("db-01\n")

hosts = ruta.read_text(encoding="utf-8").splitlines()
print(hosts)                                                 # ['web-01', 'web-02', 'db-01']
```

| Modo | Qué hace |
| --- | --- |
| `"r"` | Leer (por defecto). Falla con `FileNotFoundError` si no existe |
| `"w"` | Escribir. **Vacía** el archivo si ya existe |
| `"a"` | Añadir al final |
| `"x"` | Crear; falla con `FileExistsError` si ya existe (evita pisar algo por error) |
| `"b"` | Binario (`"rb"`, `"wb"`): imágenes, `.zip`, `.tar.gz`. Lee y escribe `bytes`, sin encoding |

### Encoding: siempre UTF-8 explícito

El **encoding** (codificación de caracteres) define cómo se guardan los caracteres como bytes. Si no lo indicas, Python usa el del sistema operativo: en Linux suele ser UTF-8, pero en Windows puede ser `cp1252`, y entonces una "ñ" o una tilde se leen mal o el script falla con `UnicodeDecodeError`.

!!! tip "Regla práctica"
    Pasa siempre `encoding="utf-8"` al leer y escribir texto. Si lees logs de terceros que pueden traer bytes inválidos, añade `errors="replace"` para que un carácter roto no tumbe el script.

### Archivos grandes línea a línea

`read_text()` carga el archivo entero en memoria; con un log de varios GB eso es un problema. Recorrer el archivo con `for` lee **una línea cada vez**:

```python title="contar_niveles.py"
from collections import Counter
from pathlib import Path

niveles: Counter[str] = Counter()
with Path("access.log").open(encoding="utf-8", errors="replace") as f:
    for linea in f:                      # una línea por iteración, memoria constante
        partes = linea.split()
        if len(partes) >= 2:
            niveles[partes[1]] += 1

print(niveles.most_common())
```

```text
[('INFO', 2), ('ERROR', 2), ('WARNING', 1)]
```

Para logs comprimidos, `gzip.open("app.log.gz", "rt", encoding="utf-8")` devuelve un archivo de texto que se recorre igual.

## CSV

El módulo **`csv`** maneja comillas, comas dentro de campos y saltos de línea, cosas que un `split(",")` rompe. **`DictReader`** convierte cada fila en un diccionario con las columnas de la cabecera.

```python title="sin_owner.py"
import csv
from pathlib import Path

with Path("inventario.csv").open(newline="", encoding="utf-8") as f:
    filas = list(csv.DictReader(f))

sin_owner = [fila for fila in filas if not fila["owner"]]

with Path("sin_owner.csv").open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["hostname", "ip"], extrasaction="ignore")
    writer.writeheader()
    writer.writerows(sin_owner)
```

!!! warning "`newline=\"\"` al abrir CSV"
    La documentación de `csv` pide abrir los archivos con `newline=""`. Sin eso, en Windows aparecen líneas en blanco entre filas y los campos con saltos de línea se rompen. Recuerda también que `csv` devuelve **todo como string**: convierte tú los números (`int(fila["puerto"])`).

## JSON

**JSON** es el formato de casi todas las APIs y de la salida de las CLIs (`aws ... --output json`, `az ... -o json`, `gcloud ... --format=json`, `kubectl get ... -o json`). El módulo `json` lo convierte en tipos de Python:

| JSON | Python |
| --- | --- |
| `object` `{}` | `dict` |
| `array` `[]` | `list` |
| `string` | `str` |
| `number` | `int` o `float` |
| `true` / `false` | `True` / `False` |
| `null` | `None` |

```python
import json
from pathlib import Path

servidor = json.loads('{"nombre": "web-01", "puertos": [80, 443], "publica": true}')  # str -> dict
print(servidor["puertos"])                     # [80, 443]

servidor["entorno"] = "producción"
texto = json.dumps(servidor, indent=2, ensure_ascii=False)     # dict -> str legible
Path("servidor.json").write_text(texto + "\n", encoding="utf-8")

with Path("servidor.json").open(encoding="utf-8") as f:
    datos = json.load(f)                       # load/dump trabajan con archivos; loads/dumps con strings
```

`ensure_ascii=False` deja las tildes tal cual (`"producción"`) en vez de escaparlas (`"producción"`).

### Leer `terraform output -json`

`terraform output -json` devuelve un objeto con un elemento por cada *output*, y cada uno trae `sensitive`, `type` y `value`:

```json title="outputs.json"
{
  "db_password": { "sensitive": true, "type": "string", "value": "no-me-imprimas" },
  "vpc_id": { "sensitive": false, "type": "string", "value": "vpc-0a1b2c3d4e5f67890" },
  "web_ips": { "sensitive": false, "type": ["list", "string"], "value": ["10.0.1.10", "10.0.1.11"] }
}
```

```python title="tf_outputs.py"
import json
from pathlib import Path

# Generado antes con: terraform output -json > outputs.json
datos = json.loads(Path("outputs.json").read_text(encoding="utf-8"))

for nombre, salida in datos.items():
    valor = "(sensible)" if salida["sensitive"] else salida["value"]
    print(f"{nombre}: {valor}")
```

```text
db_password: (sensible)
vpc_id: vpc-0a1b2c3d4e5f67890
web_ips: ['10.0.1.10', '10.0.1.11']
```

!!! danger "Con `-json`, los outputs sensibles salen en claro"
    `terraform output` oculta los valores marcados como `sensitive`, pero con `-json` los muestra **en texto plano**. No guardes ese archivo en el repositorio ni lo publiques como *artifact* del pipeline, y no imprimas `value` sin mirar `sensitive`. Mejor aún: que los secretos los lea la aplicación desde el gestor de secretos (ver [Secretos e identidades](../../devsecops/identidades-y-pipeline/secretos-identidades.md)).

En [Sistema y procesos](sistema-procesos.md) verás cómo ejecutar `terraform output -json` directamente desde Python con `subprocess`, sin archivo intermedio.

## YAML

**YAML** es el formato de Kubernetes, Helm, Ansible, Docker Compose y los workflows de CI. Python no lo trae: instala **PyYAML** (`pip install pyyaml`; se importa como `yaml`).

```python title="subir_replicas.py"
from pathlib import Path

import yaml

valores = yaml.safe_load(Path("values.yaml").read_text(encoding="utf-8"))
print(valores["replicas"], valores["image"]["tag"])     # 3 1.4.0

valores["replicas"] = 5
Path("values-prod.yaml").write_text(
    yaml.safe_dump(valores, sort_keys=False, allow_unicode=True), encoding="utf-8"
)
```

!!! danger "Usa siempre `safe_load`"
    `yaml.load()` con el *loader* completo o el inseguro puede construir objetos de Python arbitrarios a partir del archivo, lo que permite ejecutar código si el YAML viene de alguien más. **`yaml.safe_load()`** solo crea tipos básicos (dict, list, str, números, bool, None). Bandit y Semgrep marcan `yaml.load` como hallazgo (ver [Calidad y seguridad de scripts](calidad-codigo.md)).

!!! warning "Las sorpresas de YAML 1.1"
    PyYAML sigue YAML 1.1, que interpreta como booleanos o números cosas que parecen texto: `version: 1.10` se lee como el float `1.1`, `activo: yes` como `True` y `pais: NO` como `False`. Pon entre comillas los valores que deben ser string (`tag: "1.10"`). Además, `safe_dump` **no conserva comentarios** ni el formato original; si necesitas editar un YAML manteniendo comentarios, mira la librería `ruamel.yaml`.

## Variables de entorno y .env

Las **environment variables** (variables de entorno) son la forma estándar de pasar configuración y secretos a un script sin escribirlos en el código: el pipeline, el contenedor o systemd las inyectan.

```python
import os

region = os.environ.get("AWS_REGION", "us-east-1")   # opcional, con valor por defecto
api_url = os.environ["API_URL"]                       # obligatoria: KeyError si falta
token = os.getenv("API_TOKEN")                        # None si no existe
```

En desarrollo local es cómodo tenerlas en un archivo **`.env`** y cargarlo con **python-dotenv**:

```bash title=".env"
API_URL=https://api.ejemplo.com
API_TOKEN=token-de-desarrollo
```

```python
from dotenv import load_dotenv

load_dotenv()          # lee .env y lo pasa a os.environ; por defecto NO pisa variables ya definidas
```

!!! warning "El `.env` nunca va al repositorio"
    Añade `.env` al `.gitignore` y versiona un `.env.example` con los nombres de las variables y valores ficticios. En el pipeline o en producción no uses `.env`: las variables vienen del gestor de secretos o de la plataforma. Un detector de secretos como gitleaks ayuda a que no se cuele (ver [Seguridad del código](../../devsecops/codigo-y-dependencias/seguridad-codigo.md)).

## Mini-ejercicio: inventario de Ansible desde Terraform

Partiendo del `outputs.json` de arriba, escribe un script que:

1. Lea `web_ips` y genere `inventario/hosts.yml` (creando la carpeta si no existe) con un grupo `web`, un host por IP llamado `web-01`, `web-02`… con su `ansible_host`, y la variable de grupo `ansible_user: ubuntu`.
2. Muestre cuántos hosts escribió y qué outputs sensibles **omitió**, sin imprimir sus valores.

??? success "Solución"

    ```python title="tf_a_inventario.py"
    import json
    from pathlib import Path

    import yaml

    outputs = json.loads(Path("outputs.json").read_text(encoding="utf-8"))

    ips = outputs["web_ips"]["value"]
    inventario = {
        "web": {
            "hosts": {f"web-{i:02d}": {"ansible_host": ip} for i, ip in enumerate(ips, start=1)},
            "vars": {"ansible_user": "ubuntu"},
        }
    }

    destino = Path("inventario") / "hosts.yml"
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(yaml.safe_dump(inventario, sort_keys=False), encoding="utf-8")

    sensibles = [nombre for nombre, salida in outputs.items() if salida["sensitive"]]
    print(f"Inventario escrito en {destino.as_posix()} ({len(ips)} hosts)")
    print(f"Outputs sensibles omitidos: {', '.join(sensibles)}")
    ```

    ```text
    Inventario escrito en inventario/hosts.yml (2 hosts)
    Outputs sensibles omitidos: db_password
    ```

    ```yaml title="inventario/hosts.yml"
    web:
      hosts:
        web-01:
          ansible_host: 10.0.1.10
        web-02:
          ansible_host: 10.0.1.11
      vars:
        ansible_user: ubuntu
    ```

    `{i:02d}` rellena con ceros a dos dígitos y `enumerate(..., start=1)` numera desde 1. Con `ansible-inventory -i inventario/hosts.yml --list` puedes comprobar que Ansible lo entiende.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| DevOps (la automatización) | Los outputs de Terraform y los inventarios y archivos YAML que consumen otras herramientas | [Infrastructure as Code](../../devops/iac/infraestructura-como-codigo.md), [Terraform](../../devops/iac/terraform-basico.md), [Ansible](../../devops/iac/ansible.md), [Kubernetes](../../devops/contenedores/kubernetes.md) |
| DevSecOps (la verificación) | Outputs sensibles, `.env` fuera del repositorio y `yaml.safe_load` | [Secretos e identidades](../../devsecops/identidades-y-pipeline/secretos-identidades.md), [Seguridad del código](../../devsecops/codigo-y-dependencias/seguridad-codigo.md) |
| Python (la herramienta) | Context managers y excepciones que se usan al abrir archivos | [Errores, módulos y paquetes](../fundamentos/errores-modulos.md), [Estructuras de datos](../fundamentos/estructuras-datos.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 02: Plan de direccionamiento IP para una VPC](../../laboratorios/fundamentos/subnetting-plan-ips.md), [Lab 03: Script en Python para analizar logs](../../laboratorios/fundamentos/python-analizar-logs.md) |

## Referencias

- [pathlib: rutas orientadas a objetos](https://docs.python.org/es/3/library/pathlib.html)
- [Leer y escribir archivos (tutorial de Python)](https://docs.python.org/es/3/tutorial/inputoutput.html#reading-and-writing-files)
- [csv: lectura y escritura de archivos CSV](https://docs.python.org/es/3/library/csv.html)
- [json: codificador y decodificador JSON](https://docs.python.org/es/3/library/json.html)
- [PyYAML documentation](https://pyyaml.org/wiki/PyYAMLDocumentation)
- [python-dotenv](https://github.com/theskumar/python-dotenv)
- [Terraform: comando `terraform output`](https://developer.hashicorp.com/terraform/cli/commands/output)

Siguiente: [Scripts de línea de comandos](scripts-cli.md)
