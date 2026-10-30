---
tags:
  - seguridad
  - sast
  - secretos
  - ci-cd
---

# Seguridad del código

> Escribir código seguro desde el principio y comprobarlo de forma automática con SAST, detección de secretos y pre-commit hooks.

## ¿Qué es?

La seguridad del código es la parte más a la izquierda del **shift-left** (ver [Fundamentos de DevSecOps](../fundamentos-devsecops.md)). Tiene dos mitades:

- **Secure coding** (programación segura): hábitos y patrones que evitan las vulnerabilidades más comunes al escribir el código.
- **Verificación automática**: herramientas que revisan el código en el editor, en cada commit y en el pipeline de CI para detectar lo que se escapó.

| Control | Cuándo corre | Qué detecta | Herramientas |
| --- | --- | --- | --- |
| Pre-commit hooks | En tu máquina, antes del commit | Secretos, errores de formato y de lint | `pre-commit`, gitleaks |
| **SAST** (*Static Application Security Testing*, análisis estático) | En el *pull request* y en CI | Patrones de código vulnerable | SonarQube, Semgrep, CodeQL |
| Secret scanning | En el push, en CI y sobre el historial | Credenciales en el repositorio | gitleaks, TruffleHog, GitHub secret scanning |

## Secure coding

### Validar las entradas

Toda entrada externa (formularios, parámetros de URL, cabeceras, archivos, mensajes de una cola) es **no confiable** hasta que se valida. Lo recomendable es la **allowlist** (lista de permitidos): definir qué es válido y rechazar todo lo demás, en lugar de intentar bloquear lo malo.

=== "Vulnerable"

    ```python
    # Acepta cualquier valor y lo usa para construir una ruta
    def descargar(nombre):
        return open(f"/datos/informes/{nombre}").read()   # nombre = "../../etc/passwd"
    ```

=== "Seguro"

    ```python
    import re
    from pathlib import Path

    BASE = Path("/datos/informes").resolve()

    def descargar(nombre: str) -> str:
        if not re.fullmatch(r"[a-z0-9_-]{1,64}\.pdf", nombre):
            raise ValueError("Nombre de archivo no válido")
        ruta = (BASE / nombre).resolve()
        if BASE not in ruta.parents:          # defensa extra contra path traversal
            raise ValueError("Ruta fuera del directorio permitido")
        return ruta.read_text()
    ```

### Usar consultas parametrizadas

La **SQL injection** (inyección SQL) ocurre cuando los datos del usuario se concatenan dentro de la consulta y la base de datos los interpreta como código. La solución es usar **consultas parametrizadas** (*parameterized queries*): el driver envía la consulta y los datos por separado.

=== "Vulnerable"

    ```python
    # email = "' OR '1'='1" devuelve todos los usuarios
    cur.execute(f"SELECT * FROM usuarios WHERE email = '{email}'")
    ```

=== "Seguro"

    ```python
    cur.execute("SELECT * FROM usuarios WHERE email = %s", (email,))
    ```

Lo mismo aplica a comandos del sistema: evita `shell=True` y pasa los argumentos como lista (`subprocess.run(["ping", "-c", "1", host])`). Los ORM (Django ORM, SQLAlchemy, Prisma…) parametrizan por defecto, salvo que uses sus funciones de SQL crudo.

### Manejar los errores sin filtrar información

Un mensaje de error detallado ayuda a depurar, pero también al atacante (rutas internas, versiones, cadenas de conexión). Registra el detalle en los logs y devuelve al usuario un mensaje genérico.

=== "Vulnerable"

    ```python
    except Exception as e:
        return {"error": str(e), "trace": traceback.format_exc()}, 500
    ```

=== "Seguro"

    ```python
    except Exception:
        log.exception("Error procesando el pedido %s", pedido_id)
        return {"error": "Error interno. Código de referencia: " + request_id}, 500
    ```

