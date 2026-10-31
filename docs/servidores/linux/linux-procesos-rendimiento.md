---
tags:
  - servidores
  - linux
  - rendimiento
  - observabilidad
---

# Procesos y rendimiento en Linux Server

> Ver y controlar procesos, entender límites, memoria, CPU, carga e I/O, programar tareas con cron y systemd timers, y diagnosticar un servidor lento con un método (USE y "60 segundos").

!!! info "Antes de leer"
    Conviene haber leído [Linux Server: fundamentos de administración](linux-fundamentos-servidor.md) (systemd, unit files y journald). Para métricas y alertas a nivel de flota mira [Observabilidad](../../monitoreo/fundamentos/observabilidad.md); la metodología general de diagnóstico está en [Troubleshooting](../../devops/operacion/troubleshooting.md).

!!! note "Cómo se probaron los ejemplos"
    Salidas reales y abreviadas de un contenedor Ubuntu 24.04 con systemd (sysstat 12.6). Un contenedor comparte el kernel con la máquina (WSL2, 20 CPU, 7,6 GiB), así que `uptime`, `free` y `vmstat` muestran los valores de ese kernel. El OOM killer se provocó en un contenedor aparte limitado a 100 MB, para no afectar a nada más. `iotop` no funciona dentro del contenedor (`couldn't get netlink family id`) y se describe según su manual.

## ¿Qué es un proceso?

Un **proceso** es un programa en ejecución con su PID, su usuario, su memoria, sus archivos abiertos y su estado. Todo proceso tiene un padre (PPID); el primero es **systemd** (PID 1). Los **hilos** (*threads*) comparten la memoria de su proceso. Estados que verás en la columna `STAT`:

| Estado | Significado |
| --- | --- |
| `R` | *Running*: ejecutándose o listo para CPU |
| `S` | *Sleeping*: esperando algo (lo normal) |
| `D` | *Uninterruptible sleep*: esperando I/O; no responde ni a `kill -9` |
| `Z` | *Zombie*: terminó, pero su padre no ha recogido su código de salida |
| `T` | Detenido (`Ctrl+Z`, `SIGSTOP`) |

## Ver procesos

```bash
ps -eo pid,ppid,user,ni,stat,%cpu,%mem,rss,etime,cmd --sort=-%mem | head -6
pgrep -a miapp            # PIDs y comando que coinciden con "miapp"
pgrep -u miapp -l         # procesos del usuario miapp
pstree -p 1 | head        # árbol de procesos
```

```text
    PID    PPID USER      NI STAT %CPU %MEM   RSS     ELAPSED CMD
     30       1 root      -1 S<s   0.0  0.2 19468       06:40 /usr/lib/systemd/systemd-journald
      1       0 root       0 Ss    0.7  0.1 13468       06:40 /sbin/init
     95       1 systemd+   0 Ss    0.0  0.1 12432       06:39 /usr/lib/systemd/systemd-resolved
488 bash
```

`RSS` (*Resident Set Size*) es la memoria física que usa el proceso, en KiB. Toda la información sale de `/proc/<pid>/` (`status`, `limits`, `fd/`, `cmdline`), que puedes leer directamente.

### top y htop

```bash
top -b -n1 -o %MEM | head -12     # -b modo batch (para scripts), -o ordena
```

```text
top - 21:29:16 up  3:31,  0 user,  load average: 2.42, 2.22, 1.79
Tasks:  17 total,   1 running,  16 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.5 us,  1.4 sy,  0.0 ni, 97.1 id,  0.0 wa,  0.0 hi,  1.0 si,  0.0 st
MiB Mem :   7746.5 total,    894.3 free,   1408.2 used,   5762.6 buff/cache
MiB Swap:   2048.0 total,   1852.3 free,    195.7 used.   6338.2 avail Mem
```

