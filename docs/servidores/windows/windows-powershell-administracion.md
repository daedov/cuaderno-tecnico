---
tags:
  - servidores
  - windows
  - powershell
  - observabilidad
---

# Administración de Windows Server con PowerShell

> Los comandos de PowerShell que usas a diario en un servidor Windows (usuarios y grupos locales, servicios, procesos, Event Logs, actualizaciones, tareas programadas, firewall, red, discos, registro, permisos NTFS, shares y rendimiento), cada uno con su explicación y salida de ejemplo, más la tabla de equivalencias Linux ↔ Windows.

!!! info "Antes de leer"
    Necesitas lo básico de PowerShell (cmdlets Verb-Noun, pipeline de objetos, `Get-Help`, remoting) que está en [Windows Server: fundamentos](windows-server-fundamentos.md). Si vienes de Linux, ten a mano [Linux: fundamentos de servidor](../linux/linux-fundamentos-servidor.md) y la [tabla de equivalencias](#equivalencias-entre-linux-y-windows) del final. Lo que es configuración de seguridad (auditoría, LAPS, Defender, firma SMB) está en [Hardening de Windows Server](../../devsecops/hardening/hardening-windows.md).

!!! warning "Sobre las salidas de ejemplo"
    Las **salidas reales** son de un **Windows 11 Home (build 26200, Windows PowerShell 5.1, sistema en español)**, sin elevación y **solo con comandos de lectura**; se abreviaron y anonimizaron (`EQUIPO`, `usuario`, IPs de ejemplo). Los comandos que **crean o cambian** algo (`New-LocalUser`, `Set-Service`, `New-NetFirewallRule`, `Register-ScheduledTask`, `New-SmbShare`…) **no se ejecutaron**: su sintaxis se comprobó con `Get-Command <cmdlet> -Syntax` y su salida se marca como **esperada**. En Windows Server los cmdlets son los mismos.

## ¿Qué es?

Administrar Windows Server en serio es administrarlo con **PowerShell**: los mismos comandos sirven en local, en remoto (`Invoke-Command`), en Server Core, en scripts y desde [Ansible](../ansible/ansible-windows.md). Casi todo sigue el mismo patrón: un `Get-` para ver el estado, un `Set-`/`New-`/`Remove-` para cambiarlo, y el pipeline para filtrar.

Tres hábitos que te ahorran disgustos:

- **Lee antes de cambiar**: ejecuta el `Get-` equivalente y guarda el estado previo (`Export-Clixml`, `Export-Csv`).
- **Usa `-WhatIf`** en los cmdlets que lo admiten para ver qué harían sin hacerlo.
- **Consola elevada** (*Run as administrator*) para casi todo lo que cambia el sistema y para leer el log Security.

## Usuarios y grupos locales

El módulo `Microsoft.PowerShell.LocalAccounts` gestiona cuentas **locales** (en un servidor unido a dominio, las cuentas de usuarios están en Active Directory: ver [Roles y servicios](windows-roles-servicios.md#active-directory-domain-services)).

```powershell
Get-LocalUser | Format-Table Name, Enabled, PasswordLastSet, LastLogon
```

```text title="Salida real (Windows 11, abreviada)"
Name               Enabled PasswordLastSet     LastLogon
----               ------- ---------------     ---------
Administrador        False                     09-11-2023 0:12:47
usuario               True 28-03-2024 7:32:22
DefaultAccount       False
Invitado             False
WDAGUtilityAccount   False 30-05-2023 5:44:50
```

Los nombres de las cuentas y grupos integrados **se traducen** según el idioma del sistema (`Administrador`, `Administradores`, `Invitado`). En scripts usa el **SID conocido**, que no cambia: `S-1-5-32-544` es el grupo Administrators en cualquier idioma.

```powershell
Get-LocalGroupMember -SID S-1-5-32-544
```

```text title="Salida real (Windows 11)"
ObjectClass Name                  PrincipalSource
----------- ----                  ---------------
Usuario     EQUIPO\Administrador            Local
Usuario     EQUIPO\usuario       MicrosoftAccount
```

Crear una cuenta de servicio local y darle un grupo (no ejecutado):

```powershell
$pw = Read-Host -AsSecureString 'Contraseña'          # nunca la escribas en claro en el script
New-LocalUser -Name 'svc-backup' -Password $pw -FullName 'Cuenta de backup' `
              -Description 'Ejecuta la tarea de backup nocturna' -PasswordNeverExpires
Add-LocalGroupMember -Group 'Backup Operators' -Member 'svc-backup'
Disable-LocalUser -Name 'svc-backup'                  # baja: primero deshabilita, borra después
```

`New-LocalUser` exige `-Password <SecureString>` o `-NoPassword`. Para servicios en dominio, mejor **gMSA** que cuentas con contraseña (ver [Hardening de Windows Server](../../devsecops/hardening/hardening-windows.md#cuentas-y-administradores-locales)).

## Servicios

```powershell
Get-Service -Name WinRM, Spooler, W32Time, EventLog, Schedule |
  Format-Table Status, Name, DisplayName, StartType
```

```text title="Salida real (Windows 11)"
 Status Name     DisplayName                                      StartType
 ------ ----     -----------                                      ---------
Running EventLog Registro de eventos de Windows                   Automatic
Running Schedule Programador de tareas                            Automatic
Running Spooler  Cola de impresión                                Automatic
Running W32Time  Hora de Windows                                     Manual
Running WinRM    Administración remota de Windows (WS-Management) Automatic
```

- **Name** (`W32Time`) es el identificador estable; **DisplayName** se traduce. En scripts, usa siempre `Name`.
- `StartType`: `Automatic`, `AutomaticDelayedStart` (PowerShell 7), `Manual`, `Disabled`. *Manual* no significa "apagado": Windows puede iniciarlo bajo demanda (por eso W32Time está en ejecución).

`Get-Service` no muestra la **cuenta** con la que corre el servicio ni la ruta del binario; para eso, CIM:

```powershell
Get-CimInstance Win32_Service -Filter "Name='W32Time'" | Select-Object Name, StartMode, State, StartName, PathName
```

```text title="Salida real (Windows 11)"
Name      : W32Time
StartMode : Manual
State     : Running
StartName : NT AUTHORITY\LocalService
PathName  : C:\WINDOWS\system32\svchost.exe -k LocalService
```

Cambiar estado y arranque (no ejecutado):

```powershell
Set-Service -Name Spooler -StartupType Disabled
Stop-Service -Name Spooler -PassThru
Restart-Service -Name W3SVC -Force      # -Force reinicia también los servicios dependientes
```

### sc.exe para casos especiales

`sc.exe` (siempre con `.exe`: en PowerShell `sc` es alias de `Set-Content`) sigue siendo necesario para lo que los cmdlets de 5.1 no exponen, sobre todo las **recovery actions** (qué hace Windows si el servicio se cae):

```powershell
sc.exe qc W32Time            # configuración
sc.exe qfailure Spooler      # acciones de recuperación
# sc.exe failure MiServicio reset= 86400 actions= restart/5000/restart/5000/""/0   (cambia; no ejecutado)
```

```text title="Salida real de sc.exe qfailure Spooler (Windows 11)"
NOMBRE_SERVICIO: Spooler
        PERÍODO_REINICIO (en segundos): 3600
        ACCIONES_ERROR                 : REINICIAR - Retraso= 5000 ms
                                         REINICIAR - Retraso= 5000 ms
```

Fíjate en la sintaxis de `sc.exe`: `opción= valor`, con el espacio **después** del `=`.

## Procesos

```powershell
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, Id, CPU,
  @{ Name = 'WS(MB)'; Expression = { [math]::Round($_.WorkingSet64 / 1MB) } }
```

```text title="Salida real (Windows 11, abreviada)"
Name                  Id        CPU WS(MB)
----                  --        --- ------
com.docker.backend 30484 2486,59375    180
msedgewebview2     29852 2205,65625      2
python             12364 1701,84375     30
chrome             14292  1497,3125    213
```

- `CPU` son **segundos de CPU acumulados** desde que arrancó el proceso, no un porcentaje (para porcentaje, `Get-Counter`).
- `WorkingSet64` es la memoria física en uso; la propiedad calculada `@{Name=...; Expression=...}` convierte bytes a MB.
- `Get-Process -IncludeUserName` muestra el usuario dueño (requiere elevación).

```powershell
Stop-Process -Name notepad -WhatIf      # qué mataría
Stop-Process -Id 12345 -Force           # equivalente a kill -9 (no ejecutado)
```

## Event Logs con Get-WinEvent

`Get-WinEvent` es el `journalctl` de Windows. Sustituye al antiguo `Get-EventLog` (que no existe en PowerShell 7). Lo primero, ver qué logs hay y su tamaño:

```powershell
Get-WinEvent -ListLog System, Application, Security, 'Microsoft-Windows-PowerShell/Operational' -ErrorAction SilentlyContinue |
  Format-Table LogName, RecordCount, MaximumSizeInBytes, LogMode
```

```text title="Salida real (Windows 11, sin elevación)"
LogName                                  RecordCount MaximumSizeInBytes  LogMode
-------                                  ----------- ------------------  -------
System                                         37956           20971520 Circular
Application                                    42960           20971520 Circular
Microsoft-Windows-PowerShell/Operational         478           15728640 Circular
```

Security **no aparece**: sin elevación (o sin pertenecer al grupo *Event Log Readers*) no se puede leer. `Circular` significa que, al llenarse, los eventos antiguos se sobrescriben.

### Filtrar con -FilterHashtable

Filtra **en origen** con `-FilterHashtable`, no con `Where-Object` después: en un log de millones de eventos la diferencia es de segundos frente a minutos.

```powershell
# Paradas inesperadas (6008) y apagados/reinicios iniciados por alguien (1074)
Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 1074, 6008 } -MaxEvents 3 |
  Format-Table TimeCreated, Id, ProviderName
```

```text title="Salida real (Windows 11)"
TimeCreated           Id ProviderName
-----------           -- ------------
26-10-2026 10:27:51 6008 EventLog
22-10-2026 22:08:15 1074 User32
15-10-2026 21:35:58 1074 User32
```

```text title="Salida real: mensaje del evento 1074 (anonimizado)"
El proceso C:\WINDOWS\SystemApps\...\StartMenuExperienceHost.exe (EQUIPO) inició el Apagar del equipo EQUIPO
en nombre del usuario EQUIPO\usuario por el siguiente motivo: Otros (no planeado)
 Código de motivo: 0x0
 Tipo de apagado: Apagar
```

```powershell
# Errores (Level 2) del log System en los últimos 7 días
Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 2; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 3
```

```text title="Salida real (Windows 11)"
TimeCreated            Id ProviderName
-----------            -- ------------
26-10-2026 13:00:00  7000 Service Control Manager
26-10-2026 13:00:00  7009 Service Control Manager
26-10-2026 10:49:20 36881 Schannel
```

Claves útiles de la hashtable: `LogName`, `ProviderName`, `Id`, `Level` (1 crítico, 2 error, 3 advertencia, 4 información), `StartTime`, `EndTime` y `Data`. En remoto: `-ComputerName` o dentro de `Invoke-Command`.

### IDs que conviene saber de memoria

| ID | Log | Qué significa | Para qué lo miras |
| --- | --- | --- | --- |
| **4624** | Security | Inicio de sesión correcto (con *Logon Type*: 2 interactivo, 3 red, 10 RDP) | Quién entró y cómo |
| **4625** | Security | Inicio de sesión fallido | Contraseñas mal escritas, fuerza bruta |
| **4672** | Security | Inicio de sesión con privilegios especiales (admin) | Uso de cuentas privilegiadas |
| **7036** | System | Un servicio cambió de estado (iniciado/detenido) | Cronología de un servicio |
| 7000 / 7009 / 7031 | System | Servicio no arrancó / timeout / terminó inesperadamente | Servicio que no levanta |
| **6008** | System | El apagado anterior fue **inesperado** | Cortes de luz, BSOD, VM apagada a la fuerza |
| **1074** | System | Apagado o reinicio iniciado por un proceso o usuario, con motivo | "¿Quién reinició el servidor?" |
| 41 | System (Kernel-Power) | El sistema se reinició sin apagarse limpiamente | Junto con 6008 |

```powershell
# Inicios de sesión fallidos de la última hora (consola elevada)
Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4625; StartTime = (Get-Date).AddHours(-1) }
```

En el equipo de prueba, sin elevación, la consulta a Security devolvió *No se encontraron eventos que coincidan con los criterios de selección especificados*: el mensaje engaña, el motivo real es la falta de permisos. Más sobre cómo leer logs en [Cómo leer logs](../../monitoreo/logging/leer-logs.md); qué auditar y cómo llevarlo a un SIEM en [Hardening de Windows Server](../../devsecops/hardening/hardening-windows.md#logging-de-powershell-y-auditoria-avanzada).

## Actualizaciones

```powershell
Get-HotFix | Select-Object -First 3 HotFixID, Description, InstalledOn
```

```text title="Salida real (Windows 11)"
HotFixID  Description     InstalledOn
--------  -----------     -----------
KB5127648 Security Update 16-10-2026 0:00:00
KB5127690 Update          16-10-2026 0:00:00
KB5127647 Security Update 14-10-2026 0:00:00
```

`Get-HotFix` lee `Win32_QuickFixEngineering`: muestra las actualizaciones del sistema operativo, no las de otros productos (Office, SQL Server). Ojo: en el equipo de prueba (configuración regional en español) `Sort-Object InstalledOn` lanzó *No se puede reconocer la cadena como valor DateTime válido* para algunas entradas sin fecha. Filtra antes las vacías o ignora el error.

Para **instalar** actualizaciones desde la línea de comandos:

- **Windows Server 2019+**: `sconfig` (opción 6) o la herramienta de la organización (WSUS, Azure Update Manager, Configuration Manager). `UsoClient.exe StartScan` existe pero **no está documentado** por Microsoft: no construyas procesos sobre él.
- **Módulo PSWindowsUpdate** (comunidad, PowerShell Gallery): `Install-WindowsUpdate -AcceptAll -AutoReboot`; muy usado, pero no es de Microsoft.
- **A escala**: [Ansible](../ansible/ansible-recetas-servidores.md#windows-updates-por-lotes-con-reinicio) con `ansible.windows.win_updates`, o los servicios de parches de cada nube (ver [Windows Server: fundamentos](windows-server-fundamentos.md#windows-server-en-la-nube)).

## Tareas programadas

El **Task Scheduler** (Programador de tareas) es el cron de Windows. Leer:

```powershell
Get-ScheduledTask -TaskPath '\Microsoft\Windows\WindowsUpdate\' | Format-Table TaskName, State
Get-ScheduledTask -TaskName 'Adobe Acrobat Update Task' | Get-ScheduledTaskInfo
```

```text title="Salida real (Windows 11)"
TaskName        State
--------        -----
Scheduled Start Ready

TaskName       : Adobe Acrobat Update Task
LastRunTime    : 26-10-2026 15:26:05
LastTaskResult : 0
NextRunTime    : 26-10-2026 22:00:00
```

`LastTaskResult` es el código de salida: `0` es éxito; `267009` (0x41301) significa "en ejecución" y `267011` (0x41303) "nunca se ha ejecutado".

Crear una tarea se hace en piezas: **action** (qué ejecuta), **trigger** (cuándo), **principal** (con qué identidad) y **settings**. No ejecutado:

```powershell title="registrar-backup.ps1"
$action    = New-ScheduledTaskAction -Execute 'pwsh.exe' `
               -Argument '-NoProfile -NonInteractive -File C:\Scripts\backup.ps1'
$trigger   = New-ScheduledTaskTrigger -Daily -At 2am
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask -TaskName 'Backup nocturno' -TaskPath '\Operaciones\' `
  -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
  -Description 'Copia de C:\Datos a \\nas01\backups'
```

- `-StartWhenAvailable` ejecuta la tarea en cuanto pueda si el servidor estaba apagado a la hora prevista (como `anacron`).
- `-ExecutionTimeLimit` evita tareas colgadas para siempre.
- Usa una carpeta propia (`\Operaciones\`) para distinguir tus tareas de las de Windows. Para ejecutar como cuenta de dominio sin contraseña guardada, usa una gMSA como principal.

## Firewall

```powershell
Get-NetFirewallRule -Name 'WINRM-HTTP-In-TCP*' | Format-Table Name, Enabled, Profile, Direction, Action
Get-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' | Get-NetFirewallPortFilter | Format-List Protocol, LocalPort
(Get-NetFirewallRule -Enabled True -Direction Inbound).Count
```

```text title="Salida real (Windows 11)"
Name                      Enabled         Profile Direction Action
----                      -------         ------- --------- ------
WINRM-HTTP-In-TCP           False          Public   Inbound  Allow
WINRM-HTTP-In-TCP-NoScope   False Domain, Private   Inbound  Allow

Protocol  : TCP
LocalPort : 5985

266
```

Una regla no guarda el puerto ni las IPs en el objeto principal: están en **filtros** asociados (`Get-NetFirewallPortFilter`, `Get-NetFirewallAddressFilter`, `Get-NetFirewallApplicationFilter`). Por eso filtrar reglas por puerto requiere el pipeline de arriba.

Abrir un puerto solo para la red de administración (no ejecutado):

```powershell
New-NetFirewallRule -Name 'App-API-In-8443' -DisplayName 'API interna (8443)' `
  -Direction Inbound -Protocol TCP -LocalPort 8443 -Action Allow `
  -Profile Domain -RemoteAddress 10.0.20.0/24
```

Siempre `-RemoteAddress` (el *scope*): una regla sin él abre el puerto a cualquier origen. Los perfiles por defecto y el logging se tratan en [Hardening de Windows Server](../../devsecops/hardening/hardening-windows.md#firewall-de-windows); en la nube, además, está el security group o NSG (ver [Seguridad de red](../../networking/avanzado/seguridad-red.md)).

## Red

```powershell
Get-NetIPConfiguration | Where-Object IPv4DefaultGateway   # interfaz con salida: IP, gateway y DNS
Get-NetIPAddress -AddressFamily IPv4 | Format-Table InterfaceAlias, IPAddress, PrefixLength, PrefixOrigin
Get-NetRoute -DestinationPrefix 0.0.0.0/0
```

```text title="Salida real (Windows 11; propiedades principales, IPs de ejemplo)"
InterfaceAlias     : Wi-Fi
InterfaceIndex     : 18
IPv4Address        : 192.168.1.50
IPv4DefaultGateway : 192.168.1.1
DNSServer          : 192.168.1.1

InterfaceAlias                     IPAddress      PrefixLength PrefixOrigin
--------------                     ---------      ------------ ------------
vEthernet (WSL (Hyper-V firewall)) 172.19.192.1             20       Manual
Wi-Fi                              192.168.1.50             24         Dhcp
Conexión de área local* 1          169.254.78.11            16    WellKnown
Loopback Pseudo-Interface 1        127.0.0.1                 8    WellKnown
```

`PrefixOrigin` dice de dónde salió la IP: `Dhcp`, `Manual` o `WellKnown` (169.254.x.x es **APIPA/link-local**: la interfaz pidió DHCP y nadie respondió; ver [Direccionamiento IP](../../networking/basico/direccionamiento-ip.md)).

Diagnóstico (los dos sustitutos modernos de `telnet` y `nslookup`):

```powershell
Test-NetConnection -ComputerName learn.microsoft.com -Port 443
Resolve-DnsName learn.microsoft.com -Type A
```

```text title="Salida real (Windows 11, abreviada)"
ComputerName     : learn.microsoft.com
RemoteAddress    : 23.217.125.203
RemotePort       : 443
InterfaceAlias   : Wi-Fi
TcpTestSucceeded : True

Name                             Type TTL Section NameHost                        IPAddress
----                             ---- --- ------- --------                        ---------
learn.microsoft.com             CNAME  48  Answer learn-public.trafficmanager.net
learn-public.trafficmanager.net CNAME  48  Answer learn.microsoft.com.edgekey.net
learn.microsoft.com.edgekey.net CNAME  48  Answer e13636.dscb.akamaiedge.net
e13636.dscb.akamaiedge.net          A  19  Answer                                 23.217.125.203
```

`TcpTestSucceeded : False` con el ping funcionando suele ser un firewall o un servicio que no escucha; compruébalo en el servidor con `Get-NetTCPConnection -State Listen -LocalPort 443` (el `ss -tlnp` de Windows). La metodología completa está en [Troubleshooting de red](../../networking/avanzado/troubleshooting-red.md).

Para fijar IP estática y DNS (`New-NetIPAddress`, `Set-DnsClientServerAddress`) usa el script de [configuración inicial](windows-server-fundamentos.md#lo-mismo-con-powershell-repetible-y-automatizable); en la nube, mejor no. Tras cambiar registros DNS, vacía la caché del cliente:

```powershell
Clear-DnsClientCache      # el ipconfig /flushdns de PowerShell
```

## Discos y almacenamiento

```powershell
Get-Disk | Format-Table Number, FriendlyName, PartitionStyle, OperationalStatus,
  @{ n = 'Size(GB)'; e = { [math]::Round($_.Size / 1GB) } }
Get-Volume | Where-Object DriveLetter | Format-Table DriveLetter, FileSystemLabel, FileSystem, HealthStatus,
  @{ n = 'Free(GB)'; e = { [math]::Round($_.SizeRemaining / 1GB, 1) } }, @{ n = 'Size(GB)'; e = { [math]::Round($_.Size / 1GB, 1) } }
```

```text title="Salida real (Windows 11)"
Number FriendlyName                       PartitionStyle OperationalStatus Size(GB)
------ ------------                       -------------- ----------------- --------
     1 Msft Virtual Disk                  GPT            Online                 100
     0 NVMe WD PC SN560 SDDPNQE-1T00-1102 GPT            Online                 954

DriveLetter FileSystemLabel FileSystem HealthStatus Free(GB) Size(GB)
----------- --------------- ---------- ------------ -------- --------
          C OS              NTFS       Healthy         306,2    952,3
          D datos           ReFS       Healthy          98,1     99,9
```

La jerarquía es **Disk → Partition → Volume**: `Get-Disk`, `Get-Partition -DiskNumber 0`, `Get-Volume`. NTFS es el sistema de archivos general; **ReFS** se usa para datos (Hyper-V, backups, Storage Spaces), no para arrancar.

Añadir un disco nuevo, de principio a fin (por ejemplo, un volumen recién conectado a la VM; no ejecutado):

```powershell
Get-Disk | Where-Object PartitionStyle -eq 'RAW' |            # el disco nuevo aparece como RAW
  Initialize-Disk -PartitionStyle GPT -PassThru |
  New-Partition -AssignDriveLetter -UseMaximumSize |
  Format-Volume -FileSystem NTFS -NewFileSystemLabel 'Datos' -Confirm:$false
```

Ampliar un volumen después de agrandar el disco en la plataforma (EBS, Managed Disk, Persistent Disk):

```powershell
Update-HostStorageCache                                          # que Windows vea el nuevo tamaño
$max = (Get-PartitionSupportedSize -DriveLetter E).SizeMax
Resize-Partition -DriveLetter E -Size $max
```

`Get-PartitionSupportedSize` requiere elevación (en el equipo de prueba devolvió *El cliente no tenía acceso disponible a un recurso CIM*). Es el equivalente de `growpart` + `resize2fs` en Linux (ver [Linux: almacenamiento](../linux/linux-almacenamiento.md)).

## Registro

El **registry** (registro) es la base de datos jerárquica de configuración: lo más parecido a `/etc`. Se navega como un sistema de archivos con los *drives* `HKLM:` y `HKCU:`:

```powershell
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time' -Name Start, ObjectName
```

```text title="Salida real (Windows 11)"
Start      : 3
ObjectName : NT AUTHORITY\LocalService
```

`Start` es el tipo de inicio del servicio en bruto: `2` automático, `3` manual, `4` deshabilitado. Escribir (no ejecutado):

```powershell
New-Item -Path 'HKLM:\SOFTWARE\MiEmpresa\App' -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SOFTWARE\MiEmpresa\App' -Name 'Entorno' -Value 'produccion'
```

Antes de tocar el registro, exporta la clave (`reg export HKLM\SOFTWARE\MiEmpresa C:\backup\app.reg`). Si una GPO gestiona ese valor, tu cambio local se sobrescribirá en el siguiente `gpupdate`.

## Permisos NTFS

Cada archivo y carpeta tiene una **ACL** (*Access Control List*) con **ACEs** (entradas): quién, qué derecho, permitir/denegar y si es heredado.

```powershell
(Get-Acl C:\Windows\System32\drivers\etc\hosts).Owner
icacls C:\Windows\System32\drivers\etc\hosts
```

```text title="Salida real (Windows 11)"
NT AUTHORITY\SYSTEM

C:\Windows\System32\drivers\etc\hosts NT AUTHORITY\SYSTEM:(I)(F)
                                      BUILTIN\Administradores:(I)(F)
                                      BUILTIN\Usuarios:(I)(RX)
                                      ENTIDAD DE PAQUETES DE APLICACIONES\TODOS LOS PAQUETES DE APLICACIONES:(I)(RX)
Se procesaron correctamente 1 archivos; error al procesar 0 archivos
```

Cómo leer `icacls`: `(I)` heredado, `(F)` control total, `(M)` modificar, `(RX)` leer y ejecutar, `(R)` lectura, `(W)` escritura; `(OI)(CI)` en carpetas significa que se hereda a archivos y subcarpetas.

`Get-Acl` devuelve objetos (mejor para scripts); `icacls` es más cómodo para **cambiar** permisos:

```powershell
# Dar Modificar al grupo de la app en la carpeta y todo lo que contenga (no ejecutado)
icacls D:\Datos\App /grant 'CORP\GG-App-Escritura:(OI)(CI)M'
# Guardar y restaurar ACLs de un árbol entero antes de un cambio grande
icacls D:\Datos /save C:\backup\acl-datos.txt /t
```

`Get-Acl C:\Windows\Temp` falló en el equipo de prueba con *Intento de realizar una operación no válida* (`UnauthorizedAccessException`): leer una ACL también requiere permiso de lectura de permisos sobre el objeto.

## Archivos compartidos (SMB)

```powershell
Get-SmbShare
```

```text title="Salida real (Windows 11)"
Name   Path       Description
----   ----       -----------
ADMIN$ C:\WINDOWS Admin remota
C$     C:\        Recurso predeterminado
IPC$              IPC remota
```

Los shares terminados en `$` son **administrativos** (ocultos al explorar la red, solo para administradores). Crear uno (no ejecutado):

```powershell
New-Item -Path D:\Shares\Finanzas -ItemType Directory
New-SmbShare -Name 'Finanzas' -Path 'D:\Shares\Finanzas' `
  -ChangeAccess 'CORP\GG-Finanzas' -ReadAccess 'CORP\GG-Auditoria' -FolderEnumerationMode AccessBased
```

El acceso efectivo es la **intersección** de los permisos del share y los de NTFS: gana el más restrictivo. Práctica habitual: share con permisos amplios para grupos autenticados y el control fino en NTFS. `-FolderEnumerationMode AccessBased` oculta las carpetas a las que el usuario no tiene acceso. Más en [Roles y servicios: File Server](windows-roles-servicios.md#file-server).

## Rendimiento con Get-Counter

`Get-Counter` lee los **performance counters** (contadores de rendimiento), los mismos que usa Performance Monitor (`perfmon`):

```powershell
Get-Counter '\Procesador(_Total)\% de tiempo de procesador', '\Memoria\MBytes disponibles' -SampleInterval 1 -MaxSamples 2
```

```text title="Salida real (Windows 11 en español)"
Path                                                  Valor
----                                                  -----
\\equipo\procesador(_total)\% de tiempo de procesador  42,9
\\equipo\memoria\mbytes disponibles                    1370
\\equipo\procesador(_total)\% de tiempo de procesador  47,4
\\equipo\memoria\mbytes disponibles                    1346
```

!!! warning "Los nombres de contadores están traducidos"
    En un Windows en español, `Get-Counter '\Processor(_Total)\% Processor Time'` falla con *El objeto especificado no se encontró en el equipo*. Usa los nombres del idioma del sistema (`Get-Counter -ListSet *` para listarlos) o, en scripts portables, consulta las clases CIM equivalentes (`Win32_PerfFormattedData_PerfOS_Processor`). Los servidores suelen instalarse en inglés justamente por esto.

Contadores para un primer vistazo (nombres en inglés):

| Contador | Qué indica | Señal de alarma orientativa |
| --- | --- | --- |
| `\Processor(_Total)\% Processor Time` | Uso de CPU | Sostenido > 80–90 % |
| `\System\Processor Queue Length` | Hilos esperando CPU | Sostenido > 2 por núcleo |
| `\Memory\Available MBytes` | RAM libre | Pocos cientos de MB |
| `\Memory\Pages/sec` | Paginación a disco | Picos altos sostenidos |
| `\LogicalDisk(*)\% Free Space` | Espacio libre | < 10–15 % |
| `\PhysicalDisk(*)\Avg. Disk sec/Read` y `/Write` | Latencia de disco | > 20–25 ms sostenidos |
| `\Network Interface(*)\Bytes Total/sec` | Tráfico de red | Cerca del ancho de banda de la NIC |

Es la versión Windows de la metodología USE de [Linux: procesos y rendimiento](../linux/linux-procesos-rendimiento.md). Para histórico y alertas, envía estos contadores a tu plataforma de monitoreo ([Observabilidad](../../monitoreo/fundamentos/observabilidad.md)).

## Equivalencias entre Linux y Windows

| Tarea | Linux | Windows (PowerShell) |
| --- | --- | --- |
| Ver y gestionar servicios | `systemctl status/start/enable` | `Get-Service`, `Start-Service`, `Set-Service -StartupType` |
| Leer logs del sistema | `journalctl -u nginx --since today` | `Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=...}` |
| Tareas programadas | `cron`, systemd timers | Task Scheduler: `Register-ScheduledTask` |
| Configuración del sistema | Archivos en `/etc` | Registro (`HKLM:`) + GPO |
| Instalar software | `apt`, `dnf` | `winget`, `Install-WindowsFeature` (roles), MSI |
| Configuración de red | `ip addr`, `ip route` | `Get-NetIPConfiguration`, `Get-NetRoute` |
| Puertos en escucha | `ss -tulpn` | `Get-NetTCPConnection -State Listen` |
| Probar un puerto | `nc -zv host 443` | `Test-NetConnection host -Port 443` |
| Resolver DNS | `dig`, `nslookup` | `Resolve-DnsName` |
| Espacio en disco | `df -h` | `Get-Volume` |
| Discos y particiones | `lsblk`, `fdisk`, `parted` | `Get-Disk`, `Get-Partition`, `New-Partition` |
| Procesos | `ps aux`, `top`, `kill` | `Get-Process`, `Stop-Process` |
| Permisos | `chmod`, `chown`, `setfacl` | `icacls`, `Get-Acl`/`Set-Acl` |
| Usuarios locales | `useradd`, `usermod -aG` | `New-LocalUser`, `Add-LocalGroupMember` |
| Rendimiento | `vmstat`, `iostat`, `sar` | `Get-Counter`, Performance Monitor |
| Firewall | `ufw`, `firewalld` | `Get/New-NetFirewallRule` |
| Shell remota | `ssh` | `Enter-PSSession`, `Invoke-Command`, `ssh` |
| Ayuda | `man` | `Get-Help` |

## Casos de uso

### 1. "¿Quién reinició el servidor anoche?"

```powershell
Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 1074, 6008, 41; StartTime = (Get-Date).AddDays(-1) } |
  Select-Object TimeCreated, Id, Message | Format-List
```

- **1074** dice quién (usuario o proceso, por ejemplo `TrustedInstaller.exe` tras Windows Update) y el motivo.
- **6008** + **41** sin 1074 = apagado no limpio: corte, BSOD, VM detenida desde la plataforma. Revisa también el log de actividad de la nube.

### 2. Un servicio no arranca tras actualizar

1. `Get-Service MiApp` → `Stopped`. Intenta `Start-Service MiApp` y lee el error.
2. Eventos del gestor de servicios: `Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Service Control Manager'; StartTime=(Get-Date).AddHours(-2)}` (7000: no pudo iniciarse, con el motivo; 7009: timeout; 7031: terminó inesperadamente).
3. Log Application para la excepción de la propia app: `Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=...}`.
4. Revisa la cuenta y el binario con `Get-CimInstance Win32_Service -Filter "Name='MiApp'"`: contraseña caducada de la cuenta de servicio o ruta cambiada son causas clásicas.
5. Dependencias: `Get-Service MiApp -RequiredServices`.

### 3. El disco C: está al 95 %

```powershell
Get-Volume -DriveLetter C
Get-ChildItem C:\ -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    [pscustomobject]@{ Carpeta = $_.FullName
      GB = [math]::Round((Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
             Measure-Object Length -Sum).Sum / 1GB, 1) }
} | Sort-Object GB -Descending | Select-Object -First 5
```

Sospechosos habituales: logs de IIS (`C:\inetpub\logs`), volcados de memoria, `C:\Windows\SoftwareDistribution`, perfiles de usuario viejos. Limpia componentes de Windows con `Dism.exe /Online /Cleanup-Image /StartComponentCleanup` (elevado) en lugar de borrar a mano en `C:\Windows`.

### 4. Abrir el puerto de una app solo para la red interna y comprobarlo

1. `New-NetFirewallRule ... -LocalPort 8443 -RemoteAddress 10.0.20.0/24` (ver [Firewall](#firewall)).
2. En el servidor: `Get-NetTCPConnection -State Listen -LocalPort 8443` (¿la app escucha?).
3. Desde un equipo de la red 10.0.20.0/24: `Test-NetConnection srv-app01 -Port 8443` → `TcpTestSucceeded : True`.
4. Desde otra red debe fallar. Si falla desde todas, revisa también el security group/NSG de la nube.

### 5. Programar un script de limpieza semanal

Igual que el [ejemplo de backup](#tareas-programadas), con `New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am`. Verifica al día siguiente con `Get-ScheduledTaskInfo` (`LastTaskResult` = 0) y que el script deje su propio log.

## Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `Get-WinEvent` sobre Security dice "no se encontraron eventos" | Falta de permisos, no ausencia de eventos | Consola elevada o grupo *Event Log Readers* |
| `Get-Counter` "objeto no encontrado" | Nombres de contadores traducidos | Usa nombres del idioma local o clases CIM `Win32_PerfFormattedData_*` |
| Script falla en otro servidor por `Administradores` vs `Administrators` | Nombres de grupos integrados traducidos | Usa SIDs (`S-1-5-32-544`) |
| `sc config` no hace nada | En PowerShell `sc` es alias de `Set-Content` | Escribe `sc.exe` |
| `Sort-Object InstalledOn` falla en `Get-HotFix` | Entradas sin fecha o formato regional | Filtra las vacías antes de ordenar |
| `Get-WinEvent ... \| Where-Object` tarda minutos | Filtra después de leer todo el log | `-FilterHashtable` (filtra en origen) |
| La regla de firewall "no funciona" | Perfil equivocado (red marcada Public) o falta la regla en el NSG/SG | `Get-NetConnectionProfile`; revisa también la nube |
| Permiso denegado en un share aunque NTFS lo permite | El permiso del share es más restrictivo | Revisa `Get-SmbShareAccess`: gana el más restrictivo |
| `Resize-Partition` dice que no hay espacio | Windows no ha detectado el nuevo tamaño del disco | `Update-HostStorageCache` y vuelve a consultar `Get-PartitionSupportedSize` |

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Servidores (la práctica) | Fundamentos, roles, lo mismo en Linux y automatizado con Ansible | [Windows Server: fundamentos](windows-server-fundamentos.md), [Roles y servicios de Windows Server](windows-roles-servicios.md), [Linux: procesos y rendimiento](../linux/linux-procesos-rendimiento.md), [Linux: almacenamiento](../linux/linux-almacenamiento.md), [Ansible y Windows](../ansible/ansible-windows.md) |
| DevOps (la automatización) | Leer logs, diagnosticar y observar | [Cómo leer logs](../../monitoreo/logging/leer-logs.md), [Troubleshooting](../../devops/operacion/troubleshooting.md), [Observabilidad](../../monitoreo/fundamentos/observabilidad.md), [Sistema y procesos con Python](../../python/scripting/sistema-procesos.md) |
| DevSecOps (la verificación) | Auditoría, eventos de seguridad y configuración segura | [Hardening de Windows Server](../../devsecops/hardening/hardening-windows.md), [Detección y respuesta](../../devsecops/gobierno-y-respuesta/deteccion-respuesta.md) |
| Cloud (el control) | Discos, IPs y firewall de la VM a nivel de plataforma | [Máquinas virtuales](../../cloud/computo/maquinas-virtuales.md), [Redes en la nube](../../cloud/redes-y-datos/redes.md) |
| Networking (la base) | Diagnóstico de conectividad y DNS | [Troubleshooting de red](../../networking/avanzado/troubleshooting-red.md), [Puertos](../../recursos/puertos.md) |

## Referencias

- [Microsoft.PowerShell.LocalAccounts](https://learn.microsoft.com/es-es/powershell/module/microsoft.powershell.localaccounts/)
- [Get-Service](https://learn.microsoft.com/es-es/powershell/module/microsoft.powershell.management/get-service) y [Set-Service](https://learn.microsoft.com/es-es/powershell/module/microsoft.powershell.management/set-service)
- [sc.exe config](https://learn.microsoft.com/es-es/windows-server/administration/windows-commands/sc-config) y [sc.exe failure](https://learn.microsoft.com/es-es/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc742019%28v=ws.11%29)
- [Get-WinEvent](https://learn.microsoft.com/es-es/powershell/module/microsoft.powershell.diagnostics/get-winevent) y [Creating Get-WinEvent queries with FilterHashtable](https://learn.microsoft.com/en-us/powershell/scripting/samples/creating-get-winevent-queries-with-filterhashtable)
- [Get-HotFix](https://learn.microsoft.com/es-es/powershell/module/microsoft.powershell.management/get-hotfix)
- [ScheduledTasks module](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/)
- [NetSecurity (firewall)](https://learn.microsoft.com/en-us/powershell/module/netsecurity/) y [New-NetFirewallRule](https://learn.microsoft.com/en-us/powershell/module/netsecurity/new-netfirewallrule)
- [NetTCPIP](https://learn.microsoft.com/en-us/powershell/module/nettcpip/), [Test-NetConnection](https://learn.microsoft.com/en-us/powershell/module/nettcpip/test-netconnection) y [Resolve-DnsName](https://learn.microsoft.com/en-us/powershell/module/dnsclient/resolve-dnsname)
- [Storage module](https://learn.microsoft.com/en-us/powershell/module/storage/)
- [icacls](https://learn.microsoft.com/es-es/windows-server/administration/windows-commands/icacls) y [Get-Acl](https://learn.microsoft.com/es-es/powershell/module/microsoft.powershell.security/get-acl)
- [New-SmbShare](https://learn.microsoft.com/en-us/powershell/module/smbshare/new-smbshare)
- [Get-Counter](https://learn.microsoft.com/es-es/powershell/module/microsoft.powershell.diagnostics/get-counter)
- [Eventos de seguridad 4624](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4624) y [4625](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-10/security/threat-protection/auditing/event-4625)
