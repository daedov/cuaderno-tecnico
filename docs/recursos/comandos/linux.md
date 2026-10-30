# Linux

## 1. Navegación y sistema de archivos
| Comando | Descripción |
|---------|-------------|
| `pwd` | Mostrar directorio actual |
| `ls -lah` | Listar archivos con detalle, ocultos y tamaños legibles |
| `cd <ruta>` | Cambiar de directorio |
| `cd -` | Volver al directorio anterior |
| `tree -L <n>` | Ver estructura de directorios hasta n niveles |
| `find <ruta> -name "<patrón>"` | Buscar archivos por nombre |
| `find <ruta> -type f -mtime -7` | Buscar archivos modificados en los últimos 7 días |
| `find <ruta> -size +100M` | Buscar archivos mayores a 100 MB |
| `locate <archivo>` | Buscar archivos con base de datos indexada (requiere `updatedb`) |
| `stat <archivo>` | Ver metadatos (permisos, tamaño, fechas) |
| `readlink -f <archivo>` | Resolver la ruta absoluta real de un archivo/enlace |

## 2. Gestión de archivos y directorios
| Comando | Descripción |
|---------|-------------|
| `touch <archivo>` | Crear archivo vacío o actualizar fecha |
| `mkdir -p <ruta/anidada>` | Crear directorios anidados |
| `cp -r <origen> <destino>` | Copiar recursivamente |
| `mv <origen> <destino>` | Mover o renombrar |
| `rm -rf <ruta>` | Eliminar recursivamente sin confirmación (¡cuidado!) |
| `ln -s <destino> <enlace>` | Crear enlace simbólico |
| `rsync -avz <origen> <destino>` | Sincronizar archivos preservando permisos |
| `rsync -avz -e ssh <origen> <user>@<host>:<ruta>` | Sincronizar hacia un host remoto por SSH |
| `shred -u <archivo>` | Borrar de forma segura sobrescribiendo el contenido |
| `dd if=<origen> of=<destino> bs=4M status=progress` | Copia byte a byte (imágenes de disco/USB) |

## 3. Visualización y edición de texto
| Comando | Descripción |
|---------|-------------|
| `cat <archivo>` | Mostrar contenido completo |
| `less <archivo>` | Ver contenido paginado |
| `head -n <n> <archivo>` | Ver primeras n líneas |
| `tail -n <n> <archivo>` | Ver últimas n líneas |
| `tail -f <archivo>` | Seguir un archivo en tiempo real (logs) |
| `nano <archivo>` | Editor de texto simple |
| `vim <archivo>` | Editor de texto avanzado |
| `wc -l <archivo>` | Contar líneas de un archivo |
| `diff <archivo1> <archivo2>` | Comparar dos archivos |
| `sort <archivo> \| uniq -c` | Ordenar y contar líneas únicas |

## 4. Búsqueda y procesamiento de texto
| Comando | Descripción |
|---------|-------------|
| `grep "<patrón>" <archivo>` | Buscar texto en un archivo |
| `grep -r "<patrón>" <ruta>` | Buscar recursivamente en un directorio |
| `grep -i "<patrón>" <archivo>` | Buscar sin distinguir mayúsculas |
| `grep -v "<patrón>" <archivo>` | Excluir líneas que coinciden |
| `grep -E "<regex>" <archivo>` | Buscar con expresiones regulares extendidas |
| `awk '{print $1}' <archivo>` | Extraer la primera columna de cada línea |
| `awk -F: '{print $1}' /etc/passwd` | Procesar campos con delimitador personalizado |
| `sed 's/<viejo>/<nuevo>/g' <archivo>` | Reemplazar texto (salida en pantalla) |
| `sed -i 's/<viejo>/<nuevo>/g' <archivo>` | Reemplazar texto directamente en el archivo |
| `cut -d',' -f1,3 <archivo>` | Extraer columnas de un CSV |
| `tr 'a-z' 'A-Z' < <archivo>` | Convertir minúsculas a mayúsculas |