Además, ante un error la aplicación debe **fallar cerrada** (*fail closed*): si no se puede verificar un permiso, se deniega el acceso, nunca se concede por defecto. Es justo lo que cubre la categoría *Mishandling of Exceptional Conditions* del OWASP Top 10:2025.

### No hardcodear secretos

Un **secreto hardcodeado** (*hardcoded secret*, escrito directamente en el código) queda en el historial de Git para siempre, en cada clon y en cada fork.

=== "Vulnerable"

    ```python
    DB_PASSWORD = "S3cr3t0-Pr0d!"
    s3 = boto3.client("s3", aws_access_key_id="AKIA...", aws_secret_access_key="...")
    ```

=== "Seguro"

    ```python
    import os
    DB_PASSWORD = os.environ["DB_PASSWORD"]   # inyectada desde el gestor de secretos
    s3 = boto3.client("s3")                  # credenciales temporales del rol (IAM role, OIDC)
    ```

Los secretos viven en un gestor de secretos (Secrets Manager, Key Vault, Secret Manager; ver [Seguridad base en la nube](../../cloud/identidad-y-seguridad/seguridad-base.md)) y, siempre que se pueda, se sustituyen por **identidades sin secreto**: roles, Managed identities, service accounts u OIDC. Ver [Secretos e identidades](../identidades-y-pipeline/secretos-identidades.md).

## SAST

!!! tip "Escaneos en detalle"
    Herramientas, ejecución en local y en CI, SARIF, umbrales y gestión de hallazgos: [SAST](../escaneos/sast.md).

El **SAST** analiza el código fuente (o el bytecode) **sin ejecutarlo** y busca patrones que suelen ser vulnerables: inyecciones, deserialización insegura, criptografía débil, rutas construidas con datos del usuario, etc. Los motores más avanzados hacen **taint analysis** (análisis de flujo de datos contaminados): siguen un dato desde una **source** (fuente: la petición HTTP) hasta un **sink** (destino peligroso: la consulta SQL) y avisan si no pasa por una validación.

| Lo que el SAST hace bien | Sus límites |
| --- | --- |
| Revisa el 100 % del código en minutos | **Falsos positivos** (*false positives*): avisa de cosas que no son explotables |
| Señala la línea exacta del problema | **Falsos negativos**: no ve fallos de lógica de negocio ni de autorización |
| Corre antes de que exista un entorno desplegado | No sabe nada de la configuración real (red, IAM, WAF) |
| Educa: el mensaje explica el riesgo | Necesita soporte para tu lenguaje y tu framework |

!!! tip "Cómo convivir con los falsos positivos"
    Empieza con un conjunto de reglas pequeño y de alta confianza, haz que el pipeline falle solo en hallazgos **nuevos** de severidad alta, y marca los falsos positivos en la herramienta (con una justificación) en lugar de desactivar reglas enteras. Si cada build muestra 300 avisos, el equipo deja de leerlos.

### Herramientas SAST

| Herramienta | Tipo | Punto fuerte |
| --- | --- | --- |
| **SonarQube** (SonarQube Server / SonarQube Cloud) | Plataforma de calidad y seguridad del código | **Quality gates** e historial por proyecto |
| **Semgrep** | Motor de reglas *open source* con reglas tipo código | Reglas propias fáciles de escribir |
| **CodeQL** | Motor de GitHub que consulta el código como una base de datos | Análisis de flujo de datos profundo, integrado en GitHub |

#### SonarQube y los quality gates

Un **quality gate** (umbral de calidad) es un conjunto de condiciones que el código debe cumplir para pasar, por ejemplo: "cero vulnerabilidades nuevas", "todos los *security hotspots* nuevos revisados" y "cobertura de pruebas del código nuevo ≥ 80 %". El enfoque recomendado es **Clean as You Code**: el gate se evalúa sobre el **código nuevo**, para que la deuda antigua no bloquee cada cambio. El pipeline consulta el resultado del gate y falla si no se cumple.

#### Semgrep: una regla de ejemplo

