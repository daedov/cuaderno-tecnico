---
tags: [devsecops, escaneo, secretos]
---

# Secret scanning

> Detectar credenciales en el código y en el historial de Git antes de que lleguen al remoto, y saber qué hacer cuando ya llegaron.

!!! info "Dónde encaja"
    El **secret scanning** (escaneo de secretos) corre en **varias capas**: en tu máquina (pre-commit), en el **push** (push protection), en el **pipeline** y como escaneo periódico del **historial completo**. Analiza el contenido de los commits, archivos, a veces issues, PR y wikis, buscando claves de API, tokens, contraseñas y claves privadas. La parte de hábitos (no hardcodear, pre-commit) y el procedimiento ante una filtración están en [Seguridad del código](../codigo-y-dependencias/seguridad-codigo.md#deteccion-de-secretos); dónde deben vivir los secretos, en [Secretos e identidades](../identidades-y-pipeline/secretos-identidades.md). Visión de conjunto: [Escaneo de seguridad en el pipeline](escaneo-en-pipeline.md).

## ¿Qué detecta?

| Detecta | No detecta |
| --- | --- |
| Tokens con formato reconocible: AWS access keys (`AKIA…`), tokens de GitHub (`ghp_…`, `github_pat_…`), claves de Slack, Stripe, Google API… | Secretos sin formato distintivo con baja entropía (`password = "verano2026"`), salvo reglas genéricas o IA |
| Claves privadas (`-----BEGIN … PRIVATE KEY-----`) y certificados | Secretos cifrados, o fuera del alcance del escaneo (variables del CI, gestores de secretos, imágenes no escaneadas) |
| Cadenas de conexión con credenciales (`postgres://user:pass@…`) | Si una credencial **sigue activa**, salvo herramientas con verificación (TruffleHog, validity checks de GitHub) |
| Cadenas de alta **entropía** cerca de palabras como `secret`, `token`, `key` | Secretos que ya se usaron: para eso están los logs de auditoría ([Detección y respuesta](../gobierno-y-respuesta/deteccion-respuesta.md)) |
| Secretos en **commits antiguos** aunque ya no estén en la última versión | Datos personales u otra información sensible que no sea una credencial |

## Cómo funciona

1. **Patrones** (*regex*) específicos de cada proveedor: muchos tokens modernos tienen prefijo y checksum (`ghp_`, `glpat-`, `xoxb-`), lo que da muy pocos falsos positivos.
2. **Entropía**: mide lo "aleatoria" que es una cadena (entropía de Shannon). Una clave generada tiene entropía alta; una palabra, baja. Se usa para reglas genéricas y para descartar valores de ejemplo.
3. **Palabras clave** y contexto: la cadena aparece junto a `password`, `api_key`, `secret`…
4. **Allowlists**: rutas, valores y reglas que se ignoran (archivos de test, ejemplos documentados).
5. **Verificación** (solo algunas herramientas): prueba la credencial contra la API del proveedor (una llamada de solo lectura, como `sts get-caller-identity` en AWS) para saber si está activa.

```mermaid
flowchart LR
    A[Commits / archivos] --> B[Patrones por proveedor<br/>+ entropía + keywords]
    B --> C{¿En allowlist<br/>o baseline?}
    C -- Sí --> X[Ignorado]
    C -- No --> D[Candidato]
    D --> E{¿Verificación?}
    E -- Activo --> F[Crítico: rotar ya]
    E -- Inactivo / desconocido --> G[Revisar]
```

### Historial completo vs solo cambios

| Modo | Qué recorre | Cuándo |
| --- | --- | --- |
| **Historial completo** | Todos los commits de todas las ramas | Al adoptar la herramienta, de forma periódica (semanal) y tras importar un repo |
| **Solo cambios** (diff) | Los commits nuevos del push o del PR | En pre-commit, push protection y en cada PR: rápido y sin ruido histórico |
| **Directorio** (sin Git) | Los archivos tal como están | Artefactos, imágenes descomprimidas, carpetas que no son repos |

Un secreto borrado en el último commit **sigue en el historial**: por eso hace falta el escaneo completo al menos una vez.

## Herramientas

| Herramienta | Tipo | Targets | Notas |
| --- | --- | --- | --- |
| **gitleaks** | *Open source* (MIT) | Repos Git, directorios, stdin | Rápido, configurable en TOML, baseline y `.gitleaksignore`. La action oficial necesita licencia gratuita para repos de organizaciones |
| **TruffleHog** | *Open source* (AGPL-3.0) + versión Enterprise | Git, GitHub/GitLab (orgs completas), S3, GCS, Docker, filesystem… | **Verifica** cientos de tipos de credenciales contra la API del proveedor |
| **detect-secrets** | *Open source* (Yelp) | Archivos del repo | Orientado a **baseline**: registra los secretos existentes y solo bloquea los nuevos; `audit` interactivo para marcarlos |
| **GitHub secret scanning** | Nativa de GitHub | Repos, historial, issues, PR, wikis | Patrones de socios, *partner program* (avisa al proveedor), validity checks, patrones personalizados. Gratis en repos públicos; en privados, **GitHub Secret Protection** |
| **Push protection** (GitHub) | Nativa de GitHub | Cada push (y la web/API) | **Bloquea** el push con un secreto reconocido; el *bypass* exige un motivo y queda registrado |
| **GitLab secret detection** | Nativa de GitLab | Pipeline (todos los planes); *secret push protection* (Ultimate) | Basada en gitleaks; plantilla `Jobs/Secret-Detection.gitlab-ci.yml` |
| Proveedores cloud | Nativa (reacción) | Credenciales propias filtradas en sitios públicos | Como socios de GitHub, AWS, Microsoft y Google reciben el aviso y pueden notificarte, restringir o desactivar la credencial. No sustituye a tu propio escaneo |

## Ejecutarlo en local

=== "gitleaks"

    ```bash
    gitleaks git -v                                   # todo el historial del repo actual
    gitleaks git -v --log-opts="origin/main..HEAD"    # solo los commits de tu rama
    gitleaks dir ./dist                               # un directorio, sin Git
    gitleaks git --redact --report-format sarif --report-path gitleaks.sarif
    ```

    Desde la versión 8.19 los subcomandos son `git`, `dir` y `stdin`; `detect` y `protect` siguen funcionando pero están obsoletos. Salida abreviada de ejemplo (con `--redact`):

    ```text
    Finding:     aws_secret_access_key = REDACTED
    Secret:      REDACTED
    RuleID:      generic-api-key
    Entropy:     4.7
    File:        config/settings.py
    Line:        8
    Commit:      4e1f2a9...
    Fingerprint: 4e1f2a9...:config/settings.py:generic-api-key:8

    INF 214 commits scanned.
    WRN leaks found: 1
    ```

=== "TruffleHog"

    ```bash
    trufflehog git file://. --results=verified,unknown      # verificados o no verificables
    trufflehog git file://. --since-commit main --branch HEAD --fail
    trufflehog filesystem ./dist --results=verified
    ```

    `--fail` devuelve el código de salida 183 si encuentra resultados, útil en CI. TruffleHog hace llamadas a las APIs de los proveedores para verificar: ejecútalo solo sobre tus propios repositorios.

=== "detect-secrets"

    ```bash
    pipx install detect-secrets
    detect-secrets scan > .secrets.baseline          # inventario inicial (se versiona)
    detect-secrets audit .secrets.baseline           # marcar cada hallazgo: real o falso positivo
    detect-secrets scan --baseline .secrets.baseline # actualizar la baseline
    ```

    Como hook de `pre-commit` usa `detect-secrets-hook --baseline .secrets.baseline`, que solo falla con secretos **nuevos**.

## Integrarlo en el pipeline

### GitHub Actions

=== "TruffleHog"

    ```yaml title=".github/workflows/secrets.yml"
    name: secrets
    on:
      pull_request:
      push:
        branches: [main]

    permissions: {}

    jobs:
      trufflehog:
        runs-on: ubuntu-latest
        permissions:
          contents: read
        steps:
          - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
            with:
              fetch-depth: 0              # necesita el historial para comparar base y head
              persist-credentials: false
          - uses: trufflesecurity/trufflehog@31ce31ee1abbcc7dc8eee5764c17121c3044c8b2 # v3.99.7
            with:
              extra_args: --results=verified,unknown
    ```

    En `pull_request` la action escanea solo los commits del PR; en `push`, los commits del push.

=== "gitleaks"

    ```yaml title=".github/workflows/secrets.yml (job)"
      gitleaks:
        runs-on: ubuntu-latest
        permissions:
          contents: read
          pull-requests: write          # comenta en el PR la línea afectada
        steps:
          - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
            with:
              fetch-depth: 0
              persist-credentials: false
          - uses: gitleaks/gitleaks-action@e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e # v3.0.0
            env:
              GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
              GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}   # solo para repos de organizaciones
    ```

    Si prefieres no usar la action (por la licencia), instala el binario de gitleaks en el job con una versión fija y verifica su checksum.

Además, activa en la configuración del repositorio u organización (no es YAML):

- **Secret scanning** y **push protection** (*Settings → Advanced Security*). Con push protection, el desarrollador recibe el bloqueo en su `git push` y debe quitar el secreto o justificar el *bypass* (falso positivo, usado en tests, se corregirá después).
- **Delegated bypass**: el *bypass* requiere aprobación de un equipo concreto.
- **Validity checks**: GitHub comprueba con el proveedor si el secreto sigue activo.
- **Custom patterns** para tus propios formatos de token interno.

### GitLab CI

```yaml title=".gitlab-ci.yml"
include:
  - template: Jobs/Secret-Detection.gitlab-ci.yml

secret_detection:
  variables:
    SECRET_DETECTION_HISTORIC_SCAN: "true"   # solo en un pipeline programado: recorre todo el historial
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
```

Sin esa variable, el job revisa los commits del *merge request* o del push. El ejemplo de `rules` es para un pipeline programado aparte; en tu pipeline normal deja la plantilla tal cual.

## Umbrales y cuándo fallar el build

Aquí no hay severidades como en SAST o SCA: **cualquier secreto real es crítico**. Lo que se gradúa es **dónde** se bloquea:

| Capa | Acción ante un hallazgo |
| --- | --- |
| Pre-commit | Bloquear el commit (se puede saltar con `--no-verify`, por eso no basta) |
| Push protection | Bloquear el push; *bypass* solo con motivo registrado |
| PR / pipeline | **Fallar siempre** en hallazgos nuevos |
| Escaneo programado del historial | No bloquea; abre incidencias para rotar y limpiar |

Para no bloquear cada PR por secretos antiguos ya rotados, usa **baseline**:

```bash
gitleaks git --report-path gitleaks-baseline.json           # una vez, tras rotar todo
gitleaks git --baseline-path gitleaks-baseline.json -v      # después: solo hallazgos nuevos
```

## Gestión de hallazgos

!!! danger "Rotar primero, investigar después, limpiar al final"
    Un secreto que llegó al remoto está **comprometido**, aunque el repo sea privado y lo borres en el siguiente commit. El orden es: **revocar/rotar** la credencial, **investigar** si se usó en los logs de auditoría y solo después **limpiar el historial**. Los pasos detallados están en [Si se filtra un secreto](../codigo-y-dependencias/seguridad-codigo.md#si-se-filtra-un-secreto) y el playbook completo en [Ejemplo: access key de AWS filtrada en GitHub](../gobierno-y-respuesta/deteccion-respuesta.md#ejemplo-access-key-de-aws-filtrada-en-github).

Si el secreto **no** llegó al remoto (lo frenó el pre-commit o push protection): quítalo del commit (`git commit --amend` o `git reset` y rehacer el commit), muévelo al gestor de secretos y, si hay duda de que se copió a otro sitio, rótalo igual.

Falsos positivos y excepciones:

```toml title=".gitleaks.toml"
[extend]
useDefault = true                       # parte de las reglas por defecto

[[allowlists]]
description = "Claves de ejemplo de la documentación (revisado 2026-10, revisar 2027-04)"
paths = ['''docs/ejemplos/.*''']
regexes = ['''AKIAIOSFODNN7EXAMPLE''']
```

```python
API_KEY_TEST = "test_1234567890abcdef"  # gitleaks:allow  (valor de test sin permisos)
TOKEN_EJEMPLO = "abc123"                # pragma: allowlist secret  (detect-secrets)
```

- `.gitleaksignore` admite el **fingerprint** de un hallazgo concreto (`commit:archivo:regla:línea`), útil para secretos antiguos ya rotados que siguen en el historial.
- En GitHub, cierra la alerta como *revoked*, *false positive* o *used in tests*; *revoked* debe ser el motivo habitual.
- Ninguna de estas supresiones caduca sola: anota la fecha de revisión. Los plazos y el registro de excepciones siguen el proceso de [vulnerability management](../gobierno-y-respuesta/deteccion-respuesta.md#excepciones-y-riesgo-aceptado).

## Buenas prácticas y errores comunes

- **Escaneo en capas**: pre-commit (rápido) + push protection (no se puede olvidar instalar) + pipeline (no se puede saltar) + historial completo programado.
- **Haz un escaneo del historial completo** al adoptar la herramienta y rota todo lo que aparezca, aunque parezca antiguo.
- **Prioriza los verificados** (TruffleHog, validity checks): un secreto activo es una emergencia; uno inactivo, limpieza.
- **Elimina la causa**: sustituye las claves estáticas por identidades sin secreto (OIDC, roles, Managed identities); ver [Secretos e identidades](../identidades-y-pipeline/secretos-identidades.md).
- **Escanea también lo que no es código**: logs de CI, artefactos e imágenes (`gitleaks dir`, `trufflehog docker`).
- Error común: borrar el secreto en un commit nuevo y dar el problema por resuelto, sin rotarlo.
- Error común: escanear en CI con `fetch-depth: 1` (el valor por defecto de `actions/checkout`): solo se ve el último commit.
- Error común: imprimir el secreto en los logs del pipeline al reportarlo; usa `--redact`.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Gestores de secretos, KMS y logs de auditoría para investigar el uso de una credencial filtrada | [Seguridad base en la nube](../../cloud/identidad-y-seguridad/seguridad-base.md), [IAM: AWS, Azure y GCP](../../cloud/identidad-y-seguridad/iam-comparativa.md) |
| DevOps (la automatización) | Hooks, flujo de PR y pipeline donde se insertan los escaneos | [Git y control de versiones](../../devops/fundamentos/git-control-versiones.md), [Integración continua](../../devops/ci-cd/integracion-continua.md) |
| DevSecOps (la verificación) | Prevención, respuesta a la filtración y los otros escaneos | [Seguridad del código](../codigo-y-dependencias/seguridad-codigo.md), [Secretos e identidades](../identidades-y-pipeline/secretos-identidades.md), [Detección y respuesta](../gobierno-y-respuesta/deteccion-respuesta.md), [Escaneo de seguridad en el pipeline](escaneo-en-pipeline.md), [SAST](sast.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 12: Escaneos de seguridad en el pipeline](../../laboratorios/devsecops/escaneos-en-pipeline.md) |

## Referencias

- [Gitleaks](https://github.com/gitleaks/gitleaks)
- [gitleaks-action](https://github.com/gitleaks/gitleaks-action)
- [TruffleHog](https://github.com/trufflesecurity/trufflehog)
- [detect-secrets](https://github.com/Yelp/detect-secrets)
- [GitHub: acerca del secret scanning](https://docs.github.com/es/code-security/secret-scanning/introduction/about-secret-scanning)
- [GitHub: acerca de push protection](https://docs.github.com/es/code-security/secret-scanning/introduction/about-push-protection)
- [GitHub: patrones de secret scanning compatibles](https://docs.github.com/es/code-security/secret-scanning/introduction/supported-secret-scanning-patterns)
- [GitLab: pipeline secret detection](https://docs.gitlab.com/user/application_security/secret_detection/pipeline/)
- [GitLab: secret push protection](https://docs.gitlab.com/user/application_security/secret_detection/secret_push_protection/)
- [Eliminar datos confidenciales de un repositorio (GitHub)](https://docs.github.com/es/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