## 5. Permisos
| Comando | Descripción |
|---------|-------------|
| `chmod 755 <archivo>` | Asignar permisos en formato octal |
| `chmod +x <archivo>` | Hacer un archivo ejecutable |
| `chmod -R 644 <ruta>` | Cambiar permisos recursivamente |
| `chown <usuario>:<grupo> <archivo>` | Cambiar propietario y grupo |
| `chown -R <usuario> <ruta>` | Cambiar propietario recursivamente |
| `umask` | Ver/definir la máscara de permisos por defecto |
| `getfacl <archivo>` | Ver listas de control de acceso (ACL) |
| `setfacl -m u:<usuario>:rwx <archivo>` | Asignar ACL a un usuario específico |
| `chattr +i <archivo>` | Hacer un archivo inmutable (no editable ni borrable) |

## 6. Usuarios y grupos
| Comando | Descripción |
|---------|-------------|
| `whoami` | Ver usuario actual |
| `id <usuario>` | Ver UID, GID y grupos de un usuario |
| `useradd -m -s /bin/bash <usuario>` | Crear usuario con home y shell |
| `passwd <usuario>` | Cambiar contraseña de un usuario |
| `usermod -aG <grupo> <usuario>` | Agregar usuario a un grupo secundario |
| `userdel -r <usuario>` | Eliminar usuario y su home |
| `groupadd <grupo>` | Crear un grupo |
| `su - <usuario>` | Cambiar de usuario |
| `sudo <comando>` | Ejecutar un comando con privilegios de root |
| `sudo -i` | Abrir una shell interactiva como root |
| `last` | Ver historial de inicios de sesión |

## 7. Procesos y recursos
| Comando | Descripción |
|---------|-------------|
| `ps aux` | Listar todos los procesos en ejecución |
| `ps aux \| grep <proceso>` | Filtrar procesos por nombre |
| `top` | Monitor de procesos en tiempo real |
| `htop` | Monitor interactivo mejorado (requiere instalación) |
| `kill <PID>` | Terminar un proceso por su PID |
| `kill -9 <PID>` | Forzar la terminación de un proceso |
| `killall <nombre>` | Terminar procesos por nombre |
| `pkill -f "<patrón>"` | Terminar procesos que coincidan con un patrón |
| `nice -n <valor> <comando>` | Ejecutar un proceso con prioridad definida |
| `renice <valor> -p <PID>` | Cambiar la prioridad de un proceso en ejecución |
| `nohup <comando> &` | Ejecutar en segundo plano resistente al cierre de sesión |
| `jobs` / `fg` / `bg` | Gestionar trabajos en segundo/primer plano |

## 8. Monitoreo del sistema
| Comando | Descripción |
|---------|-------------|
| `uptime` | Tiempo encendido y carga promedio |
| `free -h` | Uso de memoria RAM y swap |
| `df -h` | Uso de disco por sistema de archivos |
| `du -sh <ruta>` | Tamaño total de un directorio |
| `du -h --max-depth=1 <ruta>` | Tamaño de subdirectorios de primer nivel |
| `vmstat 1` | Estadísticas de CPU, memoria e I/O cada segundo |
| `iostat -x 1` | Estadísticas detalladas de I/O de disco |
| `lscpu` | Información de la CPU |
| `lsblk` | Listar dispositivos de bloque y particiones |
| `dmesg -T \| tail` | Ver mensajes del kernel con marca de tiempo |
| `sensors` | Ver temperaturas del hardware (lm-sensors) |