```yaml title=".semgrep/sql-injection.yml"
rules:
  - id: python-sql-con-fstring
    languages: [python]
    severity: ERROR
    message: >
      Consulta SQL construida con un f-string. Usa una consulta parametrizada:
      cur.execute("... WHERE id = %s", (valor,))
    pattern-either:
      - pattern: $CUR.execute(f"...")
      - pattern: $CUR.execute("..." % $X)
      - pattern: $CUR.execute("..." + $X)
```

```bash
semgrep scan --config .semgrep/ --config p/python --error
```

`p/python` es un conjunto de reglas del registro de Semgrep y `--error` hace que el comando termine con error si hay hallazgos (útil en CI).

#### CodeQL y code scanning en GitHub

**CodeQL** es el motor de **code scanning** de GitHub. Se puede activar con *default setup* (desde la configuración del repositorio, sin escribir YAML) o con *advanced setup* (un workflow propio). Es gratuito en repositorios públicos; en privados requiere **GitHub Code Security**.

```yaml title=".github/workflows/codeql.yml"
name: CodeQL
on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read
  security-events: write   # para subir los resultados a la pestaña Security

jobs:
  analyze:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        language: [python, javascript-typescript]
    steps:
      - uses: actions/checkout@v7
      - uses: github/codeql-action/init@v4
        with:
          languages: ${{ matrix.language }}
      - uses: github/codeql-action/analyze@v4
```

Los resultados aparecen como alertas en la pestaña **Security** y como comentarios en el *pull request*.

## Detección de secretos

!!! tip "Escaneos en detalle"
    Historial completo vs solo cambios, verificación de secretos, push protection, pipeline y gestión de hallazgos: [Secret scanning](../escaneos/secret-scanning.md).

| Herramienta | Qué hace |
| --- | --- |
| **gitleaks** | Busca secretos con expresiones regulares y entropía en el repositorio, en el historial de Git o en un directorio |
| **TruffleHog** | Además de detectar, puede **verificar** si el secreto sigue activo probándolo contra la API del proveedor |
| **GitHub secret scanning** | Escanea los repositorios en GitHub y avisa al proveedor del secreto (*partner program*) para que lo revoque |
| **Push protection** | Parte de GitHub secret scanning: **bloquea el push** si contiene un secreto reconocido |

```bash
gitleaks git -v                 # escanea todo el historial de Git del repositorio
gitleaks dir ./src              # escanea un directorio (sin mirar Git)
trufflehog git file://. --results=verified   # solo secretos que siguen activos
```

!!! info "Comandos de gitleaks"
    Desde la versión 8.19, gitleaks usa los subcomandos `git`, `dir` y `stdin`. Los antiguos `detect` y `protect` siguen funcionando pero están obsoletos, así que verás los dos estilos en tutoriales.

En GitHub, secret scanning y push protection están disponibles gratis en repositorios públicos; en privados forman parte de **GitHub Secret Protection**. Revisa las condiciones actuales en la documentación.

## Pre-commit hooks

Un **pre-commit hook** es un script que Git ejecuta antes de crear un commit; si falla, el commit no se crea. El framework **`pre-commit`** gestiona estos hooks con un archivo de configuración versionado en el repositorio, para que todo el equipo use los mismos.

```yaml title=".pre-commit-config.yaml"
# Las versiones (rev) son de ejemplo: actualízalas con `pre-commit autoupdate`
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: check-yaml
      - id: end-of-file-fixer
      - id: detect-private-key        # claves privadas (-----BEGIN ... PRIVATE KEY-----)
      - id: check-added-large-files

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.24.2
    hooks:
      - id: gitleaks

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.17.2
    hooks:
      - id: ruff-check                 # linter de Python (antes id: ruff)
```

```bash
pip install pre-commit
pre-commit install              # instala el hook en .git/hooks/pre-commit
pre-commit run --all-files      # ejecuta todos los hooks sobre todo el repositorio
pre-commit autoupdate           # actualiza cada `rev` a la última versión publicada
```

