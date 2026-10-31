---
tags:
  - python
  - scripting
  - automatizacion
  - linux
---

# Sistema y procesos

> Ejecutar comandos externos de forma segura con `subprocess.run`, manejar archivos y carpetas con `os` y `shutil`, permisos y variables de entorno, llamar a `git`, `kubectl` y `terraform` desde Python, y programar scripts con cron o systemd timers.

!!! info "Antes de leer"
    Esta nota asume lo visto en [Scripts de línea de comandos](scripts-cli.md): exit codes, stdout/stderr y `logging`.

## ¿Qué es?

Muchos scripts de automatización son **pegamento**: llaman a herramientas que ya existen (`git`, `terraform`, `kubectl`, `helm`, la CLI de la nube), leen su salida y deciden qué hacer. Python lo hace con el módulo **`subprocess`**, y para el sistema de archivos y el entorno usa **`os`** y **`shutil`**.

| Módulo | Para qué |
| --- | --- |
| `subprocess` | Ejecutar otros programas y leer su salida y su exit code |
| `os` | Variables de entorno, permisos, información del proceso |
| `shutil` | Copiar, mover, borrar árboles, comprimir, buscar ejecutables, espacio en disco |
| `pathlib` | Rutas y archivos sueltos (ver [Archivos y formatos](archivos-formatos.md)) |

## subprocess.run

**`subprocess.run()`** ejecuta un comando, espera a que termine y devuelve un objeto `CompletedProcess` con `returncode`, `stdout` y `stderr`.

```python
import subprocess

r = subprocess.run(["git", "--version"], capture_output=True, text=True, check=True)
print(r.returncode, r.stdout.strip())     # 0 git version 2.51.0
```

| Parámetro | Qué hace | Recomendación |
| --- | --- | --- |
| Lista de argumentos | `["git", "log", "-n", "5"]`: cada argumento es un elemento | Siempre lista, nunca un string con espacios |
| `check=True` | Lanza `CalledProcessError` si el exit code no es 0 | Actívalo casi siempre: un fallo silencioso es lo peor |
| `capture_output=True` | Guarda stdout y stderr en el resultado en vez de mostrarlos | Cuando necesitas leer la salida |
| `text=True` | Devuelve `str` en lugar de `bytes` | Casi siempre |
| `timeout=60` | Lanza `TimeoutExpired` si tarda más (y mata el proceso) | Siempre en comandos de red o que pueden colgarse |
| `cwd="infra"` | Directorio donde se ejecuta | Mejor que cambiar el directorio de todo el script con `os.chdir` |
| `env={...}` | Variables de entorno del proceso hijo | Parte de `os.environ` y añade lo tuyo |

### Manejar los errores

```python
import subprocess

try:
    subprocess.run(
        ["terraform", "plan", "-input=false"],
        cwd="infra", capture_output=True, text=True, check=True, timeout=600,
    )
except FileNotFoundError:
    print("terraform no está instalado o no está en el PATH")
except subprocess.CalledProcessError as e:
    print(f"terraform falló con código {e.returncode}:\n{e.stderr}")
except subprocess.TimeoutExpired:
    print("terraform plan tardó demasiado")
```

- **`FileNotFoundError`**: el ejecutable no existe. Puedes comprobarlo antes con `shutil.which("terraform")`.
- **`CalledProcessError`**: el comando terminó con exit code distinto de 0 (solo con `check=True`). Trae `returncode`, `cmd`, `stdout` y `stderr`.
- **`TimeoutExpired`**: se superó el `timeout`.

!!! tip "Sin `capture_output`, la salida se ve en vivo"
    Si no capturas la salida, el comando escribe directamente en tu terminal o en el log del pipeline, que es lo que quieres para `terraform apply` o un `docker build` largos. Captura solo cuando vas a procesar el resultado.

### Nunca `shell=True` con entradas externas

Con `shell=True` el comando se pasa como **un string a la shell** (`/bin/sh`), que interpreta `;`, `|`, `&&`, `$()`… Si una parte del string viene del usuario, de un archivo o de una API, eso es una **command injection** (inyección de comandos).

=== "Vulnerable"

    ```python
    host = input("Host a comprobar: ")        # "8.8.8.8; rm -rf ~"
    subprocess.run(f"ping -c 1 {host}", shell=True)
    ```

=== "Seguro"

    ```python
    import ipaddress

    host = str(ipaddress.ip_address(input("IP a comprobar: ")))   # valida: ValueError si no es una IP
    subprocess.run(["ping", "-c", "1", host], check=True, timeout=10)
    ```

