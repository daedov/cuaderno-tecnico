---
tags:
  - servidores
  - linux
  - redes
  - ssh
---

# Redes en Linux Server

> Configurar la red de un servidor (IP estática o DHCP, rutas, DNS) con Netplan o NetworkManager, ver puertos, abrir el firewall, operar SSH del lado servidor, sincronizar la hora con chrony y salir por un proxy.

!!! info "Antes de leer"
    Conviene haber leído [Linux Server: fundamentos de administración](linux-fundamentos-servidor.md) (systemd y paquetes) y tener claros los fundamentos de red: [Direccionamiento IP](../../networking/basico/direccionamiento-ip.md), [Routing y NAT](../../networking/intermedio/routing-nat.md) y [Servicios de red](../../networking/intermedio/servicios-red.md) (DHCP y DNS). El uso de SSH y DNS desde el punto de vista DevOps está en [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md).

!!! note "Cómo se probaron los ejemplos"
    Salidas reales y abreviadas de contenedores con systemd: Ubuntu 24.04 (Netplan 1.1 + systemd-networkd) y Rocky Linux 10 (NetworkManager). Las configuraciones de red se aplicaron sobre una interfaz `dummy0` dentro del contenedor, sin tocar la red de la máquina. Netplan se validó con `netplan generate`, `sshd_config` con `sshd -t` y firewalld en modo offline (`firewall-offline-cmd`), porque el demonio no arranca con el kernel de WSL2.

## ¿Qué cambia en la red de un servidor?

En tu portátil la red "se configura sola" por DHCP. En un servidor quieres lo contrario: que la configuración sea **predecible, persistente y versionable**. Por eso hay dos capas:

- **Herramientas en caliente** (`ip`, `resolvectl`, `ss`): ver y cambiar el estado actual. Lo que cambies con `ip` **se pierde al reiniciar**.
- **Configuración persistente**: Netplan (Ubuntu) o NetworkManager (RHEL/Rocky), que se aplican en cada arranque.

## Ver el estado con ip

`ip` (paquete iproute2) sustituye a los antiguos `ifconfig`, `route` y `arp`:

| Comando | Qué muestra |
| --- | --- |
| `ip -br addr` | Interfaces y sus IPs, una por línea |
| `ip -br link` | Estado de enlace (UP/DOWN) y MAC |
| `ip route` | Tabla de rutas |
| `ip route get 1.1.1.1` | Por qué interfaz y gateway saldría un paquete |
| `ip neigh` | Tabla ARP (vecinos en la LAN) |
| `ip -s link show eth0` | Contadores de bytes, errores y descartes |

```bash
ip -br addr; ip route; ip route get 1.1.1.1
```

```text
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0@if306       UP             172.17.0.3/16
dummy0           UNKNOWN        10.20.30.15/24
default via 172.17.0.1 dev eth0
10.20.30.0/24 dev dummy0 proto kernel scope link src 10.20.30.15
172.16.0.0/16 via 10.20.30.1 dev dummy0 proto static
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.3
1.1.1.1 via 172.17.0.1 dev eth0 src 172.17.0.3 uid 0
```

Cambios temporales (útiles para probar, se pierden al reiniciar):

```bash
sudo ip addr add 10.20.30.99/24 dev eth1
sudo ip route add 172.16.0.0/16 via 10.20.30.1
sudo ip link set eth1 up
```

## Configuración persistente: Netplan y NetworkManager

