---
tags:
  - devsecops
  - hardening
  - linux
  - seguridad
  - ssh
---

# Hardening de Linux

> Cómo endurecer un servidor Ubuntu/Debian o de la familia RHEL (usuarios, SSH, servicios, kernel, montajes, auditd, SELinux/AppArmor, firewall, parches y contraseñas) y cómo verificarlo con Lynis, ssh-audit y OpenSCAP.

!!! info "Dónde encaja"
    En una VM de IaaS el sistema operativo es tu responsabilidad ([Responsabilidad compartida](../../cloud/fundamentos/responsabilidad-compartida.md)). Lo específico de la nube (IMDSv2, Session Manager / Bastion / IAP, agentes de parcheo gestionado) está en [Seguridad de máquinas virtuales](../../cloud/seguridad/seguridad-maquinas-virtuales.md). Los principios, baselines y el ciclo están en [Fundamentos de hardening](fundamentos-hardening.md). Los comandos básicos de Linux están en [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md) y en la [guía de comandos de Linux](../../recursos/comandos/linux.md).

## ¿Qué es?

Endurecer Linux consiste en llevar la instalación por defecto a una **baseline** (línea base) como CIS Level 1 Server. Las áreas son siempre las mismas; lo que cambia entre distribuciones son los nombres de paquetes y algunas herramientas:

| Área | Ubuntu / Debian | RHEL / Rocky / Alma |
| --- | --- | --- |
| Paquetes | `apt` | `dnf` |
| Nombre del servicio SSH | `ssh` (en 24.04 con socket activation, `ssh.socket`) | `sshd` |
| Mandatory Access Control | **AppArmor** | **SELinux** |
| Firewall de alto nivel | `ufw` | `firewalld` |
| Parches automáticos | `unattended-upgrades` | `dnf-automatic` |
| Algoritmos criptográficos del sistema | Configuración por servicio | **crypto-policies** (`update-crypto-policies`) |
| Paquete de auditoría | `auditd` | `audit` |
| Grupo de administradores | `sudo` | `wheel` |

!!! danger "Antes de tocar nada"
    Prueba cada cambio en un servidor de prueba o en una imagen nueva, nunca directamente en producción. Al endurecer SSH, deja **una sesión abierta** y prueba con una conexión nueva antes de cerrarla. Si te bloqueas, la salida es la consola serie o de emergencia del proveedor.

## Usuarios, sudo y root

- Cada persona usa su propia cuenta y escala con `sudo`; nadie inicia sesión como root.
- Solo root debe tener UID 0.
- Concede `sudo` por grupo, en archivos de `/etc/sudoers.d/` validados con `visudo`, y evita `NOPASSWD: ALL`.

```text title="/etc/sudoers.d/10-admins"
# Quién puede usar sudo: el grupo admins, como cualquier usuario, con contraseña
%admins ALL=(ALL:ALL) ALL
# Ejecuta los comandos en una pseudoterminal (evita que un proceso en segundo plano siga escribiendo en tu TTY)
Defaults use_pty
# Registro propio de sudo, además del journal
Defaults logfile="/var/log/sudo.log"
```

```bash
sudo visudo -c -f /etc/sudoers.d/10-admins   # valida la sintaxis antes de que te deje sin sudo
awk -F: '$3==0 {print $1}' /etc/passwd        # cuentas con UID 0 (debe salir solo root)
sudo passwd -S root                           # "L" = contraseña bloqueada
```

## SSH

**SSH** es casi siempre la puerta de entrada del servidor. Por eso conviene una configuración en un archivo aparte (*drop-in*) en lugar de editar `sshd_config`: sobrevive mejor a las actualizaciones del paquete. En OpenSSH, **el primer valor que se lee gana**, y tanto Ubuntu como RHEL incluyen `sshd_config.d/*.conf` al principio. Por eso un archivo `10-...` tiene prioridad.