Con la lista de argumentos no hay shell de por medio: `"8.8.8.8; rm -rf ~"` llegaría a `ping` como un único argumento (inválido) y no se ejecutaría nada más. Si necesitas una tubería, haz cada paso en Python (lee el stdout de un comando y pásalo con `input=` al siguiente) en lugar de recurrir a la shell. Bandit marca `shell=True` como hallazgo (ver [Calidad y seguridad de scripts](calidad-codigo.md) y [Seguridad del código](../../devsecops/codigo-y-dependencias/seguridad-codigo.md)).

## Llamar a git, kubectl y terraform

El patrón es siempre el mismo: una función pequeña que ejecuta la herramienta con `check=True` y, si la herramienta lo permite, pide la salida en **JSON** para no tener que parsear texto.

=== "git"

    ```python
    import subprocess


    def git(*args: str) -> str:
        return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout.strip()


    commit = git("rev-parse", "--short", "HEAD")
    rama = git("rev-parse", "--abbrev-ref", "HEAD")
    sucio = bool(git("status", "--porcelain"))
    print(f"{rama}@{commit}{' (con cambios sin commit)' if sucio else ''}")
    # main@7777cad (con cambios sin commit)
    ```

    Útil para etiquetar imágenes o artefactos con el commit del que salieron.