=== "Ubuntu/Debian (Netplan)"

    **Netplan** lee YAML de `/etc/netplan/*.yaml` (en orden alfabético) y genera la configuración para el *renderer*: **systemd-networkd** en Ubuntu Server o NetworkManager en escritorio. En la nube, cloud-init crea `50-cloud-init.yaml`; tus cambios van en un archivo propio con número mayor.

    ```yaml title="/etc/netplan/60-ens5-estatica.yaml"
    network:
      version: 2
      ethernets:
        ens5:
          # Identifica la NIC por MAC y le fija el nombre
          match:
            macaddress: "02:ab:cd:ef:12:34"
          set-name: ens5
          # IP estática (en vez de DHCP)
          dhcp4: false
          addresses:
            - 192.168.10.20/24
          # Ruta por defecto: "gateway4" está obsoleto, se usa routes
          routes:
            - to: default
              via: 192.168.10.1
          nameservers:
            addresses: [192.168.10.2, 192.168.10.3]
            search: [corp.ejemplo.com]
    ```

    ```bash
    sudo chmod 600 /etc/netplan/60-ens5-estatica.yaml   # Netplan avisa si es legible por otros
    sudo netplan generate          # valida y genera, sin aplicar
    sudo netplan try               # aplica y revierte en 120 s si no confirmas (ideal por SSH)
    sudo netplan apply
    netplan get ethernets.ens5.addresses
    ```

    `netplan generate` traduce el YAML a un archivo de systemd-networkd:

    ```text
    [Match]
    PermanentMACAddress=02:ab:cd:ef:12:34
    Name=ens5

    [Network]
    LinkLocalAddressing=ipv6
    Address=192.168.10.20/24
    DNS=192.168.10.2
    DNS=192.168.10.3
    Domains=corp.ejemplo.com

    [Route]
    Destination=0.0.0.0/0
    Gateway=192.168.10.1
    ```

    Con un YAML mal formado o una clave obsoleta, avisa antes de romper nada:

    ```text
    /etc/netplan/99-bad.yaml:2:1: Invalid YAML: did not find expected node content
    WARNING: `gateway4` has been deprecated, use default routes instead.
    Error: Conflicting default route declarations for IPv4 (table: main, metric: default), first declared in ens5 but also in ens5
    ```

    Para DHCP basta `dhcp4: true`. Estado: `networkctl list` y `networkctl status ens5`.

=== "RHEL/Rocky (NetworkManager)"

    En la familia RHEL la red la gestiona **NetworkManager** y se configura con `nmcli`. Cada configuración es un **connection profile** (perfil de conexión) que se guarda en `/etc/NetworkManager/system-connections/*.nmconnection` (formato keyfile; los antiguos `ifcfg-*` de `network-scripts` están retirados en RHEL 10).

    ```bash
    nmcli device status
    sudo nmcli con add type ethernet ifname ens5 con-name app-static \
      ipv4.method manual ipv4.addresses 192.168.10.20/24 ipv4.gateway 192.168.10.1 \
      ipv4.dns "192.168.10.2 192.168.10.3" ipv4.dns-search corp.ejemplo.com
    sudo nmcli con mod app-static +ipv4.routes "172.16.0.0/16 192.168.10.1"
    sudo nmcli con up app-static
    nmcli -g ipv4.addresses,ipv4.gateway,ipv4.dns,ipv4.routes con show app-static
    ```

    ```text
    Connection 'app-static' (52954090-0b36-43ff-a616-9588d7518d09) successfully added.
    Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/4)
    10.20.30.16/24
    10.20.30.1
    10.20.30.2,1.1.1.1
    172.16.0.0/16 10.20.30.1
    ```

    El perfil queda así (probado con una interfaz `dummy`; con una NIC real `type=ethernet`):

    ```ini title="/etc/NetworkManager/system-connections/app-static.nmconnection"
    [connection]
    id=app-static
    type=dummy
    interface-name=dummy0

    [ipv4]
    address1=10.20.30.16/24
    dns=10.20.30.2;1.1.1.1;
    dns-search=ejemplo.internal;
    gateway=10.20.30.1
    method=manual
    route1=172.16.0.0/16,10.20.30.1
    ```

    Para DHCP: `nmcli con mod app-static ipv4.method auto`. Interfaz de texto: `nmtui`.

!!! danger "Cambiar la red por SSH"
    Un error en la IP o el gateway te deja fuera del servidor. Usa `netplan try`, ten abierta la **consola serie** del proveedor o programa un "deshacer" (`sudo systemd-run --on-active=5m nmcli con up perfil-anterior`) antes de aplicar.

!!! tip "En la nube, casi siempre DHCP"
    En AWS, Azure y Google Cloud la IP privada se asigna en la VPC/VNet y la VM la recibe por DHCP. Una IP "fija" se consigue reservándola en la nube (IP privada estática de la NIC), no con Netplan. Ver [Redes en la nube](../../cloud/redes-y-datos/redes.md).

## Resolución de nombres: /etc/hosts y DNS

El orden de consulta lo fija `/etc/nsswitch.conf` (`hosts: files dns`): primero `/etc/hosts`, después DNS. Para comprobar cómo resuelve **el sistema** (no solo DNS), usa `getent`:

```text title="/etc/hosts"
127.0.0.1    localhost
10.20.30.50  db01.ejemplo.internal db01
```

