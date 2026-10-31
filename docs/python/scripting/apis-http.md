---
tags:
  - python
  - scripting
  - automatizacion
  - apis
  - github
---

# APIs y HTTP

> Hablar con APIs REST desde Python con `requests`: métodos, headers, tokens desde variables de entorno, JSON, timeouts, reintentos con backoff, paginación y códigos de estado, con la API de GitHub como ejemplo.

!!! info "Antes de leer"
    Esta nota asume lo visto en [Sistema y procesos](sistema-procesos.md) y en [Scripts de línea de comandos](scripts-cli.md). Para el protocolo en sí (métodos, códigos, headers, TLS) ver [Protocolos de aplicación](../../networking/intermedio/protocolos-aplicacion.md).

## ¿Qué es?

Casi todo lo que automatizas expone una **API REST** (*Representational State Transfer*) sobre HTTP: GitHub y GitLab, Grafana, Argo CD, PagerDuty, Slack, la propia API de Kubernetes y las de los proveedores cloud. Un script que habla con una API hace siempre lo mismo: **construir la petición** (método, URL, headers, cuerpo), **enviarla**, **revisar el código de estado** y **leer el JSON** de la respuesta.

```mermaid
sequenceDiagram
    participant S as Script
    participant A as API
    S->>A: GET /orgs/mi-org/repos?per_page=100<br/>Authorization: Bearer ***
    A-->>S: 200 OK + JSON (página 1)<br/>Link: <...page=2>; rel="next"
    S->>A: GET ...page=2
    A-->>S: 503 Service Unavailable
    Note over S: espera (backoff) y reintenta
    S->>A: GET ...page=2
    A-->>S: 200 OK + JSON (última página)
```

La librería de referencia es **`requests`** (`pip install requests`). La estándar `urllib.request` también funciona, pero es mucho más incómoda.

!!! note "httpx"
    **httpx** tiene una API casi igual a la de `requests` y añade soporte **async** y HTTP/2; además, a diferencia de `requests`, aplica un timeout por defecto. Si ya la usa tu proyecto, todo lo de esta nota se traduce casi línea por línea.

## Peticiones básicas

```python
import requests

r = requests.get(
    "https://api.github.com/repos/python/cpython",
    headers={"Accept": "application/vnd.github+json"},
    timeout=10,
)
print(r.status_code)              # 200
print(r.headers["Content-Type"])  # application/json; charset=utf-8
datos = r.json()                  # cuerpo JSON -> dict
print(datos["default_branch"])    # main
```

| Necesitas | Cómo |
| --- | --- |
| Parámetros de query (`?per_page=100&page=2`) | `params={"per_page": 100, "page": 2}` (los codifica por ti) |
| Enviar JSON | `json={"title": "..."}` (pone `Content-Type: application/json`) |
| Enviar un formulario | `data={"campo": "valor"}` |
| Headers | `headers={"Accept": "..."}` |
| Leer JSON | `r.json()` |
| Leer texto / bytes | `r.text` / `r.content` |
| ¿Fue 2xx? | `r.ok` o, mejor, `r.raise_for_status()` |
| URL final (con params) | `r.url` |

```python
r = requests.post(
    "https://api.ejemplo.com/v1/despliegues",
    json={"servicio": "api", "version": "1.4.0"},
    headers={"Authorization": f"Bearer {token}"},
    timeout=10,
)
print(r.status_code)   # 201 Created
```

## Autenticación con tokens

Las APIs suelen autenticar con un **token** en el header `Authorization`, normalmente con el esquema **Bearer**. El token **nunca va en el código**: se lee de una variable de entorno que inyecta el pipeline o el gestor de secretos.

```python
import os
import sys

token = os.environ.get("GITHUB_TOKEN")
if not token:
    sys.exit("Define la variable de entorno GITHUB_TOKEN")

headers = {"Authorization": f"Bearer {token}"}
```

- Pide al token **solo los permisos que necesita** el script (en GitHub, un *fine-grained personal access token* limitado a ciertos repositorios y permisos de solo lectura; dentro de GitHub Actions, el `GITHUB_TOKEN` del workflow con `permissions:` mínimos).
- No imprimas el token ni la cabecera, y cuidado con `logging` en nivel `DEBUG` de librerías que registren peticiones completas.
- Si la API admite **OIDC** o identidades de la plataforma (como las nubes), prefiérelas a un token de larga duración. Ver [Secretos e identidades](../../devsecops/identidades-y-pipeline/secretos-identidades.md).

