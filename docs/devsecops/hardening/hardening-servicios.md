---
tags:
  - devsecops
  - hardening
  - seguridad
  - tls
  - contenedores
  - docker
---

# Hardening de servicios: bases de datos y Docker

> Configuraciones seguras de referencia para PostgreSQL y MySQL/MariaDB (red, autenticación, TLS, roles) y el daemon de Docker, con su verificación real en contenedores: `psql` y `docker-bench-security`. Los servidores web están en [Hardening de servidores web](hardening-servidores-web.md).

!!! info "Dónde encaja"
    Esta nota cubre servicios que **tú instalas y operas** (en una VM, en un contenedor o en tu datacenter). Si usas el servicio gestionado del proveedor (RDS, Azure Database, Cloud SQL, un load balancer gestionado), parte del hardening lo hace él y tú configuras opciones: ver [Seguridad de bases de datos gestionadas](../../cloud/seguridad/seguridad-bases-datos.md) y [Seguridad de APIs y aplicaciones expuestas](../../cloud/seguridad/seguridad-apis-aplicaciones.md). El sistema operativo de debajo va en [Hardening de Linux](hardening-linux.md) y el ciclo general en [Fundamentos de hardening](fundamentos-hardening.md). Kubernetes tiene su propia nota: [Seguridad de Kubernetes](../infraestructura-y-contenedores/seguridad-kubernetes.md).

!!! note "Cómo se probó"
    Todo lo que tiene "salida real" se ejecutó en contenedores Docker desechables (`hard-pg`, `hard-mariadb`) con **PostgreSQL 18.6** y **MariaDB 11.8**, con un certificado autofirmado. Las salidas están abreviadas.

## ¿Qué es?

Endurecer un servicio es cambiar sus valores por defecto (pensados para "que funcione a la primera") por valores seguros: no revelar versiones, escuchar solo donde hace falta, exigir cifrado y autenticación fuerte, limitar recursos y registrar lo importante. Se apoya en las mismas fuentes que el resto del bloque: **CIS Benchmarks** (PostgreSQL, MySQL, Docker) y la documentación del proyecto.

| Servicio | Lo mínimo | Herramienta de verificación |
| --- | --- | --- |
| Base de datos | Escucha solo en red privada, `scram-sha-256`, TLS obligatorio, roles mínimos, auditoría | `pg_hba_file_rules`, `pg_stat_ssl`, `SHOW VARIABLES` |
| Docker | `daemon.json` endurecido, contenedores sin root y sin privilegios, logs con rotación | `dockerd --validate`, `docker-bench-security` |

La configuración de NGINX y Apache (TLS, cabeceras, límites) está en [Hardening de servidores web](hardening-servidores-web.md).

## Bases de datos