```bash
getent hosts db01            # 10.20.30.50     db01.ejemplo.internal db01
```

En Ubuntu (y cada vez más distros), **systemd-resolved** es el resolver local: escucha en `127.0.0.53` y `/etc/resolv.conf` suele ser un enlace a `/run/systemd/resolve/stub-resolv.conf`. Por eso **no edites `/etc/resolv.conf` a mano**: se sobrescribe. Los servidores DNS se configuran en Netplan/NetworkManager.

```bash
resolvectl status            # DNS por interfaz
resolvectl query ubuntu.com  # resolver con el mismo camino que las aplicaciones
resolvectl flush-caches
```

```text
Link 3 (dummy0)
    Current Scopes: DNS
       DNS Servers: 10.20.30.2 1.1.1.1
        DNS Domain: ejemplo.internal
ubuntu.com: 185.125.190.20                     -- link: eth0
            185.125.190.21                     -- link: eth0
```

`dig` (paquete `dnsutils`/`bind-utils`) consulta un DNS directamente y sirve para comparar con lo que ve el sistema. Fundamentos de DNS: [Servicios de red](../../networking/intermedio/servicios-red.md).

## Puertos y sockets con ss

`ss -tulpn` es el comando que más usarás: **t**cp, **u**dp, **l**istening, **p**roceso, **n**umérico.

```bash
sudo ss -tulpn
```

```text
Netid State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
udp   UNCONN 0      0         127.0.0.54:53         0.0.0.0:*    users:(("systemd-resolve",pid=95,fd=15))
udp   UNCONN 0      0          127.0.0.1:323        0.0.0.0:*    users:(("chronyd",pid=234,fd=5))
tcp   LISTEN 0      4096   127.0.0.53%lo:53         0.0.0.0:*    users:(("systemd-resolve",pid=95,fd=14))
tcp   LISTEN 0      4096         0.0.0.0:22         0.0.0.0:*    users:(("systemd",pid=1,fd=154))
```

Cómo leerlo: `0.0.0.0:22` escucha en todas las interfaces; `127.0.0.53:53` solo en local (no accesible desde fuera). Que el puerto 22 lo tenga `systemd` y no `sshd` es la **socket activation** de Ubuntu 24.04 (ver SSH más abajo).

| Comando | Para qué |
| --- | --- |
| `ss -tan state established` | Conexiones TCP abiertas |
| `ss -tnp dst :5432` | Quién está conectado a PostgreSQL |
| `ss -s` | Resumen (incluye cuántas en TIME_WAIT) |
| `ss -tlnp 'sport = :8080'` | Quién escucha en el 8080 |

Puertos bien conocidos: [Puertos comunes](../../recursos/puertos.md).

## Firewall en lo operativo

Aquí solo lo que harás a diario (abrir y revisar). Las políticas por defecto y el endurecimiento están en [Hardening de Linux](../../devsecops/hardening/hardening-linux.md). Recuerda que en la nube también está el **security group** / NSG / regla de firewall de VPC: un puerto tiene que estar abierto en ambos sitios.

=== "Ubuntu/Debian (ufw)"

    ```bash
    sudo ufw allow OpenSSH                         # antes de activar, o te quedas fuera
    sudo ufw allow from 10.0.0.0/8 to any port 5432 proto tcp
    sudo ufw enable
    sudo ufw status numbered
    sudo ufw delete 2                              # borrar por número
    ```

    ```text
    Status: active

         To                         Action      From
         --                         ------      ----
    [ 1] OpenSSH                    ALLOW IN    Anywhere
    [ 2] 5432/tcp                   ALLOW IN    10.0.0.0/8
    [ 3] OpenSSH (v6)               ALLOW IN    Anywhere (v6)
    ```

=== "RHEL/Rocky (firewalld)"

    firewalld organiza las reglas en **zonas** (*zones*): cada interfaz o rango de origen pertenece a una zona con sus servicios permitidos. Los cambios con `--permanent` no se aplican hasta `--reload`; sin `--permanent` se aplican ya pero se pierden al recargar.

    ```bash
    firewall-cmd --get-active-zones
    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --permanent --add-port=8080/tcp
    # Solo la red interna puede llegar a PostgreSQL
    sudo firewall-cmd --permanent --zone=internal --add-source=10.0.0.0/8
    sudo firewall-cmd --permanent --zone=internal --add-service=postgresql
    sudo firewall-cmd --reload
    sudo firewall-cmd --list-all
    ```

    ```text
    public (default)
      target: default
      services: cockpit dhcpv6-client http ssh
      ports: 8080/tcp
    internal
      sources: 10.0.0.0/8
      services: cockpit dhcpv6-client mdns postgresql samba-client ssh
    ```