La línea `%Cpu(s)` es la más útil: `us` (usuario), `sy` (kernel), `wa` (**iowait**: CPU esperando disco), `st` (**steal**: tiempo que el hipervisor dio a otra VM; alto en instancias *burstable* sin créditos). En `top` interactivo: `P` ordena por CPU, `M` por memoria, `1` muestra cada CPU, `k` mata un proceso. **htop** es una versión más visual (en RHEL/Rocky viene de EPEL).

### Señales y kill

`kill` envía una **señal**; no siempre "mata":

| Señal | Número | Efecto | Uso |
| --- | --- | --- | --- |
| `SIGTERM` | 15 | Pide terminar limpiamente (por defecto de `kill`) | Siempre primero |
| `SIGKILL` | 9 | El kernel lo mata sin aviso, no se puede capturar | Solo si `TERM` no funciona |
| `SIGHUP` | 1 | Muchos demonios recargan su configuración | `kill -HUP <pid>` |
| `SIGINT` | 2 | Lo que envía `Ctrl+C` | |
| `SIGSTOP` / `SIGCONT` | 19 / 18 | Pausar / reanudar | |

```bash
kill <pid>                # SIGTERM
kill -9 <pid>             # SIGKILL, último recurso
pkill -f "python app.py"  # por patrón del comando completo
systemctl kill miapp      # señal a todos los procesos de un servicio
```

Para servicios gestionados por systemd, usa `systemctl stop/restart`: si matas el proceso a mano, `Restart=` lo volverá a arrancar.

### Prioridad: nice y renice

El valor **nice** va de −20 (más prioridad) a 19 (menos). Solo root puede bajarlo de 0.

```bash
nice -n 10 tar -czf backup.tar.gz /srv/app   # arrancar con baja prioridad
renice -n 15 -p 2221                          # cambiar uno en marcha
ionice -c3 -p 2221                            # prioridad de I/O "idle"
```

```text
2221 (process ID) old priority 10, new priority 15
```

En un servicio: `Nice=10` e `IOSchedulingClass=idle` en la unit.

## Recursos y límites

### ulimit y LimitNOFILE

Cada proceso tiene **límites** (*resource limits*) por recurso, con un valor *soft* (el efectivo, que el proceso puede subir) y uno *hard* (el techo). El más famoso es el de **archivos abiertos** (`nofile`): cada conexión de red también es un archivo.

```bash
ulimit -n                                   # soft de tu shell
ulimit -Hn                                  # hard
grep -E "open files|processes" /proc/<pid>/limits   # los de un proceso en marcha
prlimit --pid <pid> --nofile                # igual, y permite cambiarlos en caliente
```

```text
Max processes             unlimited            unlimited            processes
Max open files            65536                65536                files
```

!!! warning "/etc/security/limits.conf no aplica a servicios systemd"
    `limits.conf` lo aplica PAM a las **sesiones de usuario** (login, SSH). Los servicios arrancados por systemd toman sus límites de la unit: `LimitNOFILE=65536` en un drop-in (`systemctl edit miapp`). Verifica con `systemctl show miapp -p LimitNOFILE` y en `/proc/<pid>/limits`.

### cgroups en una línea

Los **cgroups** (*control groups*) agrupan procesos y les ponen límites de CPU, memoria e I/O; systemd crea uno por servicio (y Docker uno por contenedor). Se usan con directivas en la unit (`MemoryMax=1G`, `CPUQuota=50%`, `TasksMax=`) y se observan con `systemd-cgtop` o `systemctl status` (línea `Memory:`).

## Memoria

```bash
free -h
```

```text
               total        used        free      shared  buff/cache   available
Mem:           7.6Gi       1.4Gi       895Mi        26Mi       5.6Gi       6.2Gi
Swap:          2.0Gi       195Mi       1.8Gi
```

La columna que importa es **`available`**, no `free`. Linux usa la RAM sobrante como **page cache** (`buff/cache`: archivos leídos recientemente) y la libera en cuanto un proceso la pide. "Poca memoria libre" con mucho `buff/cache` es un servidor sano. Las señales de problema son `available` bajo, swap creciendo y `si`/`so` distintos de 0 en `vmstat`.

