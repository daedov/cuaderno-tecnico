# Servidores :material-server:

**Servidores es la base de sistemas**: cómo administrar Linux Server y Windows Server con soltura (comandos, configuración, almacenamiento, red, servicios y rendimiento) y cómo **automatizarlos con Ansible**. Aunque la infraestructura viva en la nube, debajo de cada VM, nodo de Kubernetes o runner de CI hay un sistema operativo que alguien tiene que entender.

Cada nota explica los comandos con su porqué, muestra la salida esperada y termina con **casos de uso** resueltos y problemas comunes. La seguridad de los servidores está en [Hardening](../devsecops/hardening/fundamentos-hardening.md), y la chuleta rápida de comandos en [Recursos > Linux](../recursos/comandos/linux.md). Ver también el [mapa de relaciones](../mapa-de-relaciones.md).

## Linux Server

- [Fundamentos de Linux Server](linux/linux-fundamentos-servidor.md): distribuciones, arranque, jerarquía de archivos, usuarios, permisos, paquetes, systemd y journald
- [Almacenamiento en Linux](linux/linux-almacenamiento.md): discos, particiones, sistemas de archivos, fstab, LVM, swap y ampliar discos en la nube
- [Redes en Linux Server](linux/linux-redes-servidor.md): ip, Netplan y nmcli, DNS, puertos, firewall, SSH del lado servidor y chrony
- [Procesos, rendimiento y tareas programadas](linux/linux-procesos-rendimiento.md): procesos y señales, memoria y OOM, CPU, I/O, cron y systemd timers

## Windows Server

- [Fundamentos de Windows Server](windows/windows-server-fundamentos.md): ediciones, Server Core, roles y features, Windows Admin Center, PowerShell y administración remota
- [Administración con PowerShell](windows/windows-powershell-administracion.md): usuarios, servicios, Event Logs, actualizaciones, tareas, firewall, red, discos y equivalencias con Linux
- [Roles y servicios](windows/windows-roles-servicios.md): Active Directory, DNS, DHCP, Group Policy, IIS y file server

## Ansible con servidores

- [Ansible con Linux](ansible/ansible-linux.md): conexión SSH, become, intérprete, módulos esenciales, rolling updates y troubleshooting
- [Ansible con Windows](ansible/ansible-windows.md): WinRM, PSRP y SSH, Kerberos y NTLM, colecciones y módulos `win_*`, casos de uso
- [Casos de uso en flotas mixtas](ansible/ansible-casos-uso.md): inventario único y dinámico, parches, usuarios, cumplimiento y AWX

!!! tip "Para practicar"
    El [Lab 10](../laboratorios/devops/ansible-configuracion.md) configura servidores Linux con Ansible y el [Lab 22](../laboratorios/devsecops/hardening-linux-ansible.md) los endurece y mide el resultado.

!!! note "Añadir una nota"
    Crea el `.md` en `linux/`, `windows/` o `ansible/` y agrégalo a su `.pages` para fijar su orden en el menú.