## Session

Una **`requests.Session`** reutiliza la conexión TCP/TLS entre peticiones (más rápido) y guarda headers comunes, así no los repites en cada llamada:

```python
sesion = requests.Session()
sesion.headers.update({
    "Authorization": f"Bearer {token}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2026-03-10",
})
r = sesion.get("https://api.github.com/user", timeout=10)
```

`X-GitHub-Api-Version` fija la versión de la API REST de GitHub para que un cambio de versión no rompa el script. Revisa en la documentación cuál es la vigente.

## Timeouts

!!! danger "Sin `timeout`, `requests` puede esperar para siempre"
    `requests` **no tiene timeout por defecto**: si el servidor no responde, el script (y el job de CI) se queda colgado. Pasa siempre `timeout=`. Con una tupla `timeout=(5, 30)` defines por separado el tiempo para **conectar** (5 s) y para **leer** la respuesta (30 s).

## Códigos de estado y errores

`raise_for_status()` lanza `requests.HTTPError` si el código es 4xx o 5xx. Junto con los errores de red, conviene tratar cada familia de forma distinta:

| Situación | Qué ves | Qué hacer |
| --- | --- | --- |
| 2xx | `r.ok` es `True` | Leer la respuesta |
| 400 / 422 | Petición inválida | Error del script: no reintentar, revisar el cuerpo del error |
| 401 | Token inválido o ausente | Revisar la variable de entorno; no reintentar |
| 403 | Sin permiso, o *rate limit* agotado (en GitHub, con `x-ratelimit-remaining: 0`) | Revisar permisos del token, o esperar al `x-ratelimit-reset` |
| 404 | No existe, **o no tienes permiso para verlo** (muchas APIs ocultan así los recursos privados) | Revisar nombre y permisos |
| 429 | *Rate limiting* | Esperar lo que diga `Retry-After` y reintentar |
| 500, 502, 503, 504 | Error temporal del servidor o del *proxy* | Reintentar con backoff |
| `requests.ConnectionError` | DNS, conexión rechazada, TLS | Reintentar unas veces; si persiste, revisar red (ver [Troubleshooting de red](../../networking/avanzado/troubleshooting-red.md)) |
| `requests.Timeout` | Se superó el timeout | Reintentar con backoff |

```python
try:
    r = sesion.get(url, timeout=(5, 30))
    r.raise_for_status()
except requests.HTTPError as e:
    print(f"Error {e.response.status_code}: {e.response.json().get('message')}")
except requests.RequestException as e:      # clase base: red, timeout, URL inválida...
    print(f"Error de red: {e}")
```

## Reintentos con backoff

Los errores temporales (429, 5xx, cortes de red) se resuelven reintentando, pero no de inmediato: con **exponential backoff** (espera exponencial: 1 s, 2 s, 4 s…) y algo de **jitter** (variación aleatoria) para que muchos clientes no reintenten a la vez. `requests` lo trae a través de `urllib3`:

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util import Retry


def crear_sesion(token: str) -> requests.Session:
    sesion = requests.Session()
    sesion.headers.update({"Authorization": f"Bearer {token}"})
    reintentos = Retry(
        total=5,                                        # máximo de reintentos
        backoff_factor=1,                               # esperas exponenciales: ~1, 2, 4, 8… s
        status_forcelist=[429, 500, 502, 503, 504],     # códigos que se reintentan
        allowed_methods=["GET", "HEAD"],                # solo métodos seguros de repetir
        respect_retry_after_header=True,                # obedece Retry-After (por defecto ya es True)
    )
    sesion.mount("https://", HTTPAdapter(max_retries=reintentos))
    return sesion