### OOM killer

Cuando no queda memoria (en todo el sistema o en un cgroup con `MemoryMax`), el kernel elige un proceso y lo mata: es el **OOM killer** (*Out Of Memory killer*). El proceso desaparece sin log propio; la pista está en el log del kernel:

```bash
journalctl -k --since "1 hour ago" | grep -iE "out of memory|killed process"
dmesg -T | grep -i oom
```

Salida real con un contenedor limitado a 100 MB (`exit=137` = 128 + 9, muerto por `SIGKILL`):

```text
oom-kill:constraint=CONSTRAINT_MEMCG,...,task=python3,pid=442009,uid=0
Memory cgroup out of memory: Killed process 442009 (python3) total-vm:117548kB, anon-rss:101428kB, file-rss:6392kB, shmem-rss:0kB, UID:0 pgtables:256kB oom_score_adj:0
```

`CONSTRAINT_MEMCG` indica que se alcanzó el límite del cgroup (del servicio o contenedor), no la RAM total. Para un servicio systemd, `systemctl status` muestra además `Result: oom-kill`. Puedes proteger procesos críticos con `OOMScoreAdjust=-500` en su unit (más negativo = menos candidato).

## CPU y load average

```bash
uptime; nproc
```

```text
 21:29:15 up  3:31,  0 user,  load average: 2.42, 2.22, 1.79
20
```

El **load average** es el número medio de procesos **ejecutándose o esperando** (estado `R`) **más los bloqueados en I/O** (estado `D`), en los últimos 1, 5 y 15 minutos. Se interpreta **en relación con el número de CPU** (`nproc`):

- Carga 2,4 con 20 CPU: el servidor está holgado.
- Carga 8 con 4 CPU: hay el doble de trabajo del que cabe; los procesos esperan.
- Carga alta con CPU ociosa en `top`: probablemente muchos procesos en `D` esperando disco o red (NFS).

Compara los tres valores: 1 min > 15 min significa que la carga está subiendo.

```bash
mpstat -P ALL 1 1     # uso por CPU: ¿una sola CPU al 100 %? (proceso de un solo hilo)
pidstat 1 5           # qué procesos consumen CPU, segundo a segundo
```

## I/O de disco

```bash
vmstat 1 3
```

```text
procs -----------memory---------- ---swap-- -----io---- -system-- -------cpu-------
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st gu
 2  0 200384 917048 416524 5484648  154  592 36187  4321 4857    8  2  6 89  2  0  0
 0  0 200384 916824 416524 5484684    0    0     0     0 6790 30673  1  2 98  0  0  0
```

La **primera línea** es el promedio desde el arranque: ignórala y mira las siguientes. `r` = procesos esperando CPU (compáralo con `nproc`), `b` = bloqueados en I/O, `si`/`so` = swap in/out (deberían ser 0), `wa` = iowait.

```bash
iostat -xz 1 2        # -x extendido, -z oculta dispositivos sin actividad
```

```text
Device   r/s  rkB/s  r_await   w/s  wkB/s  w_await  aqu-sz  %util
sdc     0.00   0.00     0.00  2.00  48.00     1.50    0.01   2.00
```

| Columna | Qué indica |
| --- | --- |
| `r_await` / `w_await` | Latencia media por operación (ms); en SSD/NVMe, decenas de ms ya es lento |
| `aqu-sz` | Cola media de peticiones; > 1 sostenido indica saturación |
| `%util` | Tiempo con el disco ocupado; en SSD y discos de nube puede llegar al 100 % sin estar saturado de verdad |

**iotop** (`sudo iotop -o`) muestra qué proceso hace I/O en cada momento (necesita root y soporte del kernel; no funcionó en el contenedor). En la nube, revisa también los **IOPS y throughput aprovisionados** del disco: un volumen pequeño se queda sin rendimiento antes que sin espacio.

## Red: iftop y nload

