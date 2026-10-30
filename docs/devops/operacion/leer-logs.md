---
tags:
  - observabilidad
  - logs
  - troubleshooting
  - linux
  - kubernetes
---

# Cómo leer logs

> Guía para empezar a leer logs con método: qué contiene cada línea, los formatos que vas a encontrar (syslog, journald, NGINX, JSON, stack traces, Kubernetes, CloudTrail, VPC Flow Logs, CI), cómo buscar la causa y no el síntoma, y las herramientas de terminal y de la nube para filtrarlos, con ejercicios resueltos.

## ¿Qué es un log?

Un **log** (registro) es una línea de texto que un programa escribe cuando pasa algo: arrancó, recibió una petición, falló una conexión. Leídos en orden, los logs cuentan **qué pasó, cuándo y dónde**, y son casi siempre la primera evidencia cuando algo se rompe.

Los logs son uno de los tres pilares de la observabilidad: las **metrics** (métricas) te dicen *que* algo va mal, las **traces** (trazas) *dónde* se fue el tiempo y los logs *qué* pasó exactamente (ver [Observabilidad](observabilidad.md#los-tres-pilares)).

## Anatomía de una línea de log

Casi todos los formatos tienen las mismas piezas, aunque las ordenen distinto:

```text
2026-10-26T10:14:05.020Z ERROR pagos[901] request_id=req-7f3a no se pudo conectar a la base de datos db_host=10.0.21.15:5432
└──────── timestamp ───┘ └nivel┘ └origen┘ └──── contexto ───┘ └────────────── mensaje ─────────────┘ └──── contexto ────┘
```

| Pieza | Qué es | Qué mirar |
| --- | --- | --- |
| **Timestamp** (marca de tiempo) | Cuándo ocurrió | Zona horaria y precisión (segundos, milisegundos) |
| **Level** (nivel o severidad) | Gravedad del evento | Filtra primero por `ERROR`, pero no ignores los `WARN` previos |
| **Origen** | Host, servicio, proceso (**PID**, *process ID*), contenedor | Qué instancia o réplica lo escribió |
| **Mensaje** | Descripción del evento | El texto literal es lo que buscarás en el código o en Google |
| **Contexto** | Campos extra: `request_id`, `user_id`, `order_id`, duración | Permiten seguir una petición y filtrar |

### Timestamps y zonas horarias

El error más común al empezar es comparar logs con horas en zonas distintas. Fíjate siempre en el sufijo:

| Formato | Ejemplo | Cómo leerlo |
| --- | --- | --- |
| **ISO 8601** en UTC | `2026-10-26T10:14:05.020Z` | La `Z` (*Zulu*) significa UTC |
| ISO 8601 con offset | `2026-10-26T05:14:05-05:00` | Hora local de Lima o Bogotá; es el mismo instante que el anterior |
| NGINX/Apache | `26/Oct/2026:10:14:05 +0000` | `+0000` es UTC |
| syslog tradicional | `Oct 26 10:14:05` | **Sin año ni zona**: es la hora local del servidor |
| **Epoch** (tiempo Unix) | `1793009645` | Segundos desde 1970-01-01 UTC; con 13 dígitos son milisegundos |

```console
$ date -u -d @1793009645 +%Y-%m-%dT%H:%M:%SZ
2026-10-26T10:14:05Z
```

!!! tip "Trabaja en UTC"
    Configura servidores, contenedores y aplicaciones en **UTC** y convierte a la hora local solo al mostrar. Cuando un usuario diga "falló a las 5 y cuarto", tradúcelo a UTC antes de buscar.

### Niveles

| Nivel | Significado | ¿Despierta a alguien? |
| --- | --- | --- |
| `DEBUG` | Detalle interno para depurar | No; normalmente apagado en producción |
| `INFO` | Funcionamiento normal: arrancó, procesó, terminó | No |
| `WARN` / `WARNING` | Algo raro pero se recuperó (reintento, valor por defecto) | No, pero suele anticipar el error |
| `ERROR` | Una operación falló | Depende del impacto |
| `FATAL` / `CRITICAL` | El proceso no puede continuar y se detiene | Normalmente sí |

syslog usa ocho severidades numéricas (de `0` *emerg* a `7` *debug*; `3` es *err*), y `journalctl -p err` muestra de la 0 a la 3.

## Formatos más comunes

### syslog

El formato clásico de Unix. Hay dos estándares:

```text title="RFC 3164 (BSD, el antiguo)"
<34>Oct 11 22:14:15 mymachine su: 'su root' failed for lonvick on /dev/pts/8
```

- `<34>` es el **PRI**: `facility × 8 + severity`. 34 = facility 4 (*auth*) × 8 + severidad 2 (*crit*).
- Fecha sin año ni zona, host `mymachine`, programa `su`, mensaje.

```text title="RFC 5424 (el moderno)"
<165>1 2003-10-11T22:14:15.003Z mymachine.example.com evntslog - ID47 [exampleSDID@32473 iut="3" eventSource="Application"] An application event log entry
```

- PRI `165`, versión `1`, timestamp ISO 8601, host, aplicación (`evntslog`), PID (`-` = vacío), ID de mensaje (`ID47`), **structured data** entre corchetes y mensaje.

En disco, `/var/log/syslog` (Debian/Ubuntu) o `/var/log/messages` (RHEL) no suelen mostrar el PRI y, según la distribución y la configuración de rsyslog, usan la fecha corta tradicional o ISO 8601.

### journald

En sistemas con systemd, el **journal** guarda los logs de todos los servicios con metadatos (unit, PID, prioridad, arranque). Se lee con `journalctl`:

```text
Oct 26 10:14:02 web-01 gunicorn[901]: [ERROR] Worker failed to boot.
Oct 26 10:14:02 web-01 systemd[1]: miapp.service: Main process exited, code=exited, status=3/NOTIMPLEMENTED
Oct 26 10:14:02 web-01 systemd[1]: miapp.service: Failed with result 'exit-code'.
Oct 26 10:14:07 web-01 systemd[1]: miapp.service: Scheduled restart job, restart counter is at 4.
```

Las líneas de `systemd[1]` describen el **síntoma** (el proceso salió con código 3 y se reinicia); la causa está en las líneas de la propia aplicación justo antes. Más sobre systemd en [Linux, redes y scripting](../fundamentos/linux-redes-scripting.md#systemd).

### Access log de NGINX y Apache (combined)

El formato **combined** es el mismo en NGINX y Apache:

```text
203.0.113.24 - - [26/Oct/2026:10:14:05 +0000] "POST /api/pagos HTTP/1.1" 502 157 "-" "Mozilla/5.0"
```

| Campo (posición con `awk`) | Valor | Significado |
| --- | --- | --- |
| `$1` | `203.0.113.24` | IP del cliente (detrás de un load balancer, la del balanceador salvo que registres `X-Forwarded-For`) |
| `$2`, `$3` | `- -` | identd y usuario autenticado (casi siempre vacíos) |
| `$4 $5` | `[26/Oct/2026:10:14:05 +0000]` | Fecha con zona |
| `$6 $7 $8` | `"POST /api/pagos HTTP/1.1"` | Método, ruta y protocolo |
| `$9` | `502` | **Código de estado** HTTP |
| `$10` | `157` | Bytes enviados en el cuerpo |
| resto | `"-" "Mozilla/5.0"` | Referer y user agent |

`4xx` = error del cliente (ruta inexistente, sin permiso); `5xx` = error del servidor o de algo detrás. Un `502` o `504` en un proxy significa que el **backend** falló o no respondió: la explicación está en el **error log** del proxy (`/var/log/nginx/error.log`) y en los logs del backend. Repaso de códigos en [Protocolos de aplicación](../../networking/intermedio/protocolos-aplicacion.md#codigos-de-estado).

### Logs JSON estructurados

```json
{"ts":"2026-10-26T10:14:05.020Z","level":"ERROR","service":"pagos","request_id":"req-7f3a","msg":"no se pudo conectar a la base de datos","error":"connection refused","db_host":"10.0.21.15:5432"}
```

Cada campo tiene nombre, así que se filtra por `level` o `request_id` sin expresiones regulares. Es el formato que esperan Loki, CloudWatch Logs Insights o Cloud Logging. Una línea por evento (**JSON Lines**), nunca JSON con saltos de línea.

### Stack traces de aplicación

Cuando una excepción no se controla, el lenguaje imprime la pila de llamadas (**stack trace** o *traceback*). Lo importante es saber **en qué orden leerla**.

**Python: de abajo arriba.** La última línea es la excepción; encima, la llamada más reciente (*most recent call last*):

```text
Traceback (most recent call last):
  File "/app/main.py", line 12, in <module>
    main()
  File "/app/main.py", line 7, in main
    config = cargar_config(os.environ["CONFIG_PATH"])
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/app/config.py", line 7, in cargar_config
    return json.loads(texto)
           ^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.12/json/__init__.py", line 346, in loads
    return _default_decoder.decode(s)
           ^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.12/json/decoder.py", line 337, in decode
    obj, end = self.raw_decode(s, idx=_w(s, 0).end())
               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.12/json/decoder.py", line 355, in raw_decode
    raise JSONDecodeError("Expecting value", s, err.value) from None
json.decoder.JSONDecodeError: Expecting value: line 1 column 1 (char 0)
```

1. Última línea: **qué** pasó (`JSONDecodeError`: el texto no es JSON; "line 1 column 1" suele significar archivo vacío).
2. Sube hasta el **último frame de tu código** (no de la librería estándar): `config.py`, línea 7. Ahí es donde actúas.
3. Sigue subiendo para ver **quién** lo llamó y con qué (`CONFIG_PATH`).

**Java: de arriba abajo y busca el último "Caused by".** Java imprime primero la excepción y la llamada más reciente arriba; las excepciones envueltas aparecen como `Caused by:` y **la última es la causa raíz** (ejemplo ilustrativo):

```text
com.ejemplo.pedidos.RepositorioException: No se pudo guardar el pedido A-2045
    at com.ejemplo.pedidos.PedidoRepositorio.guardar(PedidoRepositorio.java:58)
    at com.ejemplo.pedidos.PedidoService.crear(PedidoService.java:31)
    at com.ejemplo.pedidos.PedidoController.crear(PedidoController.java:22)
    ... 48 more
Caused by: org.postgresql.util.PSQLException: Connection to 10.0.21.15:5432 refused. Check that the hostname and port are correct and that the postmaster is accepting TCP/IP connections.
    at org.postgresql.core.v3.ConnectionFactoryImpl.openConnectionImpl(ConnectionFactoryImpl.java:342)
    ... 12 more
Caused by: java.net.ConnectException: Connection refused
    at java.base/sun.nio.ch.Net.connect0(Native Method)
```

La primera línea es el síntoma ("no se pudo guardar el pedido"); el último `Caused by` es la causa (nadie escucha en `10.0.21.15:5432`). `... 48 more` indica frames repetidos que Java omite.

### Logs de Kubernetes

Los contenedores escriben a `stdout`/`stderr` y `kubectl logs` los muestra. Además, Kubernetes genera **events** (eventos) sobre los objetos, que explican lo que el log de la aplicación no puede contar (no se pudo descargar la imagen, no hay nodo con memoria suficiente):

```text
LAST SEEN   TYPE      REASON      OBJECT                        MESSAGE
3m          Normal    Pulled      pod/api-7d9f8c6b5-x2k4p       Successfully pulled image "registry.ejemplo.com/tienda/api:1.4.3"
2m          Warning   BackOff     pod/api-7d9f8c6b5-x2k4p       Back-off restarting failed container api in pod api-7d9f8c6b5-x2k4p_tienda(...)
```

Mira primero los `Warning`. Cómo diagnosticar cada estado (CrashLoopBackOff, Pending, OOMKilled…) se ve en [Troubleshooting](troubleshooting.md#kubernetes).

### CloudTrail (JSON)

Cada llamada a la API de AWS queda como un evento JSON. Los campos que importan para leerlo:

```json
{
  "eventTime": "2026-10-26T10:14:05Z",
  "eventSource": "s3.amazonaws.com",
  "eventName": "PutObject",
  "awsRegion": "us-east-1",
  "sourceIPAddress": "198.51.100.7",
  "userIdentity": {
    "type": "AssumedRole",
    "arn": "arn:aws:sts::111122223333:assumed-role/rol-ci/GitHubActions"
  },
  "errorCode": "AccessDenied",
  "errorMessage": "User: arn:aws:sts::111122223333:assumed-role/rol-ci/GitHubActions is not authorized to perform: s3:PutObject on resource: \"arn:aws:s3:::artefactos-prod/app.zip\" because no identity-based policy allows the s3:PutObject action"
}
```

Responde **quién** (`userIdentity.arn`), **qué** (`eventSource` + `eventName`), **cuándo** (`eventTime`, siempre UTC), **desde dónde** (`sourceIPAddress`) y **si falló** (`errorCode`). Los equivalentes son el Activity Log de Azure y Cloud Audit Logs de Google Cloud ([Seguridad base](../../cloud/identidad-y-seguridad/seguridad-base.md)).

### VPC Flow Logs

Metadatos de tráfico de red, una conexión por línea, separados por espacios:

```text
2 111122223333 eni-0a1b2c3d 10.0.11.10 10.0.21.15 51544 5432 6 3 180 1793009640 1793009700 REJECT OK
```

Versión, cuenta, interfaz, IP y puerto de origen, IP y puerto de destino, protocolo (`6` = TCP), paquetes, bytes, inicio y fin (epoch) y **acción**. Un `REJECT` hacia el puerto 5432 indica que un security group o una NACL lo bloqueó. Cómo usarlos en un diagnóstico está en [Troubleshooting de red](../../networking/avanzado/troubleshooting-red.md#en-la-nube).

### Logs de un job de CI

El log de un job es largo y el error real casi nunca está en la última línea. En GitHub Actions:

```text
2026-10-26T10:14:01.1021345Z ##[group]Run npm ci
2026-10-26T10:14:09.4410022Z npm error code E401
2026-10-26T10:14:09.4412118Z npm error Unable to authenticate, need: Basic realm="GitHub Package Registry"
2026-10-26T10:14:09.5017744Z ##[error]Process completed with exit code 1.
```

`##[error]Process completed with exit code 1.` solo dice que el paso falló; la causa son las líneas anteriores (`E401`: credenciales del registry). Busca el **primer** error del paso que falló. Si no basta, vuelve a ejecutar el job con **debug logging** (opción *Enable debug logging* al relanzarlo, o la variable `ACTIONS_STEP_DEBUG` en `true`). Ver [Integración continua](../ci-cd/integracion-continua.md).

## Método para leer logs

1. **Sitúate en el momento del fallo.** Pide la hora exacta (en UTC) y abre una ventana de unos minutos antes y después.
2. **Filtra por nivel**, pero lee también los `WARN` previos: un reintento suele anunciar el error.
3. **Busca el primer error, no el último.** Un fallo provoca una cascada; el primero suele ser la causa y los siguientes, consecuencias.
4. **Sigue un request ID o correlation ID.** Con el mismo identificador en todos los servicios puedes reconstruir el camino de una petición.
5. **Compara con un periodo sano.** Lo que aparece en ambos periodos no es la causa.
6. **Distingue causa de síntoma.** "502 en NGINX" es un síntoma; "el backend no escucha en el puerto 8081" es una causa; "el deploy cambió el puerto" es la causa raíz.
7. **Cuidado con los errores "normales".** Muchos sistemas registran errores ruidosos todo el día (bots que piden `/wp-login.php`, un health check mal configurado). Si aparecían ayer igual, no son tu problema de hoy.

## Herramientas en la terminal

Las salidas son reales, sobre los archivos de ejemplo de los ejercicios. Chuleta en [Comandos de Linux](../../recursos/comandos/linux.md).

| Herramienta | Para qué |
| --- | --- |
| `less archivo` | Navegar archivos grandes: `/texto` busca hacia adelante, `n` siguiente, `G` va al final, `F` sigue el archivo como `tail -f` |
| `tail -n 100 archivo` / `tail -f archivo` | Ver el final / seguir en vivo |
| `grep` | Filtrar líneas: `-i` sin mayúsculas, `-v` invertir, `-E` regex extendida, `-A/-B/-C N` líneas de contexto, `-c` contar, `-n` número de línea, `-m1` solo la primera |
| `awk` | Trabajar por columnas y condiciones |
| `cut -d' ' -f1` | Extraer una columna con separador fijo |
| `sort \| uniq -c \| sort -nr` | Contar ocurrencias y ordenar de mayor a menor |
| `zgrep` | `grep` sobre logs rotados comprimidos (`.gz`) |

```console
$ awk '{print $9}' access.log | sort | uniq -c | sort -nr    # códigos de estado
      6 200
      5 404
      4 502
      4 401
      1 504
      1 201

$ awk '$9 >= 500 {print substr($4, 2, 17)}' access.log | uniq -c    # errores 5xx por minuto
      3 26/Oct/2026:10:14
      2 26/Oct/2026:10:15

$ grep -B1 -A1 'WARNING' app.log      # contexto alrededor de una línea
2026-10-26 10:14:05,020 ERROR pagos: no se pudo conectar a la base de datos
2026-10-26 10:14:05,021 WARNING pagos: reintentando conexion (1/3)
2026-10-26 10:14:12,101 ERROR pagos: no se pudo conectar a la base de datos

$ grep -m1 -n 'ERROR' app.log          # el primer error y su número de línea
2:2026-10-26 10:14:05,020 ERROR pagos: no se pudo conectar a la base de datos

$ zgrep 'ERROR' app.log.1.gz            # log rotado de ayer
2026-10-25 23:40:02,310 ERROR pagos: timeout llamando a la pasarela de pago
```

### jq para logs JSON

**jq** filtra y transforma JSON. No estaba instalado en el equipo donde se probaron los comandos: la sintaxis está verificada contra el [manual de jq](https://jqlang.org/manual/) y las salidas son las esperadas para `app.json`.

```console
$ jq -r 'select(.level == "ERROR") | [.ts, .request_id, .msg] | @tsv' app.json
2026-10-26T10:14:05.020Z	req-7f3a	no se pudo conectar a la base de datos
2026-10-26T10:14:12.101Z	req-8b21	no se pudo conectar a la base de datos
2026-10-26T10:15:01.998Z	req-a114	timeout esperando a la base de datos

$ jq -r '.level' app.json | sort | uniq -c | sort -nr
      3 ERROR
      2 INFO
      1 WARN

$ jq -c 'select(.request_id == "req-8b21")' app.json
{"ts":"2026-10-26T10:14:11.700Z","level":"WARN","service":"pagos","request_id":"req-8b21","msg":"reintento 1/3 hacia la base de datos"}
{"ts":"2026-10-26T10:14:12.101Z","level":"ERROR","service":"pagos","request_id":"req-8b21","msg":"no se pudo conectar a la base de datos","error":"connection refused","db_host":"10.0.21.15:5432"}
```

- `select(...)` deja pasar solo los objetos que cumplen la condición; `-c` imprime cada uno en una línea; `-r` con `@tsv` saca texto separado por tabuladores.
- Si en el archivo hay líneas que no son JSON, `jq` se detiene con un error de *parse*; usa `jq -R 'fromjson? // empty'` para ignorarlas.

### journalctl

```bash
journalctl -u miapp --since "1 hour ago"      # logs de una unit en la última hora
journalctl -u miapp -p err -b                  # solo err o peor, desde el último arranque
journalctl -u miapp -f                         # seguir en vivo
journalctl -k --since "10:00" --until "10:30"  # mensajes del kernel en una ventana
journalctl -u miapp -o json --no-pager | jq -r '.MESSAGE'
```

### kubectl logs

```bash
kubectl logs api-7d9f8c6b5-x2k4p -n tienda --since=1h        # última hora de un Pod
kubectl logs deploy/api -n tienda -f                          # seguir un Pod del deployment
kubectl logs api-7d9f8c6b5-x2k4p -n tienda --previous         # el contenedor ANTERIOR (antes del reinicio)
kubectl logs -l app=api -n tienda --tail=50 --timestamps      # todos los Pods con esa label
kubectl logs api-7d9f8c6b5-x2k4p -n tienda -c istio-proxy     # un contenedor concreto del Pod
kubectl get events -n tienda --sort-by=.metadata.creationTimestamp
```

`--previous` es clave en un **CrashLoopBackOff**: el contenedor actual acaba de arrancar y su log está vacío; lo que te interesa es por qué murió el anterior. Más comandos en [kubectl](../../recursos/comandos/kubectl.md).

## Consultas de logs en la nube

La misma pregunta, **errores por minuto en la última hora**, en cada proveedor. Detalle de cada servicio en [Observabilidad nativa](../../cloud/operacion-y-gobierno/observabilidad-nativa.md).

=== "AWS"

    **CloudWatch Logs Insights** (elige la última hora en el selector de tiempo; con logs JSON los campos se descubren solos):

    ```text
    fields @timestamp, @message
    | filter level = "ERROR"
    | stats count(*) as errores by bin(1m)
    | sort errores desc
    ```

=== "Azure"

    **KQL** en un Log Analytics workspace, sobre la tabla `AppTraces` de Application Insights (`SeverityLevel` 3 = Error, 4 = Critical):

    ```text
    AppTraces
    | where TimeGenerated > ago(1h) and SeverityLevel >= 3
    | summarize errores = count() by bin(TimeGenerated, 1m)
    | order by TimeGenerated asc
    ```

=== "Google Cloud"

    En **Logs Explorer** el filtro es `severity>=ERROR` (el histograma ya muestra el conteo). Para agregar, usa **Log Analytics** con SQL sobre la vista del log bucket:

    ```sql
    SELECT TIMESTAMP_TRUNC(timestamp, MINUTE) AS minuto, COUNT(*) AS errores
    FROM `mi-proyecto.global._Default._AllLogs`
    WHERE severity IN ('ERROR', 'CRITICAL', 'ALERT', 'EMERGENCY')
      AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
    GROUP BY minuto
    ORDER BY minuto
    ```

## Escribir logs que se puedan leer

Quien lee los logs a las 3 de la mañana puede ser tu yo del futuro. Al escribirlos:

- **Structured logging** (logs estructurados): JSON con campos fijos (`ts`, `level`, `service`, `request_id`, `msg`) en lugar de frases libres.
- **Correlation ID** (identificador de correlación): genera un `request_id` en la entrada (gateway o load balancer), propágalo en una cabecera a cada servicio e inclúyelo en cada línea. Con OpenTelemetry, registra también el `trace_id`.
- **Niveles bien usados**: `ERROR` solo cuando algo falló de verdad; un 404 de un bot no es un `ERROR` de tu aplicación. Si todo es error, nada lo es.
- **Mensajes con contexto**: "timeout después de 5000 ms llamando a inventario (intento 3/3)" en vez de "error".
- **UTC e ISO 8601** con milisegundos.
- **Nunca secretos ni PII** (*personally identifiable information*, datos personales): contraseñas, tokens, cabeceras `Authorization`, números de tarjeta, correos. Los logs se copian a muchos sistemas y los lee mucha gente; enmascara los datos sensibles. Ver [Secretos e identidades](../../devsecops/identidades-y-pipeline/secretos-identidades.md).

En Python, el módulo `logging` y cómo usar niveles y formato están en [Scripts de línea de comandos](../../python/scripting/scripts-cli.md#logging-en-vez-de-print).

## Ejercicios

### 1. Un access log con errores 5xx

Los usuarios reportan que "pagar no funciona" desde las 10:14 UTC. Tienes el access log y el error log de NGINX (son los mismos archivos que usan los ejemplos de la sección de herramientas):

```text title="access.log"
203.0.113.10 - - [26/Oct/2026:10:12:01 +0000] "GET /api/productos HTTP/1.1" 200 5123 "-" "Mozilla/5.0"
198.51.100.7 - - [26/Oct/2026:10:12:03 +0000] "GET /api/productos/42 HTTP/1.1" 200 812 "-" "Mozilla/5.0"
192.0.2.55 - - [26/Oct/2026:10:12:09 +0000] "GET /wp-login.php HTTP/1.1" 404 153 "-" "python-requests/2.31"
192.0.2.55 - - [26/Oct/2026:10:12:10 +0000] "GET /.env HTTP/1.1" 404 153 "-" "python-requests/2.31"
203.0.113.10 - - [26/Oct/2026:10:12:15 +0000] "POST /api/carrito HTTP/1.1" 201 64 "-" "Mozilla/5.0"
192.0.2.55 - - [26/Oct/2026:10:12:20 +0000] "GET /admin HTTP/1.1" 404 153 "-" "python-requests/2.31"
198.51.100.7 - - [26/Oct/2026:10:13:02 +0000] "POST /api/login HTTP/1.1" 401 41 "-" "Mozilla/5.0"
203.0.113.10 - - [26/Oct/2026:10:13:30 +0000] "POST /api/pagos HTTP/1.1" 200 97 "-" "Mozilla/5.0"
192.0.2.55 - - [26/Oct/2026:10:13:41 +0000] "GET /phpmyadmin/ HTTP/1.1" 404 153 "-" "python-requests/2.31"
203.0.113.24 - - [26/Oct/2026:10:14:05 +0000] "POST /api/pagos HTTP/1.1" 502 157 "-" "Mozilla/5.0"
198.51.100.7 - - [26/Oct/2026:10:14:07 +0000] "GET /api/productos HTTP/1.1" 200 5123 "-" "Mozilla/5.0"
203.0.113.10 - - [26/Oct/2026:10:14:12 +0000] "POST /api/pagos HTTP/1.1" 502 157 "-" "Mozilla/5.0"
198.51.100.31 - - [26/Oct/2026:10:14:20 +0000] "POST /api/login HTTP/1.1" 401 41 "-" "curl/8.5.0"
198.51.100.31 - - [26/Oct/2026:10:14:21 +0000] "POST /api/login HTTP/1.1" 401 41 "-" "curl/8.5.0"
203.0.113.24 - - [26/Oct/2026:10:14:33 +0000] "POST /api/pagos HTTP/1.1" 502 157 "-" "Mozilla/5.0"
198.51.100.7 - - [26/Oct/2026:10:14:40 +0000] "GET /api/carrito HTTP/1.1" 200 230 "-" "Mozilla/5.0"
203.0.113.10 - - [26/Oct/2026:10:15:02 +0000] "POST /api/pagos HTTP/1.1" 504 167 "-" "Mozilla/5.0"
192.0.2.55 - - [26/Oct/2026:10:15:10 +0000] "GET /config.php HTTP/1.1" 404 153 "-" "python-requests/2.31"
198.51.100.31 - - [26/Oct/2026:10:15:12 +0000] "POST /api/login HTTP/1.1" 401 41 "-" "curl/8.5.0"
203.0.113.24 - - [26/Oct/2026:10:15:30 +0000] "POST /api/pagos HTTP/1.1" 502 157 "-" "Mozilla/5.0"
198.51.100.7 - - [26/Oct/2026:10:15:45 +0000] "GET /api/productos/7 HTTP/1.1" 200 790 "-" "Mozilla/5.0"
```

```text title="error.log"
2026/10/26 10:13:58 [notice] 1#1: signal 1 (SIGHUP) received from 412, reconfiguring
2026/10/26 10:14:05 [error] 31#31: *1841 connect() failed (111: Connection refused) while connecting to upstream, client: 203.0.113.24, server: tienda.ejemplo.com, request: "POST /api/pagos HTTP/1.1", upstream: "http://10.0.21.40:8081/api/pagos", host: "tienda.ejemplo.com"
2026/10/26 10:14:12 [error] 31#31: *1849 connect() failed (111: Connection refused) while connecting to upstream, client: 203.0.113.10, server: tienda.ejemplo.com, request: "POST /api/pagos HTTP/1.1", upstream: "http://10.0.21.40:8081/api/pagos", host: "tienda.ejemplo.com"
2026/10/26 10:15:02 [error] 31#31: *1877 upstream timed out (110: Connection timed out) while connecting to upstream, client: 203.0.113.10, server: tienda.ejemplo.com, request: "POST /api/pagos HTTP/1.1", upstream: "http://10.0.21.40:8081/api/pagos", host: "tienda.ejemplo.com"
```

¿Qué endpoints fallan, desde cuándo y qué harías a continuación?

??? success "Solución"
    ```console
    $ awk '$9 >= 500 {print $7}' access.log | sort | uniq -c
          5 /api/pagos
    $ grep -o 'upstream: "[^"]*"' error.log | sort | uniq -c
          3 upstream: "http://10.0.21.40:8081/api/pagos"
    ```

    - Solo falla `/api/pagos`; `/api/productos` sigue respondiendo 200, así que NGINX está bien y el problema está **detrás**, en el backend de pagos.
    - El último 200 de pagos es a las 10:13:30 y el primer 502 a las 10:14:05. Justo entre medias, a las 10:13:58, NGINX recibió un `SIGHUP` y **recargó su configuración**: algo cambió.
    - `Connection refused` hacia `10.0.21.40:8081` significa que llegas al host pero **nadie escucha en ese puerto**; el `timed out` posterior apunta a que además el camino o el host dejó de responder.
    - Siguiente paso: revisar qué cambió en la configuración de NGINX (¿el puerto del upstream es correcto?) y, en `10.0.21.40`, si el servicio de pagos está levantado (`ss -tlnp`, `systemctl status`). La distinción refused/timeout está explicada en [Troubleshooting de red](../../networking/avanzado/troubleshooting-red.md#timeout-vs-connection-refused).

### 2. Un stack trace de Python

Un job nocturno falla con el traceback de la sección [Stack traces de aplicación](#stack-traces-de-aplicacion). La variable `CONFIG_PATH` vale `/etc/job/config.json`. ¿Qué falló y dónde lo arreglarías?

??? success "Solución"
    - Última línea: `JSONDecodeError: Expecting value: line 1 column 1 (char 0)`. El parser no encontró **nada** que leer en el primer carácter: el archivo está vacío (o empieza con algo que no es JSON).
    - Los tres frames de abajo son de la librería `json`: **no** están mal. El último frame de nuestro código es `config.py`, línea 7, en `cargar_config`, llamado desde `main.py` con `os.environ["CONFIG_PATH"]`.
    - Causa: `/etc/job/config.json` está vacío. Comprueba con `wc -c /etc/job/config.json` y averigua qué lo generó vacío (un despliegue que falló a medias, un template sin valores).
    - Mejora: validar en `cargar_config` y lanzar un error claro ("el archivo de configuración X está vacío").

### 3. IPs con más errores 4xx

Con el mismo `access.log` del ejercicio 1, ¿qué IPs generan más respuestas 4xx? ¿Alguna es sospechosa?

??? success "Solución"
    ```console
    $ awk '$9 ~ /^4/ {print $1}' access.log | sort | uniq -c | sort -nr
          5 192.0.2.55
          3 198.51.100.31
          1 198.51.100.7
    $ grep '192.0.2.55' access.log | awk '{print $7, $9}'
    /wp-login.php 404
    /.env 404
    /admin 404
    /phpmyadmin/ 404
    /config.php 404
    ```

    - `192.0.2.55`: rutas típicas de un **escáner automático** (`/.env`, `/wp-login.php`) con `python-requests`. Todo 404: ruido habitual de Internet, no la causa de la caída. Si aparece todos los días, es un error "normal".
    - `198.51.100.31`: tres `401` seguidos en `/api/login` con `curl` en dos minutos. Puede ser un intento de **fuerza bruta**: vale la pena una regla de rate limiting o de detección (ver [Detección y respuesta](../../devsecops/gobierno-y-respuesta/deteccion-respuesta.md)).
    - `198.51.100.7`: un 401 aislado de un navegador; probablemente una contraseña mal escrita.

### 4. Seguir un request ID entre dos servicios

El gateway devolvió un 500. Tienes sus logs y los del servicio de pedidos:

```text title="gateway.log"
2026-10-26T10:20:31.104Z INFO  gateway request_id=req-c55e method=POST path=/api/pedidos client=203.0.113.24
2026-10-26T10:20:31.109Z INFO  gateway request_id=req-d901 method=GET path=/api/productos client=198.51.100.7
2026-10-26T10:20:34.131Z WARN  gateway request_id=req-c55e upstream=pedidos slow_response duration_ms=3020
2026-10-26T10:20:34.133Z ERROR gateway request_id=req-c55e status=500 duration_ms=3029 upstream=pedidos
```

```text title="pedidos.log"
2026-10-26T10:20:31.112Z INFO  pedidos request_id=req-c55e crear pedido user=u-381 items=3
2026-10-26T10:20:31.115Z INFO  pedidos request_id=req-c55e reservando stock en inventario
2026-10-26T10:20:31.120Z INFO  pedidos request_id=req-77aa crear pedido user=u-112 items=1
2026-10-26T10:20:34.118Z ERROR pedidos request_id=req-c55e llamada a inventario fallida: HTTP 503 after 3000ms (circuit=closed)
2026-10-26T10:20:34.120Z ERROR pedidos request_id=req-c55e no se pudo crear el pedido: InventarioNoDisponible
2026-10-26T10:20:34.122Z INFO  pedidos request_id=req-77aa pedido creado order_id=A-2045
```

¿Qué servicio tiene el problema?

??? success "Solución"
    ```console
    $ grep -h 'req-c55e' gateway.log pedidos.log | sort
    2026-10-26T10:20:31.104Z INFO  gateway request_id=req-c55e method=POST path=/api/pedidos client=203.0.113.24
    2026-10-26T10:20:31.112Z INFO  pedidos request_id=req-c55e crear pedido user=u-381 items=3
    2026-10-26T10:20:31.115Z INFO  pedidos request_id=req-c55e reservando stock en inventario
    2026-10-26T10:20:34.118Z ERROR pedidos request_id=req-c55e llamada a inventario fallida: HTTP 503 after 3000ms (circuit=closed)
    2026-10-26T10:20:34.120Z ERROR pedidos request_id=req-c55e no se pudo crear el pedido: InventarioNoDisponible
    2026-10-26T10:20:34.131Z WARN  gateway request_id=req-c55e upstream=pedidos slow_response duration_ms=3020
    2026-10-26T10:20:34.133Z ERROR gateway request_id=req-c55e status=500 duration_ms=3029 upstream=pedidos
    ```

    - Como los timestamps son ISO 8601 en UTC, `sort` los intercala en orden cronológico.
    - El **primer** error es de `pedidos` a las 10:20:34.118: **inventario** respondió 503 tras 3 s. El 500 del gateway es la consecuencia, 15 ms después.
    - Ni el gateway ni pedidos son la causa: el siguiente paso es buscar `req-c55e` en los logs de **inventario**. Que otro pedido (`req-77aa`) sin reserva de stock sí funcionara refuerza la hipótesis.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Dónde viven los logs de cada nube, cómo se consultan y cuánto cuestan; logs de auditoría | [Observabilidad nativa](../../cloud/operacion-y-gobierno/observabilidad-nativa.md), [Seguridad base](../../cloud/identidad-y-seguridad/seguridad-base.md) |
| DevOps (la automatización) | Centralizar logs, correlacionarlos con métricas y trazas, y usarlos para diagnosticar | [Observabilidad](observabilidad.md), [Troubleshooting](troubleshooting.md), [Operación y fiabilidad (SRE)](operacion-sre.md), [Kubernetes](../contenedores/kubernetes.md) |
| DevSecOps (la verificación) | Los mismos logs como fuente de detección: escáneres, fuerza bruta, accesos denegados | [Detección y respuesta](../../devsecops/gobierno-y-respuesta/deteccion-respuesta.md) |
| Networking (la base) | Flow logs, errores de conexión y su significado en la red | [Troubleshooting de red](../../networking/avanzado/troubleshooting-red.md) |
| Python (la herramienta) | Escribir logs con `logging` y procesar archivos de log grandes | [Scripts de línea de comandos](../../python/scripting/scripts-cli.md), [Archivos y formatos](../../python/scripting/archivos-formatos.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 03: Script en Python para analizar logs](../../laboratorios/fundamentos/python-analizar-logs.md), [Lab 11: Observabilidad con Prometheus y Grafana](../../laboratorios/devops/observabilidad-prometheus-grafana.md), [Lab 18: AWS: API serverless con Lambda, API Gateway y DynamoDB](../../laboratorios/cloud/aws-serverless-api.md), [Lab 21: Game day: incidente simulado, troubleshooting y postmortem](../../laboratorios/operacion/game-day-incidente.md) |

## Referencias

- [RFC 3164: The BSD syslog Protocol](https://www.rfc-editor.org/rfc/rfc3164)
- [RFC 5424: The Syslog Protocol](https://www.rfc-editor.org/rfc/rfc5424)
- [journalctl (man page)](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html)
- [NGINX: módulo de logs (`log_format combined`)](https://nginx.org/en/docs/http/ngx_http_log_module.html)
- [Apache HTTP Server: Log Files](https://httpd.apache.org/docs/current/logs.html)
- [Python: traceback y excepciones](https://docs.python.org/es/3/tutorial/errors.html)
- [jq Manual](https://jqlang.org/manual/)
- [GNU grep manual](https://www.gnu.org/software/grep/manual/grep.html)
- [The GNU Awk User's Guide](https://www.gnu.org/software/gawk/manual/gawk.html)
- [Kubernetes: kubectl logs](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/)
- [Kubernetes: Logging Architecture](https://kubernetes.io/docs/concepts/cluster-administration/logging/)
- [CloudTrail record contents](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference-record-contents.html)
- [VPC Flow Logs records](https://docs.aws.amazon.com/vpc/latest/userguide/flow-log-records.html)
- [CloudWatch Logs Insights query syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [Kusto Query Language (KQL)](https://learn.microsoft.com/es-es/kusto/query/)
- [Cloud Logging: Log Analytics](https://cloud.google.com/logging/docs/log-analytics)
- [GitHub Actions: Enabling debug logging](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/troubleshooting-workflows/enabling-debug-logging)
