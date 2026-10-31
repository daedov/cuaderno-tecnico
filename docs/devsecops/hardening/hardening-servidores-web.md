---
tags:
  - devsecops
  - hardening
  - seguridad
  - tls
---

# Hardening de servidores web: NGINX y Apache

> Configuración segura de referencia para NGINX y Apache: TLS, cabeceras de seguridad, límites y timeouts, con su verificación real: `nginx -t`, `curl -I` y `testssl.sh`.

!!! info "Dónde encaja"
    Esta nota cubre servidores web que **tú instalas y operas**. Si usas un load balancer o una API gestionada del proveedor, parte del hardening lo hace él: ver [Seguridad de APIs y aplicaciones expuestas](../../cloud/seguridad/seguridad-apis-aplicaciones.md). Las bases de datos y el daemon de Docker están en [Hardening de servicios](hardening-servicios.md), el sistema operativo en [Hardening de Linux](hardening-linux.md) y el ciclo general en [Fundamentos de hardening](fundamentos-hardening.md).

!!! note "Cómo se probó"
    Todo lo que tiene "salida real" se ejecutó en un contenedor Docker desechable (`hard-nginx`) con **nginx 1.30.6 / OpenSSL 3.5** y **Apache httpd 2.4**, con un certificado autofirmado. Las salidas están abreviadas.

Lo mínimo: sin versión visible, solo HTTPS con TLS 1.2+, cabeceras de seguridad, límites y timeouts. Se apoya en el **CIS Benchmark** de NGINX y de Apache HTTP Server, en la guía TLS de referencia y en la documentación de cada proyecto.

## TLS: la configuración de referencia

El **Mozilla SSL Configuration Generator** se mudó a **TLSRef Configurator** (`configurator.tlsref.org`, mantenido por las mismas personas); la página antigua redirige allí. A la fecha de esta nota publica la **TLSRef Guideline v6.0** con tres perfiles:

| Perfil | Protocolos | Para quién |
| --- | --- | --- |
| **Modern** | Solo TLS 1.3 | Servicios cuyos clientes son todos modernos (APIs internas, apps propias) |
| **Intermediate** | TLS 1.2 y 1.3, solo suites AEAD con forward secrecy | **Recomendado para casi todo** |
| **Old** | Incluye TLS 1.0/1.1 | Solo como último recurso para clientes muy antiguos |

Novedad de la v6.0: el grupo híbrido poscuántico **X25519MLKEM768** aparece primero en la lista de curvas; el generador solo lo incluye si indicas **OpenSSL 3.5 o superior**. Genera siempre la configuración indicando tu versión real del servidor y de OpenSSL (`nginx -V` muestra ambas).

## Configuración endurecida

