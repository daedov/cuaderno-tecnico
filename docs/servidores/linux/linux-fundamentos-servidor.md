---
tags:
  - servidores
  - linux
  - systemd
  - administracion
---

# Linux Server: fundamentos de administración

> Lo que necesitas para administrar un servidor Linux con soltura: elegir distro, entender el arranque, usuarios, permisos, paquetes, servicios con systemd, logs con journald, hostname y hora, con comandos probados en Ubuntu 24.04 LTS y Rocky Linux 10.

!!! info "Antes de leer"
    Conviene que manejes la terminal (moverte por directorios, editar un archivo, `sudo`). Los conceptos de Bash, systemd y SSH orientados a DevOps están en [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md) y la guía de comandos de [Linux](../../recursos/comandos/linux.md). Aquí no se repite el **hardening** (endurecimiento): para eso ve a [Hardening de Linux](../../devsecops/hardening/hardening-linux.md).

!!! note "Cómo se probaron los ejemplos"
    Las salidas son reales, abreviadas, de contenedores Docker con systemd como PID 1 (`ubuntu:24.04` con systemd 255 y `rockylinux/rockylinux:10` con systemd 257). Un contenedor no es una VM: no hay GRUB ni kernel propio, y algunos comandos (por ejemplo cambiar el hostname) fallan dentro de él. Donde pasa, se indica.

## ¿Qué es un servidor Linux?

Un **servidor** es una máquina (física, VM o instancia en la nube) que ofrece servicios a otras: una API, una base de datos, un *file server*. En la práctica, administrar Linux Server es dominar seis cosas: **quién** entra (usuarios y sudo), **qué** puede tocar (permisos), **qué software** hay (paquetes), **qué corre** (servicios con systemd), **qué pasó** (logs) y **dónde y cuándo** está (hostname y hora). Las notas hermanas cubren [almacenamiento](linux-almacenamiento.md), [redes](linux-redes-servidor.md) y [procesos y rendimiento](linux-procesos-rendimiento.md).

## Distribuciones de servidor

Una **distro** (distribución) es el kernel Linux más un conjunto de paquetes, un gestor de paquetes y una política de soporte. En servidores importan sobre todo dos familias:

| Distro | Familia / paquetes | Soporte (orientativo) | Dónde la verás |
| --- | --- | --- | --- |
| **Ubuntu Server LTS** (24.04, 26.04) | Debian / `apt`, `.deb` | 5 años estándar; hasta 10+ con Ubuntu Pro (ESM) | Nube pública, startups, Kubernetes |
| **Debian** (13 "trixie") | Debian / `apt` | ~3 años + Debian LTS hasta ~5 | Servidores "de toda la vida", imágenes base |
| **RHEL** (Red Hat Enterprise Linux 9 y 10) | Red Hat / `dnf`, `.rpm` | 10 años (Full + Maintenance) + soporte extendido de pago | Empresa, banca, sector público |
| **Rocky Linux / AlmaLinux** (9 y 10) | Clones compatibles con RHEL / `dnf` | Siguen el ciclo de RHEL, gratis | Quien quiere RHEL sin suscripción |
| **SUSE Linux Enterprise Server (SLES)** | SUSE / `zypper`, `.rpm` | Ciclo largo empresarial | SAP y entornos europeos |

!!! tip "Cómo elegir"
    En una entrevista, la respuesta corta es: **LTS o enterprise, nunca una versión intermedia** en producción. Elige la familia que tu equipo ya sabe operar y que tus proveedores certifican (p. ej. SAP certifica SLES y RHEL). Revisa siempre la fecha de fin de soporte (*End of Life*, **EOL**) antes de crear un servidor: los ciclos cambian y la referencia es la página oficial de cada distro.

Para saber qué tienes delante:

```bash
cat /etc/os-release | head -4
uname -r                # versión del kernel
```

```text
PRETTY_NAME="Ubuntu 24.04.5 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.5 LTS (Noble Numbat)"
5.15.146.1-microsoft-standard-WSL2
```

## Arranque: de firmware a systemd