=== "PostgreSQL"

    ```ini title="postgresql.conf (extracto)"
    # --- Conexiones ---
    listen_addresses = '*'                 # en el contenedor; en una VM usa la IP privada concreta ('10.0.2.15')
    port = 5432
    max_connections = 100

    # --- Autenticación ---
    password_encryption = scram-sha-256    # nunca md5 (PostgreSQL 18 lo marca como obsoleto)
    authentication_timeout = 30s

    # --- TLS (TLSRef Guideline v6.0, intermediate, PostgreSQL 18) ---
    ssl = on
    ssl_cert_file = '/var/lib/postgresql/certs/server.crt'
    ssl_key_file  = '/var/lib/postgresql/certs/server.key'   # dueño postgres, permisos 0600
    ssl_min_protocol_version = 'TLSv1.2'
    ssl_groups = 'X25519MLKEM768:X25519:prime256v1:secp384r1'  # parámetro nuevo en PostgreSQL 18
    ssl_ciphers = 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305'

    # --- Logging de seguridad ---
    log_connections = 'receipt,authentication,authorization'   # en PostgreSQL 18 es una lista (antes on/off)
    log_disconnections = on
    log_line_prefix = '%m [%p] %q%u@%d from %h '
    log_statement = 'ddl'                  # registra CREATE/ALTER/DROP
    # shared_preload_libraries = 'pgaudit' # auditoría detallada (requiere instalar la extensión)
    ```

    ```text title="pg_hba.conf"
    # Se evalúa de arriba abajo: gana la primera línea que coincide
    # TYPE     DATABASE  USER       ADDRESS          METHOD
    local      all       postgres                    peer            # admin solo desde el socket local, como usuario del SO
    local      all       all                         scram-sha-256
    hostssl    appdb     app_rw     172.16.0.0/12    scram-sha-256   # la app, solo con TLS y desde su red
    hostnossl  all       all        0.0.0.0/0        reject          # cualquier intento sin TLS
    host       all       all        0.0.0.0/0        reject          # todo lo demás, rechazado
    host       all       all        ::/0             reject
    ```

    ```sql title="Rol de aplicación con permisos mínimos"
    CREATE ROLE app_rw LOGIN PASSWORD '...';          -- la contraseña, desde un gestor de secretos
    REVOKE ALL ON DATABASE appdb FROM PUBLIC;          -- nadie se conecta "por defecto"
    REVOKE CREATE ON SCHEMA public FROM PUBLIC;        -- ya es así desde PostgreSQL 15; explícito no sobra
    GRANT CONNECT ON DATABASE appdb TO app_rw;
    GRANT USAGE ON SCHEMA public TO app_rw;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw;   -- sin DDL ni superuser
    ```

    Verificación (salida real, PostgreSQL 18.6):

    ```text
    =# SHOW password_encryption;                     -> scram-sha-256
    =# SELECT left(rolpassword,14) FROM pg_authid WHERE rolname='app_rw';  -> SCRAM-SHA-256$
    =# SELECT line_number, type, auth_method, error FROM pg_hba_file_rules;   -- columna error vacía en las 6 reglas

    $ psql "host=hard-pg dbname=appdb user=app_rw sslmode=disable"
    FATAL:  pg_hba.conf rejects connection for host "172.21.0.4", user "app_rw", database "appdb", no encryption

    $ psql "host=hard-pg dbname=appdb user=app_rw sslmode=require" -c "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();"
     ssl | version |         cipher
     t   | TLSv1.3 | TLS_AES_256_GCM_SHA384

    $ psql "host=hard-pg dbname=appdb user=postgres sslmode=require"
    FATAL:  pg_hba.conf rejects connection for host "172.21.0.4", user "postgres", database "appdb", SSL encryption

    LOG:  connection authenticated: identity="app_rw" method=scram-sha-256 (/etc/postgresql/pg_hba.conf:5)
    ```

    `pg_hba_file_rules` es la forma de **validar** `pg_hba.conf` antes de `SELECT pg_reload_conf();`: si una línea tiene un error, aparece en la columna `error`. En producción usa `sslmode=verify-full` en los clientes para validar también el certificado y el nombre del servidor.

    Para auditoría detallada (quién leyó o cambió qué), la extensión **pgAudit** registra sentencias por clase (`pgaudit.log = 'ddl, role, write'`); no viene en la imagen oficial, así que no se probó aquí.

=== "MySQL / MariaDB"

    Tras instalar, ejecuta el asistente: `mysql_secure_installation` en MySQL o `mariadb-secure-installation` en MariaDB (quita usuarios anónimos y la base `test`, y evita el login remoto de root).

    ```ini title="/etc/mysql/conf.d/90-hardening.cnf"
    # En MySQL la sección se llama [mysqld]
    # Los comentarios van en su propia línea: al final de un valor lo invalidan
    [mariadbd]
    # En el contenedor; en una VM, la IP privada concreta
    bind-address             = 0.0.0.0
    # Rechaza conexiones sin TLS
    require_secure_transport = ON
    tls_version              = TLSv1.2,TLSv1.3
    # Evita LOAD DATA LOCAL (lectura de archivos del cliente)
    local_infile             = OFF
    # Autoriza por IP, no por DNS inverso
    skip_name_resolve        = ON
    symbolic-links           = 0
    ```

    Verificación (salida real, MariaDB 11.8.9, que genera un certificado TLS propio si no le das uno):

    ```text
    MariaDB> SHOW GLOBAL VARIABLES WHERE Variable_name IN ('require_secure_transport','tls_version','local_infile','have_ssl');
    have_ssl                  YES
    local_infile              OFF
    require_secure_transport  ON
    tls_version               TLSv1.2,TLSv1.3

    $ mariadb -h hard-mariadb -uroot -p --skip-ssl -e "SELECT 1"
    ERROR 3159 (08004): Connections using insecure transport are prohibited while --require_secure_transport=ON.

    MariaDB> SELECT user, host FROM mysql.user;
    root    %          <- la imagen oficial crea root accesible desde cualquier host
    ```

    Ese `root@'%'` es un buen ejemplo de valor por defecto inseguro: en producción, define `MARIADB_ROOT_HOST` (o elimina ese usuario) y crea usuarios por aplicación con `GRANT` solo sobre su base, con `REQUIRE SSL` si quieres reforzarlo por usuario.

Comandos útiles del cliente en [Comandos de MySQL](../../recursos/comandos/mysql.md).

