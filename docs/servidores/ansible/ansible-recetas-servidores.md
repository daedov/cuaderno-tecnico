---
tags:
  - servidores
  - ansible
  - linux
  - windows
---

# Recetas de Ansible para servidores

> Playbooks completos para tareas de administración de servidores, por sistema operativo. En Linux: alta de un servidor, parches con rolling update, ampliar un volumen LVM y desplegar un servicio systemd. En Windows: IIS, Windows Updates por lotes, unirse a Active Directory y el servicio de un agente.

!!! info "Antes de leer"
    La conexión, las variables y los módulos de cada sistema están en [Ansible con Linux Server](ansible-linux.md) y [Ansible con Windows Server](ansible-windows.md): estas recetas usan el mismo inventario (grupos `linux`, `ubuntu`, `rhel`, `windows`, `win_web`, `win_app`). Los casos que mezclan los dos sistemas en un mismo playbook (parches por ventanas, usuarios, cumplimiento) están en [Ansible en flotas mixtas](ansible-casos-uso.md).

!!! note "Cómo se probó"
    - **Linux**: ejecutadas por SSH contra los dos contenedores de [Ansible con Linux Server](ansible-linux.md) (Ubuntu 24.04 y Rocky Linux 9.8 con systemd), con salidas reales. Límites del contenedor: no se puede reiniciar de verdad (el reinicio se simuló), firewalld no arranca porque el kernel de Docker Desktop no tiene las funciones de nftables que necesita, y el caso de LVM solo se validó con `ansible-lint` (no se crearon discos).
    - **Windows**: **no se ejecutaron** (sin host Windows). Se validaron con `--syntax-check`, `ansible-lint` y `ansible-doc` con las colecciones de [Ansible con Windows Server](ansible-windows.md); las salidas contra Windows están marcadas como **salida esperada**.

## Linux

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