`iftop -i eth0` muestra el ancho de banda por conexión y `nload` el total por interfaz, ambos en vivo. Para un histórico ligero: `sar -n DEV 1` (tráfico por interfaz) y `sar -n TCP,ETCP 1` (conexiones y retransmisiones). Más herramientas en [Redes en Linux Server](linux-redes-servidor.md).

## Tareas programadas

### cron

**cron** ejecuta comandos según un calendario. Cada usuario tiene su **crontab** (`crontab -e` para editar, `crontab -l` para ver); las tareas del sistema van en `/etc/cron.d/` (con un campo extra de usuario) o en `/etc/cron.daily/` y similares.

```text title="crontab -e (usuario ana)"
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=""
# ┌──────── minuto (0-59)
# │  ┌───── hora (0-23)
# │  │  ┌── día del mes (1-31)
# │  │  │   ┌─ mes (1-12)
# │  │  │   │   ┌─ día de la semana (0-7, 0 y 7 = domingo)
# m  h  dom mon dow  comando
*/5  *  *   *   *    /usr/local/bin/healthcheck.sh >> /var/log/healthcheck.log 2>&1
30   2  *   *   1-5  /usr/local/bin/backup.sh
0    0  1   *   *    /usr/local/bin/informe-mensual.sh
@reboot              /usr/local/bin/al-arrancar.sh
```

Se lee: cada 5 minutos; a las 02:30 de lunes a viernes; a medianoche del día 1 de cada mes; y una vez al arrancar. `crontab` valida la sintaxis al instalar:

```text
"/tmp/malo.cron":0: bad minute
errors in crontab file, can't install.
```

```text title="/etc/cron.d/limpieza"
# m h dom mon dow USUARIO comando
15 3 * * * root find /var/tmp -type f -mtime +7 -delete
```

!!! warning "Los tres fallos clásicos de cron"
    1. **PATH mínimo**: cron no carga tu `.bashrc`; usa rutas absolutas o define `PATH`.
    2. **Salida perdida**: redirige a un log (`>> archivo 2>&1`) o lo verás solo en el correo local, si existe.
    3. **`%` sin escapar**: en la línea de crontab `%` es un salto de línea; escribe `date +\%F`.

    Los logs de cron están en `journalctl -u cron` (Ubuntu) o `journalctl -u crond` y `/var/log/cron` (RHEL).

### systemd timers

Un **timer** de systemd activa un `.service` según un calendario. Frente a cron: logs en el journal, dependencias, límites de recursos, ejecución pendiente si el servidor estaba apagado (`Persistent=true`) y retraso aleatorio para que no arranque toda la flota a la vez.

```ini title="/etc/systemd/system/backup.service"
[Unit]
Description=Backup diario de /srv/app

[Service]
# oneshot: ejecuta y termina (no es un demonio)
Type=oneshot
ExecStart=/usr/bin/tar -czf /var/backups/app.tar.gz -C /srv app
# Baja prioridad de CPU e I/O para no molestar al servicio
Nice=10
IOSchedulingClass=idle
```

```ini title="/etc/systemd/system/backup.timer"
[Unit]
Description=Ejecuta backup.service cada dia a las 02:30

[Timer]
# Calendario: todos los días a las 02:30
OnCalendar=*-*-* 02:30:00
# Hasta 15 min de retraso aleatorio
RandomizedDelaySec=15min
# Si estaba apagado a esa hora, se ejecuta al arrancar
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemd-analyze verify /etc/systemd/system/backup.{service,timer}   # sin salida = OK
systemd-analyze calendar "Mon..Fri 08:00" "*:0/15" --iterations=2       # probar expresiones
sudo systemctl daemon-reload
sudo systemctl enable --now backup.timer      # se habilita el .timer, no el .service
systemctl list-timers
sudo systemctl start backup.service           # ejecutar ahora para probar
journalctl -u backup.service
```