```mermaid
flowchart LR
    A[Firmware<br/>UEFI o BIOS] --> B[Bootloader<br/>GRUB 2]
    B --> C[Kernel + initramfs]
    C --> D[systemd<br/>PID 1]
    D --> E[default.target<br/>multi-user o graphical]
```

1. **Firmware** (UEFI en equipos modernos, BIOS en antiguos): inicializa el hardware y busca un disco arrancable.
2. **GRUB 2** (el **bootloader**, cargador de arranque): muestra el menú, carga el kernel y el **initramfs** (sistema de archivos inicial en memoria con los drivers necesarios para montar `/`). Su configuración se edita en `/etc/default/grub` y se regenera (`update-grub` en Ubuntu, `grub2-mkconfig -o ...` o `grubby` en RHEL).
3. **Kernel**: monta la raíz y ejecuta el primer proceso.
4. **systemd** (PID 1): arranca las units en paralelo según sus dependencias hasta alcanzar el **target** por defecto.

Un **target** es un grupo de units que define un "estado" del sistema (el equivalente moderno de los antiguos *runlevels*):

| Target | Para qué | Runlevel antiguo |
| --- | --- | --- |
| `multi-user.target` | Servidor normal: red y servicios, sin entorno gráfico | 3 |
| `graphical.target` | Igual + escritorio | 5 |
| `rescue.target` | Modo monousuario con sistemas de archivos montados | 1 |
| `emergency.target` | Shell mínima, raíz en solo lectura (para reparar fstab, por ejemplo) | — |

```bash
systemctl get-default                       # target por defecto
sudo systemctl set-default multi-user.target
systemd-analyze blame | head                # qué units tardaron más en el arranque
journalctl -b -1 -p err                     # errores del arranque anterior
```

!!! tip "Arrancar en rescue desde GRUB"
    Si un servidor no arranca (por ejemplo por un `/etc/fstab` roto), en el menú de GRUB pulsa `e`, añade `systemd.unit=rescue.target` (o `emergency.target`) al final de la línea `linux` y arranca con `Ctrl+X`. En la nube, usa la consola serie del proveedor (EC2 Serial Console, Azure Serial Console, consola serie de Compute Engine).

## Jerarquía de archivos (FHS)

El **Filesystem Hierarchy Standard** (**FHS**, estándar de jerarquía del sistema de archivos) define dónde va cada cosa. Saberlo te dice dónde buscar sin adivinar:

| Ruta | Contenido | Ejemplo |
| --- | --- | --- |
| `/etc` | Configuración del sistema y servicios (texto) | `/etc/ssh/sshd_config`, `/etc/fstab` |
| `/var` | Datos variables: logs, colas, cachés, bases de datos | `/var/log`, `/var/lib/mysql` |
| `/opt` | Software de terceros autocontenido | `/opt/miapp` |
| `/srv` | Datos que sirve el servidor | `/srv/www`, `/srv/ftp` |
| `/home` | Directorios de usuarios | `/home/ana` |
| `/usr` | Programas y librerías del sistema (solo lectura en operación) | `/usr/bin`, `/usr/lib/systemd/system` |
| `/tmp`, `/var/tmp` | Temporales (`/tmp` se suele vaciar al reiniciar, `/var/tmp` no) | |
| `/proc` | Sistema de archivos virtual con procesos y kernel | `/proc/cpuinfo`, `/proc/<pid>/limits` |
| `/sys` | Vista virtual de dispositivos y parámetros del kernel | `/sys/block/sda` |
| `/boot` | Kernel, initramfs y GRUB | |

!!! warning "/usr/lib frente a /etc"
    Los archivos que instala un paquete viven en `/usr/lib/...` (p. ej. `/usr/lib/systemd/system/ssh.service`). **No los edites**: la próxima actualización los sobrescribe. Tus cambios van en `/etc/...`, que tiene prioridad.

## Usuarios y grupos

```bash
sudo useradd -m -s /bin/bash -c "Ana Ops" ana   # -m crea /home/ana, -s shell
sudo groupadd devops
sudo usermod -aG devops,sudo ana                # -a = añadir; sin -a REEMPLAZA los grupos
id ana
```

