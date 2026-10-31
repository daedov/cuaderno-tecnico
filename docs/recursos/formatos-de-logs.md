---
tags:
  - recursos
  - logs
  - observabilidad
  - troubleshooting
---

# Formatos de logs

Referencia de los formatos de log más comunes y cómo leer cada campo. El método para buscar la causa, las herramientas de terminal y los ejercicios están en [Cómo leer logs](../devops/operacion/leer-logs.md).

## syslog

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

## journald

En sistemas con systemd, el **journal** guarda los logs de todos los servicios con metadatos (unit, PID, prioridad, arranque). Se lee con `journalctl`:

```text
Oct 26 10:14:02 web-01 gunicorn[901]: [ERROR] Worker failed to boot.
Oct 26 10:14:02 web-01 systemd[1]: miapp.service: Main process exited, code=exited, status=3/NOTIMPLEMENTED
Oct 26 10:14:02 web-01 systemd[1]: miapp.service: Failed with result 'exit-code'.
Oct 26 10:14:07 web-01 systemd[1]: miapp.service: Scheduled restart job, restart counter is at 4.
```

Las líneas de `systemd[1]` describen el **síntoma** (el proceso salió con código 3 y se reinicia); la causa está en las líneas de la propia aplicación justo antes. Más sobre systemd en [Linux, redes y scripting](../devops/fundamentos/linux-redes-scripting.md#systemd).

## Access log de NGINX y Apache (combined)

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

`4xx` = error del cliente (ruta inexistente, sin permiso); `5xx` = error del servidor o de algo detrás. Un `502` o `504` en un proxy significa que el **backend** falló o no respondió: la explicación está en el **error log** del proxy (`/var/log/nginx/error.log`) y en los logs del backend. Repaso de códigos en [Protocolos de aplicación](../networking/intermedio/protocolos-aplicacion.md#codigos-de-estado).

## Logs JSON estructurados

```json
{"ts":"2026-10-26T10:14:05.020Z","level":"ERROR","service":"pagos","request_id":"req-7f3a","msg":"no se pudo conectar a la base de datos","error":"connection refused","db_host":"10.0.21.15:5432"}
```

Cada campo tiene nombre, así que se filtra por `level` o `request_id` sin expresiones regulares. Es el formato que esperan Loki, CloudWatch Logs Insights o Cloud Logging. Una línea por evento (**JSON Lines**), nunca JSON con saltos de línea.

## Stack traces de aplicación

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

## Logs de Kubernetes

Los contenedores escriben a `stdout`/`stderr` y `kubectl logs` los muestra. Además, Kubernetes genera **events** (eventos) sobre los objetos, que explican lo que el log de la aplicación no puede contar (no se pudo descargar la imagen, no hay nodo con memoria suficiente):

```text
LAST SEEN   TYPE      REASON      OBJECT                        MESSAGE
3m          Normal    Pulled      pod/api-7d9f8c6b5-x2k4p       Successfully pulled image "registry.ejemplo.com/tienda/api:1.4.3"
2m          Warning   BackOff     pod/api-7d9f8c6b5-x2k4p       Back-off restarting failed container api in pod api-7d9f8c6b5-x2k4p_tienda(...)
```

Mira primero los `Warning`. Cómo diagnosticar cada estado (CrashLoopBackOff, Pending, OOMKilled…) se ve en [Troubleshooting](../devops/operacion/troubleshooting.md#kubernetes).

## CloudTrail (JSON)

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

Responde **quién** (`userIdentity.arn`), **qué** (`eventSource` + `eventName`), **cuándo** (`eventTime`, siempre UTC), **desde dónde** (`sourceIPAddress`) y **si falló** (`errorCode`). Los equivalentes son el Activity Log de Azure y Cloud Audit Logs de Google Cloud ([Seguridad de logging y detección](../cloud/seguridad/seguridad-logging-deteccion.md)).

## VPC Flow Logs

Metadatos de tráfico de red, una conexión por línea, separados por espacios:

```text
2 111122223333 eni-0a1b2c3d 10.0.11.10 10.0.21.15 51544 5432 6 3 180 1793009640 1793009700 REJECT OK
```

Versión, cuenta, interfaz, IP y puerto de origen, IP y puerto de destino, protocolo (`6` = TCP), paquetes, bytes, inicio y fin (epoch) y **acción**. Un `REJECT` hacia el puerto 5432 indica que un security group o una NACL lo bloqueó. Cómo usarlos en un diagnóstico está en [Troubleshooting de red](../networking/avanzado/troubleshooting-red.md#en-la-nube).

## Logs de un job de CI

El log de un job es largo y el error real casi nunca está en la última línea. En GitHub Actions:

```text
2026-10-26T10:14:01.1021345Z ##[group]Run npm ci
2026-10-26T10:14:09.4410022Z npm error code E401
2026-10-26T10:14:09.4412118Z npm error Unable to authenticate, need: Basic realm="GitHub Package Registry"
2026-10-26T10:14:09.5017744Z ##[error]Process completed with exit code 1.
```

`##[error]Process completed with exit code 1.` solo dice que el paso falló; la causa son las líneas anteriores (`E401`: credenciales del registry). Busca el **primer** error del paso que falló. Si no basta, vuelve a ejecutar el job con **debug logging** (opción *Enable debug logging* al relanzarlo, o la variable `ACTIONS_STEP_DEBUG` en `true`). Ver [Integración continua](../devops/ci-cd/integracion-continua.md).

## Referencias

- [RFC 3164: The BSD syslog Protocol](https://www.rfc-editor.org/rfc/rfc3164)
- [RFC 5424: The Syslog Protocol](https://www.rfc-editor.org/rfc/rfc5424)
- [journalctl (man page)](https://www.freedesktop.org/software/systemd/man/latest/journalctl.html)
- [NGINX: módulo de logs (`log_format combined`)](https://nginx.org/en/docs/http/ngx_http_log_module.html)
- [Apache HTTP Server: Log Files](https://httpd.apache.org/docs/current/logs.html)
- [Python: traceback y excepciones](https://docs.python.org/es/3/tutorial/errors.html)
- [Kubernetes: Logging Architecture](https://kubernetes.io/docs/concepts/cluster-administration/logging/)
- [CloudTrail record contents](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference-record-contents.html)
- [VPC Flow Logs records](https://docs.aws.amazon.com/vpc/latest/userguide/flow-log-records.html)
- [GitHub Actions: Enabling debug logging](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/troubleshooting-workflows/enabling-debug-logging)
