# Python :material-language-python:

**Python es la herramienta**: fundamentos del lenguaje enfocados en **scripting y automatización** de infraestructura, no en desarrollo de aplicaciones. Leer logs y archivos de configuración, llamar APIs, ejecutar comandos y automatizar tareas en la nube.

La sección va en orden: primero el lenguaje y después cómo aplicarlo. Cada nota incluye un mini-ejercicio práctico con su solución.

Ver también [Linux, redes y scripting](../devops/fundamentos/linux-redes-scripting.md) (cuándo usar Bash y cuándo Python) y el [mapa de relaciones](../mapa-de-relaciones.md).

## Fundamentos

- **1.** [Entorno de trabajo](fundamentos/entorno-python.md): instalación, `venv`, `pip`, `uv` y `pipx`
- **2.** [Sintaxis y tipos](fundamentos/sintaxis-tipos.md): variables, strings, f-strings, conversión de tipos, type hints
- **3.** [Estructuras de datos](fundamentos/estructuras-datos.md): list, dict, set, tuple, comprehensions, `collections`
- **4.** [Control de flujo y funciones](fundamentos/control-flujo-funciones.md): condicionales, bucles, funciones puras vs con efectos
- **5.** [Errores, módulos y paquetes](fundamentos/errores-modulos.md): excepciones, `with`, `import`, librería estándar

## Scripting

- **6.** [Archivos y formatos](scripting/archivos-formatos.md): `pathlib`, CSV, JSON, YAML, `.env`, `terraform output -json`
- **7.** [Scripts de línea de comandos](scripting/scripts-cli.md): `argparse`, exit codes, stdin/stdout/stderr, `logging`
- **8.** [Sistema y procesos](scripting/sistema-procesos.md): `subprocess`, `os`, `shutil`, cron y systemd timers
- **9.** [APIs y HTTP](scripting/apis-http.md): `requests`, tokens, timeouts, reintentos, paginación
- **10.** [Automatización cloud con SDKs](scripting/automatizacion-cloud.md): boto3, Azure SDK, Google Cloud client libraries, credenciales sin claves
- **11.** [Calidad y seguridad de scripts](scripting/calidad-codigo.md): `mypy`, `ruff`, `pytest`, `pyproject.toml`, Bandit, `pip-audit`

!!! note "Añadir una nota"
    Crea un `.md` en `fundamentos/` o `scripting/` y agrégalo a su `.pages` para fijar su orden en el menú.
