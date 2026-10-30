---
tags:
  - servidores
  - ansible
  - linux
  - ssh
---

# Ansible con Linux Server

> Cómo conectar Ansible a servidores Linux de verdad: requisitos del nodo, llaves SSH, `become`, intérprete de Python, bastion host, `ansible.cfg`, módulos esenciales para administrar servidores, casos completos (alta de un servidor, parches con rolling update, ampliar LVM, servicio systemd) y los errores de conexión con sus mensajes reales.

!!! info "Antes de leer"
    Los conceptos de Ansible (inventario, playbooks, roles, handlers, idempotencia, Vault) están en [Configuration management con Ansible](../../devops/iac/ansible.md), y cada línea de un proyecto explicada en [Anatomía de los archivos de Ansible](../../recursos/anatomia/ansible.md). El [Lab 10](../../laboratorios/devops/ansible-configuracion.md) los practica con contenedores conectados por `docker exec`. Esta nota da el paso que falta: **servidores por SSH**, con `sudo`, varios sistemas operativos y los problemas que aparecen en el trabajo real. Lo que se configura dentro de Linux (usuarios, systemd, LVM, firewall) se explica a mano en la sección [Linux Server](../linux/linux-fundamentos-servidor.md).

!!! note "Cómo se probó"
    Con `ansible-core` 2.21.5 y `ansible-lint` 26.10.1 (control node en WSL2 con Ubuntu 22.04) contra dos contenedores con **systemd y OpenSSH**: `srv-ans-ubuntu` (Ubuntu 24.04) y `srv-ans-rocky` (Rocky Linux 9.8), con un usuario `ansible`, llave ed25519 y `sudo` sin contraseña. La conexión es **SSH real**; `srv-ans-rocky` solo es alcanzable **a través de** `srv-ans-ubuntu` como bastion. Las salidas son reales salvo donde se indica. Límites del contenedor: no se puede reiniciar de verdad (el reinicio se simuló), firewalld no arranca porque el kernel de Docker Desktop no tiene las funciones de nftables que necesita, y el caso de LVM solo se validó con `ansible-lint` (no se crearon discos).

## Requisitos del nodo gestionado

| Requisito | Por qué | Cómo comprobarlo |
| --- | --- | --- |
| **SSH** accesible desde el control node | Es la conexión por defecto (`ansible_connection: ssh`) | `ssh -p 22 ansible@servidor` |
| **Python 3** soportado por tu `ansible-core` | Casi todos los módulos son programas Python que Ansible copia y ejecuta. `ansible-core` 2.21 admite Python **3.9 a 3.14** en el nodo gestionado | `python3 --version` en el servidor |
| Un usuario para Ansible con `sudo` | Las tareas de sistema (paquetes, servicios) necesitan root | `sudo -l -U ansible` |
| Hora sincronizada y DNS | Evita fallos de certificados, de Kerberos y de repositorios | `timedatectl`, `resolvectl status` |