## Runtime de contenedores: el daemon de Docker

```json title="/etc/docker/daemon.json"
{
  "icc": false,
  "userns-remap": "default",
  "no-new-privileges": true,
  "live-restore": true,
  "userland-proxy": false,
  "log-level": "info",
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "default-ulimits": { "nofile": { "Name": "nofile", "Soft": 64000, "Hard": 64000 } },
  "default-address-pools": [ { "base": "10.200.0.0/16", "size": 24 } ]
}
```

JSON no admite comentarios, así que la explicación va aparte:

| Clave | Qué hace | Control CIS (docker-bench) |
| --- | --- | --- |
| `icc: false` | Los contenedores de la red `bridge` por defecto no se hablan entre sí (usa redes definidas por el usuario) | 2.2 |
| `userns-remap` | El root del contenedor se mapea a un usuario sin privilegios del host | 2.9 |
| `no-new-privileges` | Ningún proceso gana privilegios con binarios setuid | 2.14 |
| `live-restore` | Los contenedores siguen corriendo si el daemon se reinicia o actualiza | 2.15 |
| `userland-proxy: false` | Usa iptables/nftables en lugar del proceso `docker-proxy` para publicar puertos | 2.16 |
| `log-opts` | Rotación de logs: evita llenar el disco | — (y 2.13: enviar logs a un sistema central) |
| `default-address-pools` | Rangos propios para no solapar con tus redes (ver [Direccionamiento IP](../../networking/basico/direccionamiento-ip.md)) | — |

```bash
# Validar el archivo sin arrancar el daemon (Docker 23+)
dockerd --validate --config-file /etc/docker/daemon.json
```

```text title="Salida real (dockerd 29.9.2 en contenedor docker:dind)"
level=warning msg="userns remapping enabled, disabling containerd snapshotter"
configuration OK
```

!!! warning "`userns-remap` tiene consecuencias"
    Cambia los dueños efectivos de los volúmenes (los bind mounts pueden dar *permission denied*), desactiva el *containerd image store* (lo dice el aviso de arriba) y no se combina con `--privileged` ni con namespaces del host. Pruébalo antes en un nodo aparte. Una alternativa más limpia es **Docker rootless mode**: el daemon entero corre como usuario sin privilegios (`dockerd-rootless-setuptool.sh install`), con límites conocidos (puertos < 1024, algunos drivers de red y de almacenamiento).

El daemon es solo la mitad: cada contenedor debería arrancar con usuario no root, `--read-only`, `--cap-drop ALL`, `--security-opt no-new-privileges`, límites de memoria, CPU y PIDs, y nunca con el socket de Docker montado. Eso está en [Seguridad de contenedores](../infraestructura-y-contenedores/seguridad-contenedores.md).

### docker-bench-security

**docker-bench-security** (v1.6.0, basado en el CIS Docker Benchmark 1.6.0; CIS ha publicado versiones posteriores del benchmark, revisa la vigente) comprueba host, daemon, archivos de configuración, imágenes y contenedores en ejecución. Solo lee. La imagen publicada en Docker Hub está desactualizada; el proyecto pide construirla:

```bash
git clone https://github.com/docker/docker-bench-security.git
cd docker-bench-security
docker build --no-cache -t docker-bench-security .
docker run --rm --net host --pid host --userns host --cap-add audit_control \
  -v /etc:/etc:ro -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --label docker_bench_security docker-bench-security
```

```text title="Salida real abreviada (Docker Desktop 28.5.1 con los contenedores de esta nota en marcha)"
# Docker Bench for Security v1.6.0
# Based on the CIS Docker Benchmark 1.6.0.

[WARN] 2.2 - Ensure network traffic is restricted between containers on the default bridge (Scored)
[PASS] 2.5 - Ensure insecure registries are not used (Scored)
[WARN] 2.9 - Enable user namespace support (Scored)
[WARN] 2.14 - Ensure containers are restricted from acquiring new privileges (Scored)
[WARN] 2.15 - Ensure live restore is enabled (Scored)
[WARN] 4.1 - Ensure that a user for the container has been created (Automated)
[WARN]      * Running as root: hard-pg
[WARN]      * Running as root: hard-nginx
[WARN] 5.13 - Ensure that the container's root filesystem is mounted as read only (Automated)
[WARN] 5.26 - Ensure that the container is restricted from acquiring additional privileges (Automated)
[WARN] 5.29 - Ensure that the PIDs cgroup limit is used (Automated)
[PASS] 5.5 - Ensure that privileged containers are not used (Automated)
[PASS] 5.32 - Ensure that the Docker socket is not mounted inside any containers (Automated)

[INFO] Checks: 117
[INFO] Score: 2
```