```text
uid=1001(ana) gid=1001(ana) groups=1001(ana),27(sudo),1002(devops)
```

| Comando | Qué hace |
| --- | --- |
| `passwd ana` / `chpasswd` | Fija la contraseña (interactivo / en lote desde stdin) |
| `passwd -l ana` / `usermod -L ana` | Bloquea la contraseña (las llaves SSH siguen funcionando) |
| `usermod -s /usr/sbin/nologin ana` | Impide el login interactivo |
| `chage -l ana` | Muestra la caducidad de la contraseña |
| `userdel -r ana` | Borra el usuario y su home |
| `useradd --system --shell /usr/sbin/nologin miapp` | **Service account** (cuenta de servicio) para un demonio |

Los tres archivos que conviene saber leer:

```text title="/etc/passwd  (nombre:x:UID:GID:comentario:home:shell)"
ana:x:1001:1001:Ana Ops:/home/ana:/bin/bash
```

```text title="/etc/shadow  (nombre:hash:último cambio:mín:máx:aviso:...)"
ana:!:20753:0:99999:7:::
```

```text title="/etc/group  (grupo:x:GID:miembros)"
devops:x:1002:ana
```

En `/etc/shadow`, un `!` o `*` en el campo del hash significa "sin contraseña válida" (cuenta bloqueada para login con contraseña). Lee siempre estos archivos con `getent passwd ana` o `getent group devops`: `getent` también consulta LDAP/SSSD si el servidor está unido a un directorio.

### sudo y sudoers

El grupo administrador cambia según la familia: **`sudo`** en Ubuntu/Debian y **`wheel`** en RHEL/Rocky (`%wheel ALL=(ALL) ALL` en `/etc/sudoers`). Para reglas propias, crea un archivo en `/etc/sudoers.d/` y edítalo **siempre con `visudo`**, que valida la sintaxis antes de guardar: un sudoers roto te deja sin `sudo`.

```text title="/etc/sudoers.d/devops"
# El grupo devops puede reiniciar nginx como root sin contraseña, y nada más
%devops ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx
```

```bash
sudo visudo -f /etc/sudoers.d/devops     # editar con validación
sudo chmod 440 /etc/sudoers.d/devops
sudo visudo -c                           # validar todo
sudo -l -U ana                           # qué puede hacer ana
```

```text
/etc/sudoers: parsed OK
/etc/sudoers.d/README: parsed OK
/etc/sudoers.d/devops: parsed OK

User ana may run the following commands on srv-lx-ubuntu:
    (ALL : ALL) ALL
    (root) NOPASSWD: /usr/bin/systemctl restart nginx
```

Con un error tipográfico (`NOPASWD`), `visudo -cf` lo detecta:

```text
/tmp/bad:1:39: syntax error
%devops ALL=(root) NOPASWD: /usr/bin/x
                                      ^
```

Las políticas de sudo (registro, `use_pty`, quién debe tener sudo) están en [Hardening de Linux](../../devsecops/hardening/hardening-linux.md).

## Permisos

Cada archivo tiene **dueño**, **grupo** y permisos para tres clases: *user* (u), *group* (g) y *others* (o). Cada clase tiene **r** (leer, 4), **w** (escribir, 2) y **x** (ejecutar o, en directorios, entrar; 1). La notación **octal** suma esos valores: `640` = `rw-` (6) para el dueño, `r--` (4) para el grupo, `---` (0) para el resto.

```bash
sudo chown ana:devops /srv/app/config.yml
sudo chmod 640 /srv/app/config.yml        # o: chmod u=rw,g=r,o= ...
stat -c "%a %A %U:%G" /srv/app/config.yml
```

```text
640 -rw-r----- ana:devops
```

| Octal | Archivo típico |
| --- | --- |
| `600` | Llave privada, `.env` con secretos |
| `640` | Configuración legible por el grupo del servicio |
| `644` | Archivo público de solo lectura |
| `755` | Script o directorio accesible por todos |
| `750` | Directorio solo para dueño y grupo |

### umask