## SSH del lado servidor

| Ubuntu/Debian | RHEL/Rocky |
| --- | --- |
| Paquete `openssh-server`, servicio `ssh` | Paquete `openssh-server`, servicio `sshd` |
| Configuración en `/etc/ssh/sshd_config` y `/etc/ssh/sshd_config.d/*.conf` | Igual |

```bash
sudo sshd -t                                   # validar configuración (sin salida = OK)
sudo sshd -T | grep -E '^(port|passwordauthentication|permitrootlogin) '   # configuración efectiva
sudo systemctl reload ssh                      # "sshd" en RHEL
```

!!! warning "Ubuntu 24.04: SSH por socket activation"
    En Ubuntu 22.10+ el puerto 22 lo abre `ssh.socket` (systemd) y arranca `sshd` al llegar una conexión. Si cambias `Port` o `ListenAddress`, un generador traduce `sshd_config` a la configuración del socket, pero solo tras `sudo systemctl daemon-reload && sudo systemctl restart ssh.socket`. Probado: con `Port 2222` en `sshd_config.d/`, tras esos dos comandos `ss` mostró el socket en 2222.

### Llaves autorizadas

El servidor acepta una llave si su parte pública está en `~/.ssh/authorized_keys` del usuario. Los permisos importan: si son demasiado abiertos, `sshd` **ignora** el archivo en silencio.

```bash
# Desde tu equipo: copia la llave pública (pide la contraseña una vez)
ssh-copy-id -i ~/.ssh/id_ed25519.pub ana@web01
```

```text
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
Number of key(s) added: 1
```

```bash
# En el servidor, los permisos correctos:
ls -la /home/ana/.ssh
```

```text
drwx------ 2 ana ana 4096 Oct 26 21:24 .
-rw------- 1 ana ana   99 Oct 26 21:24 authorized_keys
```

Desactivar contraseñas, root y algoritmos débiles es hardening: [Hardening de Linux](../../devsecops/hardening/hardening-linux.md) y [Hardening de servicios](../../devsecops/hardening/hardening-servicios.md).

### ~/.ssh/config del lado cliente

```text title="~/.ssh/config"
# Bastion con IP pública
Host bastion
    HostName 203.0.113.10
    User ana
    IdentityFile ~/.ssh/id_ed25519

# Servidor privado: se llega saltando por el bastion
Host web01
    HostName 10.20.30.15
    User ana
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ProxyJump bastion
    ServerAliveInterval 30
```

`ssh -G web01` muestra la configuración efectiva que usará el cliente; es la forma rápida de depurar un `config`.

### Túneles, scp y rsync

```bash
ssh -L 15432:db01:5432 web01      # local forward: localhost:15432 → db01:5432 vía web01
ssh -R 9000:localhost:3000 web01  # remote forward: web01:9000 → tu localhost:3000
ssh -D 1080 bastion               # proxy SOCKS dinámico
ssh -J bastion ana@10.20.30.15    # salto puntual sin config
scp app.tar.gz web01:/tmp/
rsync -avz --delete ./release/ web01:/srv/app/release/   # solo copia diferencias
```

`rsync` es preferible a `scp` para despliegues y backups: reanuda, compara y con `--delete` deja el destino idéntico al origen (pruébalo antes con `-n`, *dry run*). Probado entre los dos contenedores con llave ed25519:

```text
sending incremental file list
app.txt
sent 197 bytes  received 104 bytes  602.00 bytes/sec
```

## Sincronización de hora con chrony

Una hora incorrecta rompe TLS (certificados "aún no válidos"), Kerberos, la correlación de logs y los tokens con caducidad. **chrony** es el cliente NTP por defecto en Ubuntu y RHEL.

```text title="/etc/chrony.conf (Rocky) o /etc/chrony/chrony.conf (Ubuntu), extracto"
# Servidores NTP; iburst acelera la primera sincronización
pool 2.rocky.pool.ntp.org iburst
# Si el desfase supera 1 s, corrige de golpe en las 3 primeras actualizaciones
makestep 1.0 3
# Copia la hora al reloj hardware
rtcsync
driftfile /var/lib/chrony/drift
```