!!! warning "El pre-commit no sustituye al pipeline"
    Cualquiera puede saltarse los hooks locales con `git commit --no-verify` o no instalarlos nunca. Usa los hooks para dar retroalimentación rápida y **repite los mismos controles en CI**, donde no se pueden omitir. Ver [Integración continua](../../devops/ci-cd/integracion-continua.md).

## Si se filtra un secreto

!!! danger "Primero rotar, después limpiar"
    En cuanto un secreto llega a un repositorio remoto debes darlo por **comprometido**: pueden haberlo copiado bots que escanean GitHub en segundos. Borrar el commit no lo "des-filtra".

1. **Revocar y rotar** el secreto en el proveedor (desactivar la access key, regenerar el token, cambiar la contraseña) y desplegar el nuevo valor desde el gestor de secretos.
2. **Investigar** si se usó: revisa los logs de auditoría (CloudTrail, Activity Log, Cloud Audit Logs) desde el momento de la filtración. Ver [Detección y respuesta](../gobierno-y-respuesta/deteccion-respuesta.md).
3. **Limpiar el historial** con `git filter-repo` o BFG Repo-Cleaner, hacer *force push* y pedir a quien tenga clones que los vuelva a clonar. En GitHub, los commits antiguos pueden seguir accesibles por su SHA o en forks, por lo que puede hacer falta contactar al soporte.
4. **Prevenir** que se repita: añade gitleaks al pre-commit y al pipeline, activa push protection y, si se puede, sustituye el secreto por una identidad sin secreto (OIDC, roles).

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Dónde se guardan y cifran los secretos que no deben estar en el código | [Seguridad base en la nube](../../cloud/identidad-y-seguridad/seguridad-base.md), [IAM: AWS, Azure y GCP](../../cloud/identidad-y-seguridad/iam-comparativa.md) |
| DevOps (la automatización) | El pipeline y el flujo de *pull requests* donde corren SAST y secret scanning | [Integración continua](../../devops/ci-cd/integracion-continua.md), [Git y control de versiones](../../devops/fundamentos/git-control-versiones.md), [Pipeline CI/CD con GitHub Actions](../../devops/ci-cd/ci-cd-github-actions.md) |
| DevSecOps (la verificación) | Dependencias, escaneo en el pipeline y gestión de secretos | [Software supply chain](cadena-suministro.md), [Escaneo de seguridad en el pipeline](../escaneos/escaneo-en-pipeline.md), [SAST](../escaneos/sast.md), [Secret scanning](../escaneos/secret-scanning.md), [Secretos e identidades](../identidades-y-pipeline/secretos-identidades.md), [Fundamentos de DevSecOps](../fundamentos-devsecops.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 04: Flujo Git con ramas, pull requests y code review](../../laboratorios/devops/git-flujo-pull-request.md), [Lab 12: Escaneos de seguridad en el pipeline](../../laboratorios/devsecops/escaneos-en-pipeline.md) |

## Referencias

- [OWASP Secure Coding Practices (Developer Guide)](https://owasp.org/www-project-developer-guide/)
- [OWASP Cheat Sheet Series: SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [OWASP Cheat Sheet Series: Input Validation](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)
- [SonarQube: quality gates](https://docs.sonarsource.com/sonarqube-server/latest/quality-standards-administration/managing-quality-gates/introduction-to-quality-gates/)
- [Semgrep: escribir reglas](https://semgrep.dev/docs/writing-rules/overview)
- [Acerca del code scanning con CodeQL](https://docs.github.com/es/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning-with-codeql)
- [Acerca del secret scanning](https://docs.github.com/es/code-security/secret-scanning/introduction/about-secret-scanning)
- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [TruffleHog](https://github.com/trufflesecurity/trufflehog)
- [pre-commit](https://pre-commit.com/)
- [Eliminar datos confidenciales de un repositorio (GitHub)](https://docs.github.com/es/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
- [Guía de comandos de seguridad](../../recursos/comandos/seguridad.md)