La **umask** es la máscara que se **resta** de los permisos por defecto al crear archivos (666) y directorios (777). Con `022` obtienes 644/755; con `027`, 640/750:

```bash
umask             # 0022
(umask 027; touch /tmp/u; mkdir /tmp/ud; ls -ld /tmp/u /tmp/ud)
```

```text
-rw-r----- 1 root root    0 Oct 27 02:22 /tmp/u
drwxr-x--- 2 root root 4096 Oct 27 02:22 /tmp/ud
```

Para un servicio, fíjala en su unit con `UMask=0027`. Dato útil: el modo de los homes nuevos lo decide `HOME_MODE` en `/etc/login.defs`; en las pruebas era `0750` en Ubuntu 24.04 y `0700` en Rocky 10.

### SUID, SGID y sticky bit

| Bit | Octal | En archivo | En directorio | Ejemplo |
| --- | --- | --- | --- | --- |
| **SUID** | 4000 | Se ejecuta con el UID del dueño | — | `/usr/bin/passwd` (`-rwsr-xr-x`) |
| **SGID** | 2000 | Se ejecuta con el GID del grupo | Lo creado dentro hereda el grupo | Carpetas compartidas de equipo |
| **Sticky** | 1000 | — | Solo el dueño puede borrar sus archivos | `/tmp` (`drwxrwxrwt`) |

```bash
sudo chgrp devops /srv/compartido && sudo chmod 2775 /srv/compartido
ls -ld /srv/compartido /tmp /usr/bin/passwd
```

```text
drwxrwsr-x 2 root devops  4096 Oct 27 02:22 /srv/compartido
drwxrwxrwt 1 root root    4096 Oct 27 02:22 /tmp
-rwsr-xr-x 1 root root   64152 May 30  2024 /usr/bin/passwd
```

Auditar binarios SUID inesperados es tarea de hardening: ver [Hardening de Linux](../../devsecops/hardening/hardening-linux.md).

### ACL

Las **ACL** (*Access Control Lists*, listas de control de acceso) añaden permisos para usuarios o grupos concretos sin cambiar dueño ni grupo. El `+` al final de `ls -l` indica que hay ACL.

```bash
sudo setfacl -m u:auditor:r /srv/app/config.yml      # auditor puede leer
getfacl /srv/app/config.yml
sudo setfacl -d -m g:devops:rwx /srv/compartido      # -d: ACL por defecto (heredada)
sudo setfacl -x u:auditor /srv/app/config.yml        # quitar la entrada
```

```text
# file: srv/app/config.yml
# owner: ana
# group: devops
user::rw-
user:auditor:r--
group::r--
mask::r--
other::---
```

La línea `mask` limita el máximo efectivo de las entradas de grupo y de usuarios nombrados: si haces `chmod g-r` después, también recortas la ACL.

## Paquetes

| Tarea | Ubuntu/Debian | RHEL/Rocky |
| --- | --- | --- |
| Refrescar índice | `apt update` | `dnf makecache` (automático) |
| Instalar | `apt install nginx` | `dnf install nginx` |
| Buscar | `apt search nginx` | `dnf search nginx` |
| Información | `apt show nginx`, `apt-cache policy nginx` | `dnf info nginx` |
| Actualizar todo | `apt upgrade` (o `full-upgrade`) | `dnf upgrade` |
| Solo seguridad | `unattended-upgrades` | `dnf upgrade --security` |
| Qué paquete tiene este archivo | `dpkg -S /ruta` | `rpm -qf /ruta` |
| Quién provee un comando | `apt-file search` | `dnf provides /usr/bin/dig` |
| Listar instalados | `dpkg -l`, `apt list --installed` | `rpm -qa`, `dnf list --installed` |
| Fijar versión | `apt-mark hold` | `dnf versionlock add` |
| Historial / rollback | `/var/log/apt/history.log` | `dnf history`, `dnf history undo N` |
| ¿Hace falta reiniciar? | existe `/var/run/reboot-required` | `dnf needs-restarting -r` |