Cómo leerlo:

- Los `WARN` de la sección 2 son exactamente las claves del `daemon.json` de arriba: el Docker Desktop de la prueba usa la configuración por defecto.
- Los de las secciones 4 y 5 señalan cómo se lanzaron los contenedores de laboratorio (como root, con sistema de archivos escribible, sin límite de PIDs): endurecer el servicio no basta si el contenedor corre con permisos de más.
- En **Docker Desktop** el daemon vive en una VM interna; los controles de host (sección 1) y de archivos (sección 3) dicen poco. Ejecútalo en el host Linux real donde corre producción.

## Errores comunes

- **Romper producción por endurecer sin probar**: activar `require_secure_transport` antes de que todos los clientes tengan TLS. Prueba en staging y despliega por fases.
- Recargar sin validar: revisa siempre `pg_hba_file_rules` antes del reload.
- `listen_addresses = '*'` o `bind-address = 0.0.0.0` en una VM con IP pública y el firewall "abierto un momento".
- `trust` o `md5` en `pg_hba.conf` "para probar", que se quedan en producción.
- La aplicación conectándose a la base de datos como `postgres` o `root`.
- Contenedores endurecidos por dentro pero lanzados con `--privileged` o con `/var/run/docker.sock` montado.
- Medir solo una vez: sin re-escaneo periódico la configuración vuelve a derivar (ver [Hardening como código](hardening-como-codigo.md)).

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Versión gestionada de estos servicios y lo que el proveedor ya endurece | [Seguridad de bases de datos gestionadas](../../cloud/seguridad/seguridad-bases-datos.md), [Seguridad de APIs y aplicaciones expuestas](../../cloud/seguridad/seguridad-apis-aplicaciones.md), [Seguridad de contenedores y Kubernetes en la nube](../../cloud/seguridad/seguridad-contenedores-kubernetes.md) |
| DevOps (la automatización) | Construir imágenes y desplegar estos servicios con la configuración ya endurecida | [Docker](../../devops/contenedores/docker.md), [Configuration management con Ansible](../../devops/iac/ansible.md), [Hardening como código](hardening-como-codigo.md) |
| DevSecOps (la verificación) | Ciclo de hardening, sistema operativo, contenedores, Kubernetes y pruebas de la aplicación | [Fundamentos de hardening](fundamentos-hardening.md), [Hardening de Linux](hardening-linux.md), [Hardening de Windows](hardening-windows.md), [Hardening de servidores web](hardening-servidores-web.md), [Seguridad de contenedores](../infraestructura-y-contenedores/seguridad-contenedores.md), [Seguridad de Kubernetes](../infraestructura-y-contenedores/seguridad-kubernetes.md), [KSPM](../escaneos/kspm.md), [DAST](../escaneos/dast.md), [CVE en Linux, OpenSSL, OpenSSH y utilidades base](../vulnerabilidades/cve-linux-sistemas.md) |
| Networking (la base) | TLS, HTTP y reverse proxies sobre los que se apoya todo esto | [Protocolos de aplicación](../../networking/intermedio/protocolos-aplicacion.md), [Balanceo y alta disponibilidad de red](../../networking/avanzado/balanceo-alta-disponibilidad.md), [Seguridad de red](../../networking/avanzado/seguridad-red.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 22: Endurecer un servidor Linux con Ansible y medirlo con Lynis y OpenSCAP](../../laboratorios/devsecops/hardening-linux-ansible.md) |

## Referencias

- [PostgreSQL: el archivo pg_hba.conf](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html)
- [PostgreSQL: conexiones TCP/IP seguras con SSL](https://www.postgresql.org/docs/current/ssl-tcp.html)
- [pgAudit](https://github.com/pgaudit/pgaudit)
- [MariaDB: mariadb-secure-installation](https://mariadb.com/kb/en/mariadb-secure-installation/)
- [MySQL: mysql_secure_installation](https://dev.mysql.com/doc/refman/8.4/en/mysql-secure-installation.html)
- [Docker: daemon configuration file](https://docs.docker.com/reference/cli/dockerd/#daemon-configuration-file)
- [Docker: user namespace remapping](https://docs.docker.com/engine/security/userns-remap/)
- [Docker: rootless mode](https://docs.docker.com/engine/security/rootless/)
- [docker-bench-security](https://github.com/docker/docker-bench-security)
- [CIS Benchmarks (PostgreSQL, MySQL, Docker)](https://www.cisecurity.org/cis-benchmarks)
- [Comandos de Docker](../../recursos/comandos/docker.md)