=== "NGINX"

    ```nginx title="/etc/nginx/nginx.conf"
    user  nginx;                          # los workers no corren como root
    worker_processes  auto;
    error_log  /var/log/nginx/error.log notice;
    pid        /run/nginx.pid;

    events {
        worker_connections  1024;
    }

    http {
        include       /etc/nginx/mime.types;
        default_type  application/octet-stream;
        access_log    /var/log/nginx/access.log;
        sendfile      on;

        server_tokens off;                # oculta la versión en la cabecera Server y en páginas de error

        # Límites y timeouts: cortan clientes lentos (Slowloris) y peticiones enormes
        client_max_body_size        10m;  # tamaño máximo del cuerpo (subidas)
        client_body_timeout         10s;
        client_header_timeout       10s;
        keepalive_timeout           15s;
        send_timeout                10s;
        large_client_header_buffers 4 8k;

        # Zonas de rate limiting por IP de origen (se aplican en cada server/location)
        limit_req_zone  $binary_remote_addr zone=por_ip:10m rate=10r/s;
        limit_conn_zone $binary_remote_addr zone=conn_ip:10m;

        # TLS "intermediate" (TLSRef Guideline v6.0, nginx 1.30, OpenSSL 3.5)
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ecdh_curve X25519MLKEM768:X25519:prime256v1:secp384r1;  # X25519MLKEM768 requiere OpenSSL >= 3.5
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
        ssl_prefer_server_ciphers off;    # todas las suites son fuertes: deja elegir al cliente
        ssl_session_timeout 1d;
        ssl_session_cache shared:MozSSL:10m;  # unas 40000 sesiones

        include /etc/nginx/conf.d/*.conf;
    }
    ```

    ```nginx title="/etc/nginx/conf.d/sitio.conf"
    # HTTP solo redirige a HTTPS
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        return 308 https://$host$request_uri;
    }

    server {
        listen 443 ssl default_server;
        listen [::]:443 ssl default_server;
        http2 on;
        server_name localhost;

        ssl_certificate     /etc/nginx/certs/server.crt;   # certificado + intermedios
        ssl_certificate_key /etc/nginx/certs/server.key;   # permisos 600, dueño root

        # Cabeceras de seguridad ("always" = también en respuestas 4xx/5xx)
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
        add_header Content-Security-Policy "default-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;

        limit_req  zone=por_ip burst=20 nodelay;   # ráfagas de hasta 20 peticiones, luego 503
        limit_conn conn_ip 20;                      # máximo 20 conexiones simultáneas por IP

        # Solo los métodos que la aplicación usa
        if ($request_method !~ ^(GET|HEAD|POST)$) {
            return 405;
        }

        # Nunca servir archivos ocultos (.git, .env, .htpasswd)
        location ~ /\. {
            deny all;
        }

        location / {
            root  /usr/share/nginx/html;
            index index.html;
        }
    }
    ```

=== "Apache"

    ```apache title="/etc/httpd/conf.d/seguridad.conf (o conf/extra/ en httpd oficial)"
    # Requiere mod_ssl, mod_headers, mod_rewrite, mod_reqtimeout, mod_socache_shmcb y mod_http2
    # Apache no admite comentarios al final de una línea: van siempre en su propia línea

    # Cabecera "Server: Apache" sin versión ni módulos, y sin firma en páginas de error
    ServerTokens Prod
    ServerSignature Off
    # Deshabilita el método TRACE
    TraceEnable Off
    # Timeouts y tamaño máximo del cuerpo (10 MB); RequestReadTimeout mitiga Slowloris
    Timeout 30
    RequestReadTimeout header=10-20,MinRate=500 body=20,MinRate=500
    LimitRequestBody 10485760

    <Directory "/usr/local/apache2/htdocs">
        # Sin listado de directorios ni SSI, e ignorando .htaccess
        Options -Indexes -Includes
        AllowOverride None
        Require all granted
    </Directory>
    # Nunca servir archivos ocultos (.git, .env, .htpasswd)
    <FilesMatch "^\.">
        Require all denied
    </FilesMatch>

    # TLS "intermediate" (TLSRef Guideline v6.0)
    Listen 443
    SSLProtocol             -all +TLSv1.2 +TLSv1.3
    SSLOpenSSLConfCmd       Curves X25519MLKEM768:X25519:prime256v1:secp384r1
    SSLCipherSuite          ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305
    SSLCipherSuite          TLSv1.3 TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    SSLHonorCipherOrder     off
    SSLSessionTickets       off
    SSLSessionCache         "shmcb:logs/ssl_scache(512000)"

    <VirtualHost *:80>
        RewriteEngine On
        RewriteCond %{REQUEST_URI} !^/.well-known/acme-challenge/
        RewriteRule ^.*$ https://%{HTTP_HOST}%{REQUEST_URI} [R=308,QSA,L]
    </VirtualHost>

    <VirtualHost *:443>
        ServerName localhost
        SSLEngine on
        SSLCertificateFile    /usr/local/apache2/certs/server.crt
        SSLCertificateKeyFile /usr/local/apache2/certs/server.key
        Protocols h2 http/1.1
        Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"
        Header always set Content-Security-Policy "default-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'"
        Header always set X-Content-Type-Options "nosniff"
        Header always set Referrer-Policy "strict-origin-when-cross-origin"
    </VirtualHost>
    ```

    Validado con `httpd -t` en `httpd:2.4-alpine` y comprobado con una petición HTTPS: `Server: Apache` sin versión y las cabeceras presentes.