```

!!! warning "Reintentar solo lo idempotente"
    Una operación es **idempotente** si repetirla deja el mismo resultado (`GET`, `PUT`, `DELETE`). Reintentar un `POST` que crea algo puede crearlo dos veces si la primera petición sí llegó pero se perdió la respuesta. Por eso `Retry` excluye `POST` por defecto. Si la API lo soporta, usa una **idempotency key** (clave de idempotencia) en un header para que el servidor ignore los duplicados.

Si se agotan los reintentos por código de estado, `requests` lanza `requests.exceptions.RetryError` (una subclase de `RequestException`).

## Paginación

Las APIs devuelven las listas largas **por páginas**. Hay tres estilos comunes:

| Estilo | Cómo se ve | Ejemplos |
| --- | --- | --- |
| Header `Link` | `Link: <...?page=2>; rel="next"` | GitHub |
| Token / cursor en el cuerpo | `{"items": [...], "nextPageToken": "abc"}` | Google Cloud, muchas APIs modernas |
| Offset / page | `?page=3&per_page=100` hasta que llega una página vacía | APIs sencillas |

`requests` ya interpreta el header `Link` en **`r.links`**, así que paginar en GitHub es seguir `next` hasta que no exista. Un **generador** (`yield`) entrega los elementos a medida que llegan:

```python
from collections.abc import Iterator

import requests


def paginar(sesion: requests.Session, url: str, params: dict | None = None) -> Iterator[dict]:
    siguiente: str | None = url
    while siguiente:
        r = sesion.get(siguiente, params=params, timeout=(5, 30))
        r.raise_for_status()
        yield from r.json()
        siguiente = r.links.get("next", {}).get("url")
        params = None                  # la URL de "next" ya incluye los parámetros