```text
  Original form: *:0/15
Normalized form: *-*-* *:00/15:00
    Next elapse: Mon 2026-10-26 21:30:00 -05
NEXT                            LEFT LAST PASSED UNIT         ACTIVATES
Tue 2026-10-27 02:40:37 -05 5h 10min -         - backup.timer backup.service
```

| cron | `OnCalendar=` |
| --- | --- |
| `*/5 * * * *` | `*:0/5` |
| `30 2 * * *` | `*-*-* 02:30:00` |
| `30 2 * * 1-5` | `Mon..Fri 02:30` |
| `0 0 1 * *` | `monthly` o `*-*-01 00:00:00` |
| `@reboot` | `OnBootSec=1min` |

## Método: USE y "Linux performance analysis in 60 seconds"

Ante "el servidor va lento", no saltes al primer sospechoso. El **método USE** de Brendan Gregg revisa, para **cada recurso** (CPU, memoria, disco, red), tres cosas:

| | CPU | Memoria | Disco | Red |
| --- | --- | --- | --- | --- |
| **U**tilization (uso) | `mpstat`, `top` | `free` (`available`) | `iostat` `%util` | `sar -n DEV` |
| **S**aturation (saturación) | load > `nproc`, `vmstat r` | swap, `vmstat si/so`, OOM | `aqu-sz`, `vmstat b` | retransmisiones (`sar -n ETCP`) |
| **E**rrors (errores) | `dmesg` | OOM killer en `journalctl -k` | errores de I/O en `dmesg` | `ip -s link` (errors, dropped) |

La lista de **"Linux performance analysis in 60 seconds"** (Netflix/Brendan Gregg) es el primer minuto de cualquier investigación:

```bash
uptime                 # carga: ¿sube o baja?
dmesg -T | tail        # OOM, errores de disco o red
vmstat 1               # r, b, si/so, us/sy/wa
mpstat -P ALL 1        # ¿una CPU saturada?
pidstat 1              # qué proceso consume CPU
iostat -xz 1           # latencia y saturación de disco
free -m                # memoria disponible
sar -n DEV 1           # tráfico de red
sar -n TCP,ETCP 1      # conexiones y retransmisiones
top                    # vista general para confirmar
```

## Casos de uso

### Servidor lento

1. `uptime` y `nproc`: ¿la carga supera las CPU?
2. `vmstat 1`: si `r` es alto y `id` bajo → CPU; si `wa` y `b` son altos → disco; si `si/so` ≠ 0 → memoria.
3. CPU: `pidstat 1` o `top` para el proceso; mira `st` si es una VM *burstable*.
4. Disco: `iostat -xz 1` (latencia) e `iotop -o` (quién).
5. Memoria: `free -h` y `journalctl -k | grep -i oom`.
6. Si todo está tranquilo, el problema está fuera (base de datos, DNS, red): ver [Troubleshooting](../../devops/operacion/troubleshooting.md).

### Disco lleno