## 9. Red y conectividad
| Comando | Descripción |
|---------|-------------|
| `ip a` | Ver interfaces y direcciones IP |
| `ip r` | Ver tabla de rutas |
| `ping <host>` | Comprobar conectividad |
| `traceroute <host>` | Ver la ruta de red hacia un host |
| `ss -tulpn` | Ver puertos abiertos y procesos asociados |
| `netstat -tulpn` | Alternativa clásica para ver puertos (net-tools) |
| `curl -I <url>` | Ver cabeceras HTTP de una URL |
| `curl -O <url>` | Descargar un archivo |
| `wget <url>` | Descargar archivos desde la línea de comandos |
| `dig <dominio>` | Consultar registros DNS |
| `nslookup <dominio>` | Resolver nombres de dominio |
| `nc -zv <host> <puerto>` | Comprobar si un puerto está abierto |
| `scp <archivo> <user>@<host>:<ruta>` | Copiar archivos por SSH |
| `ssh <user>@<host>` | Conectarse a un host remoto |
| `ssh -i <clave.pem> <user>@<host>` | Conectarse usando una clave privada |

## 10. Archivos comprimidos y empaquetado
| Comando | Descripción |
|---------|-------------|
| `tar -czvf <archivo>.tar.gz <ruta>` | Comprimir en formato tar.gz |
| `tar -xzvf <archivo>.tar.gz` | Descomprimir tar.gz |
| `tar -xzvf <archivo>.tar.gz -C <destino>` | Descomprimir en un directorio específico |
| `zip -r <archivo>.zip <ruta>` | Comprimir en formato zip |
| `unzip <archivo>.zip` | Descomprimir un zip |
| `gzip <archivo>` / `gunzip <archivo>.gz` | Comprimir/descomprimir un archivo individual |
| `xz -9 <archivo>` | Comprimir con alta compresión |

## 11. Gestión de paquetes
| Comando | Descripción |
|---------|-------------|
| `apt update && apt upgrade` | Actualizar índices y paquetes (Debian/Ubuntu) |
| `apt install <paquete>` | Instalar un paquete (Debian/Ubuntu) |
| `apt remove --purge <paquete>` | Eliminar paquete y su configuración |
| `dpkg -i <paquete>.deb` | Instalar un paquete .deb local |
| `dnf install <paquete>` | Instalar un paquete (Fedora/RHEL) |
| `yum install <paquete>` | Instalar un paquete (RHEL/CentOS antiguos) |
| `rpm -ivh <paquete>.rpm` | Instalar un paquete .rpm local |
| `snap install <paquete>` | Instalar un paquete Snap |
| `which <comando>` | Ver la ruta del ejecutable de un comando |
| `apt list --installed` | Listar paquetes instalados |

## 12. Servicios y systemd
| Comando | Descripción |
|---------|-------------|
| `systemctl status <servicio>` | Ver estado de un servicio |
| `systemctl start <servicio>` | Iniciar un servicio |
| `systemctl stop <servicio>` | Detener un servicio |
| `systemctl restart <servicio>` | Reiniciar un servicio |
| `systemctl enable <servicio>` | Habilitar servicio al arranque |
| `systemctl disable <servicio>` | Deshabilitar servicio en el arranque |
| `systemctl daemon-reload` | Recargar definiciones tras editar units |
| `systemctl list-units --type=service` | Listar servicios activos |
| `journalctl -u <servicio>` | Ver logs de un servicio |
| `journalctl -u <servicio> -f` | Seguir logs de un servicio en tiempo real |
| `journalctl --since "1 hour ago"` | Filtrar logs por tiempo |

## 13. Discos y almacenamiento
| Comando | Descripción |
|---------|-------------|
| `fdisk -l` | Listar discos y particiones |
| `mount <dispositivo> <punto>` | Montar un sistema de archivos |
| `umount <punto>` | Desmontar un sistema de archivos |
| `mkfs.ext4 <dispositivo>` | Formatear una partición en ext4 |
| `blkid` | Ver UUID y tipo de los sistemas de archivos |
| `lsof <archivo>` | Ver qué procesos usan un archivo |
| `lsof -i :<puerto>` | Ver qué proceso usa un puerto |
| `findmnt` | Ver el árbol de montajes |