=== "Ubuntu/Debian"

    ```bash
    apt-cache policy chrony          # versión instalada y candidata
    dpkg -S /usr/sbin/chronyd        # a qué paquete pertenece
    sudo apt-mark hold chrony        # congelar
    apt-mark showhold
    sudo apt-mark unhold chrony
    sudo apt install nginx=<versión>  # instalar una versión concreta (ver apt-cache policy)
    ```

    ```text
    chrony:
      Installed: 4.5-1ubuntu4.2
      Candidate: 4.5-1ubuntu4.2
    chrony: /usr/sbin/chronyd
    chrony set on hold.
    ```

    Desde Ubuntu 24.04 los repositorios usan el formato **deb822** en `/etc/apt/sources.list.d/ubuntu.sources` (antes, una línea por repo en `/etc/apt/sources.list`). Para un repositorio de terceros, añade su llave en `/etc/apt/keyrings/` y referénciala con `Signed-By:`; `apt-key` está obsoleto.

=== "RHEL/Rocky"

    ```bash
    dnf info chrony
    rpm -qf /usr/sbin/chronyd
    dnf repolist
    sudo dnf install python3-dnf-plugin-versionlock   # plugin de versionlock
    sudo dnf versionlock add chrony
    dnf versionlock list
    sudo dnf versionlock delete chrony
    dnf updateinfo summary            # avisos de seguridad pendientes
    dnf needs-restarting -r           # ¿hace falta reiniciar?
    ```

    ```text
    repo id                         repo name
    appstream                       Rocky Linux 10 - AppStream
    baseos                          Rocky Linux 10 - BaseOS
    extras                          Rocky Linux 10 - Extras
    Adding versionlock on: chrony-0:4.8-2.el10.*
    Updates Information Summary: available
        28 Security notice(s)
             1 Critical Security notice(s)
            15 Important Security notice(s)
    No core libraries or services have been updated since boot-up.
    Reboot should not be necessary.
    ```

    Los repos se definen en `/etc/yum.repos.d/*.repo`. Muchos paquetes útiles (como `htop`) están en **EPEL** (*Extra Packages for Enterprise Linux*): `dnf install epel-release` en Rocky/Alma.