=== "terraform"

    ```python
    import json
    import subprocess
    from pathlib import Path


    def terraform_outputs(directorio: Path) -> dict:
        """Devuelve los outputs de Terraform como dict {nombre: valor}."""
        resultado = subprocess.run(
            ["terraform", f"-chdir={directorio}", "output", "-json"],
            capture_output=True, text=True, check=True, timeout=120,
        )
        return {nombre: o["value"] for nombre, o in json.loads(resultado.stdout).items()}


    outputs = terraform_outputs(Path("infra"))
    print(outputs["vpc_id"], outputs["web_ips"])
    # vpc-0a1b2c3d4e5f67890 ['10.0.1.10', '10.0.1.11']
    ```

    `-chdir=` hace que Terraform trabaje en ese directorio. Recuerda que este dict incluye los outputs sensibles en claro (ver [Archivos y formatos](archivos-formatos.md#leer-terraform-output-json)).

=== "kubectl"

    ```python
    import json
    import subprocess


    def pods_con_problemas(namespace: str, max_reinicios: int = 5) -> list[str]:
        salida = subprocess.run(
            ["kubectl", "get", "pods", "-n", namespace, "-o", "json"],
            capture_output=True, text=True, check=True, timeout=30,
        ).stdout
        problemas = []
        for pod in json.loads(salida)["items"]:
            nombre = pod["metadata"]["name"]
            fase = pod["status"].get("phase", "Unknown")
            reinicios = sum(c.get("restartCount", 0) for c in pod["status"].get("containerStatuses", []))
            if fase not in ("Running", "Succeeded") or reinicios > max_reinicios:
                problemas.append(f"{nombre}: fase={fase}, reinicios={reinicios}")
        return problemas


    print("\n".join(pods_con_problemas("produccion")))
    # api-7d9f-def: fase=Running, reinicios=12
    # worker-55c-xyz: fase=Pending, reinicios=0
    ```

    `kubectl` usa el contexto activo del kubeconfig; pásale `--context` si el script no debe depender de lo que tengas seleccionado. Ver [Kubernetes](../../devops/contenedores/kubernetes.md).

!!! note "Cuándo usar el SDK en vez de la CLI"
    Llamar a `aws`, `az` o `gcloud` con `subprocess` funciona, pero para lógica no trivial es mejor el **SDK** de la nube: errores como excepciones, paginación y tipos en lugar de texto. Ver [Automatización cloud con SDKs](automatizacion-cloud.md).

## os y shutil

```python
import os
import shutil

shutil.copy2("app/conf/app.ini", "app/conf/app.ini.bak")         # copia conservando fechas
shutil.copytree("app", "app-respaldo", dirs_exist_ok=True)         # copia un árbol completo
archivo = shutil.make_archive("respaldo-app", "gztar", root_dir="app-respaldo")   # respaldo-app.tar.gz
shutil.move(archivo, "/backups/")                                  # mover (también entre discos)
shutil.rmtree("app-respaldo")                                      # borra un árbol: sin papelera, cuidado

uso = shutil.disk_usage("/")
print(f"Libre: {uso.free / uso.total:.0%}")                        # Libre: 35%
print(shutil.which("kubectl"))                                     # ruta del ejecutable o None
print(os.cpu_count(), os.getpid())
```

| Tarea | Función |
| --- | --- |
| Copiar archivo | `shutil.copy2(origen, destino)` |
| Copiar carpeta | `shutil.copytree(origen, destino, dirs_exist_ok=True)` |
| Mover / renombrar | `shutil.move(origen, destino)` |
| Borrar carpeta con contenido | `shutil.rmtree(ruta)` |
| Crear `.tar.gz` o `.zip` | `shutil.make_archive(nombre, "gztar" \| "zip", root_dir=...)` |
| Espacio en disco | `shutil.disk_usage(ruta)` |
| ¿Está instalado? | `shutil.which("terraform")` |

!!! danger "`rmtree` con rutas calculadas"
    `shutil.rmtree` no pregunta. Si la ruta se construye con variables, valida antes que no esté vacía y que esté dentro del directorio esperado (`base in ruta.resolve().parents`), y ofrece `--dry-run`. Es el equivalente a `rm -rf "$DIR/"` con `DIR` vacío en Bash.

## Permisos

```python
import os
import stat
from pathlib import Path

clave = Path("clave.pem")
clave.chmod(0o600)                                   # solo el dueño lee y escribe (como `chmod 600`)
print(oct(stat.S_IMODE(clave.stat().st_mode)))      # 0o600
print(os.access(clave, os.R_OK))                     # ¿puede leerlo este proceso?
```

- Los permisos se escriben en **octal** (`0o600`, `0o755`), igual que en `chmod`.
- Para crear un archivo con secretos sin que exista ni un instante con permisos abiertos, usa `os.open(ruta, os.O_WRONLY | os.O_CREAT, 0o600)` o ajusta el **umask** del proceso.
- `os.chown` / `shutil.chown` cambian el dueño (requiere privilegios). Ejecuta los scripts con el usuario mínimo necesario, no como `root`.
- En Windows, `chmod` solo cambia el atributo de solo lectura; los permisos reales son ACLs.

## Variables de entorno en procesos hijos

El proceso hijo hereda las variables del script. Para añadir o cambiar algunas **sin tocar las del script**, crea un diccionario nuevo:

```python
import os
import subprocess

env = {**os.environ, "TF_IN_AUTOMATION": "1", "TF_LOG": "ERROR"}
subprocess.run(["terraform", "plan", "-input=false"], cwd="infra", env=env, check=True)
```

!!! warning "`env=` reemplaza, no añade"
    Si pasas `env={"TF_LOG": "ERROR"}` sin copiar `os.environ`, el hijo pierde `PATH`, `HOME` y las credenciales de la nube, y suele fallar de formas confusas. Por la misma razón, no pongas secretos en los argumentos del comando: otros usuarios del sistema pueden verlos con `ps`; pásalos por variables de entorno o por stdin.

## Programar scripts

Un script que debe correr cada noche (limpiar snapshots, revisar certificados, un reporte de costos) se programa con **cron** o con un **systemd timer** en Linux. La sintaxis de crontab, los fallos clásicos de cron, el `.timer` completo (`OnCalendar`, `Persistent`, `RandomizedDelaySec`) y cómo habilitarlo y probarlo están en [Procesos y rendimiento en Linux Server](../../servidores/linux/linux-procesos-rendimiento.md#tareas-programadas); systemd en general, en [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md#systemd). Aquí, lo propio de un script de Python:

=== "cron"

    ```bash title="crontab -e"
    # min hora día mes día_semana  comando
    0 3 * * * /opt/scripts/.venv/bin/python /opt/scripts/limpiar.py --apply >> /var/log/limpiar.log 2>&1
    ```

    Usa rutas absolutas (cron arranca con un `PATH` mínimo) y el Python del **venv** del script.

=== "systemd timer"

    ```ini title="/etc/systemd/system/limpiar.service"
    [Unit]
    Description=Limpieza de snapshots antiguos

    [Service]
    Type=oneshot
    User=automatizacion
    EnvironmentFile=/etc/limpiar/env
    ExecStart=/opt/scripts/.venv/bin/python /opt/scripts/limpiar.py --apply
    ```

    Se activa con un `limpiar.timer` (`OnCalendar=*-*-* 03:00:00`) que se habilita con `systemctl enable --now limpiar.timer`; los logs quedan en `journalctl -u limpiar.service`. A diferencia de cron, el servicio corre con su propio usuario (`User=`), recibe la configuración y los secretos de un `EnvironmentFile` en lugar de la línea de comandos, y admite opciones de *hardening*.

En la nube, para tareas programadas sin servidor propio tienes **Amazon EventBridge Scheduler**, **Azure Functions** con *timer trigger* y **Cloud Scheduler**, que disparan una función o un job (ver [Serverless](../../cloud/computo/serverless.md)). En Kubernetes, un **CronJob**.

## ¿Python o Bash?

| Mejor en Bash | Mejor en Python |
| --- | --- |
| Encadenar unos pocos comandos y tuberías | Lógica con condiciones, bucles y estructuras de datos |
| Scripts cortos (decenas de líneas) | Scripts que crecen o se reutilizan |
| Pasos simples de un pipeline o un `Dockerfile` | Procesar JSON/YAML o hablar con APIs y SDKs |
| Entornos mínimos donde no hay Python | Manejo de errores fino y pruebas con `pytest` |

Una señal clara: si en Bash empiezas a usar `jq` encadenado con arrays y funciones, o el script supera ~50–100 líneas, pásalo a Python.

## Mini-ejercicio: *preflight check* del pipeline

Escribe `preflight.py`, que compruebe antes de un despliegue que están instaladas `git`, `terraform`, `kubectl` y `helm`:

- Si una herramienta no está en el `PATH`, la marca como `[FALTA]` sin intentar ejecutarla.
- Si está, ejecuta su comando de versión (con `timeout`) y muestra la primera línea.
- Termina con exit code 1 si falta o falla alguna, y 0 si todo está bien.

??? success "Solución"

    ```python title="preflight.py"
    #!/usr/bin/env python3
    """Comprueba que las herramientas que necesita el pipeline están instaladas."""
    import shutil
    import subprocess
    import sys

    HERRAMIENTAS = {
        "git": ["git", "--version"],
        "terraform": ["terraform", "version"],
        "kubectl": ["kubectl", "version", "--client"],
        "helm": ["helm", "version", "--short"],
    }


    def version(comando: list[str]) -> str:
        resultado = subprocess.run(comando, capture_output=True, text=True, check=True, timeout=15)
        return resultado.stdout.strip().splitlines()[0]


    def main() -> int:
        faltan = []
        for nombre, comando in HERRAMIENTAS.items():
            if shutil.which(nombre) is None:
                faltan.append(nombre)
                print(f"[FALTA] {nombre}")
                continue
            try:
                print(f"[OK]    {nombre}: {version(comando)}")
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
                faltan.append(nombre)
                print(f"[ERROR] {nombre}: {e}")
        if faltan:
            print(f"Faltan o fallan: {', '.join(faltan)}", file=sys.stderr)
            return 1
        return 0


    if __name__ == "__main__":
        sys.exit(main())
    ```

    ```text
    $ ./preflight.py; echo "exit=$?"
    [OK]    git: git version 2.51.0
    [OK]    terraform: Terraform v1.7.5
    [OK]    kubectl: Client Version: v1.29.1
    [FALTA] helm
    Faltan o fallan: helm
    exit=1
    ```

    Las versiones dependen de tu máquina. Para exigir versiones mínimas, compara las cadenas con `packaging.version.Version` en lugar de compararlas como texto (`"1.10" < "1.9"` es `True` como string).

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Tareas programadas sin servidor y CLIs de la nube que puedes invocar | [Serverless](../../cloud/computo/serverless.md) |
| DevOps (la automatización) | Bash, systemd y las herramientas (`terraform`, `kubectl`, `git`) que el script orquesta | [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md), [Terraform](../../devops/iac/terraform-basico.md), [Kubernetes](../../devops/contenedores/kubernetes.md), [Git y control de versiones](../../devops/fundamentos/git-control-versiones.md) |
| DevSecOps (la verificación) | Command injection con `shell=True`, permisos de archivos con secretos y secretos fuera de los argumentos | [Seguridad del código](../../devsecops/codigo-y-dependencias/seguridad-codigo.md), [Secretos e identidades](../../devsecops/identidades-y-pipeline/secretos-identidades.md) |
| Python (la herramienta) | Excepciones y CLIs que envuelven estas llamadas | [Errores, módulos y paquetes](../fundamentos/errores-modulos.md), [Scripts de línea de comandos](scripts-cli.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 12: Escaneos de seguridad en el pipeline](../../laboratorios/devsecops/escaneos-en-pipeline.md) |

## Referencias

- [subprocess: gestión de subprocesos](https://docs.python.org/es/3/library/subprocess.html)
- [Consideraciones de seguridad de subprocess](https://docs.python.org/es/3/library/subprocess.html#security-considerations)
- [shutil: operaciones de archivos de alto nivel](https://docs.python.org/es/3/library/shutil.html)
- [os: interfaces misceláneas del sistema operativo](https://docs.python.org/es/3/library/os.html)
- [systemd.timer (man page)](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html)
- [crontab(5) (man page)](https://man7.org/linux/man-pages/man5/crontab.5.html)
- [Terraform: opción global `-chdir`](https://developer.hashicorp.com/terraform/cli/commands)
- [kubectl: formatos de salida](https://kubernetes.io/docs/reference/kubectl/#output-options)

Siguiente: [APIs y HTTP](apis-http.md)