```bash
chronyc sources -v        # fuentes y su estado (* = la elegida)
chronyc tracking          # desfase actual respecto a NTP
sudo systemctl restart chronyd   # "chrony" en Ubuntu
```

```text
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^* 91.189.91.157                 2   6    17     7  -1448ms[-1448ms] +/-   56ms
^+ 185.125.190.56                2   6    17     7  -1425ms[-1425ms] +/-   68ms
^- 185.125.190.57                2   6    17     6  -1557ms[-1557ms] +/-   68ms
```

(Salida del contenedor con `chronyd -x`, que mide pero no ajusta el reloj; el desfase de ~1,4 s es del entorno de prueba.) En la nube usa el NTP del proveedor, que no necesita salida a Internet: **Amazon Time Sync Service** (`169.254.169.123`), el host de Hyper-V en Azure y `metadata.google.internal` en Google Cloud. Las imágenes oficiales suelen venir ya configuradas.

## Proxy de salida

Muchas redes corporativas obligan a salir a Internet por un **proxy**. No hay un único ajuste: cada herramienta lee el suyo.

| Dónde | Cómo |
| --- | --- |
| Shell y la mayoría de CLIs (`curl`, `pip`, `git`) | Variables `http_proxy`, `https_proxy`, `no_proxy` (y en mayúsculas) |
| Para todos los usuarios | `/etc/environment` |
| `apt` | `/etc/apt/apt.conf.d/95proxy` |
| `dnf` | `proxy=` en `/etc/dnf/dnf.conf` |
| Un servicio systemd | `Environment=` en un drop-in (no lee `/etc/environment` por defecto) |

```text title="/etc/environment"
http_proxy=http://proxy.ejemplo.internal:3128
https_proxy=http://proxy.ejemplo.internal:3128
no_proxy=localhost,127.0.0.1,169.254.169.254,.ejemplo.internal
```

```text title="/etc/apt/apt.conf.d/95proxy"
Acquire::http::Proxy "http://proxy.ejemplo.internal:3128";
Acquire::https::Proxy "http://proxy.ejemplo.internal:3128";
```

Comprobado con `apt-config dump | grep -i proxy` y, en Rocky, con `dnf config-manager --dump`. Incluye siempre en `no_proxy` el **endpoint de metadatos** de la nube (`169.254.169.254`): si pasa por el proxy, la VM pierde sus credenciales de rol.

## Diagnóstico rápido

Orden sugerido, de abajo arriba: ¿interfaz UP y con IP? (`ip -br a`) → ¿ruta? (`ip route get <destino>`) → ¿resuelve? (`getent hosts`, `resolvectl query`) → ¿llega? (`ping`, `nc -zv host puerto`) → ¿escucha el servicio? (`ss -tlnp`) → ¿lo bloquea un firewall? (ufw/firewalld y el security group). La metodología completa y más herramientas (`tcpdump`, `mtr`, `curl -v`) están en [Troubleshooting de red](../../networking/avanzado/troubleshooting-red.md) y [Troubleshooting](../../devops/operacion/troubleshooting.md).

## Casos de uso

### Pasar un servidor de DHCP a IP estática

1. Anota lo actual: `ip -br a`, `ip route`, `resolvectl status`.
2. Escribe el YAML de Netplan (o el perfil de `nmcli`) con IP, gateway y DNS.
3. Valida (`netplan generate`) y aplica con red de seguridad (`netplan try`).
4. Comprueba desde **otra** sesión SSH antes de cerrar la actual.

### Una aplicación no es accesible desde fuera

1. `ss -tlnp | grep 8080`: si muestra `127.0.0.1:8080`, la app solo escucha en local; cámbiala a `0.0.0.0` o a la IP de la interfaz.
2. Firewall local: `ufw status` o `firewall-cmd --list-all`.
3. Firewall de la nube: security group, NSG o regla de VPC.
4. Prueba desde otra máquina: `nc -zv web01 8080`. `Connection refused` = llega pero nada escucha; *timeout* = algo filtra.

### Añadir una ruta a una red on-premise por la VPN

Con Netplan, añade bajo la interfaz `routes: - to: 172.16.0.0/16 via: 10.20.30.1`; con NetworkManager, `nmcli con mod perfil +ipv4.routes "172.16.0.0/16 10.20.30.1"` y `nmcli con up perfil`. Verifica con `ip route get 172.16.5.10`.

### Cambiar el puerto de SSH en Ubuntu 24.04