La lista completa de comandos de cada familia (quitar paquetes, dependencias, cachés, `unattended-upgrades` y `dnf-automatic`) está en las guías de comandos de [Debian](../../recursos/comandos/debian.md) y [Amazon Linux](../../recursos/comandos/amazon-linux.md). La política de parches automáticos y su verificación están en [Hardening de Linux](../../devsecops/hardening/hardening-linux.md#parches-automaticos); el *rolling update* (actualización gradual) de una flota con Ansible, en [Recetas de Ansible para servidores](../ansible/ansible-recetas-servidores.md#parches-con-rolling-update).

## Servicios con systemd

| Comando | Qué hace |
| --- | --- |
| `systemctl start nginx` (o `stop`, `restart`) | Arranca, para o reinicia ahora |
| `systemctl reload nginx` | Recarga la configuración sin cortar conexiones (si el servicio lo soporta) |
| `systemctl enable --now nginx` | Lo activa al arranque y lo inicia ya |
| `systemctl disable nginx` | Quita el arranque automático (no lo para) |
| `systemctl status nginx` | Estado, PID, memoria y últimas líneas de log |
| `systemctl is-active` / `is-enabled` / `is-failed` | Para scripts (código de salida) |
| `systemctl mask nginx` | Enlaza la unit a `/dev/null`: nadie puede arrancarla |
| `systemctl --failed` | Units en error |
| `systemctl cat nginx` | Unit efectiva, con drop-ins |
| `systemctl daemon-reload` | Relee los unit files tras editarlos |

### Unit file comentado

```ini title="/etc/systemd/system/miapp.service"
[Unit]
Description=Mi aplicacion de ejemplo
Documentation=https://example.com/miapp
# Arranca después de que la red esté configurada (no solo "levantada")
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
# Usuario sin privilegios creado con useradd --system
User=miapp
Group=miapp
# El "-" hace que no falle si el archivo no existe
EnvironmentFile=-/etc/default/miapp
ExecStart=/usr/local/bin/miapp.sh
# Reinicia solo si termina con error, esperando 5 s
Restart=on-failure
RestartSec=5s
# Límite de archivos abiertos para este servicio
LimitNOFILE=65536

[Install]
# "enable" lo engancha al target de servidor normal
WantedBy=multi-user.target
```

```bash
sudo systemd-analyze verify /etc/systemd/system/miapp.service   # sin salida = OK
sudo systemctl daemon-reload
sudo systemctl enable --now miapp
systemctl status miapp --no-pager
```

```text
● miapp.service - Mi aplicacion de ejemplo
     Loaded: loaded (/etc/systemd/system/miapp.service; enabled; preset: enabled)
     Active: active (running) since Tue 2026-10-27 02:23:34 UTC; 5ms ago
       Docs: https://example.com/miapp
   Main PID: 456 (bash)
     CGroup: /system.slice/miapp.service
             ├─456 bash /usr/local/bin/miapp.sh
             └─459 sleep 30
```

`systemd-analyze verify` detecta claves mal escritas que systemd ignoraría en silencio:

```text
/tmp/bad.service:3: Unknown key name 'Restartt' in section 'Service', ignoring.
```

### Drop-ins: cambiar una unit sin tocarla

Un **drop-in** es un fragmento en `/etc/systemd/system/<unit>.d/*.conf` que sobrescribe solo las claves que pones. Es la forma correcta de ajustar units que instala un paquete. `sudo systemctl edit miapp` abre el editor, crea `override.conf` y hace el `daemon-reload` por ti.

```ini title="/etc/systemd/system/miapp.service.d/override.conf"
[Service]
Environment=PORT=9090
Restart=always
```

```bash
systemctl show miapp -p Restart -p Environment -p LimitNOFILE
```

```text
Restart=always
Environment=PORT=9090
LimitNOFILE=65536
```

!!! warning "Listas en drop-ins"
    Las claves que admiten varios valores (como `ExecStart=`) se **acumulan**. Para reemplazar el comando de arranque, primero vacíalo: una línea `ExecStart=` vacía y después la nueva `ExecStart=...`.

`mask` es más fuerte que `disable`:

```text
Created symlink /etc/systemd/system/cron.service → /dev/null.
Failed to start cron.service: Unit cron.service is masked.
```

## Logs con journald

**journald** recoge stdout/stderr de todos los servicios, el log del kernel y syslog en un journal binario indexado. Se consulta con `journalctl`:

| Comando | Para qué |
| --- | --- |
| `journalctl -u miapp` | Logs de un servicio |
| `journalctl -u miapp -f` | Seguir en vivo |
| `journalctl -b` / `-b -1` | Arranque actual / anterior |
| `journalctl -p err -b` | Solo prioridad `err` o peor en este arranque |
| `journalctl --since "1 hour ago" --until "10 min ago"` | Ventana de tiempo |
| `journalctl -k` | Solo kernel (como `dmesg`) |
| `journalctl -o short-iso` / `-o json` | Formato con fecha ISO / JSON |
| `journalctl --disk-usage` | Cuánto ocupa |
| `journalctl --vacuum-size=500M` | Borrar lo más antiguo hasta 500 MB |

```bash
journalctl -u miapp -o short-iso -n 2 --no-pager
```

```text
2026-10-27T02:23:34+00:00 srv-lx-ubuntu systemd[1]: Started miapp.service - Mi aplicacion de ejemplo.
2026-10-27T02:23:34+00:00 srv-lx-ubuntu miapp.sh[488]: miapp vivo puerto=9090
```

### Persistencia del journal

Con el valor por defecto `Storage=auto`, journald guarda en disco **solo si existe `/var/log/journal`**; si no, guarda en `/run/log/journal` y los logs se pierden al reiniciar. Que exista o no depende de la distro y de la imagen (en la imagen de Ubuntu existía; en la imagen mínima de Rocky, no). Para hacerlo explícito:

```ini title="/etc/systemd/journald.conf.d/persistente.conf"
[Journal]
# Guardar siempre en /var/log/journal
Storage=persistent
# Tope de espacio para el journal persistente
SystemMaxUse=1G
```

```bash
sudo systemctl restart systemd-journald
journalctl --list-boots     # con persistencia verás varios arranques
```

### rsyslog y logrotate en lo esencial

Muchas distros mantienen **rsyslog** para escribir también archivos de texto clásicos (`/var/log/syslog` y `/var/log/auth.log` en Ubuntu; `/var/log/messages` y `/var/log/secure` en RHEL) y para reenviar logs a un servidor central. **logrotate** rota esos archivos para que no llenen el disco:

```text title="/etc/logrotate.d/rsyslog (Ubuntu 24.04, abreviado)"
/var/log/syslog
/var/log/auth.log
{
    rotate 4
    weekly
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
```

Se lee así: rota cada semana (`weekly`) y conserva 4 archivos antiguos (`rotate 4`); no falla si el log no existe (`missingok`) ni rota si está vacío (`notifempty`); comprime con gzip a partir de la segunda rotación (`compress` + `delaycompress`), y después avisa a rsyslog para que reabra los archivos (`postrotate`). Ojo: logrotate solo admite comentarios en líneas propias que empiecen con `#`, no al final de una directiva.

`sudo logrotate -d /etc/logrotate.d/miapp` hace una prueba en seco (*dry run*) sin rotar nada. Cómo leer e interpretar los logs: [Cómo leer logs](../../monitoreo/logging/leer-logs.md).

## Hostname y zona horaria

```bash
hostnamectl                                       # nombre, SO, kernel, virtualización
sudo hostnamectl set-hostname web01.ejemplo.internal
timedatectl                                       # hora, zona y si está sincronizada
sudo timedatectl set-timezone America/Lima
timedatectl list-timezones | grep America
```

```text
               Local time: Tue 2026-10-27 02:23:42 UTC
           Universal time: Tue 2026-10-27 02:23:42 UTC
                Time zone: Etc/UTC (UTC, +0000)
System clock synchronized: yes
              NTP service: active
```

!!! tip "UTC en servidores"
    Deja los servidores en **UTC** salvo que una aplicación exija otra zona: los logs de toda la flota se correlacionan sin conversiones. La sincronización NTP con chrony está en [Redes en Linux Server](linux-redes-servidor.md#sincronizacion-de-hora-con-chrony).

En el contenedor, `hostnamectl set-hostname` falló con `Device or resource busy` porque Docker gestiona el hostname; en una VM funciona. En la nube, cloud-init puede reescribir el hostname en cada arranque (`preserve_hostname: true` en su configuración lo evita).

## Casos de uso

### Un servicio no arranca tras actualizar

1. Mira el estado y el motivo: `systemctl status miapp` (busca `code=exited, status=...`).
2. Lee los logs del intento: `journalctl -u miapp -b --no-pager | tail -50`.
3. Si editaste la unit: `systemd-analyze verify` y `systemctl daemon-reload`.
4. Si el problema es la versión nueva, vuelve a la anterior: `dnf history undo <id>` o `dnf downgrade paquete` en RHEL; `apt install paquete=<versión anterior>` en Ubuntu (lista versiones con `apt-cache policy`). Después congela con `apt-mark hold` / `dnf versionlock` hasta tener la corrección.

### Dar a un equipo permiso para reiniciar un servicio, y nada más

Crea un grupo, mete a las personas y escribe una regla en `/etc/sudoers.d/` con la ruta absoluta del comando exacto (como el ejemplo de `devops` de arriba). Valida con `visudo -c` y comprueba con `sudo -l -U usuario`.

### Carpeta compartida de equipo que no se "rompe"

```bash
sudo mkdir -p /srv/compartido
sudo chgrp devops /srv/compartido
sudo chmod 2775 /srv/compartido                 # SGID: todo hereda el grupo devops
sudo setfacl -d -m g:devops:rwx /srv/compartido # ACL por defecto: el grupo siempre puede escribir
```

### Subir el límite de archivos de un servicio del proveedor

No edites `/usr/lib/systemd/system/nginx.service`. Usa `sudo systemctl edit nginx`, añade `[Service]` y `LimitNOFILE=65536`, y reinicia. Verifica con `systemctl show nginx -p LimitNOFILE`. Más detalle en [Procesos y rendimiento](linux-procesos-rendimiento.md).

### Los logs desaparecen al reiniciar

`journalctl --list-boots` muestra un solo arranque y no existe `/var/log/journal`: el journal es volátil. Aplica el drop-in `Storage=persistent` de arriba y fija `SystemMaxUse` para que no llene `/var`.

## Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| El usuario perdió todos sus grupos | `usermod -G grupo` sin `-a` | Usa siempre `usermod -aG`; restaura los grupos desde `/etc/group` o el backup |
| `sudo: parse error in /etc/sudoers` y nadie puede usar sudo | Editaste sudoers sin `visudo` | `pkexec visudo`, consola de la nube o arranque en rescue; en adelante, `visudo -f` |
| Cambio en la unit sin efecto | Falta `systemctl daemon-reload` | Recarga y reinicia; `systemctl cat` muestra lo que systemd usa |
| El cambio desaparece tras actualizar | Editaste el archivo en `/usr/lib/systemd/system` | Usa drop-ins con `systemctl edit` |
| `Permission denied` con permisos aparentemente correctos | Falta `x` en algún directorio padre, ACL `mask` restrictiva o SELinux/AppArmor | `namei -l /ruta/completa`, `getfacl`, `ausearch -m avc` (ver hardening) |
| Servicio "habilitado" que no arranca en el boot | `WantedBy=` ausente o target equivocado | Añade `[Install] WantedBy=multi-user.target` y vuelve a hacer `enable` |
| `apt upgrade` deja paquetes "kept back" | Requieren instalar o quitar dependencias | `apt full-upgrade` revisando qué cambia, o instala el paquete explícitamente |
| El servidor pide reinicio y nadie lo hace | Kernel o glibc actualizados en disco, pero no en memoria | `dnf needs-restarting -r` o `/var/run/reboot-required`; programa una ventana |

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Las VMs donde corren estos servidores, imágenes y acceso por consola | [Máquinas virtuales](../../cloud/computo/maquinas-virtuales.md), [Seguridad de máquinas virtuales](../../cloud/seguridad/seguridad-maquinas-virtuales.md) |
| DevOps (la automatización) | systemd, Bash y SSH para automatizar; gestionar todo esto como código | [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md), [Ansible](../../devops/iac/ansible.md), [Ansible para Linux](../ansible/ansible-linux.md), [Cómo leer logs](../../monitoreo/logging/leer-logs.md) |
| DevSecOps (la verificación) | sudo, SSH, SUID, auditd, parches y su verificación | [Hardening de Linux](../../devsecops/hardening/hardening-linux.md), [CVE en Linux y sistemas](../../devsecops/vulnerabilidades/cve-linux-sistemas.md) |
| Servidores | El resto de la administración Linux | [Almacenamiento](linux-almacenamiento.md), [Redes](linux-redes-servidor.md), [Procesos y rendimiento](linux-procesos-rendimiento.md) |

## Referencias

- [Ubuntu Server documentation](https://documentation.ubuntu.com/server/)
- [Ubuntu release cycle](https://ubuntu.com/about/release-cycle)
- [Red Hat Enterprise Linux Life Cycle](https://access.redhat.com/support/policy/updates/errata)
- [Rocky Linux documentation](https://docs.rockylinux.org/)
- [Debian releases](https://www.debian.org/releases/)
- [Filesystem Hierarchy Standard 3.0](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html)
- [systemd.unit(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html), [systemd.service(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html), [journald.conf(5)](https://www.freedesktop.org/software/systemd/man/latest/journald.conf.html)
- [sudoers(5)](https://www.sudo.ws/docs/man/sudoers.man/)
- [setfacl(1)](https://man7.org/linux/man-pages/man1/setfacl.1.html), [chmod(1)](https://man7.org/linux/man-pages/man1/chmod.1.html)
- [Red Hat: Managing software with the DNF tool (RHEL 9)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/managing_software_with_the_dnf_tool/index)