## Cabeceras de seguridad

| Cabecera | Qué evita | Cuidado con |
| --- | --- | --- |
| `Strict-Transport-Security` (**HSTS**) | Que el navegador vuelva a usar HTTP (downgrade, SSL stripping) | `includeSubDomains` afecta a **todos** los subdominios; empieza con un `max-age` corto |
| `Content-Security-Policy` (**CSP**) | XSS e inyección de recursos de terceros | Rompe scripts inline y CDNs no declarados; pruébala con `Content-Security-Policy-Report-Only` |
| `frame-ancestors` (dentro de CSP) | **Clickjacking** (incrustar tu web en un iframe ajeno) | Sustituye a `X-Frame-Options`, que solo se mantiene por compatibilidad |
| `X-Content-Type-Options: nosniff` | Que el navegador "adivine" el tipo y ejecute un archivo como script | Sirve los `Content-Type` correctos |
| `Referrer-Policy` | Filtrar URLs internas o tokens en el `Referer` | — |
| `Permissions-Policy` | Uso de cámara, micrófono, geolocalización desde tu origen o iframes | Declara solo lo que uses |

!!! tip "OCSP stapling"
    El generador ofrece `ssl_stapling on` como opción. Antes de activarlo, revisa si tu CA sigue publicando OCSP: varias (incluida Let's Encrypt en 2025) lo retiraron en favor de las CRL, y con certificados sin URI de OCSP la directiva no aporta nada.

## Cómo verificar el servidor web

```bash
# Validar la sintaxis antes de recargar (en el contenedor o en el host)
docker exec hard-nginx nginx -t
curl -skI https://localhost:8443/
curl -sI  http://localhost:8080/ | head -1
```

```text title="Salida real (abreviada)"
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful

HTTP/1.1 200 OK
Server: nginx
Strict-Transport-Security: max-age=63072000; includeSubDomains
Content-Security-Policy: default-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()

HTTP/1.1 308 Permanent Redirect
```

`Server: nginx` ya no muestra la versión. Además, `GET /.git/config` devolvió `403` y `DELETE /` devolvió `405`.

**testssl.sh** revisa protocolos, suites, certificado, cabeceras y vulnerabilidades conocidas de TLS. Se ejecutó en contenedor (imagen `drwetter/testssl.sh:3.2`, 72 s):

```bash
docker run --rm --network hard-net drwetter/testssl.sh:3.2 --quiet --color 0 hard-nginx:443
```

```text title="Salida real de testssl.sh (abreviada)"
 SSLv2      not offered (OK)
 SSLv3      not offered (OK)
 TLS 1      not offered
 TLS 1.1    not offered
 TLS 1.2    offered (OK)
 TLS 1.3    offered (OK): final
 ALPN/HTTP2 h2, http/1.1 (offered)

 Obsoleted CBC ciphers (AES, ARIA etc.)            not offered
 Forward Secrecy strong encryption (AEAD ciphers)  offered (OK)
 KEMs offered                 X25519MLKEM768
 Strict Transport Security    730 days=63072000 s, includeSubDomains
 Server banner                nginx

 Heartbleed (CVE-2014-0160)                not vulnerable (OK), no heartbeat extension
 ROBOT                                     Server does not support any cipher suites that use RSA key transport
 BEAST (CVE-2011-3389)                     not vulnerable (OK), no SSL3 or TLS1

 Chain of trust               NOT ok (self signed)
 Overall Grade                T
 Grade cap reasons            Grade capped to T. Issues with chain of trust (self signed)
```

La nota `T` se debe **solo** al certificado autofirmado del laboratorio; con un certificado de una CA pública desaparece ese límite. La simulación de clientes mostró que navegadores actuales (Chromium 137, Firefox 137, Edge 133) negocian TLS 1.3 con `X25519MLKEM768`, y que IE 8 y Java 7 ya no conectan, como corresponde al perfil intermediate.

Si no tienes testssl.sh a mano, `openssl s_client` da una comprobación rápida:

```bash
openssl s_client -connect hard-nginx:443 -servername localhost -brief </dev/null
openssl s_client -connect hard-nginx:443 -tls1_1 -cipher 'DEFAULT@SECLEVEL=0' -brief </dev/null
```

```text title="Salida real (abreviada)"
Protocol version: TLSv1.3
Ciphersuite: TLS_AES_256_GCM_SHA384
Negotiated TLS1.3 group: X25519MLKEM768

...:error:0A00042E:SSL routines:ssl3_read_bytes:tlsv1 alert protocol version:...:SSL alert number 70
```

El segundo comando fuerza TLS 1.1 (bajando el nivel de seguridad del cliente, que si no se niega por su cuenta) y el servidor lo rechaza con `protocol version`. Para sitios públicos, añade **Mozilla HTTP Observatory**, que puntúa las cabeceras desde fuera. Más sobre TLS y el handshake en [Protocolos de aplicación](../../networking/intermedio/protocolos-aplicacion.md); para probar la aplicación en sí, [Pruebas dinámicas](../codigo-y-dependencias/pruebas-dinamicas.md).

## Errores comunes

- **Romper producción por endurecer sin probar**: activar HSTS con `includeSubDomains` (o `preload`) y descubrir un subdominio que solo funciona por HTTP; o una CSP estricta que bloquea el JavaScript de la aplicación. Prueba en staging, usa `Report-Only` y despliega por fases.
- Recargar sin validar: siempre `nginx -t` o `apachectl configtest` antes del reload.
- Copiar una configuración TLS antigua de un blog. Genera la tuya en TLSRef Configurator con tus versiones reales.
- Medir solo una vez: sin re-escaneo periódico la configuración vuelve a derivar (ver [Hardening como código](hardening-como-codigo.md)).

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Load balancers, API gateways y WAF gestionados | [Seguridad de APIs y aplicaciones expuestas](../../cloud/seguridad/seguridad-apis-aplicaciones.md) |
| DevSecOps (la verificación) | Otros servicios, sistema operativo y pruebas de la aplicación en marcha | [Hardening de servicios](hardening-servicios.md), [Hardening de Linux](hardening-linux.md), [DAST](../escaneos/dast.md) |
| Networking (la base) | TLS, HTTP y reverse proxies | [Protocolos de aplicación](../../networking/intermedio/protocolos-aplicacion.md), [Balanceo y alta disponibilidad de red](../../networking/avanzado/balanceo-alta-disponibilidad.md) |

## Referencias

- [TLSRef Configurator (antes Mozilla SSL Configuration Generator)](https://configurator.tlsref.org/)
- [Mozilla SSL Configuration Generator (redirige a TLSRef)](https://ssl-config.mozilla.org/)
- [Mozilla HTTP Observatory](https://developer.mozilla.org/en-US/observatory)
- [MDN: cabeceras HTTP de seguridad (Strict-Transport-Security, CSP)](https://developer.mozilla.org/es/docs/Web/HTTP/Headers/Strict-Transport-Security)
- [OWASP HTTP Headers Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html)
- [NGINX: módulo ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [Apache HTTP Server: Security Tips](https://httpd.apache.org/docs/2.4/misc/security_tips.html)
- [testssl.sh](https://github.com/testssl/testssl.sh)
- [CIS Benchmarks (NGINX y Apache)](https://www.cisecurity.org/cis-benchmarks)