Las tareas de Linux de un **rolling update** (actualización gradual): actualizar, detectar si hace falta reiniciar y reiniciar esperando a que vuelva. Aquí va la forma más prudente, de uno en uno; el patrón de tandas completo (`serial` como número, porcentaje o lista, `max_fail_percentage`, ventanas y drenado del balanceador) se explica en [Parches mensuales con ventanas](ansible-casos-uso.md#parches-mensuales-con-ventanas).

```yaml title="playbooks/parches.yml"
---
- name: Parches con rolling update
  hosts: linux
  become: true
  serial: 1                          # de uno en uno
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

Fíjate en que el play se repite (**un PLAY por tanda**): primero termina `srv-ans-ubuntu` y solo entonces empieza `srv-ans-rocky`. En Rocky, `needs-restarting -r` pidió reinicio de verdad tras actualizar paquetes del sistema. En Ubuntu se creó el archivo a mano para la prueba. En un entorno real, añade antes y después las tareas para **drenar** el nodo del balanceador, como en [Parches mensuales con ventanas](ansible-casos-uso.md#parches-mensuales-con-ventanas).

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

Es el mecanismo de template + `notify` + handler del [role comentado de la Anatomía](../../recursos/anatomia/ansible.md#role-comentado) (cuándo y cuántas veces corre un handler: [handlers/main.yml](../../recursos/anatomia/ansible.md#handlersmainyml)), aplicado a una unit de systemd y con su ejecución real en las dos distribuciones:

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

## Windows

### Instalar IIS y publicar un sitio

```yaml title="playbooks/win-iis.yml"
---
- name: Instalar IIS y publicar un sitio
  hosts: win_web
  vars:
    iis_sitio: intranet
    iis_ruta: C:\inetpub\intranet
    iis_puerto: 80
  tasks:
    - name: Instalar el rol Web-Server con sus herramientas
      ansible.windows.win_feature:
        name: Web-Server
        include_management_tools: true
        state: present
      register: iis_feature

    - name: Reiniciar si la instalación lo pide
      ansible.windows.win_reboot:
      when: iis_feature.reboot_required

    - name: Crear la carpeta del sitio
      ansible.windows.win_file:
        path: "{{ iis_ruta }}"
        state: directory

    - name: Publicar la página de inicio
      ansible.windows.win_template:
        src: templates/index.html.j2
        dest: "{{ iis_ruta }}\\index.html"

    - name: Crear el application pool
      microsoft.iis.web_app_pool:
        name: "{{ iis_sitio }}"
        state: started

    - name: Crear el sitio con su binding
      microsoft.iis.website:
        name: "{{ iis_sitio }}"
        physical_path: "{{ iis_ruta }}"
        application_pool: "{{ iis_sitio }}"
        state: started
        bindings:
          set:                                  # lista exacta: quita los bindings que no estén
            - ip: "*"
              port: "{{ iis_puerto }}"
              hostname: intranet.corp.ejemplo.com

    - name: Abrir el puerto HTTP en el firewall
      ansible.windows.win_firewall_rule:
        name: IIS intranet HTTP
        localport: "{{ iis_puerto }}"
        protocol: tcp
        direction: in
        action: allow
        profiles: [domain]
        state: present
        enabled: true

    - name: Comprobar que responde
      ansible.windows.win_uri:
        url: http://localhost:{{ iis_puerto }}/
        headers:
          Host: intranet.corp.ejemplo.com
        return_content: true
      register: iis_respuesta
      failed_when: "'intranet' not in iis_respuesta.content"
```

```text title="Salida esperada (no ejecutada: sin host Windows)"
TASK [Instalar el rol Web-Server con sus herramientas] ****
changed: [win-web01]
changed: [win-web02]
TASK [Reiniciar si la instalación lo pide] ****************
skipping: [win-web01]
skipping: [win-web02]
...
PLAY RECAP ************************************************
win-web01 : ok=8  changed=6  unreachable=0  failed=0  skipped=1
win-web02 : ok=8  changed=6  unreachable=0  failed=0  skipped=1
```

El certificado HTTPS del sitio y la configuración manual de IIS están en [IIS](../windows/windows-roles-servicios.md#iis).

### Windows Updates por lotes con reinicio

```yaml title="playbooks/win-updates.yml"
---
- name: Windows Updates por lotes con reinicio
  hosts: windows
  serial: "25%"                     # de cuatro en cuatro si hay 16 servidores
  max_fail_percentage: 0
  tasks:
    - name: Buscar las actualizaciones pendientes (sin instalar)
      ansible.windows.win_updates:
        category_names:
          - SecurityUpdates
          - CriticalUpdates
          - UpdateRollups
        state: searched
      register: upd_pendientes

    - name: Mostrar cuántas hay
      ansible.windows.win_shell: Write-Output "{{ upd_pendientes.found_update_count }} actualizaciones pendientes"
      changed_when: false

    - name: Instalar y reiniciar las veces que haga falta
      ansible.windows.win_updates:
        category_names:
          - SecurityUpdates
          - CriticalUpdates
          - UpdateRollups
        reject_list:
          - KB5034441                   # ejemplo: un KB que tu equipo decidió aplazar
        reboot: true                    # reinicia y continúa hasta terminar
        reboot_timeout: 3600
      register: upd_resultado

    - name: Fallar si alguna no se instaló
      ansible.builtin.assert:
        that: upd_resultado.failed_update_count | default(0) == 0
        fail_msg: "{{ upd_resultado.failed_update_count }} actualizaciones fallaron en {{ inventory_hostname }}"
```

- Las tandas (`serial`, `max_fail_percentage`) siguen el patrón de [Parches mensuales con ventanas](ansible-casos-uso.md#parches-mensuales-con-ventanas); lo propio de Windows es `win_updates`.
- `state: searched` es el "modo informe": lista sin instalar. Útil para revisar antes de la ventana.
- Con `reboot: true`, el módulo reinicia y vuelve a buscar hasta que no quedan actualizaciones de esas categorías.
- Si los servidores usan **WSUS** o Windows Update for Business, el módulo respeta esa configuración (`server_selection` permite forzar `windows_update`). Las políticas de parcheo están en [Hardening de Windows](../../devsecops/hardening/hardening-windows.md#parches-windows-update-y-wsus).

### Unir servidores a Active Directory

```yaml title="playbooks/win-dominio.yml"
---
- name: Unir servidores Windows al dominio
  hosts: win_app
  vars:
    dominio_fqdn: corp.ejemplo.com
    dominio_ou: OU=Servidores,DC=corp,DC=ejemplo,DC=com
  tasks:
    - name: Apuntar el DNS a los controladores de dominio
      ansible.windows.win_dns_client:
        adapter_names: "*"
        dns_servers:
          - 10.20.0.10
          - 10.20.0.11

    - name: Unir al dominio en la OU de servidores y reiniciar
      microsoft.ad.membership:
        dns_domain_name: "{{ dominio_fqdn }}"
        hostname: "{{ inventory_hostname }}"    # renombra y une en un solo reinicio
        domain_ou_path: "{{ dominio_ou }}"
        domain_admin_user: "{{ vault_join_user }}"
        domain_admin_password: "{{ vault_join_password }}"
        state: domain
        reboot: true
      no_log: true
```

Antes de unirse, el servidor **no está en el dominio**, así que la primera conexión no puede ser Kerberos: usa una cuenta local con NTLM sobre HTTPS (o SSH) para este play, y Kerberos a partir de ahí. Usa una cuenta con permiso **solo** para unir equipos a esa OU (delegación en AD), no un Domain Admin. Los pasos manuales equivalentes (`Add-Computer`) están en [Unir un equipo al dominio](../windows/windows-roles-servicios.md#unir-un-equipo-al-dominio).

### Regla de firewall y servicio de un agente

```yaml title="playbooks/win-firewall-servicio.yml"
---
- name: Regla de firewall y servicio de un agente
  hosts: win_app
  vars:
    agente_msi_url: https://repo.corp.ejemplo.com/agente/agente-2.4.1-x64.msi
    agente_product_id: "{6F1A6B3E-0000-4C2B-9C1D-1234567890AB}"
  tasks:
    - name: Instalar el agente desde un MSI
      ansible.windows.win_package:
        path: "{{ agente_msi_url }}"
        product_id: "{{ agente_product_id }}"   # así sabe si ya está instalado (idempotencia)
        arguments: /qn /norestart
        state: present

    - name: Permitir el puerto del agente solo desde la red de gestión
      ansible.windows.win_firewall_rule:
        name: Agente de monitoreo 9182
        localport: 9182
        protocol: tcp
        direction: in
        action: allow
        remoteip: 10.20.0.0/24
        profiles: [domain, private]
        state: present
        enabled: true

    - name: Servicio en automático con reinicio ante fallos
      ansible.windows.win_service:
        name: AgenteMonitoreo
        start_mode: auto
        state: started
        failure_actions:                        # lo mismo que "sc.exe failure"
          - type: restart
            delay_ms: 5000
          - type: restart
            delay_ms: 30000
        failure_reset_period_sec: 86400
```

Sin `product_id`, `win_package` no puede saber si el MSI ya está instalado y lo descargaría en cada ejecución. Lo obtienes en un equipo donde ya esté instalado, en el registro de desinstalación (`Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*` y la propiedad `PSChildName`). Evita `Win32_Product`: es lento y hace que Windows Installer revise todos los MSI.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Servidores (la base) | Lo mismo hecho a mano | [Fundamentos de Linux Server](../linux/linux-fundamentos-servidor.md), [Almacenamiento](../linux/linux-almacenamiento.md), [Redes en Linux Server](../linux/linux-redes-servidor.md), [Roles y servicios de Windows Server](../windows/windows-roles-servicios.md) |
| Servidores (automatización) | Conexión de cada sistema y casos con flotas mixtas | [Ansible con Linux Server](ansible-linux.md), [Ansible con Windows Server](ansible-windows.md), [Ansible en flotas mixtas](ansible-casos-uso.md) |
| DevOps (la automatización) | Conceptos, roles y estrategias de despliegue | [Configuration management con Ansible](../../devops/iac/ansible.md), [Anatomía de Ansible](../../recursos/anatomia/ansible.md), [Despliegue continuo](../../devops/ci-cd/despliegue-continuo.md) |
| DevSecOps (la verificación) | Qué reglas y qué endurecimiento aplicar | [Hardening de Linux](../../devsecops/hardening/hardening-linux.md), [Hardening de Windows](../../devsecops/hardening/hardening-windows.md) |

## Referencias

- [Ansible: Controlling playbook execution (serial, max_fail_percentage)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_strategies.html)
- [Módulo `ansible.builtin.reboot`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/reboot_module.html)
- [Módulo `ansible.posix.authorized_key`](https://docs.ansible.com/ansible/latest/collections/ansible/posix/authorized_key_module.html)
- [Módulo `community.general.lvol`](https://docs.ansible.com/ansible/latest/collections/community/general/lvol_module.html)
- [Módulo `ansible.posix.firewalld`](https://docs.ansible.com/ansible/latest/collections/ansible/posix/firewalld_module.html) y [`community.general.ufw`](https://docs.ansible.com/ansible/latest/collections/community/general/ufw_module.html)
- [DNF plugins: needs-restarting (`-r`: código 1 si hace falta reiniciar)](https://dnf-plugins-core.readthedocs.io/en/latest/needs_restarting.html)
- [Colección `ansible.windows`](https://docs.ansible.com/ansible/latest/collections/ansible/windows/index.html)
- [Colección `microsoft.ad`](https://docs.ansible.com/ansible/latest/collections/microsoft/ad/index.html)
- [Colección `microsoft.iis` en Ansible Galaxy](https://galaxy.ansible.com/ui/repo/published/microsoft/iis/)