repos = list(paginar(sesion, "https://api.github.com/orgs/mi-org/repos", {"per_page": 100}))
```

!!! tip "Pide páginas grandes y respeta el rate limit"
    Usa el tamaño máximo de página que permita la API (`per_page=100` en GitHub) para hacer menos llamadas. GitHub informa del límite en los headers `x-ratelimit-limit`, `x-ratelimit-remaining` y `x-ratelimit-reset`; un script que recorre muchas organizaciones debería mirarlos.

## Mini-ejercicio: repositorios inactivos en GitHub

Escribe `repos_inactivos.py ORG [--dias N]` que, con un token de `GITHUB_TOKEN`:

1. Recorra **todas** las páginas de `GET /orgs/{org}/repos` (`per_page=100`), con reintentos ante 429 y 5xx.
2. Muestre los repositorios **no archivados** cuyo último push (`pushed_at`) es anterior a N días (por defecto 180), ordenados del más antiguo al más reciente.
3. Salga con 2 si falta el token y con 1 ante errores HTTP o de red, mostrando el mensaje de la API.

Es el tipo de reporte que alimenta una revisión de gobernanza: repositorios abandonados con dependencias y secretos que nadie mantiene.

??? success "Solución"

    ```python title="repos_inactivos.py"
    #!/usr/bin/env python3
    """Lista los repositorios no archivados de una organización sin pushes recientes."""
    import argparse
    import os
    import sys
    from collections.abc import Iterator
    from datetime import datetime, timedelta, timezone

    import requests
    from requests.adapters import HTTPAdapter
    from urllib3.util import Retry

    API = os.environ.get("GITHUB_API_URL", "https://api.github.com")


    def crear_sesion(token: str) -> requests.Session:
        sesion = requests.Session()
        sesion.headers.update({
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2026-03-10",
        })
        reintentos = Retry(total=5, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504],
                           allowed_methods=["GET"])
        sesion.mount("https://", HTTPAdapter(max_retries=reintentos))
        return sesion


    def repos_de(sesion: requests.Session, org: str) -> Iterator[dict]:
        url: str | None = f"{API}/orgs/{org}/repos"
        params: dict | None = {"per_page": 100, "type": "all"}
        while url:
            r = sesion.get(url, params=params, timeout=(5, 30))
            r.raise_for_status()
            yield from r.json()
            url = r.links.get("next", {}).get("url")
            params = None


    def main() -> int:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("org")
        parser.add_argument("--dias", type=int, default=180)
        args = parser.parse_args()

        token = os.environ.get("GITHUB_TOKEN")
        if not token:
            print("Define la variable de entorno GITHUB_TOKEN", file=sys.stderr)
            return 2

        limite = datetime.now(timezone.utc) - timedelta(days=args.dias)
        try:
            inactivos = [
                repo for repo in repos_de(crear_sesion(token), args.org)
                if not repo["archived"]
                and repo["pushed_at"]
                and datetime.fromisoformat(repo["pushed_at"]) < limite
            ]
        except requests.HTTPError as e:
            print(f"Error {e.response.status_code}: {e.response.json().get('message')}", file=sys.stderr)
            return 1
        except requests.RequestException as e:
            print(f"Error de red: {e}", file=sys.stderr)
            return 1

        for repo in sorted(inactivos, key=lambda r: r["pushed_at"]):
            print(f"{repo['pushed_at'][:10]}  {repo['name']}  ({repo['visibility']})")
        print(f"{len(inactivos)} repositorios sin pushes en {args.dias} días", file=sys.stderr)
        return 0


    if __name__ == "__main__":
        sys.exit(main())
    ```

    ```text
    $ GITHUB_TOKEN=... ./repos_inactivos.py mi-org --dias 365
    2025-02-01  repo-1  (private)
    2025-03-01  repo-2  (private)
    2025-06-01  repo-5  (private)
    3 repositorios sin pushes en 365 días

    $ GITHUB_TOKEN=token-caducado ./repos_inactivos.py mi-org; echo "exit=$?"
    Error 401: Bad credentials
    exit=1
    ```

    Detalles que importan:

    - `datetime.fromisoformat` acepta el sufijo `Z` desde Python 3.11, y compara bien porque ambas fechas tienen zona horaria (UTC).
    - `pushed_at` puede ser `null` en un repositorio vacío; por eso se comprueba antes de convertirlo.
    - `GITHUB_API_URL` permite apuntar a GitHub Enterprise Server (o a un servidor de pruebas local) sin tocar el código. En GitHub Actions esa variable ya existe.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Networking (la base) | HTTP, códigos de estado, headers y TLS que hay debajo de cada petición | [Protocolos de aplicación](../../networking/intermedio/protocolos-aplicacion.md), [Troubleshooting de red](../../networking/avanzado/troubleshooting-red.md) |
| Cloud (el control) | Diseño de APIs (paginación, idempotencia, errores) desde el lado de quien las construye | [Integración y APIs](../../cloud/arquitectura/integracion-apis.md) |
| DevOps (la automatización) | Integraciones del pipeline con GitHub, Argo CD, Grafana o PagerDuty | [Integración continua](../../devops/ci-cd/integracion-continua.md) |
| DevSecOps (la verificación) | Tokens con permisos mínimos, fuera del código y de los logs; pruebas de seguridad de APIs | [Secretos e identidades](../../devsecops/identidades-y-pipeline/secretos-identidades.md), [Pruebas dinámicas](../../devsecops/codigo-y-dependencias/pruebas-dinamicas.md) |
| Python (la herramienta) | Variables de entorno, CLIs y manejo de excepciones | [Archivos y formatos](archivos-formatos.md#variables-de-entorno-y-env), [Scripts de línea de comandos](scripts-cli.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 11: Observabilidad con Prometheus y Grafana](../../laboratorios/devops/observabilidad-prometheus-grafana.md), [Lab 18: AWS: API serverless con Lambda, API Gateway y DynamoDB](../../laboratorios/cloud/aws-serverless-api.md) |

## Referencias

- [Requests: Quickstart](https://requests.readthedocs.io/en/latest/user/quickstart/)
- [Requests: Advanced Usage (sessions, timeouts, adapters)](https://requests.readthedocs.io/en/latest/user/advanced/)
- [urllib3: `Retry`](https://urllib3.readthedocs.io/en/stable/reference/urllib3.util.html#urllib3.util.Retry)
- [HTTPX](https://www.python-httpx.org/)
- [GitHub REST API: versiones](https://docs.github.com/es/rest/about-the-rest-api/api-versions)
- [GitHub REST API: paginación](https://docs.github.com/es/rest/using-the-rest-api/using-pagination-in-the-rest-api)
- [GitHub REST API: límites de tasa](https://docs.github.com/es/rest/using-the-rest-api/rate-limits-for-the-rest-api)
- [GitHub REST API: listar repositorios de una organización](https://docs.github.com/es/rest/repos/repos#list-organization-repositories)
- [MDN: códigos de estado de respuesta HTTP](https://developer.mozilla.org/es/docs/Web/HTTP/Status)

Siguiente: [Automatización cloud con SDKs](automatizacion-cloud.md)