## 14. Programación de tareas
| Comando | Descripción |
|---------|-------------|
| `crontab -e` | Editar tareas programadas del usuario |
| `crontab -l` | Listar tareas programadas |
| `at <hora>` | Programar un comando para una única ejecución futura |
| `systemctl list-timers` | Listar temporizadores de systemd |
| `watch -n <n> "<comando>"` | Ejecutar un comando repetidamente cada n segundos |
| `sleep <n>` | Pausar la ejecución n segundos |
| `timeout <n> <comando>` | Ejecutar un comando con límite de tiempo |

## 15. Redirección, tuberías y control de flujo
| Comando | Descripción |
|---------|-------------|
| `<comando> > <archivo>` | Redirigir salida sobrescribiendo el archivo |
| `<comando> >> <archivo>` | Redirigir salida agregando al archivo |
| `<comando> 2> <archivo>` | Redirigir errores (stderr) a un archivo |
| `<comando> &> <archivo>` | Redirigir salida y errores a un archivo |
| `<comando1> \| <comando2>` | Encadenar salida de un comando como entrada de otro |
| `<comando1> && <comando2>` | Ejecutar el segundo solo si el primero tiene éxito |
| `<comando1> \|\| <comando2>` | Ejecutar el segundo solo si el primero falla |
| `<comando> \| tee <archivo>` | Mostrar salida y guardarla en un archivo a la vez |
| `xargs <comando>` | Construir comandos a partir de la entrada estándar |
| `find . -name "*.log" \| xargs rm` | Combinar búsqueda con acción en lote |

## 16. Variables de entorno y shell
| Comando | Descripción |
|---------|-------------|
| `echo $PATH` | Mostrar el valor de una variable de entorno |
| `export VAR=<valor>` | Definir una variable de entorno |
| `env` | Listar variables de entorno |
| `printenv <VAR>` | Ver el valor de una variable específica |
| `alias ll='ls -lah'` | Crear un alias de comando |
| `history` | Ver historial de comandos |
| `!!` | Repetir el último comando |
| `source <archivo>` | Ejecutar un script en la shell actual |
| `chmod +x script.sh && ./script.sh` | Hacer ejecutable y correr un script |

## 17. Seguridad y auditoría
| Comando | Descripción |
|---------|-------------|
| `sudo -l` | Ver qué comandos puede ejecutar el usuario con sudo |
| `passwd -l <usuario>` | Bloquear la contraseña de un usuario |
| `ss -tulpn` | Auditar puertos y servicios expuestos |
| `who` / `w` | Ver usuarios conectados actualmente |
| `fail2ban-client status` | Ver estado de protección contra fuerza bruta |
| `ssh-keygen -t ed25519 -C "<comentario>"` | Generar par de claves SSH |
| `ssh-copy-id <user>@<host>` | Copiar clave pública a un host remoto |
| `gpg --gen-key` | Generar un par de claves GPG |
| `sha256sum <archivo>` | Verificar la integridad de un archivo |
| `openssl rand -base64 <n>` | Generar una cadena aleatoria segura |
| `chmod 600 <clave>` | Restringir permisos de una clave privada |

## 18. Contenedores y depuración
| Comando | Descripción |
|---------|-------------|
| `strace -p <PID>` | Rastrear llamadas al sistema de un proceso |
| `ltrace <comando>` | Rastrear llamadas a librerías |
| `tcpdump -i <interfaz> port <puerto>` | Capturar tráfico de red |
| `curl -w "@-" -o /dev/null -s <url>` | Medir tiempos de respuesta HTTP |
| `nsenter -t <PID> -n ip a` | Entrar al namespace de red de un proceso/contenedor |
| `cat /proc/<PID>/status` | Ver estado detallado de un proceso |
| `ulimit -a` | Ver límites de recursos del shell actual |

!!! example "Practica en el laboratorio"
    - [Lab 01: Diagnóstico de red desde Linux](../../laboratorios/fundamentos/linux-red-diagnostico.md)