Crea `/etc/ssh/sshd_config.d/10-port.conf` con `Port 2222`, valida con `sshd -t`, abre el puerto (`ufw allow 2222/tcp` y el security group), ejecuta `systemctl daemon-reload` y `systemctl restart ssh.socket`, y prueba con `ssh -p 2222` **antes** de cerrar la sesión actual.

## Problemas comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| La IP configurada con `ip addr add` desaparece al reiniciar | `ip` solo cambia el estado en memoria | Configúrala en Netplan o NetworkManager |
| Cambios en `/etc/resolv.conf` se pierden | Lo gestiona systemd-resolved o NetworkManager | Configura DNS en Netplan/nmcli; verifica con `resolvectl` |
| `netplan apply` avisa "Permissions ... are too open" | YAML legible por otros (puede contener secretos de Wi-Fi) | `chmod 600 /etc/netplan/*.yaml` |
| SSH pide contraseña aunque copiaste la llave | Permisos de `~/.ssh` o `authorized_keys`, o home con escritura para el grupo | `chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys`; mira `journalctl -u ssh` |
| Cambié `Port` y SSH sigue en el 22 (Ubuntu 24.04) | Socket activation | `daemon-reload` + `restart ssh.socket` |
| `firewall-cmd --add-port` funcionó pero se perdió | Faltó `--permanent` | Repite con `--permanent` y `--reload` (o `--runtime-to-permanent`) |
| Errores TLS "certificate is not yet valid" | Reloj desfasado | `chronyc tracking`; revisa que chrony tenga fuentes alcanzables (UDP 123) |
| `apt`/`dnf` no descargan pero `curl` sí | Proxy configurado solo en el shell | Configura el proxy en apt/dnf |

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Networking (la base) | IP, rutas, DNS, TCP y diagnóstico por capas | [Direccionamiento IP](../../networking/basico/direccionamiento-ip.md), [Routing y NAT](../../networking/intermedio/routing-nat.md), [Servicios de red](../../networking/intermedio/servicios-red.md), [Troubleshooting de red](../../networking/avanzado/troubleshooting-red.md) |
| Cloud (el control) | VPC/VNet, IPs privadas, security groups, bastion | [Redes en la nube](../../cloud/redes-y-datos/redes.md), [Seguridad de redes](../../cloud/seguridad/seguridad-redes.md) |
| DevOps (la automatización) | SSH, DNS y HTTP en el día a día; red y firewall como código | [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md), [Ansible para Linux](../ansible/ansible-linux.md) |
| DevSecOps (la verificación) | Endurecer SSH y el firewall, verificarlo | [Hardening de Linux](../../devsecops/hardening/hardening-linux.md), [Hardening de servicios](../../devsecops/hardening/hardening-servicios.md) |
| Servidores | El resto de la administración Linux | [Fundamentos](linux-fundamentos-servidor.md), [Almacenamiento](linux-almacenamiento.md), [Procesos y rendimiento](linux-procesos-rendimiento.md) |

## Referencias

- [Netplan documentation](https://netplan.readthedocs.io/en/stable/) y [Netplan YAML reference](https://netplan.readthedocs.io/en/stable/netplan-yaml/)
- [Ubuntu Server: networking](https://documentation.ubuntu.com/server/explanation/networking/)
- [Red Hat: Configuring and managing networking (RHEL 9)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_networking/index)
- [nmcli(1)](https://networkmanager.dev/docs/api/latest/nmcli.html), [ip(8)](https://man7.org/linux/man-pages/man8/ip.8.html), [ss(8)](https://man7.org/linux/man-pages/man8/ss.8.html)
- [resolvectl(1)](https://www.freedesktop.org/software/systemd/man/latest/resolvectl.html)
- [ufw (Ubuntu Server)](https://documentation.ubuntu.com/server/how-to/security/firewalls/), [firewalld documentation](https://firewalld.org/documentation/)
- [sshd_config(5)](https://man.openbsd.org/sshd_config), [ssh_config(5)](https://man.openbsd.org/ssh_config)
- [chrony documentation](https://chrony-project.org/documentation.html)
- [Amazon Time Sync Service](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/set-time.html), [Azure: Time sync for Linux VMs](https://learn.microsoft.com/es-es/azure/virtual-machines/linux/time-sync), [Google Cloud: Configure NTP](https://cloud.google.com/compute/docs/instances/configure-ntp)
