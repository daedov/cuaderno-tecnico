---
tags:
  - linux
  - cloud
---
# Amazon Linux

Comandos propios de Amazon Linux. Lo común a cualquier Linux (archivos, permisos, procesos, `systemctl`, red) está en [Linux](linux.md). Para la versión de Debian ver [Debian](debian.md).

!!! info "Versión de referencia"
    Amazon Linux 2023 (AL2023). El usuario por defecto en EC2 es `ec2-user`. Amazon Linux 2 usa `yum` y `amazon-linux-extras`, que ya no existen en AL2023.

## 1. Identificar el sistema
| Comando | Descripción |
|---------|-------------|
| `cat /etc/os-release` | Ver distribución y versión |
| `cat /etc/amazon-linux-release` | Ver la versión exacta |
| `hostnamectl` | Ver nombre del equipo, sistema operativo y kernel |
| `uname -r` | Ver el kernel en uso |
| `rpm -q kernel` | Listar los kernels instalados |

## 2. Actualizar el sistema
| Comando | Descripción |
|---------|-------------|
| `sudo dnf makecache` | Actualizar el índice de paquetes |
| `dnf check-update` | Ver qué paquetes tienen actualización |
| `sudo dnf upgrade` | Actualizar paquetes |
| `dnf updateinfo list` | Ver los avisos de seguridad pendientes |
| `sudo dnf upgrade --security` | Instalar solo parches de seguridad |
| `dnf check-release-update` | Ver si hay una versión nueva de AL2023 |
| `sudo dnf upgrade --releasever=<versión>` | Pasar a una versión concreta de AL2023 |
| `sudo dnf needs-restarting -r` | Ver si el sistema necesita reiniciarse |

!!! tip "AL2023 está fijado a una versión"
    Cada AMI apunta a una versión concreta del repositorio, así que `dnf upgrade` **no** salta a la siguiente. Para eso se usa `dnf check-release-update` y luego `--releasever`.

## 3. Instalar, buscar y quitar paquetes
| Comando | Descripción |
|---------|-------------|
| `dnf search <texto>` | Buscar un paquete |
| `dnf info <paquete>` | Ver información de un paquete |
| `sudo dnf install <paquete>` | Instalar un paquete |
| `sudo dnf install ./<archivo>.rpm` | Instalar un `.rpm` local resolviendo dependencias |
| `sudo dnf reinstall <paquete>` | Reinstalar un paquete |
| `sudo dnf remove <paquete>` | Desinstalar un paquete |
| `sudo dnf autoremove` | Quitar dependencias que ya no se usan |
| `sudo dnf clean all` | Vaciar la caché de paquetes y metadatos |

## 4. Consultar paquetes instalados
| Comando | Descripción |
|---------|-------------|
| `rpm -qa` | Listar paquetes instalados |
| `dnf list installed` | Listar paquetes instalados (formato de `dnf`) |
| `rpm -q <paquete>` | Ver si un paquete está instalado y su versión |
| `rpm -ql <paquete>` | Ver los archivos que instaló un paquete |
| `rpm -qf <ruta>` | Ver qué paquete instaló un archivo |
| `dnf provides <archivo>` | Buscar qué paquete contiene un archivo o comando, aunque no esté instalado |
| `dnf list --showduplicates <paquete>` | Ver todas las versiones disponibles |
| `dnf repoquery --requires <paquete>` | Ver las dependencias de un paquete |
| `dnf history` | Ver el historial de instalaciones |
| `dnf history info <id>` | Ver el detalle de una transacción |
| `sudo dnf history undo <id>` | Deshacer una transacción |

## 5. Bloquear versiones y repositorios
| Comando | Descripción |
|---------|-------------|
| `sudo dnf install python3-dnf-plugin-versionlock` | Instalar el plugin para bloquear versiones |
| `sudo dnf versionlock add <paquete>` | Impedir que un paquete se actualice |
| `sudo dnf versionlock delete <paquete>` | Quitar el bloqueo |
| `dnf versionlock list` | Ver paquetes bloqueados |
| `dnf repolist` | Ver los repositorios activos |
| `/etc/yum.repos.d/` | Carpeta donde se configuran los repos |

!!! note
    **EPEL no es compatible** con AL2023. Si falta un paquete, revisa primero los repos de Amazon o instala desde el binario oficial del proyecto.

## 6. Actualizaciones automáticas
| Comando | Descripción |
|---------|-------------|
| `sudo dnf install dnf-automatic` | Instalar la herramienta |
| `/etc/dnf/automatic.conf` | Archivo donde se elige qué se actualiza y si se aplica |
| `sudo systemctl enable --now dnf-automatic.timer` | Activar la ejecución programada |
| `sudo dnf-automatic --downloadupdates` | Ejecutar una vez solo descargando, sin instalar |
| `systemctl list-timers dnf-automatic*` | Ver cuándo se ejecuta la próxima vez |

## 7. Usuarios
| Comando | Descripción |
|---------|-------------|
| `sudo useradd -m <usuario>` | Crear un usuario con su home |
| `sudo passwd <usuario>` | Asignarle contraseña |
| `sudo usermod -aG wheel <usuario>` | Dar permisos de sudo (grupo `wheel`) |
| `sudo userdel -r <usuario>` | Eliminar un usuario y su home |

## 8. Seguridad del sistema
| Comando | Descripción |
|---------|-------------|
| `sestatus` | Ver el estado de SELinux (en AL2023 viene en modo *permissive*) |
| `getenforce` | Ver el modo actual de SELinux |
| `sudo setenforce 1` | Pasar a modo *enforcing* hasta el próximo reinicio |
| `/etc/selinux/config` | Archivo para cambiar el modo de forma permanente |
| `sudo ausearch -m avc -ts recent` | Ver bloqueos recientes de SELinux |
| `sudo dnf install firewalld` | Instalar el firewall (no viene por defecto) |
| `sudo systemctl enable --now firewalld` | Activar el firewall |
| `sudo firewall-cmd --permanent --add-port=<puerto>/tcp` | Abrir un puerto de forma permanente |
| `sudo firewall-cmd --reload` | Aplicar los cambios |
| `sudo firewall-cmd --list-all` | Ver las reglas activas |
| `sudo nft list ruleset` | Ver las reglas a bajo nivel (nftables) |

!!! warning "En EC2 el firewall principal es el grupo de seguridad"
    Si un puerto no responde, revisa primero el **security group** y la **NACL** de la subred, y después el firewall del sistema.

## 9. Logs
| Comando | Descripción |
|---------|-------------|
| `journalctl -p err -b` | Ver solo errores del arranque actual |
| `journalctl -u sshd` | Ver logs del servicio SSH (en AL2023 se llama `sshd`) |
| `cat /var/log/dnf.log` | Ver el log de `dnf` |

!!! note
    AL2023 no instala `rsyslog` por defecto, así que no existe `/var/log/messages`: todo se lee con `journalctl`.

## 10. En EC2
| Comando | Descripción |
|---------|-------------|
| `cloud-init status --long` | Ver si el *user data* terminó y si dio error |
| `cat /var/log/cloud-init-output.log` | Ver la salida del script de *user data* |
| `ec2-metadata --all` | Ver todos los metadatos de la instancia |
| `ec2-metadata -i` | Ver el ID de la instancia |
| `systemctl status amazon-ssm-agent` | Ver el agente de Systems Manager (viene instalado) |
| `chronyc sources -v` | Ver la sincronización de hora (usa Amazon Time Sync) |

!!! example "Practica en el laboratorio"
    - [Lab 01: Diagnóstico de red desde Linux](../../laboratorios/fundamentos/linux-red-diagnostico.md)