```text title="/etc/ssh/sshd_config.d/10-hardening.conf"
# --- Autenticación ---
PermitRootLogin no                  # root nunca entra por SSH; se escala con sudo
PasswordAuthentication no           # solo llaves: elimina fuerza bruta de contraseñas
KbdInteractiveAuthentication no     # cierra también el login por teclado interactivo (PAM)
PermitEmptyPasswords no
PubkeyAuthentication yes
AuthenticationMethods publickey     # exige llave de forma explícita
MaxAuthTries 3                      # intentos por conexión antes de cortarla
MaxSessions 2                       # sesiones multiplexadas por conexión
LoginGraceTime 30                   # segundos para autenticarse
AllowGroups sshusers                # solo miembros de este grupo (créalo y añade usuarios ANTES)

# --- Funciones que un servidor normal no necesita ---
X11Forwarding no
AllowTcpForwarding no               # quítalo solo en bastiones, con excepción documentada
AllowAgentForwarding no
PermitTunnel no
GatewayPorts no
PermitUserEnvironment no

# --- Sesiones inactivas ---
ClientAliveInterval 300             # comprueba cada 5 min si el cliente sigue ahí
ClientAliveCountMax 2               # tras 2 comprobaciones sin respuesta, corta
TCPKeepAlive no                     # usa ClientAlive (cifrado) en vez de keepalive TCP

# --- Registro y aviso legal ---
LogLevel VERBOSE                    # registra la huella de la llave usada en cada login
Banner /etc/issue.net               # aviso antes de autenticarse

# --- Algoritmos (válidos para OpenSSH 9.x) ---
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256,rsa-sha2-256-cert-v01@openssh.com
```

Orden seguro para aplicarlo:

```bash
sudo groupadd -f sshusers && sudo usermod -aG sshusers ana   # primero el grupo
sudo sshd -t && echo OK                                       # valida la sintaxis
sudo sshd -T | grep -E '^(permitrootlogin|passwordauthentication|allowgroups) '  # config efectiva
```