Las imágenes "cloud" de Ubuntu, Debian, RHEL, Rocky y Alma ya traen Python 3. Si un host no lo tiene (imágenes mínimas, contenedores), se instala primero con `ansible.builtin.raw`, que no necesita Python, como en el paso 7 del [Lab 10](../../laboratorios/devops/ansible-configuracion.md#paso-7-el-playbook-y-la-primera-ejecucion). El control node necesita Python 3.12 o superior para `ansible-core` 2.21.

!!! tip "Una cuenta dedicada, no la tuya"
    Crea un usuario de servicio (`ansible`, `svc-ansible`) con su propia llave y una regla en `/etc/sudoers.d/`. Así sabes en los logs qué hizo la automatización, puedes revocarla sin tocar a las personas y aplicarle restricciones. Cómo escribir la regla de sudoers con `visudo`: [sudo y sudoers](../linux/linux-fundamentos-servidor.md#sudo-y-sudoers).

```text title="/etc/sudoers.d/ansible"
# Usuario de automatización: sudo sin contraseña (se autentica con llave SSH)
ansible ALL=(ALL) NOPASSWD: ALL
```

Si tu política exige contraseña de sudo, quita `NOPASSWD` y pasa la contraseña con `--ask-become-pass` (`-K`) o con `ansible_become_password` cifrada en Vault.

## Conexión SSH con llave

```bash
ssh-keygen -t ed25519 -C "ansible@control" -f ~/.ssh/ansible_prod   # par de llaves para Ansible
ssh-copy-id -i ~/.ssh/ansible_prod.pub ansible@10.20.1.11             # o repártela con cloud-init / la consola de la nube
ssh-keyscan -H 10.20.1.11 >> ~/.ssh/known_hosts                       # registrar la host key (sin desactivar la comprobación)
```

Organiza el inventario en **dos ejes**: una carpeta por **entorno** (`inventories/dev`, `inventories/prod`, cada una con sus `group_vars`) y, dentro, grupos por **sistema operativo** (`ubuntu`, `rhel`) que heredan de un grupo `linux`. Eliges el entorno con `-i inventories/prod` y nunca mezclas producción con desarrollo por un `--limit` mal escrito. En el inventario solo dejas la conexión; el resto en `group_vars`:

```yaml title="inventories/prod/hosts.yml"
all:
  children:
    linux:
      children:
        ubuntu:
          hosts:
            web-lnx01:
              ansible_host: 10.20.1.11
            web-lnx02:
              ansible_host: 10.20.1.12
        rhel:
          hosts:
            db-lnx01:
              ansible_host: 10.20.2.11
```

```yaml title="inventories/prod/group_vars/linux/vars.yml"
---
ansible_user: ansible                               # usuario remoto
ansible_ssh_private_key_file: ~/.ssh/ansible_prod   # llave privada en el control node
ansible_become: true                                # sudo por defecto en estos hosts
ansible_become_method: sudo                         # el valor por defecto; su, doas, pbrun... existen
# ansible_python_interpreter: /usr/bin/python3      # solo si la detección automática falla
```

| Variable | Qué hace | Ejemplo |
| --- | --- | --- |
| `ansible_host` | IP o DNS real | `10.20.1.11` |
| `ansible_port` | Puerto SSH | `22`, `2222` |
| `ansible_user` | Usuario remoto | `ansible` |
| `ansible_ssh_private_key_file` | Llave privada | `~/.ssh/ansible_prod` |
| `ansible_ssh_common_args` | Opciones extra de `ssh`, `scp` y `sftp` | `-o ProxyJump=bastion` |
| `ansible_become` / `ansible_become_method` / `ansible_become_user` | Escalar privilegios | `true` / `sudo` / `postgres` |
| `ansible_python_interpreter` | Python del host | `/usr/bin/python3`, `auto_silent` |

!!! tip "ssh-agent en lugar de rutas"
    Si cargas la llave en **ssh-agent** (`ssh-add ~/.ssh/ansible_prod`), no necesitas `ansible_ssh_private_key_file` y la llave con passphrase solo se desbloquea una vez. En las pruebas de esta nota se usó así porque el control node trabajaba en una carpeta de Windows (`/mnt/c`), donde los archivos aparecen con permisos 0777 y SSH rechaza la llave (ver [Problemas comunes](#problemas-comunes)).

### Detección del intérprete de Python

No hace falta fijar `ansible_python_interpreter`: Ansible hace **interpreter discovery** (detección del intérprete) en la primera tarea y guarda el resultado como fact. En las pruebas:

```bash
ansible all -m ansible.builtin.setup -a 'filter=discovered_interpreter_python'
```

```text
srv-ans-ubuntu | SUCCESS =>
    ansible_facts:
        discovered_interpreter_python: /usr/bin/python3.12
    changed: false
srv-ans-rocky | SUCCESS =>
    ansible_facts:
        discovered_interpreter_python: /usr/bin/python3.9
    changed: false
```

`interpreter_python = auto_silent` en `ansible.cfg` evita el aviso que sale cuando detecta uno. Fíjalo a mano solo si el host tiene varios Python y el detectado no es el bueno (por ejemplo, uno de una aplicación en `/opt`).

### Bastion host o jump host

En la nube los servidores privados no tienen IP pública: se llega a ellos a través de un **bastion host** (servidor de salto). OpenSSH lo resuelve con `ProxyJump`:

```yaml title="inventories/prod/group_vars/rhel.yml"
---
# db-lnx01 solo es alcanzable desde la red privada: saltar por el bastion
ansible_ssh_common_args: "-o ProxyJump=ansible@bastion.ejemplo.com:22"
```

Así se probó `srv-ans-rocky`, cuyo `ansible_host` es un nombre que solo resuelve dentro de la red de Docker:

```yaml title="inventario de pruebas (fragmento)"
srv-ans-rocky:
  ansible_host: srv-ans-rocky
  ansible_ssh_common_args: "-o ProxyJump=ansible@127.0.0.1:2221"
```

!!! warning "El salto no hereda las opciones de la línea de comandos"
    El `ssh` que abre el salto es otro proceso: no recibe la llave de `ansible_ssh_private_key_file` ni los `-o` que Ansible pasa al `ssh` principal. En las pruebas, la primera vez falló con `Host key verification failed.` porque el `known_hosts` alternativo solo se pasó como `-o UserKnownHostsFile`. La solución robusta es definir el bastion en un archivo de configuración de SSH (que sí se usa en los dos saltos) y apuntar a él con `ssh_args = -F ~/.ssh/config-ansible` o ponerlo en `~/.ssh/config`, y usar ssh-agent para las llaves. Más sobre `~/.ssh/config` en [Redes en Linux Server](../linux/linux-redes-servidor.md#sshconfig-del-lado-cliente).

En AWS también puedes evitar el bastion con **Session Manager** (plugin de conexión `community.aws.aws_ssm`), y en Azure y Google Cloud con Azure Bastion o IAP TCP forwarding como `ProxyCommand`. Ver [Redes en la nube](../../cloud/redes-y-datos/redes.md).

## ansible.cfg para servidores

```ini title="ansible.cfg"
[defaults]
inventory = inventories/prod/hosts.yml
forks = 20                          ; hosts en paralelo (por defecto 5): súbelo con flotas grandes
interpreter_python = auto_silent    ; detección del intérprete sin avisos
callback_result_format = yaml       ; salida legible
retry_files_enabled = False

[privilege_escalation]
become_method = sudo

[ssh_connection]
pipelining = True                   ; menos conexiones por tarea: mucho más rápido
ssh_args = -o ControlMaster=auto -o ControlPersist=60s   ; reutiliza la conexión SSH
```

| Opción | Efecto | Cuidado |
| --- | --- | --- |
| `forks` | Cuántos hosts a la vez | Más forks = más CPU y memoria en el control node |
| `pipelining` | Envía el módulo por la conexión abierta en vez de copiarlo a un temporal | Requiere que `sudoers` no tenga `requiretty` (no está por defecto en las distribuciones actuales) |
| `ControlPersist` | Mantiene abierta la conexión SSH unos segundos entre tareas | Los sockets no funcionan en sistemas de archivos de Windows montados en WSL |
| `host_key_checking` | Comprobar la host key | Déjalo en `True`: desactivarlo te expone a un ataque *man-in-the-middle* (intermediario). Ver [Anatomía: ansible.cfg](../../recursos/anatomia/ansible.md#ansiblecfg-comentado-linea-por-linea) |

## Comprobar la conexión

```bash
ansible-inventory --graph
ansible all -m ansible.builtin.ping
ansible all -m ansible.builtin.command -a 'id -un' --become
```

```text
@all:
  |--@ungrouped:
  |--@linux:
  |  |--@ubuntu:
  |  |  |--srv-ans-ubuntu
  |  |--@rocky:
  |  |  |--srv-ans-rocky
srv-ans-ubuntu | SUCCESS =>
    ansible_facts:
        discovered_interpreter_python: /usr/bin/python3.12
    changed: false
    ping: pong
srv-ans-rocky | SUCCESS =>
    ...
    ping: pong
srv-ans-ubuntu | CHANGED | rc=0 >>
root
srv-ans-rocky | CHANGED | rc=0 >>
root
```

`ping` comprueba SSH + Python + que el módulo se ejecuta (no es ICMP). El `id -un` con `--become` comprueba que `sudo` funciona. Para los **facts** (datos del sistema) usa `setup` con un filtro; sin filtro devuelve cientos de líneas:

```bash
ansible all -m ansible.builtin.setup -a 'filter=ansible_distribution*,ansible_os_family,ansible_python_version,ansible_memtotal_mb'
```

```text
srv-ans-rocky | SUCCESS =>
    ansible_facts:
        ansible_distribution: Rocky
        ansible_distribution_file_variety: RedHat
        ansible_distribution_major_version: '9'
        ansible_distribution_release: Blue Onyx
        ansible_distribution_version: '9.8'
        ansible_memtotal_mb: 7746
        ansible_os_family: RedHat
        ansible_python_version: 3.9.25
    changed: false
```

`ansible_os_family` (`Debian`, `RedHat`, `Suse`…) es el fact que usarás en los `when` para distinguir distribuciones.

## Módulos esenciales para servidores

| Tarea | Módulo | Equivale a |
| --- | --- | --- |
| Paquetes (cualquier distro) | `ansible.builtin.package` | `apt install` / `dnf install` |
| Paquetes con opciones propias | `ansible.builtin.apt`, `ansible.builtin.dnf` | `apt-get upgrade`, `dnf update` |
| Servicios | `ansible.builtin.systemd_service` (o `service`) | `systemctl enable --now` |
| Usuarios y grupos | `ansible.builtin.user`, `ansible.builtin.group` | `useradd`, `groupadd` |
| Llaves SSH | `ansible.posix.authorized_key` | editar `~/.ssh/authorized_keys` |
| Archivos | `ansible.builtin.copy`, `template`, `file` | `cp`, plantilla, `mkdir`/`chmod` |
| Editar una línea o un bloque | `ansible.builtin.lineinfile`, `blockinfile` | `sed`, editar a mano |
| Cron | `ansible.builtin.cron` | `crontab -e` |
| Montajes y fstab | `ansible.posix.mount` | `mount` + `/etc/fstab` |
| LVM y sistemas de archivos | `community.general.lvg`, `lvol`, `filesystem` | `vgcreate`, `lvextend`, `mkfs` |
| Firewall | `ansible.posix.firewalld`, `community.general.ufw` | `firewall-cmd`, `ufw` |
| Reiniciar y esperar | `ansible.builtin.reboot` | `reboot` + esperar a SSH |

Los comandos manuales equivalentes están en [Fundamentos de Linux Server](../linux/linux-fundamentos-servidor.md), [Almacenamiento](../linux/linux-almacenamiento.md) y [Redes en Linux Server](../linux/linux-redes-servidor.md). Ejemplos cortos de los que no aparecen en los casos de uso:

```yaml title="ejemplos de tareas"
- name: Grupo para el equipo de operaciones
  ansible.builtin.group:
    name: operaciones
    state: present

- name: Límite de sesiones SSH (una línea concreta)
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config.d/50-ansible.conf
    regexp: '^MaxSessions'
    line: MaxSessions 4
    create: true
    mode: "0644"
    validate: /usr/sbin/sshd -t -f %s       # si la sintaxis falla, no se escribe
  notify: Recargar sshd

- name: Entradas de /etc/hosts gestionadas como bloque
  ansible.builtin.blockinfile:
    path: /etc/hosts
    marker: "# {mark} ANSIBLE: hosts internos"
    block: |
      10.20.2.11 db-lnx01.corp.ejemplo.com db-lnx01
      10.20.2.12 db-lnx02.corp.ejemplo.com db-lnx02

- name: Copia de seguridad diaria a las 02:15
  ansible.builtin.cron:
    name: backup-diario                      # identifica la entrada: así no se duplica
    minute: "15"
    hour: "2"
    user: root
    job: /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1

- name: Montar el volumen de datos por UUID
  ansible.posix.mount:
    path: /datos
    src: UUID=4f1c2a9e-0000-4b7e-9c55-0d2f6a1b3c4d
    fstype: xfs
    opts: defaults,nofail                    # que un disco ausente no bloquee el arranque
    state: mounted                           # monta y escribe en /etc/fstab

- name: Sistema de archivos XFS en el LV nuevo
  community.general.filesystem:
    fstype: xfs
    dev: /dev/vg_datos/lv_app
```

Son tareas sueltas para copiar dentro de un play (el `notify` necesita un handler `Recargar sshd` en ese play). `lineinfile` es cómodo, pero si gestionas casi todo un archivo usa `template`: varias `lineinfile` sobre el mismo archivo son frágiles. Instala las colecciones con un `requirements.yml` (`ansible.posix`, `community.general`).

## Casos de uso

### Alta de un servidor nuevo

Usuarios con su llave, paquetes base, zona horaria, sincronización de hora y firewall, para Ubuntu y Rocky en el mismo play:

```yaml title="playbooks/alta-servidor.yml"
---
- name: Alta de un servidor Linux nuevo
  hosts: linux
  become: true
  vars:
    alta_zona_horaria: Etc/UTC
    alta_admins:
      - nombre: dani
        llave: "{{ lookup('ansible.builtin.file', 'files/dani.pub') }}"
    alta_paquetes_comunes: [chrony, tar, rsync]
    alta_paquetes_familia:                 # lo que cambia de nombre entre familias
      Debian: [curl, vim, ufw]
      RedHat: [vim-enhanced, firewalld]
    alta_puertos_tcp: ["22", "8080"]
  tasks:
    - name: Instalar paquetes base
      ansible.builtin.package:
        name: "{{ alta_paquetes_comunes + alta_paquetes_familia[ansible_facts['os_family']] }}"
        state: present

    - name: Fijar la zona horaria
      community.general.timezone:
        name: "{{ alta_zona_horaria }}"

    - name: Activar chrony (sincronización de hora)
      ansible.builtin.systemd_service:
        name: "{{ 'chrony' if ansible_facts['os_family'] == 'Debian' else 'chronyd' }}"
        state: started
        enabled: true

    - name: Crear las cuentas de administración
      ansible.builtin.user:
        name: "{{ item.nombre }}"
        groups: "{{ 'sudo' if ansible_facts['os_family'] == 'Debian' else 'wheel' }}"
        append: true                       # sin append, le quitaría el resto de grupos
        shell: /bin/bash
      loop: "{{ alta_admins }}"
      loop_control:
        label: "{{ item.nombre }}"

    - name: Autorizar sus llaves SSH
      ansible.posix.authorized_key:
        user: "{{ item.nombre }}"
        key: "{{ item.llave }}"
        exclusive: true                    # borra cualquier otra llave de ese usuario
      loop: "{{ alta_admins }}"
      loop_control:
        label: "{{ item.nombre }}"

    - name: Firewall en Ubuntu (ufw)
      when: ansible_facts['os_family'] == 'Debian'
      block:
        - name: Permitir los puertos TCP
          community.general.ufw:
            rule: allow
            port: "{{ item }}"
            proto: tcp
          loop: "{{ alta_puertos_tcp }}"

        - name: Activar ufw con política de entrada deny
          community.general.ufw:
            state: enabled
            default: deny
            direction: incoming

    - name: Firewall en Rocky (firewalld)
      when: ansible_facts['os_family'] == 'RedHat'
      block:
        - name: Arrancar firewalld
          ansible.builtin.systemd_service:
            name: firewalld
            state: started
            enabled: true

        - name: Abrir los puertos TCP en la zona public
          ansible.posix.firewalld:
            port: "{{ item }}/tcp"
            zone: public
            permanent: true                # sobrevive a reinicios
            immediate: true                # y se aplica ya
            state: enabled
          loop: "{{ alta_puertos_tcp }}"
```

Primera ejecución real en Ubuntu y segunda (idempotencia). La zona horaria sale `ok` porque la imagen ya venía en UTC: el módulo comprueba antes de cambiar.

```text
TASK [Instalar paquetes base] ********************************
changed: [srv-ans-ubuntu]
TASK [Fijar la zona horaria] *********************************
ok: [srv-ans-ubuntu]
TASK [Activar chrony (sincronización de hora)] ***************
changed: [srv-ans-ubuntu]
TASK [Crear las cuentas de administración] *******************
changed: [srv-ans-ubuntu] => (item=dani)
TASK [Autorizar sus llaves SSH] ******************************
changed: [srv-ans-ubuntu] => (item=dani)
TASK [Permitir los puertos TCP] ******************************
changed: [srv-ans-ubuntu] => (item=22)
changed: [srv-ans-ubuntu] => (item=8080)
TASK [Activar ufw con política de entrada deny] **************
changed: [srv-ans-ubuntu]
PLAY RECAP ***************************************************
srv-ans-ubuntu : ok=8  changed=6  unreachable=0  failed=0  skipped=2

# segunda ejecución
srv-ans-ubuntu : ok=8  changed=0  unreachable=0  failed=0  skipped=2
```

Dos problemas reales que salieron al probarlo en Rocky 9, y que verás en el trabajo:

- La primera versión instalaba `curl` en las dos familias y Rocky falló con `Depsolve Error occurred: ... package curl-minimal ... conflicts with curl provided by curl-7.76.1...`. RHEL 9 y sus clones traen `curl-minimal`, que ya da el comando `curl`. Por eso las listas de paquetes se separan por familia.
- `firewalld` no pudo arrancar dentro del contenedor y la tarea siguiente falló con `firewall is not currently running, unable to perform immediate actions without a running firewall daemon`. En una VM arranca sin problema; si de verdad necesitas configurarlo sin el servicio activo (por ejemplo, al construir una imagen), el módulo tiene `offline: true` y solo admite cambios `permanent`.

El firewall operativo se explica en [Redes en Linux Server](../linux/linux-redes-servidor.md#firewall-en-lo-operativo); qué reglas y qué endurecimiento aplicar, en [Hardening de Linux](../../devsecops/hardening/hardening-linux.md).

### Parches con rolling update

Un **rolling update** (actualización gradual) parchea los servidores por tandas para que el servicio siga disponible. `serial` fija el tamaño de cada tanda y `max_fail_percentage` detiene todo si fallan demasiados:

```yaml title="playbooks/parches.yml"
---
- name: Parches con rolling update
  hosts: linux
  become: true
  serial: 1                          # de uno en uno (también "25%" o una lista [1, "25%", "50%"])
  max_fail_percentage: 0             # si falla uno, no se toca el siguiente
  vars:
    parches_permitir_reinicio: true
  tasks:
    - name: Actualizar paquetes (Debian/Ubuntu)
      ansible.builtin.apt:
        upgrade: dist
        update_cache: true
        autoremove: true
      when: ansible_facts['os_family'] == 'Debian'

    - name: Actualizar paquetes (RHEL/Rocky)
      ansible.builtin.dnf:
        name: "*"
        state: latest # noqa: package-latest
        update_only: true            # actualiza lo instalado, no instala nada nuevo
      when: ansible_facts['os_family'] == 'RedHat'

    - name: Comprobar si hace falta reiniciar (Debian/Ubuntu)
      ansible.builtin.stat:
        path: /var/run/reboot-required
      register: parches_flag_debian
      when: ansible_facts['os_family'] == 'Debian'

    - name: Comprobar si hace falta reiniciar (RHEL/Rocky)
      ansible.builtin.command: needs-restarting -r   # rc=1 si hace falta reiniciar
      register: parches_flag_redhat
      changed_when: false
      failed_when: parches_flag_redhat.rc not in [0, 1]
      when: ansible_facts['os_family'] == 'RedHat'

    - name: Decidir si se reinicia
      ansible.builtin.set_fact:
        parches_reinicio: >-
          {{ (parches_flag_debian.stat.exists | default(false))
             or (parches_flag_redhat.rc | default(0)) == 1 }}

    - name: Reiniciar y esperar a que vuelva
      ansible.builtin.reboot:
        reboot_timeout: 600
        msg: Reinicio por parches (Ansible)
      when:
        - parches_reinicio | bool
        - parches_permitir_reinicio | bool

    - name: Avisar si el reinicio quedó pendiente
      ansible.builtin.debug:
        msg: "Reinicio necesario pero no permitido en {{ inventory_hostname }}"
      when:
        - parches_reinicio | bool
        - not (parches_permitir_reinicio | bool)
```

- `needs-restarting` viene en `dnf-utils` (`yum-utils`) en RHEL y clones. En Debian/Ubuntu el aviso es el archivo `/var/run/reboot-required`, que crean los paquetes que lo necesitan (kernel, libc…).
- `ansible.builtin.reboot` lanza el reinicio, espera a que SSH vuelva y comprueba que el **boot ID** cambió (`/proc/sys/kernel/random/boot_id`). Un contenedor comparte el kernel del host, así que ese ID nunca cambia: por eso en la prueba se ejecutó con `-e parches_permitir_reinicio=false`.

```bash
ansible-playbook playbooks/parches.yml -e parches_permitir_reinicio=false
```

```text
PLAY [Parches con rolling update] ****************************
TASK [Gathering Facts] ***************************************
ok: [srv-ans-ubuntu]
TASK [Actualizar paquetes (Debian/Ubuntu)] *******************
ok: [srv-ans-ubuntu]
...
TASK [Avisar si el reinicio quedó pendiente] *****************
ok: [srv-ans-ubuntu] =>
    msg: Reinicio necesario pero no permitido en srv-ans-ubuntu

PLAY [Parches con rolling update] ****************************
TASK [Gathering Facts] ***************************************
ok: [srv-ans-rocky]
TASK [Actualizar paquetes (RHEL/Rocky)] **********************
changed: [srv-ans-rocky]
...
TASK [Avisar si el reinicio quedó pendiente] *****************
ok: [srv-ans-rocky] =>
    msg: Reinicio necesario pero no permitido en srv-ans-rocky

PLAY RECAP ***************************************************
srv-ans-rocky  : ok=5  changed=1  unreachable=0  failed=0  skipped=3
srv-ans-ubuntu : ok=5  changed=0  unreachable=0  failed=0  skipped=3
```

Fíjate en que el play se repite (**un PLAY por tanda**): primero termina `srv-ans-ubuntu` y solo entonces empieza `srv-ans-rocky`. En Rocky, `needs-restarting -r` pidió reinicio de verdad tras actualizar paquetes del sistema. En Ubuntu se creó el archivo a mano para la prueba. En un entorno real, añade antes y después tareas para **drenar** el nodo del balanceador y comprobar la salud de la aplicación; ver [Despliegue continuo y estrategias](../../devops/ci-cd/despliegue-continuo.md) y el patrón completo en [Casos de uso con flotas mixtas](ansible-casos-uso.md#parches-mensuales-con-ventanas).

### Ampliar un disco LVM

El disco nuevo (`/dev/sdc`) ya está conectado a la VM. Se añade al **volume group** y se extiende el **logical volume** junto con su sistema de archivos, sin desmontar:

```yaml title="playbooks/ampliar-lvm.yml"
---
- name: Ampliar un volumen LVM en caliente
  hosts: db
  become: true
  serial: 1
  vars:
    lvm_vg: vg_datos
    lvm_lv: lv_pg
    lvm_pvs:                       # TODOS los PV del VG: los que no estén se quitarían
      - /dev/sdb
      - /dev/sdc
    lvm_tamano: +100%FREE          # "+" = añadir; sin "+" sería el tamaño final
  tasks:
    - name: Añadir el disco nuevo al volume group
      community.general.lvg:
        vg: "{{ lvm_vg }}"
        pvs: "{{ lvm_pvs }}"

    - name: Extender el LV y el sistema de archivos
      community.general.lvol:
        vg: "{{ lvm_vg }}"
        lv: "{{ lvm_lv }}"
        size: "{{ lvm_tamano }}"
        resizefs: true             # equivale a lvextend -r: crece ext4 o XFS

    - name: Comprobar el espacio final
      ansible.builtin.command: df -h /var/lib/postgresql
      register: lvm_df
      changed_when: false

    - name: Mostrar el resultado
      ansible.builtin.debug:
        var: lvm_df.stdout_lines
```

!!! danger "Cuidado con `pvs` en `lvg`"
    `community.general.lvg` deja el VG con **exactamente** los PV de la lista: si olvidas uno que tiene datos, intentará quitarlo. Prueba siempre con `--check --diff` y `--limit` a un solo host. El procedimiento manual y el caso de nube (`growpart` cuando amplías el disco en lugar de añadir uno) están en [Ampliar un LV en caliente](../linux/linux-almacenamiento.md#ampliar-un-lv-en-caliente).

Este playbook solo se validó con `ansible-lint` y `ansible-doc` (el `+` en `size` lo admite `lvol` desde community.general 3.0.0): no se crearon discos en las pruebas.

### Desplegar un servicio systemd con template y handler

```yaml title="playbooks/servicio.yml"
---
- name: Desplegar un servicio systemd con template y handler
  hosts: linux
  become: true
  vars:
    app_nombre: lab-web
    app_puerto: 8080
    app_dir: /srv/lab-web
  tasks:
    - name: Crear el usuario de sistema
      ansible.builtin.user:
        name: "{{ app_nombre }}"
        system: true
        shell: /usr/sbin/nologin
        create_home: false

    - name: Crear la carpeta del contenido
      ansible.builtin.file:
        path: "{{ app_dir }}"
        state: directory
        owner: "{{ app_nombre }}"
        mode: "0755"

    - name: Publicar la página
      ansible.builtin.copy:
        content: "Hola desde {{ inventory_hostname }} ({{ ansible_facts['distribution'] }})\n"
        dest: "{{ app_dir }}/index.html"
        mode: "0644"

    - name: Instalar la unit de systemd
      ansible.builtin.template:
        src: templates/lab-web.service.j2
        dest: /etc/systemd/system/{{ app_nombre }}.service
        mode: "0644"
      notify: Reiniciar lab-web

    - name: Activar el servicio
      ansible.builtin.systemd_service:
        name: "{{ app_nombre }}"
        state: started
        enabled: true
        daemon_reload: true          # relee las units antes de arrancar

  handlers:
    - name: Reiniciar lab-web
      ansible.builtin.systemd_service:
        name: "{{ app_nombre }}"
        state: restarted
        daemon_reload: true
```

```ini title="playbooks/templates/lab-web.service.j2"
# {{ ansible_managed }}
[Unit]
Description={{ app_nombre }} (servidor HTTP de ejemplo)
After=network-online.target
Wants=network-online.target

[Service]
User={{ app_nombre }}
WorkingDirectory={{ app_dir }}
ExecStart=/usr/bin/python3 -m http.server {{ app_puerto }} --bind 0.0.0.0
Restart=on-failure
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
```

Tres ejecuciones reales: la primera crea todo, la segunda no cambia nada y la tercera cambia el puerto, lo que modifica la unit y **dispara el handler**:

```bash
ansible-playbook playbooks/servicio.yml
ansible-playbook playbooks/servicio.yml
ansible-playbook playbooks/servicio.yml -e app_puerto=8081 --diff
```

```text
# 1.ª: ok=7 changed=6 en cada host (incluye RUNNING HANDLER [Reiniciar lab-web])
# 2.ª: ok=6 changed=0 en cada host (sin handler)
# 3.ª:
TASK [Instalar la unit de systemd] ***************************
--- before: /etc/systemd/system/lab-web.service
+++ after: .../lab-web.service.j2
@@ -7,7 +7,7 @@
 [Service]
 User=lab-web
 WorkingDirectory=/srv/lab-web
-ExecStart=/usr/bin/python3 -m http.server 8080 --bind 0.0.0.0
+ExecStart=/usr/bin/python3 -m http.server 8081 --bind 0.0.0.0
 Restart=on-failure
changed: [srv-ans-ubuntu]
changed: [srv-ans-rocky]
TASK [Activar el servicio] ***********************************
ok: [srv-ans-ubuntu]
ok: [srv-ans-rocky]
RUNNING HANDLER [Reiniciar lab-web] **************************
changed: [srv-ans-ubuntu]
changed: [srv-ans-rocky]
PLAY RECAP ***************************************************
srv-ans-rocky  : ok=7  changed=2  unreachable=0  failed=0  skipped=0
srv-ans-ubuntu : ok=7  changed=2  unreachable=0  failed=0  skipped=0
```

Y la comprobación desde cada servidor:

```bash
ansible linux -m ansible.builtin.uri -a 'url=http://127.0.0.1:8081/ return_content=true'
```

```text
srv-ans-ubuntu | SUCCESS =>
    content: |-
        Hola desde srv-ans-ubuntu (Ubuntu)
    server: SimpleHTTP/0.6 Python/3.12.3
    status: 200
srv-ans-rocky | SUCCESS =>
    content: |-
        Hola desde srv-ans-rocky (Rocky)
    server: SimpleHTTP/0.6 Python/3.9.25
    status: 200
```

Sin el handler, cambiar la unit no reiniciaría el servicio: seguiría escuchando en 8080 con la configuración vieja hasta el siguiente reinicio, el típico "lo cambié y no hace nada". Las units de systemd y sus drop-ins se explican en [Servicios con systemd](../linux/linux-fundamentos-servidor.md#servicios-con-systemd).

## Problemas comunes

Todos los mensajes de esta tabla salieron en las pruebas, salvo el de `requiretty`:

| Síntoma (mensaje real) | Causa | Solución |
| --- | --- | --- |
| `UNREACHABLE! ... ssh: connect to host 127.0.0.1 port 2229: Connection refused` | Puerto equivocado, `sshd` parado o firewall | `ansible_port` correcto; `systemctl status ssh` (o `sshd`) en el host; revisa security groups / NSG / firewall |
| `UNREACHABLE! ... ansible@127.0.0.1: Permission denied (publickey,password).` | La llave que ofreces no está en `authorized_keys` de ese usuario, o el usuario es otro | Revisa `ansible_user` y `ansible_ssh_private_key_file`; `ssh -i llave usuario@host` a mano; `ssh-add -l` para ver qué llaves tiene el agente |
| `WARNING: UNPROTECTED PRIVATE KEY FILE! Permissions 0777 for '.../id_lab' are too open. ... This private key will be ignored.` seguido de `Permission denied (publickey,password)` | La llave privada tiene permisos abiertos. Típico al guardarla en `/mnt/c` desde WSL | `chmod 600` en un sistema de archivos de Linux (`~/.ssh`), o cárgala en ssh-agent |
| `Host key verification failed.` | La host key no está en `known_hosts` (o cambió). Con `ProxyJump`, el salto usa su propio `known_hosts` | `ssh-keyscan` del host (y del bastion); configura el bastion en `~/.ssh/config`. Si la llave cambió sin motivo, investiga antes de aceptarla |
| `FAILED! ... Task failed: Missing sudo password` | El usuario necesita contraseña para `sudo` y no se la diste | `-K` / `ansible_become_password` (en Vault), o una regla `NOPASSWD` para la cuenta de automatización |
| `The module interpreter '/usr/bin/python' was not found.` con `module_stderr: /bin/sh: 1: /usr/bin/python: not found` | `ansible_python_interpreter` apunta a un Python que no existe (las distros actuales solo tienen `python3`) | Quita la variable para que actúe la detección automática, o pon `/usr/bin/python3` |
| Error del intérprete o `python3: not found` en un host recién creado | La imagen mínima no trae Python | Instálalo con `ansible.builtin.raw` y `gather_facts: false` en un play previo |
| `sudo: sorry, you must have a tty to run sudo` | `Defaults requiretty` en sudoers (sistemas antiguos) con `pipelining = True` | Quita `requiretty` de sudoers o desactiva `pipelining` para esos hosts |
| `Depsolve Error occurred ... conflicts with curl provided by ...` | Paquete con otro nombre o en conflicto en esa familia (aquí `curl-minimal` en RHEL 9) | Listas de paquetes por `ansible_os_family` |
| `firewall is not currently running, unable to perform immediate actions` | `firewalld` parado o sin arrancar | Arráncalo antes; para imágenes, `offline: true` con `permanent: true` |
| Tareas lentas en flotas grandes | `forks` bajo, sin `pipelining`, facts completos en cada play | Sube `forks`, activa `pipelining`, usa `gather_facts: false` o **fact caching** donde no hagan falta |

### Depurar con -vvvv

```bash
ansible srv-ans-ubuntu -m ansible.builtin.ping -vvvv
```

```text
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: ansible
<127.0.0.1> SSH: EXEC ssh -F .../ssh_config -o Port=2221 -o KbdInteractiveAuthentication=no
  -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey
  -o PasswordAuthentication=no -o 'User="ansible"' -o ConnectTimeout=10 ...
<127.0.0.1> (255, b'', b'ansible@127.0.0.1: Permission denied (publickey,password).\r\n')
```

Con `-vvvv` ves **el comando `ssh` exacto** que lanza Ansible (usuario, puerto, opciones). Cópialo, quítale lo que sobra y ejecútalo tú: si `ssh` a mano falla igual, el problema no es de Ansible sino de SSH, de red o del servidor. Para eso, el método de [Troubleshooting](../../devops/operacion/troubleshooting.md) y los registros de `sshd` (`journalctl -u ssh` en Ubuntu, `-u sshd` en RHEL) en el servidor.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Servidores (la base) | Lo que Ansible automatiza, hecho a mano | [Fundamentos de Linux Server](../linux/linux-fundamentos-servidor.md), [Almacenamiento](../linux/linux-almacenamiento.md), [Redes en Linux Server](../linux/linux-redes-servidor.md), [Procesos y rendimiento](../linux/linux-procesos-rendimiento.md) |
| Servidores (automatización) | Windows y flotas mixtas | [Ansible con Windows Server](ansible-windows.md), [Casos de uso con flotas mixtas](ansible-casos-uso.md) |
| Cloud (el control) | Las VMs, sus llaves SSH y el acceso a redes privadas | [Máquinas virtuales](../../cloud/computo/maquinas-virtuales.md), [Redes en la nube](../../cloud/redes-y-datos/redes.md) |
| DevOps (la automatización) | Conceptos, roles, pruebas y estrategias de despliegue | [Configuration management con Ansible](../../devops/iac/ansible.md), [Pruebas de infraestructura](../../devops/iac/pruebas-infraestructura.md), [Despliegue continuo](../../devops/ci-cd/despliegue-continuo.md), [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md) |
| DevSecOps (la verificación) | Endurecer lo que configuras y hacerlo como código | [Hardening de Linux](../../devsecops/hardening/hardening-linux.md), [Hardening como código](../../devsecops/hardening/hardening-como-codigo.md), [Lab 22: Hardening de Linux con Ansible](../../laboratorios/devsecops/hardening-linux-ansible.md) |
| Recursos | Comandos y estructura de archivos | [Comandos de Ansible](../../recursos/comandos/ansible.md), [Anatomía de Ansible](../../recursos/anatomia/ansible.md) |

## Referencias

- [Ansible: Connection methods and details](https://docs.ansible.com/ansible/latest/inventory_guide/connection_details.html)
- [Ansible: Understanding privilege escalation (become)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_privilege_escalation.html)
- [Ansible: Interpreter discovery](https://docs.ansible.com/ansible/latest/reference_appendices/interpreter_discovery.html)
- [Ansible: Controlling playbook execution (serial, max_fail_percentage)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_strategies.html)
- [Ansible: Release and maintenance (matriz de versiones de Python)](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html)
- [Ansible: Special variables y connection variables](https://docs.ansible.com/ansible/latest/reference_appendices/special_variables.html)
- [Módulo `ansible.builtin.reboot`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/reboot_module.html)
- [Módulo `ansible.posix.authorized_key`](https://docs.ansible.com/ansible/latest/collections/ansible/posix/authorized_key_module.html)
- [Módulo `community.general.lvol`](https://docs.ansible.com/ansible/latest/collections/community/general/lvol_module.html)
- [Módulo `ansible.posix.firewalld`](https://docs.ansible.com/ansible/latest/collections/ansible/posix/firewalld_module.html) y [`community.general.ufw`](https://docs.ansible.com/ansible/latest/collections/community/general/ufw_module.html)
- [DNF plugins: needs-restarting (`-r`: código 1 si hace falta reiniciar)](https://dnf-plugins-core.readthedocs.io/en/latest/needs_restarting.html)
- [OpenSSH: ssh_config(5), ProxyJump](https://man.openbsd.org/ssh_config)
