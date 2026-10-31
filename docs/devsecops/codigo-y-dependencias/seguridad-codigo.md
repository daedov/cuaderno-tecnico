---
tags:
  - seguridad
  - sast
  - secretos
  - ci-cd
---

# Seguridad del código

> Escribir código seguro desde el principio (validar entradas, consultas parametrizadas, errores sin fugas de información, secretos fuera del código) y usar pre-commit hooks como primera red. Las herramientas de escaneo están en la sección [Escaneos](../escaneos/escaneo-en-pipeline.md).

## ¿Qué es?

La seguridad del código es la parte más a la izquierda del **shift-left** (ver [Fundamentos de DevSecOps](../fundamentos-devsecops.md)). Tiene dos mitades:

- **Secure coding** (programación segura): hábitos y patrones que evitan las vulnerabilidades más comunes al escribir el código.
- **Verificación automática**: herramientas que revisan el código en el editor, en cada commit y en el pipeline de CI para detectar lo que se escapó.

| Control | Cuándo corre | Qué detecta | Herramientas |
| --- | --- | --- | --- |
| Pre-commit hooks | En tu máquina, antes del commit | Secretos, errores de formato y de lint | `pre-commit`, gitleaks |
| **SAST** (*Static Application Security Testing*, análisis estático) | En el *pull request* y en CI | Patrones de código vulnerable | SonarQube, Semgrep, CodeQL |
| Secret scanning | En el push, en CI y sobre el historial | Credenciales en el repositorio | gitleaks, TruffleHog, GitHub secret scanning |

!!! info "Los escaneos tienen su propia sección"
    Esta nota trata los hábitos de programación segura y el flujo de pre-commit. Herramientas, comandos, integración en CI, umbrales y gestión de hallazgos de cada escaneo: [SAST](../escaneos/sast.md) y [Secret scanning](../escaneos/secret-scanning.md); visión de conjunto en [Escaneo de seguridad en el pipeline](../escaneos/escaneo-en-pipeline.md).

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

Los secretos viven en un gestor de secretos (Secrets Manager, Key Vault, Secret Manager; ver [Seguridad de cifrado y secretos](../../cloud/seguridad/seguridad-cifrado-secretos.md)) y, siempre que se pueda, se sustituyen por **identidades sin secreto**: roles, Managed identities, service accounts u OIDC. Ver [Secretos e identidades](../identidades-y-pipeline/secretos-identidades.md).

## Escaneos sobre el código

Los hábitos anteriores se comprueban de forma automática con dos escaneos. Aquí solo ves qué atrapa cada uno en tu código; las herramientas, la ejecución en local y en CI, los umbrales y la gestión de hallazgos están en la sección de escaneos.

### SAST

El **SAST** analiza el código fuente (o el bytecode) **sin ejecutarlo** y busca justo los patrones que esta nota enseña a evitar: inyecciones (SQL construida con f-strings, comandos con `shell=True`), path traversal, deserialización insegura, criptografía débil. Los motores más avanzados hacen **taint analysis** (análisis de flujo de datos contaminados): siguen un dato desde una **source** (fuente: la petición HTTP) hasta un **sink** (destino peligroso: la consulta SQL) y avisan si no pasa por una validación. No ve fallos de lógica de negocio ni de autorización, no sabe nada de la configuración real (red, IAM, WAF) y da **falsos positivos** (*false positives*).

Dos ideas que unen el SAST con la programación segura:

- Convierte los errores que ya cometió tu equipo en **reglas propias**, con un mensaje que explique el riesgo y la corrección (por ejemplo, una regla de Semgrep que marque `cur.execute(f"...")` y proponga la [consulta parametrizada](#usar-consultas-parametrizadas)).
- Evalúa el **quality gate** (umbral de calidad: por ejemplo, "cero vulnerabilidades nuevas" y "todos los *security hotspots* nuevos revisados") solo sobre el **código nuevo**, el enfoque *Clean as You Code* de SonarQube, para que la deuda antigua no bloquee cada cambio.

Detalle: [SAST](../escaneos/sast.md).

### Detección de secretos

El **secret scanning** (escaneo de secretos) busca credenciales (claves de API, tokens, claves privadas) en los archivos y en **todo el historial de Git**: un secreto borrado en el último commit sigue en los anteriores. Es la red de seguridad del hábito [No hardcodear secretos](#no-hardcodear-secretos) y corre en capas: pre-commit, **push protection** (bloquea el push que contiene un secreto reconocido), pipeline y escaneo periódico del historial.

Detalle (gitleaks, TruffleHog, GitHub secret scanning, baselines y falsos positivos): [Secret scanning](../escaneos/secret-scanning.md).

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
4. **Prevenir** que se repita: añade gitleaks al pre-commit y al pipeline, activa push protection (ver [Secret scanning](../escaneos/secret-scanning.md)) y, si se puede, sustituye el secreto por una identidad sin secreto (OIDC, roles).

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Dónde se guardan y cifran los secretos que no deben estar en el código | [Seguridad de cifrado y secretos](../../cloud/seguridad/seguridad-cifrado-secretos.md), [IAM: AWS, Azure y GCP](../../cloud/fundamentos/iam-comparativa.md) |
| DevOps (la automatización) | El pipeline y el flujo de *pull requests* donde corren SAST y secret scanning | [Integración continua](../../devops/ci-cd/integracion-continua.md), [Git y control de versiones](../../devops/fundamentos/git-control-versiones.md) |
| DevSecOps (la verificación) | Herramientas de escaneo del código (SAST, secret scanning), dependencias y gestión de secretos | [Software supply chain](cadena-suministro.md), [Escaneo de seguridad en el pipeline](../escaneos/escaneo-en-pipeline.md), [SAST](../escaneos/sast.md), [Secret scanning](../escaneos/secret-scanning.md), [Secretos e identidades](../identidades-y-pipeline/secretos-identidades.md), [Fundamentos de DevSecOps](../fundamentos-devsecops.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 04: Flujo Git con ramas, pull requests y code review](../../laboratorios/devops/git-flujo-pull-request.md), [Lab 12: Escaneos de seguridad en el pipeline](../../laboratorios/devsecops/escaneos-en-pipeline.md) |

## Referencias

- [OWASP Secure Coding Practices (Developer Guide)](https://owasp.org/www-project-developer-guide/)
- [OWASP Cheat Sheet Series: SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [OWASP Cheat Sheet Series: Input Validation](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html)
- [SonarQube: quality gates](https://docs.sonarsource.com/sonarqube-server/latest/quality-standards-administration/managing-quality-gates/introduction-to-quality-gates/)
- [Semgrep: escribir reglas](https://semgrep.dev/docs/writing-rules/overview)
- [pre-commit](https://pre-commit.com/)
- [Eliminar datos confidenciales de un repositorio (GitHub)](https://docs.github.com/es/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
- [Guía de comandos de seguridad](../../recursos/comandos/seguridad.md)