=== "Ubuntu / Debian"

    ```bash
    sudo systemctl reload ssh      # el servicio se llama "ssh"
    ```

    En Ubuntu 24.04 SSH arranca por **socket activation** (`ssh.socket`): si cambias `Port` o `ListenAddress`, sigue los pasos de [SSH del lado servidor](../../servidores/linux/linux-redes-servidor.md#ssh-del-lado-servidor).

=== "RHEL / Rocky / Alma"

    ```bash
    sudo systemctl reload sshd
    update-crypto-policies --show   # DEFAULT, FUTURE, FIPS...
    ```

    En RHEL los algoritmos de SSH (y de TLS, Kerberos…) vienen de **crypto-policies**, mediante el `Include` de `50-redhat.conf`. Tu `10-hardening.conf` gana porque se lee antes, pero Red Hat recomienda ajustar los algoritmos con una política o un **subpolicy module** (`update-crypto-policies --set DEFAULT:MI-MODULO`). Así lo hace también el perfil CIS de SCAP Security Guide (regla *Implement Custom Crypto Policy Modules for CIS Benchmark*).

!!! note "Post-quantum y versiones"
    `sntrup761x25519-sha512` es un intercambio de llaves híbrido post-cuántico disponible desde OpenSSH 8.5. OpenSSH 9.9 añadió `mlkem768x25519-sha256`, que pasó a ser el predeterminado en OpenSSH 10. **No lo pongas en un servidor con una versión anterior**: `sshd -t` lo rechaza (ver [Cómo verificarlo](#como-verificarlo)). Comprueba tu versión con `ssh -V`.

## Paquetes, servicios y puertos

Aplica **mínima funcionalidad**: lo que no está instalado no se puede explotar ni hay que parchearlo.

```bash
systemctl list-unit-files --type=service --state=enabled   # qué arranca con el sistema
sudo ss -tulpn                                             # qué escucha y qué proceso lo abre
sudo systemctl disable --now cups avahi-daemon             # ejemplo: impresión y mDNS en un servidor
sudo systemctl mask rpcbind                                # mask: impide que otro servicio lo arranque
```

Candidatos típicos a quitar en un servidor: clientes y servidores heredados (`telnet`, `rsh`, `tftp`, `xinetd`), `avahi`, `cups`, servidores de correo locales que no envían nada y entornos gráficos. Para cada puerto que veas con `ss`, pregúntate quién lo usa; si no hay respuesta, ciérralo. Puertos habituales en [Puertos](../../recursos/puertos.md).

## Parámetros del kernel (sysctl)

```ini title="/etc/sysctl.d/60-hardening.conf"
# --- Red (IPv4) ---
net.ipv4.conf.all.accept_redirects = 0       # ignora ICMP redirects (evita desvíos de rutas)
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0         # un servidor que no es router no los envía
net.ipv4.conf.all.accept_source_route = 0    # rechaza paquetes con ruta elegida por el origen
net.ipv4.conf.all.rp_filter = 1              # reverse path filtering: descarta IPs de origen falsificadas
net.ipv4.conf.all.log_martians = 1           # registra paquetes con direcciones imposibles
net.ipv4.icmp_echo_ignore_broadcasts = 1     # no responde a pings a broadcast (smurf)
net.ipv4.tcp_syncookies = 1                  # resiste SYN flood
net.ipv4.ip_forward = 0                      # OJO: en hosts de Docker/Kubernetes o routers debe ser 1
# --- Red (IPv6) ---
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_ra = 0              # ignora router advertisements si la IP es estática

# --- Kernel ---
kernel.kptr_restrict = 2                     # oculta direcciones del kernel en /proc (dificulta exploits)
kernel.dmesg_restrict = 1                    # solo root lee dmesg
kernel.unprivileged_bpf_disabled = 1         # sin eBPF para usuarios sin privilegios (1 no se puede revertir sin reiniciar)
kernel.yama.ptrace_scope = 1                 # un proceso solo puede depurar a sus descendientes
kernel.randomize_va_space = 2                # ASLR completo
fs.suid_dumpable = 0                         # sin core dumps de programas SUID

# --- Sistema de archivos ---
fs.protected_symlinks = 1                    # evita ataques con symlinks en directorios compartidos (/tmp)
fs.protected_hardlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
```

```bash
sudo sysctl --system                          # carga todos los archivos de /etc/sysctl.d
sysctl kernel.kptr_restrict kernel.dmesg_restrict   # comprueba el valor efectivo
```

## Opciones de montaje

Montar con `nodev,nosuid,noexec` impide crear dispositivos, usar binarios SUID o ejecutar programas desde directorios donde cualquiera escribe:

```text title="/etc/fstab (fragmento)"
tmpfs  /dev/shm  tmpfs  defaults,nodev,nosuid,noexec  0 0
tmpfs  /tmp      tmpfs  defaults,nodev,nosuid,noexec,size=2G  0 0
```

```bash
findmnt -no OPTIONS /dev/shm   # rw,nosuid,nodev,noexec,...
findmnt -no OPTIONS /tmp
```

!!! warning "`noexec` en `/tmp` rompe cosas"
    Algunos instaladores y aplicaciones ejecutan scripts desde `/tmp`. Pruébalo antes. Si algo falla, configura esa aplicación para usar otro directorio temporal y documenta una excepción; no quites el control para todo el sistema. Las particiones separadas (`/var`, `/var/log`, `/home`) son CIS Level 2 y conviene decidirlas al crear la imagen.

## Permisos y SUID

```bash
stat -c '%a %U:%G %n' /etc/shadow /etc/passwd /etc/ssh/sshd_config
sudo find / -xdev -perm -4000 -type f              # binarios SUID: compara con una lista conocida
sudo find / -xdev -type f -perm -0002              # archivos escribibles por cualquiera
sudo find / -xdev \( -nouser -o -nogroup \)        # archivos sin dueño (restos de usuarios borrados)
```

Fija también una `UMASK 027` en `/etc/login.defs` para que los archivos nuevos no sean legibles por otros usuarios.

## Auditoría con auditd

`auditd` registra en el kernel eventos de seguridad (cambios de identidad, uso de privilegios, carga de módulos) que el log normal no ve. Instala `auditd` (Ubuntu) o `audit` (RHEL).

```text title="/etc/audit/rules.d/50-hardening.rules"
# Cambios en identidades y privilegios (w = escritura, a = cambio de atributos)
-w /etc/passwd -p wa -k identidad
-w /etc/shadow -p wa -k identidad
-w /etc/group -p wa -k identidad
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
# Cambios en la configuración de SSH
-w /etc/ssh/sshd_config -p wa -k sshd
-w /etc/ssh/sshd_config.d/ -p wa -k sshd
# Comandos ejecutados como root por usuarios reales (auid = quien inició sesión)
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k root_cmd
# Carga y descarga de módulos del kernel
-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -k modulos
# Reglas inmutables hasta reiniciar: un atacante con root no puede desactivarlas en caliente
-e 2
```

```bash
sudo augenrules --load            # compila rules.d y las carga
sudo auditctl -l                  # reglas activas
sudo ausearch -k identidad -ts today -i
```

!!! warning "Volumen de logs"
    La regla de `execve` puede generar mucho volumen en servidores con mucha actividad. Revisa el tamaño en `/etc/audit/auditd.conf` (`max_log_file`, `max_log_file_action`) y envía los eventos a tu SIEM ([Detección y respuesta](../gobierno-y-respuesta/deteccion-respuesta.md)).

## Logging y journald

La baseline pide un journal **persistente** (`Storage=persistent`, para que los logs sobrevivan al reinicio), comprimido (`Compress=yes`) y con tope de disco (`SystemMaxUse=`). Cómo se configura con un drop-in y por qué con `Storage=auto` puede ser volátil: [Persistencia del journal](../../servidores/linux/linux-fundamentos-servidor.md#persistencia-del-journal).

Los logs que solo están en el servidor desaparecen si un atacante los borra o si la instancia se elimina. Envíalos a un sistema central (rsyslog/syslog-ng, el agente de la nube u OpenTelemetry), como se ve en [Observabilidad](../../monitoreo/fundamentos/observabilidad.md) y [Logging y detección en la nube](../../cloud/seguridad/seguridad-logging-deteccion.md).

## SELinux y AppArmor

El **MAC** (*Mandatory Access Control*, control de acceso obligatorio) limita lo que puede hacer cada proceso aunque corra como root. Desactivarlo "porque da problemas" es uno de los antipatrones más comunes.

=== "SELinux (RHEL)"

    ```bash
    getenforce                          # Enforcing | Permissive | Disabled
    sestatus
    sudo ausearch -m AVC -ts recent     # qué bloqueó SELinux
    sudo setenforce 1                   # Enforcing hasta reiniciar
    ```

    Persistente en `/etc/selinux/config` con `SELINUX=enforcing`. Si una aplicación falla, usa `Permissive` solo temporalmente para diagnosticar y corrige el contexto o el booleano (`semanage`, `setsebool`); no lo desactives.

=== "AppArmor (Ubuntu)"

    ```bash
    sudo aa-status                      # perfiles en enforce y complain
    sudo aa-enforce /etc/apparmor.d/usr.sbin.nginx   # pasa un perfil a enforce (paquete apparmor-utils)
    sudo journalctl -k | grep -i apparmor            # denegaciones
    ```

## Firewall local

El firewall local es una capa más, además del Security group, NSG o firewall de VPC ([Seguridad de red](../../networking/avanzado/seguridad-red.md)). Todos los front-ends (`ufw`, `firewalld`) usan **nftables** por debajo en las versiones actuales.

=== "ufw (Ubuntu)"

    ```bash
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow from 10.0.0.0/16 to any port 22 proto tcp   # SSH solo desde la red interna
    sudo ufw enable
    sudo ufw status verbose
    ```

=== "firewalld (RHEL)"

    ```bash
    sudo firewall-cmd --get-default-zone
    sudo firewall-cmd --list-all
    sudo firewall-cmd --permanent --remove-service=cockpit     # quita lo que no uses
    sudo firewall-cmd --reload
    ```

## Parches automáticos

=== "Ubuntu / Debian"

    ```text title="/etc/apt/apt.conf.d/20auto-upgrades"
    APT::Periodic::Update-Package-Lists "1";   // actualiza índices a diario
    APT::Periodic::Unattended-Upgrade "1";     // aplica las actualizaciones (por defecto, las de seguridad)
    ```

    ```bash
    sudo unattended-upgrade --dry-run --debug   # qué instalaría, sin instalar
    ```

=== "RHEL / Rocky / Alma"

    ```ini title="/etc/dnf/automatic.conf (fragmento)"
    [commands]
    upgrade_type = security   # solo erratas de seguridad
    apply_updates = yes
    ```

    ```bash
    sudo systemctl enable --now dnf-automatic.timer
    ```

Los parches del kernel necesitan reinicio (o *livepatch*). Planifícalo; un kernel parcheado que no se ha cargado no protege. El contexto de por qué importa está en [CVE en Linux y sistemas](../vulnerabilidades/cve-linux-sistemas.md).

## Contraseñas y bloqueo de cuentas

Aunque SSH sea solo con llave, las contraseñas siguen usándose en `sudo` y en la consola.

```ini title="/etc/security/pwquality.conf (fragmento)"
minlen = 14      # longitud mínima
```

```ini title="/etc/security/faillock.conf (fragmento)"
deny = 5           # bloquea tras 5 fallos
unlock_time = 900  # durante 15 minutos
```

En RHEL `faillock` se activa con `sudo authselect enable-feature with-faillock`. En Ubuntu hay que añadir `pam_faillock` a `/etc/pam.d/common-auth`; hazlo con un rol probado (ver [Hardening como código](hardening-como-codigo.md)), porque un error en PAM puede impedir cualquier login. Consulta y desbloquea con `faillock --user ana [--reset]`.

**fail2ban** lee los logs y bloquea en el firewall las IPs con muchos fallos. Con SSH solo por llave reduce sobre todo el ruido:

```ini title="/etc/fail2ban/jail.local"
[sshd]
enabled  = true
backend  = systemd   # lee del journal
maxretry = 5
findtime = 10m
bantime  = 1h
```

```bash
sudo fail2ban-client status sshd
```

## Cómo verificarlo

Las salidas de esta sección son **reales** (octubre de 2026), obtenidas en contenedores Docker desechables: `ubuntu:24.04` (OpenSSH 9.6p1, Lynis 3.0.9 del repositorio de Ubuntu) y `rockylinux/rockylinux:9` (Rocky 9.8, OpenSSH 9.9p1, Lynis 3.1.7 de EPEL, OpenSCAP 1.3.14, SCAP Security Guide 0.1.82).

!!! warning "Límites de auditar un contenedor"
    Un contenedor comparte el kernel del host y no tiene systemd, montajes propios ni auditd. `sysctl -p` falla con `Read-only file system` y los controles de kernel, particiones y auditd salen como *not applicable* o no se evalúan. Para el resultado completo, audita una VM. Ver [Lab 22](../../laboratorios/devsecops/hardening-linux-ansible.md).

### Lynis: hardening index antes y después

```bash
sudo lynis audit system --quick
```

```text
  Lynis security scan details:

  Hardening index : 58 [###########         ]
  Tests performed : 236

  Warnings (1):
  Suggestions (50):
  * Consider hardening SSH configuration [SSH-7408]      (x9: AllowTcpForwarding, MaxAuthTries, X11Forwarding...)
  * Default umask in /etc/login.defs could be more strict like 027 [AUTH-9328]
  * Configure maximum password age in /etc/login.defs [AUTH-9286]
  * Add a legal banner to /etc/issue, to warn unauthorized users [BANN-7126]
  * Enable auditd to collect audit information [ACCT-9628]
  ...
```

Se aplicaron tres cambios: el `10-hardening.conf` de SSH, `UMASK 027` y antigüedad de contraseñas en `/etc/login.defs`, y un banner legal.

| Medición (Ubuntu 24.04) | Hardening index | Sugerencias |
| --- | --- | --- |
| Instalación por defecto (con sshd en marcha) | 58 | 50 |
| + SSH endurecido + `login.defs` + banner en español | 69 | 39 |
| + banner con texto en inglés | 70 | 38 |

!!! tip "Lo que enseña el banner"
    Con el banner solo en español, Lynis seguía marcando `BANN-7126`: busca palabras clave en inglés ("authorized", "monitored", "prohibited"…). Un control automatizado comprueba **una forma concreta** de cumplirlo. Lee qué evalúa antes de dar el hallazgo por bueno o por falso positivo.

En Rocky 9 (sin sshd en marcha) el índice pasó de 66 a 68 con los mismos cambios. Lynis guarda el detalle en `/var/log/lynis-report.dat` (`grep hardening_index`) para compararlo entre ejecuciones. El paquete de Ubuntu suele ir atrasado (avisa *This release is more than 4 months old*); para tener la versión actual usa el repositorio de CISOfy.

### sshd -t: validar antes de recargar

```bash
sudo sshd -t && echo OK
```

```text
OK
```

Sin salida y con código 0 significa sintaxis válida. Dos errores reales para reconocerlos:

```text
# Valor inválido
/tmp/t2.conf line 1: unsupported option "nope".

# Algoritmo que esta versión no conoce (mlkem768x25519-sha256 en OpenSSH 9.6)
Unsupported KEX algorithm "mlkem768x25519-sha256"
/tmp/bad.conf line 1: Bad SSH2 KexAlgorithms 'mlkem768x25519-sha256'.
```

`sshd -T` imprime la configuración efectiva tras aplicar `Include` y el orden de prioridad. Úsalo para confirmar que tu drop-in gana.

### ssh-audit: algoritmos ofrecidos

**ssh-audit** se conecta al servidor y analiza lo que ofrece. Úsalo solo contra servidores propios o con autorización.

```bash
ssh-audit -n 127.0.0.1     # -n: sin colores
```

Antes (configuración por defecto de Ubuntu 24.04), resumido:

```text
(kex) ecdh-sha2-nistp256         -- [fail] using elliptic curves that are suspected as being backdoored by the U.S. National Security Agency
(kex) diffie-hellman-group14-sha256 -- [warn] 2048-bit modulus only provides 112-bits of symmetric strength
(key) ecdsa-sha2-nistp256        -- [fail] using elliptic curves that are suspected as being backdoored ...
(mac) umac-64-etm@openssh.com    -- [warn] using small 64-bit tag size
(mac) hmac-sha1-etm@openssh.com  -- [fail] using broken SHA-1 hash algorithm
(mac) hmac-sha2-256              -- [warn] using encrypt-and-MAC mode

# algorithm recommendations (for OpenSSH 9.6)
(rec) -ecdh-sha2-nistp256        -- kex algorithm to remove
(rec) -hmac-sha1                 -- mac algorithm to remove
(rec) -umac-64-etm@openssh.com   -- mac algorithm to remove
... (12 recomendaciones de eliminar)
```

Después de `10-hardening.conf`: ningún `[fail]` ni `[warn]`, y el código de salida pasa de 3 a 0, útil como *gate* en un pipeline.

```text
(kex) sntrup761x25519-sha512@openssh.com  -- [info] available since OpenSSH 8.5
(kex) curve25519-sha256                   -- [info] available since OpenSSH 7.4
(mac) hmac-sha2-512-etm@openssh.com       -- [info] available since OpenSSH 6.2

# algorithm recommendations (for OpenSSH 9.6)
(rec) +diffie-hellman-group16-sha512      -- kex algorithm to append
```

Las recomendaciones `+` son opcionales: sugiere añadir grupos Diffie-Hellman grandes como alternativa compatible. El paquete de Ubuntu 24.04 es ssh-audit 3.1.0; la versión actual (3.9.0) se instala con `pipx install ssh-audit` y puede dar recomendaciones más recientes.

### OpenSCAP con SCAP Security Guide

**OpenSCAP** (`oscap`) evalúa un perfil de **SCAP Security Guide** (SSG, del proyecto ComplianceAsCode) y genera un informe HTML con cada regla, su severidad y cómo corregirla.

=== "RHEL / Rocky / Alma"

    ```bash
    sudo dnf install openscap-scanner scap-security-guide
    oscap info /usr/share/xml/scap/ssg/content/ssg-rl9-ds.xml | grep -A1 'Title: CIS'   # perfiles
    sudo oscap xccdf eval \
      --profile xccdf_org.ssgproject.content_profile_cis_server_l1 \
      --results resultados.xml \
      --report informe.html \
      /usr/share/xml/scap/ssg/content/ssg-rl9-ds.xml          # en RHEL: ssg-rhel9-ds.xml
    ```

    Resultado real en el contenedor Rocky 9.8 (unos 20 s):

    ```text
    Title   Ensure the Default Umask is Set Correctly in /etc/profile
    Rule    xccdf_org.ssgproject.content_rule_accounts_umask_etc_profile
    Result  fail
    ```

    | Ejecución | pass | fail | notapplicable | Score |
    | --- | --- | --- | --- | --- |
    | Antes | 70 | 5 | 220 | 87,85 |
    | Después de `umask 027` y `pam_wheel` para `su` | 72 | 3 | 220 | 89,06 |

    Los 220 *notapplicable* son reglas de kernel, particiones, auditd y servicios que no existen en un contenedor. Siguieron fallando *Custom Crypto Policy Modules*, *Authselect Profile* y *Default Bash Umask*: el informe HTML indica qué espera exactamente cada regla. El código de salida de `oscap` es 2 cuando alguna regla falla.

=== "Ubuntu"

    El paquete `ssg-debderived` de Ubuntu 24.04 trae SSG 0.1.71, con contenido solo hasta `ssg-ubuntu2204-ds.xml`; no hay datastream para 24.04 en ese paquete. Por eso no se ejecutó la evaluación en el contenedor Ubuntu. Opciones:

    - **Ubuntu Security Guide (USG)**, la herramienta oficial de Canonical para CIS y DISA STIG en Ubuntu, que requiere suscripción Ubuntu Pro (`sudo pro enable usg`, `sudo apt install usg`, `sudo usg audit <perfil>`; consulta el nombre exacto del perfil en la documentación de USG).
    - Compilar o descargar el datastream de **ComplianceAsCode** (las versiones recientes incluyen Ubuntu 24.04) y usar el mismo `oscap xccdf eval` con `ssg-ubuntu2404-ds.xml`.

!!! tip "Remediación generada"
    `oscap xccdf generate fix --fix-type ansible --profile ... --output fix.yml <datastream>` genera un playbook de Ansible con las correcciones del perfil. Revísalo y pásalo por `--check` antes de usarlo (ver [Hardening como código](hardening-como-codigo.md)).

### Control → comando de verificación

| Control | Comando de verificación (solo lectura) | Valor esperado |
| --- | --- | --- |
| Sin login de root por SSH | `sudo sshd -T` (línea `permitrootlogin`) | `permitrootlogin no` |
| SSH sin contraseña | `sudo sshd -T` (línea `passwordauthentication`) | `passwordauthentication no` |
| Algoritmos SSH | `ssh-audit -n localhost; echo $?` | Sin `[fail]`, código 0 |
| Solo root con UID 0 | `awk -F: '$3==0' /etc/passwd` | Solo `root` |
| Servicios mínimos | `systemctl list-unit-files --state=enabled` | Solo los necesarios |
| Puertos | `sudo ss -tulpn` | Solo los esperados |
| sysctl | `sysctl kernel.kptr_restrict net.ipv4.conf.all.accept_redirects` | `2` y `0` |
| `/dev/shm` y `/tmp` | `findmnt -no OPTIONS /dev/shm` | Incluye `nodev,nosuid,noexec` |
| Permisos de `/etc/shadow` | `stat -c '%a %U:%G' /etc/shadow` | `640 root:shadow` (Ubuntu) o `0 root:root` (RHEL) |
| auditd activo | `sudo auditctl -s` y `sudo auditctl -l` | `enabled 2` y reglas cargadas |
| SELinux / AppArmor | `getenforce` / `sudo aa-status` | `Enforcing` / perfiles en enforce |
| Firewall | `sudo ufw status` / `sudo firewall-cmd --list-all` | Política por defecto deny |
| Parches automáticos | `systemctl status unattended-upgrades` / `systemctl status dnf-automatic.timer` | Activo |
| Bloqueo de cuentas | `grep -v '^#' /etc/security/faillock.conf` | Valores definidos |
| Global | `sudo lynis audit system` / `oscap xccdf eval ...` | Índice o score que no baja entre ejecuciones |

## Errores comunes

- **Romper producción por endurecer sin probar**: `AllowGroups` sin haber añadido a nadie al grupo, `PasswordAuthentication no` sin llaves instaladas, `noexec` en `/tmp` que rompe un instalador, `ip_forward = 0` en un nodo de Kubernetes. Prueba en una copia, aplica por fases y ten acceso de consola.
- **Recargar sshd sin `sshd -t`**: un error de sintaxis puede impedir que el servicio arranque después de un reinicio.
- **Copiar listas de algoritmos de otra versión**: un algoritmo que tu OpenSSH no conoce hace fallar la configuración, como se vio con `mlkem768x25519-sha256` en 9.6.
- **Desactivar SELinux o AppArmor** en vez de corregir la política.
- **auditd con `-e 2` sin probar las reglas**: quedan fijas hasta reiniciar.
- **Pelear contra crypto-policies en RHEL** en vez de usar un subpolicy module.
- **Auditar solo en el contenedor o solo una vez**: los resultados de kernel y montajes solo valen en una VM real, y sin reescaneo periódico el drift vuelve.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Imágenes, acceso sin SSH abierto, parches gestionados | [Seguridad de máquinas virtuales](../../cloud/seguridad/seguridad-maquinas-virtuales.md), [Máquinas virtuales](../../cloud/computo/maquinas-virtuales.md) |
| DevOps (la automatización) | Linux base, aplicar todo esto con Ansible | [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md), [Ansible](../../devops/iac/ansible.md), [Anatomía de Ansible](../../recursos/anatomia/ansible.md) |
| DevSecOps (la verificación) | Baselines, CVE de Linux, otros sistemas del bloque | [Fundamentos de hardening](fundamentos-hardening.md), [Hardening de servicios](hardening-servicios.md), [Hardening como código](hardening-como-codigo.md), [CVE en Linux y sistemas](../vulnerabilidades/cve-linux-sistemas.md), [Cumplimiento y gobierno](../gobierno-y-respuesta/cumplimiento.md) |
| Networking (la base) | Firewalls, SSH, puertos | [Seguridad de red](../../networking/avanzado/seguridad-red.md), [Protocolos de aplicación](../../networking/intermedio/protocolos-aplicacion.md) |
| Laboratorios | Endurecer y medir un servidor | [Lab 22](../../laboratorios/devsecops/hardening-linux-ansible.md), [Lab 10: Ansible](../../laboratorios/devops/ansible-configuracion.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 22: Endurecer un servidor Linux con Ansible y medirlo con Lynis y OpenSCAP](../../laboratorios/devsecops/hardening-linux-ansible.md) |

## Referencias

- [CIS Benchmarks: Ubuntu Linux](https://www.cisecurity.org/benchmark/ubuntu_linux) y [Red Hat Enterprise Linux](https://www.cisecurity.org/benchmark/red_hat_linux)
- [Red Hat: Security hardening (RHEL 9)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/security_hardening/index)
- [Ubuntu Security Guide (USG)](https://documentation.ubuntu.com/security/compliance/usg/)
- [OpenSSH: sshd_config(5)](https://man.openbsd.org/sshd_config)
- [ssh-audit](https://github.com/jtesta/ssh-audit) y [guías de hardening de ssh-audit](https://www.ssh-audit.com/hardening_guides.html)
- [Lynis](https://cisofy.com/lynis/) y [repositorio de Lynis](https://github.com/CISOfy/lynis)
- [OpenSCAP: Getting started](https://www.open-scap.org/getting-started/) y [ComplianceAsCode / SCAP Security Guide](https://github.com/ComplianceAsCode/content)
- [Documentación del kernel: /proc/sys/kernel](https://docs.kernel.org/admin-guide/sysctl/kernel.html) y [/proc/sys/fs](https://docs.kernel.org/admin-guide/sysctl/fs.html)
- [Linux Audit: auditctl(8)](https://man7.org/linux/man-pages/man8/auditctl.8.html)
- [Ubuntu Server: AppArmor](https://documentation.ubuntu.com/server/how-to/security/apparmor/) y [Red Hat: Using SELinux (RHEL 9)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_selinux/index)
- [Ubuntu Server: Automatic updates](https://documentation.ubuntu.com/server/how-to/software/automatic-updates/)
- [fail2ban](https://github.com/fail2ban/fail2ban)
