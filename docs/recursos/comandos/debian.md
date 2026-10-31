---
tags:
  - linux
---
# Debian

Comandos propios de Debian. Lo común a cualquier Linux (archivos, permisos, procesos, `systemctl`, red) está en [Linux](linux.md). Para la versión de Amazon ver [Amazon Linux](amazon-linux.md).

!!! info "Versión de referencia"
    Debian 12 (*bookworm*). En la AMI oficial de EC2 el usuario por defecto es `admin`.

## 1. Identificar el sistema
| Comando | Descripción |
|---------|-------------|
| `cat /etc/os-release` | Ver distribución, versión y nombre en clave |
| `cat /etc/debian_version` | Ver la versión exacta (por ejemplo, 12.7) |
| `hostnamectl` | Ver nombre del equipo, sistema operativo y kernel |
| `uname -r` | Ver el kernel en uso |
| `dpkg -l 'linux-image*'` | Listar los kernels instalados |

## 2. Actualizar el sistema
| Comando | Descripción |
|---------|-------------|
| `sudo apt update` | Actualizar el índice de paquetes |
| `apt list --upgradable` | Ver qué paquetes tienen actualización |
| `sudo apt upgrade` | Actualizar paquetes sin quitar ninguno |
| `sudo apt full-upgrade` | Actualizar instalando o quitando paquetes si hace falta |
| `apt list --upgradable \| grep security` | Ver actualizaciones que vienen del repo de seguridad |
| `sudo needrestart` | Ver qué servicios o si el sistema necesitan reiniciarse |

## 3. Instalar, buscar y quitar paquetes
| Comando | Descripción |
|---------|-------------|
| `apt search <texto>` | Buscar un paquete |
| `apt show <paquete>` | Ver información de un paquete |
| `sudo apt install <paquete>` | Instalar un paquete |
| `sudo apt install ./<archivo>.deb` | Instalar un `.deb` local resolviendo dependencias |
| `sudo dpkg -i <archivo>.deb` | Instalar un `.deb` local sin resolver dependencias |
| `sudo apt install --reinstall <paquete>` | Reinstalar un paquete |
| `sudo apt remove <paquete>` | Desinstalar un paquete y conservar su configuración |
| `sudo apt purge <paquete>` | Desinstalar un paquete y borrar su configuración |
| `sudo apt autoremove` | Quitar dependencias que ya no se usan |
| `sudo apt clean` | Vaciar la caché de paquetes descargados |

## 4. Consultar paquetes instalados
| Comando | Descripción |
|---------|-------------|
| `dpkg -l` | Listar paquetes instalados |
| `apt list --installed` | Listar paquetes instalados (formato de `apt`) |
| `dpkg -s <paquete>` | Ver si un paquete está instalado y su versión |
| `dpkg -L <paquete>` | Ver los archivos que instaló un paquete |
| `dpkg -S <ruta>` | Ver qué paquete instaló un archivo |
| `apt-file search <archivo>` | Buscar qué paquete contiene un archivo, aunque no esté instalado (requiere `apt-file update`) |
| `apt-cache policy <paquete>` | Ver versión instalada, disponibles y de qué repo viene |
| `apt-cache depends <paquete>` | Ver las dependencias de un paquete |
| `cat /var/log/apt/history.log` | Ver el historial de instalaciones |

## 5. Bloquear versiones y repositorios
| Comando | Descripción |
|---------|-------------|
| `sudo apt-mark hold <paquete>` | Impedir que un paquete se actualice |
| `sudo apt-mark unhold <paquete>` | Quitar el bloqueo |
| `apt-mark showhold` | Ver paquetes bloqueados |
| `apt-cache policy` | Ver los repositorios configurados y su prioridad |
| `/etc/apt/sources.list` y `/etc/apt/sources.list.d/` | Archivos donde se configuran los repos |

## 6. Actualizaciones automáticas
| Comando | Descripción |
|---------|-------------|
| `sudo apt install unattended-upgrades` | Instalar la herramienta |
| `sudo dpkg-reconfigure -plow unattended-upgrades` | Activar las actualizaciones automáticas |
| `/etc/apt/apt.conf.d/50unattended-upgrades` | Archivo donde se elige qué se actualiza |
| `sudo unattended-upgrade --dry-run -d` | Simular sin instalar nada |
| `sudo unattended-upgrade -d` | Aplicar ahora las actualizaciones (por defecto, solo seguridad) |

## 7. Usuarios
| Comando | Descripción |
|---------|-------------|
| `sudo adduser <usuario>` | Crear un usuario de forma interactiva (home, contraseña y datos) |
| `sudo usermod -aG sudo <usuario>` | Dar permisos de sudo (grupo `sudo`) |
| `sudo deluser --remove-home <usuario>` | Eliminar un usuario y su home |

## 8. Seguridad del sistema
| Comando | Descripción |
|---------|-------------|
| `sudo aa-status` | Ver el estado de AppArmor y los perfiles cargados (requiere `apparmor-utils`) |
| `sudo apt install ufw` | Instalar el firewall `ufw` (no viene por defecto) |
| `sudo ufw allow <puerto>/tcp` | Abrir un puerto |
| `sudo ufw enable` | Activar el firewall |
| `sudo ufw status verbose` | Ver las reglas activas |
| `sudo nft list ruleset` | Ver las reglas a bajo nivel (nftables) |

!!! warning "Antes de `ufw enable` en un servidor remoto"
    Ejecuta `sudo ufw allow 22/tcp` primero o perderás la conexión SSH. En EC2 revisa también el **security group**, que es el primer filtro.

## 9. Logs
| Comando | Descripción |
|---------|-------------|
| `journalctl -p err -b` | Ver solo errores del arranque actual |
| `journalctl -u ssh` | Ver logs del servicio SSH (en Debian se llama `ssh`) |
| `cat /var/log/dpkg.log` | Ver el log de instalación de paquetes |

!!! note
    Debian 12 no instala `rsyslog` por defecto, así que no existe `/var/log/syslog`: todo se lee con `journalctl`.

## 10. En EC2
| Comando | Descripción |
|---------|-------------|
| `cloud-init status --long` | Ver si el *user data* terminó y si dio error |
| `cat /var/log/cloud-init-output.log` | Ver la salida del script de *user data* |
| `timedatectl status` | Ver hora y si está sincronizada |

La AMI de Debian no trae el agente de Systems Manager: hay que instalarlo. Para leer los metadatos de la instancia usa IMDSv2:

```bash
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
curl -sH "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

!!! example "Practica en el laboratorio"
    - [Lab 01: Diagnóstico de red desde Linux](../../laboratorios/fundamentos/linux-red-diagnostico.md)