El procedimiento completo (`df -h` y `df -i`, `du`, archivos borrados que siguen abiertos con `lsof +L1`, limpieza y ampliación del volumen) está en [Almacenamiento: el disco /var está al 95 %](linux-almacenamiento.md#el-disco-var-esta-al-95).

### Too many open files

Síntoma: la aplicación registra `EMFILE` o `Too many open files`. Reproducido en el laboratorio con un límite de 20:

```text
OSError: [Errno 24] Too many open files: '/etc/hostname'
```

1. Cuenta los abiertos: `ls /proc/<pid>/fd | wc -l` y compáralo con `grep "open files" /proc/<pid>/limits`.
2. Si la cifra crece sin parar, es una **fuga** (conexiones o archivos que no se cierran): subir el límite solo lo retrasa.
3. Si es carga legítima, sube el límite del servicio con `LimitNOFILE=` en un drop-in, `daemon-reload` y reinicio. Revisa también el máximo del sistema: `cat /proc/sys/fs/file-max`.

### Proceso zombie

```bash
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/ || NR==1'
```

```text
    PID    PPID STAT CMD
   2270    2268 Z    [python3] <defunct>
```

Un zombie no consume CPU ni memoria: solo una entrada en la tabla de procesos. **No se puede matar** (ya está muerto); el responsable es el padre (`PPID`), que no llamó a `wait()`. Opciones: que el padre lo recoja (`kill -CHLD <ppid>` a veces ayuda), reiniciar el padre (sus zombies pasan a PID 1, que los recoge) o corregir el código. Unos pocos no son un problema; miles pueden agotar los PIDs.

## Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| "No hay memoria libre" con `free` | Confundir `free` con `available` | Mira `available`; el page cache se libera solo |
| El proceso desaparece sin log | OOM killer | Busca "oom" en `journalctl -k`; ajusta `MemoryMax`, la app o la RAM |
| `kill -9` no mata el proceso | Está en estado `D` esperando I/O (p. ej. NFS caído) | Resuelve el I/O; a veces solo un reinicio |
| Subí `nofile` en `limits.conf` y el servicio no cambia | Los servicios systemd no usan `limits.conf` | `LimitNOFILE=` en la unit |
| Load average alto con CPU ociosa | Procesos en `D` (disco o almacenamiento de red) | `vmstat` (`b`, `wa`) e `iostat -xz` |
| El cron funciona a mano pero no programado | PATH, variables o `%` sin escapar | Rutas absolutas, `PATH=` en el crontab y redirigir la salida a un log |
| El timer no se ejecuta | Se habilitó el `.service` y no el `.timer`, o falta `daemon-reload` | `systemctl enable --now x.timer`; `systemctl list-timers` |
| CPU alta en `st` | La VM se queda sin créditos o el host está saturado | Cambia el tipo de instancia o el modo de créditos |

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Tamaño de la VM, créditos de CPU, IOPS del disco, métricas nativas | [Máquinas virtuales](../../cloud/computo/maquinas-virtuales.md), [Observabilidad nativa](../../monitoreo/nube/observabilidad-nativa.md) |
| DevOps (la automatización) | Métricas, alertas y diagnóstico a escala; programar scripts | [Observabilidad](../../monitoreo/fundamentos/observabilidad.md), [Troubleshooting](../../devops/operacion/troubleshooting.md), [Sistema y procesos con Python](../../python/scripting/sistema-procesos.md), [Ansible para Linux](../ansible/ansible-linux.md) |
| DevSecOps (la verificación) | Procesos inesperados, límites de servicios y auditoría | [Hardening de Linux](../../devsecops/hardening/hardening-linux.md), [Detección y respuesta](../../devsecops/gobierno-y-respuesta/deteccion-respuesta.md) |
| Servidores | El resto de la administración Linux | [Fundamentos](linux-fundamentos-servidor.md), [Almacenamiento](linux-almacenamiento.md), [Redes](linux-redes-servidor.md) |

## Referencias

- [Brendan Gregg: The USE Method](https://www.brendangregg.com/usemethod.html)
- [Netflix Tech Blog: Linux Performance Analysis in 60,000 Milliseconds](https://netflixtechblog.com/linux-performance-analysis-in-60-000-milliseconds-accc10403c55)
- [proc(5)](https://man7.org/linux/man-pages/man5/proc.5.html), [ps(1)](https://man7.org/linux/man-pages/man1/ps.1.html), [signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html), [getrlimit(2)](https://man7.org/linux/man-pages/man2/getrlimit.2.html)
- [sysstat (iostat, mpstat, pidstat, sar)](https://sysstat.github.io/)
- [systemd.exec(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html), [systemd.resource-control(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html), [systemd.timer(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html), [systemd.time(7)](https://www.freedesktop.org/software/systemd/man/latest/systemd.time.html)
- [crontab(5)](https://man7.org/linux/man-pages/man5/crontab.5.html)
- [Kernel docs: Out Of Memory handling](https://www.kernel.org/doc/gorman/html/understand/understand016.html)
- [Red Hat: Monitoring and managing system status and performance (RHEL 9)](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/monitoring_and_managing_system_status_and_performance/index)
