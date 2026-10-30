---
tags:
  - servidores
  - windows
  - powershell
  - computo
---

# Windows Server: fundamentos

> Qué versiones de Windows Server están vigentes, cuándo elegir Server Core o Desktop Experience, cómo dejar un servidor listo con `sconfig` y PowerShell, cómo instalar roles y features, con qué herramientas se administra (Server Manager, Windows Admin Center, RSAT, MMC), por qué PowerShell es la herramienta principal y cómo administrar en remoto con PowerShell Remoting y OpenSSH.

!!! info "Antes de leer"
    Conviene que sepas qué es una máquina virtual y cómo se crea en la nube ([Máquinas virtuales](../../cloud/computo/maquinas-virtuales.md)) y tener nociones de red: IP, DNS y puertos ([Direccionamiento IP](../../networking/basico/direccionamiento-ip.md), [Servicios de red](../../networking/intermedio/servicios-red.md)). Si vienes de Linux, la nota hermana es [Linux: fundamentos de servidor](../linux/linux-fundamentos-servidor.md). La seguridad (baselines, LAPS, Defender, RDP) **no** se repite aquí: está en [Hardening de Windows Server](../../devsecops/hardening/hardening-windows.md).

!!! warning "Sobre las salidas de ejemplo"
    Las salidas marcadas como **salida real** se obtuvieron en un **Windows 11 Home (build 26200, Windows PowerShell 5.1)**, sin elevación y solo con comandos de lectura; se abreviaron y anonimizaron (equipo `EQUIPO`, usuario `usuario`). Los cmdlets que solo existen en Windows Server (`Get-WindowsFeature`, `Install-WindowsFeature`…) se verificaron contra Microsoft Learn y su salida se marca como **esperada**.

## ¿Qué es Windows Server?

Windows Server es la edición de Windows pensada para **servir** a otros equipos: identidad (Active Directory), DNS, DHCP, archivos, web (IIS), virtualización (Hyper-V) o aplicaciones .NET y SQL Server. Comparte núcleo con Windows cliente (Windows Server 2025 y Windows 11 24H2 tienen la misma base, build 26100), pero cambia en tres cosas:

- **Roles y features**: componentes de servidor que no existen en Windows 11 (AD DS, DHCP Server, Failover Clustering…).
- **Ciclo de vida fijo y largo**: 5 años de soporte principal + 5 de extendido.
- **Licenciamiento por núcleos** y opción de instalar **sin escritorio** (Server Core).

En la nube es una VM más (IaaS): según el [Shared Responsibility Model](../../cloud/fundamentos/responsabilidad-compartida.md), el sistema operativo, los parches y los roles son tuyos.

## Versiones y canales vigentes

Windows Server tiene dos **servicing channels** (canales de mantenimiento):

| Canal | Qué es | Soporte | Instalación |
| --- | --- | --- | --- |
| **Long-Term Servicing Channel (LTSC)** | Versión "mayor" cada 2–3 años; la que usarás casi siempre | 5 años mainstream + 5 años extended | Server Core o Desktop Experience |
| **Annual Channel (AC)** | Versión anual centrada en **hosts de contenedores** | 18 meses + 6 meses | Solo Server Core; solo clientes con Software Assurance |

Versiones LTSC con soporte (consultado en *Windows Server release information* el 26-10-2026):

| Versión | Build | Disponible desde | Fin de soporte mainstream | Fin de soporte extendido |
| --- | --- | --- | --- | --- |
| **Windows Server 2025** | 26100 | 2024-11-01 | 2029-11-13 | 2034-11-14 |
| **Windows Server 2022** | 20348 | 2021-08-18 | Terminado (octubre de 2026) | 2031-10-14 |
| Windows Server 2019 | 17763 | 2018-11-13 | Terminado | 2029-01-09 |
| Windows Server 2016 | 14393 | 2016-08-02 | Terminado | 2027-01-12 |

La versión AC más reciente es **Windows Server, version 23H2**. Para saber qué tienes delante, Microsoft recomienda mirar `OSDisplayVersion`: `21H2` en Windows Server 2022 es LTSC; `23H2` es Annual Channel.

!!! tip "Qué elegir hoy"
    Para un servidor nuevo: **Windows Server 2025 LTSC**. Windows Server 2022 sigue recibiendo parches de seguridad (soporte extendido) pero ya no mejoras. Revisa siempre el ciclo de vida de Microsoft antes de planificar: las fechas son lo que más cambia en esta tabla.

### Standard vs Datacenter

| Aspecto | Standard | Datacenter |
| --- | --- | --- |
| VMs con Windows Server incluidas (*OSEs*) | 2 por cada licencia completa de núcleos | Ilimitadas en ese host |
| Roles base (AD DS, DNS, DHCP, IIS, File Server, Hyper-V) | Sí | Sí |
| Storage Spaces Direct, SDN, Shielded VMs | No | Sí |
| Cuándo | Servidores físicos con pocas VMs, o VMs en la nube | Hosts de virtualización muy densos, clústeres hiperconvergentes |

En la nube casi siempre da igual: pagas la licencia en el precio por hora de la VM (*license included*) o traes la tuya (BYOL / Azure Hybrid Benefit).

**Licenciamiento en una línea**: por núcleos físicos (mínimo 8 por procesador y 16 por servidor) más **CALs** (*Client Access Licenses*) por usuario o dispositivo que accede; Windows Server 2025 añade además pago por uso vía Azure Arc. Confírmalo con tu distribuidor: es un tema contractual.

## Server Core vs Desktop Experience

| | **Server Core** | **Server with Desktop Experience** |
| --- | --- | --- |
| Interfaz | Consola (`sconfig`, PowerShell, `cmd`) | Escritorio completo, Server Manager local |
| Disco y RAM | Menos | Más (varios GB extra) |
| Parches y reinicios | Menos (menos componentes) | Más |
| Superficie de ataque | Menor | Mayor |
| Administración | Remota: Windows Admin Center, RSAT, PowerShell | Local o remota |
| Compatibilidad | Algunas apps de terceros con GUI no funcionan | Todo |

Desde Windows Server 2016 **no puedes cambiar** entre Core y Desktop Experience después de instalar: hay que reinstalar. La recomendación de Microsoft es Server Core salvo que una aplicación necesite el escritorio.

Para saber qué tipo de instalación tienes, lee el registro:

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' |
  Select-Object ProductName, EditionID, DisplayVersion, CurrentBuild, InstallationType
```

```text title="Salida real (Windows 11 Home)"
ProductName      : Windows 10 Home Single Language
EditionID        : CoreSingleLanguage
DisplayVersion   : 25H2
CurrentBuild     : 26200
InstallationType : Client
```

`InstallationType` vale `Client` en Windows 11, `Server Core` en Server Core y `Server` con Desktop Experience. Fíjate en la trampa: `ProductName` dice **Windows 10** en un Windows 11 (Microsoft no actualizó esa clave). Para inventario usa `Get-ComputerInfo` o `Get-CimInstance Win32_OperatingSystem`:

```powershell
Get-ComputerInfo -Property OsName, OsVersion, WindowsInstallationType, CsDomain, CsPartOfDomain
```

```text title="Salida real (Windows 11 Home)"
OsName                  : Microsoft Windows 11 Home Single Language
OsVersion               : 10.0.26200
WindowsInstallationType : Client
CsDomain                : WORKGROUP
CsPartOfDomain          : False
```

## Instalación y configuración inicial

Tras instalar (ISO, plantilla de la nube o imagen *sysprep*), un servidor necesita siempre lo mismo: nombre, IP, DNS, hora, actualizaciones, acceso remoto y, casi siempre, unirse al dominio.

### sconfig

`sconfig` es el menú de texto para configurar Server Core (también existe en Desktop Experience). Desde Windows Server 2022 está escrito en PowerShell y arranca automáticamente al iniciar sesión en Server Core. Opciones principales (salida esperada, Windows Server 2022/2025):

```text title="Salida esperada de sconfig (resumida)"
 1) Domain/workgroup:                    Workgroup: WORKGROUP
 2) Computer name:                       WIN-8QK1T2ABCDE
 3) Add local administrator
 4) Remote management:                   Enabled
 5) Update setting:                      Download only
 6) Install updates
 7) Remote desktop:                      Disabled
 8) Network settings
 9) Date and time
10) Telemetry setting:                   Required
11) Windows activation
12) Log off user
13) Restart server
14) Shut down server
15) Exit to command line (PowerShell)
```

### Lo mismo con PowerShell (repetible y automatizable)

Lo que haces con `sconfig` a mano conviene tenerlo en un script (o en [Ansible](../ansible/ansible-windows.md)) para que todos los servidores queden iguales. Estos comandos **cambian** el sistema; no se ejecutaron en el equipo de prueba (sintaxis comprobada con `Get-Command -Syntax`):

```powershell title="configuracion-inicial.ps1"
# 1. Nombre (requiere reinicio; lo hacemos al final)
Rename-Computer -NewName 'SRV-APP01'

# 2. IP estática y DNS en la interfaz principal
New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress 10.0.10.21 -PrefixLength 24 -DefaultGateway 10.0.10.1
Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ServerAddresses 10.0.10.10, 10.0.10.11

# 3. Zona horaria (en dominio, la hora la sincroniza el DC; fuera de dominio, revisa w32tm)
Set-TimeZone -Id 'SA Pacific Standard Time'

# 4. Unir al dominio y reiniciar (pide credenciales con permiso para unir equipos)
Add-Computer -DomainName 'corp.contoso.com' -OUPath 'OU=Servidores,DC=corp,DC=contoso,DC=com' `
             -Credential (Get-Credential) -Restart
```

!!! tip "En la nube, no fijes la IP dentro del SO"
    En AWS, Azure y Google Cloud la IP privada se asigna en la NIC de la VM y llega por DHCP. Si fijas la IP dentro de Windows y luego cambia en la plataforma, pierdes la conexión. Reserva la IP en la nube (IP privada estática) y deja Windows en DHCP.

## Roles, role services y features

- **Role** (rol): función principal del servidor (AD DS, DNS Server, DHCP Server, Web Server (IIS), File and Storage Services, Hyper-V).
- **Role service** (servicio de rol): pieza de un rol (por ejemplo, `Web-Asp-Net45` dentro de IIS o `FS-DFS-Namespace` dentro de File Services).
- **Feature** (característica): componente de apoyo que no es un rol por sí mismo (Failover Clustering, .NET Framework 3.5, Windows Server Backup, RSAT).

Se gestionan con el módulo **ServerManager**, que **solo existe en Windows Server**:

```powershell
Get-WindowsFeature -Name Web-*, AD-Domain-Services, DHCP, DNS
```

```text title="Salida esperada (Windows Server; [X] = instalado)"
Display Name                                            Name                       Install State
------------                                            ----                       -------------
[X] Web Server (IIS)                                    Web-Server                     Installed
    [X] Web Server                                      Web-WebServer                  Installed
        [X] Common HTTP Features                        Web-Common-Http                Installed
[ ] Active Directory Domain Services                    AD-Domain-Services             Available
[ ] DHCP Server                                         DHCP                           Available
[ ] DNS Server                                          DNS                            Available
```

```powershell
# Instalar IIS con sus herramientas de administración (consola y módulos PowerShell)
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Ver qué haría sin hacerlo
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -WhatIf

# Quitar un rol y además borrar sus binarios del disco (Features on Demand)
Uninstall-WindowsFeature -Name Web-Server -Remove
```

```text title="Salida esperada de Install-WindowsFeature"
Success Restart Needed Exit Code      Feature Result
------- -------------- ---------      --------------
True    No             Success        {Common HTTP Features, Default Document, ...}
```

Opciones clave: `-IncludeManagementTools` (sin él, en Server Core no tendrás los cmdlets del rol), `-IncludeAllSubFeature`, `-Source` (ruta a `\sources\sxs` del ISO cuando el servidor no tiene internet o los binarios se quitaron) y `-ComputerName` para instalar en otro servidor.

En Windows 11 no existe `Get-WindowsFeature`: el equivalente cliente es `Get-WindowsOptionalFeature -Online` (módulo DISM) y requiere consola elevada.

```text title="Salida real (Windows 11 Home, sin elevación)"
PS> Get-Command Get-WindowsFeature, Install-WindowsFeature
Get-Command : No se encuentra el término 'Get-WindowsFeature'...

PS> Get-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole
Get-WindowsOptionalFeature : La operación solicitada requiere elevación.
```

## Herramientas de gestión

| Herramienta | Qué es | Cuándo usarla |
| --- | --- | --- |
| **Server Manager** | Consola gráfica incluida en Desktop Experience: roles, features, grupos de servidores | Servidor con escritorio, tareas puntuales |
| **Windows Admin Center** (WAC) | Consola web gratuita (gateway + navegador) para servidores, clústeres, Hyper-V y Azure Local; no requiere escritorio en el servidor gestionado | Administrar Server Core y flotas pequeñas con interfaz moderna |
| **RSAT** (*Remote Server Administration Tools*) | Consolas y módulos PowerShell (ActiveDirectory, GroupPolicy, DnsServer, DhcpServer) instalables en Windows 11 Pro/Enterprise como *Features on Demand* | Administrar desde tu estación de trabajo |
| **MMC** (*Microsoft Management Console*) | Contenedor de *snap-ins*: `compmgmt.msc`, `services.msc`, `eventvwr.msc`, `dsa.msc` (usuarios de AD), `gpmc.msc`, `dnsmgmt.msc`, `dhcpmgmt.msc` | Herramientas clásicas, también en remoto |
| **PowerShell** | Shell y lenguaje de automatización | Todo lo repetible: es la herramienta principal |
| **Azure Arc** | Proyecta servidores on-premise u otras nubes en Azure (políticas, Update Manager, WAC en el portal) | Gestión híbrida centralizada |

Sobre Windows Admin Center (verificado el 26-10-2026): la versión GA más reciente es la **2606**; desde la 2410 el backend usa .NET 8. Cada versión se soporta hasta 30 días después de que salga la siguiente, así que mantenlo actualizado. WAC no sustituye a System Center ni a Intune: está pensado para un servidor o clúster cada vez.

```powershell
# RSAT en Windows 11 Pro/Enterprise (consola elevada; no disponible en Home)
Get-WindowsCapability -Online -Name 'Rsat.*' | Select-Object Name, State
Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'
```

## PowerShell como herramienta principal

### Windows PowerShell 5.1 vs PowerShell 7

| | **Windows PowerShell 5.1** | **PowerShell 7.x** |
| --- | --- | --- |
| Ejecutable | `powershell.exe` | `pwsh.exe` |
| Base | .NET Framework 4.x | .NET moderno (7.6 LTS usa .NET 10) |
| Viene con Windows | Sí, en todas las versiones vigentes | No: se instala aparte (MSI, `winget`) |
| Plataformas | Solo Windows | Windows, Linux, macOS |
| Estado | Mantenido (parches), sin nuevas funciones | Activo: 7.6 es la LTS vigente (soporte hasta 14-11-2028); 7.4 LTS y 7.5 terminan el 10-11-2026 |
| Módulos de servidor | Todos | La mayoría; los que no son compatibles se cargan con la *Windows PowerShell compatibility* (un proceso 5.1 por detrás) |
| Remoting por SSH | No | Sí (`-HostName`) |

Ambos conviven sin problema. En el equipo de prueba solo hay 5.1:

```powershell
$PSVersionTable.PSVersion.ToString()
winget install --id Microsoft.PowerShell --source winget   # instalar PowerShell 7 (no ejecutado)
```

```text title="Salida real (Windows 11 Home)"
5.1.26100.9711
```

`winget` viene instalado por defecto también en **Windows Server 2025**.

### Cmdlets Verb-Noun

Los comandos se llaman **cmdlets** y siguen el patrón `Verbo-Sustantivo`: `Get-Service`, `Set-Service`, `New-LocalUser`. Los verbos están normalizados (`Get-Verb` devuelve 98 en 5.1): `Get` lee, `Set` modifica, `New` crea, `Remove` borra, `Start`/`Stop`, `Enable`/`Disable`. Saber el verbo te deja adivinar el comando.

```powershell
Get-Command -Noun Service
```

```text title="Salida real (Windows 11, PowerShell 5.1)"
Name            CommandType Source
----            ----------- ------
Get-Service          Cmdlet Microsoft.PowerShell.Management
New-Service          Cmdlet Microsoft.PowerShell.Management
Restart-Service      Cmdlet Microsoft.PowerShell.Management
Set-Service          Cmdlet Microsoft.PowerShell.Management
Start-Service        Cmdlet Microsoft.PowerShell.Management
Stop-Service         Cmdlet Microsoft.PowerShell.Management
...
```

Hay **alias** para quien viene de `cmd` o Linux (`ls` → `Get-ChildItem`, `ps` → `Get-Process`, `kill` → `Stop-Process`, `cat` → `Get-Content`, `gsv` → `Get-Service`). Úsalos en la consola, **nunca en scripts**: dificultan la lectura y en PowerShell 7 sobre Linux `ls` es el `ls` real.

### El pipeline pasa objetos, no texto

La gran diferencia con Bash: `|` pasa **objetos .NET con propiedades**, no líneas de texto. No necesitas `grep`, `awk` ni `cut`; filtras y seleccionas por propiedad:

```powershell
Get-Service | Where-Object Status -eq 'Running' | Sort-Object Name | Select-Object -First 3 Name, Status
```

```text title="Salida real (Windows 11)"
Name             Status
----             ------
AdobeARMservice Running
Appinfo         Running
AsusAppService  Running
```

Patrón habitual: **obtener → filtrar (`Where-Object`) → ordenar (`Sort-Object`) → elegir columnas (`Select-Object`) → formatear o exportar** (`Format-Table`, `Export-Csv`, `ConvertTo-Json`). Formatea siempre **al final**: después de `Format-Table` ya no hay objetos útiles, solo instrucciones de formato.

### Get-Help, Get-Command y Get-Member

Las tres herramientas para descubrir cualquier cosa sin salir de la consola:

| Cmdlet | Pregunta que responde | Ejemplo |
| --- | --- | --- |
| `Get-Command` | ¿Qué comando existe para esto? | `Get-Command -Module NetTCPIP -Verb Get` |
| `Get-Help` | ¿Cómo se usa? | `Get-Help Get-WinEvent -Examples`, `-Online`, `-Full` |
| `Get-Member` | ¿Qué propiedades y métodos tiene lo que devuelve? | `Get-Service W32Time \| Get-Member -MemberType Property` |

```text title="Salida real: Get-Service W32Time | Get-Member -MemberType Property (abreviada)"
Name                Definition
----                ----------
CanStop             bool CanStop {get;}
DependentServices   System.ServiceProcess.ServiceController[] DependentServices {get;}
DisplayName         string DisplayName {get;set;}
ServiceName         string ServiceName {get;set;}
...
```

La ayuda local **no viene completa**: en el equipo de prueba `Get-Help Get-Service` solo mostró la sintaxis generada automáticamente. Descárgala con `Update-Help` (consola elevada; en servidores sin internet, `Save-Help` en otro equipo y `Update-Help -SourcePath`) o usa `Get-Help <cmdlet> -Online`.

### Perfiles

Un **profile** (perfil) es un script que se ejecuta al abrir PowerShell: alias, funciones, módulos y prompt personalizados. Hay cuatro, según alcance (todos los usuarios o el actual) y host (todas las consolas o solo esta):

```powershell
$PROFILE | Select-Object *
```

```text title="Salida real (Windows 11, PowerShell 5.1; ruta de usuario anonimizada)"
AllUsersAllHosts       : C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1
AllUsersCurrentHost    : C:\Windows\System32\WindowsPowerShell\v1.0\Microsoft.PowerShell_profile.ps1
CurrentUserAllHosts    : C:\Users\usuario\OneDrive\Documentos\WindowsPowerShell\profile.ps1
CurrentUserCurrentHost : C:\Users\usuario\OneDrive\Documentos\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
```

PowerShell 7 usa otra carpeta (`Documents\PowerShell`). En servidores, evita perfiles con lógica: los scripts deben funcionar sin depender del perfil de quien los ejecuta (`pwsh -NoProfile`).

### Execution policy

La **execution policy** (directiva de ejecución) decide si se pueden ejecutar scripts `.ps1` y si deben estar firmados. Se define por ámbito, y gana el más específico según el orden de la tabla:

```powershell
Get-ExecutionPolicy -List
```

```text title="Salida real (Windows 11)"
        Scope ExecutionPolicy
        ----- ---------------
MachinePolicy       Undefined
   UserPolicy       Undefined
      Process          Bypass
  CurrentUser       Undefined
 LocalMachine    RemoteSigned
```

| Valor | Efecto |
| --- | --- |
| `Restricted` | No ejecuta scripts (por defecto en Windows cliente) |
| `RemoteSigned` | Scripts locales sí; los descargados de internet deben estar firmados (por defecto en Windows Server) |
| `AllSigned` | Todo firmado por un editor de confianza |
| `Bypass` | Nada se bloquea ni avisa (lo usan herramientas que lanzan PowerShell, como en este caso el ámbito `Process`) |

!!! warning "No es una barrera de seguridad"
    Microsoft lo dice explícitamente: la execution policy evita ejecuciones **accidentales**, no ataques (basta `powershell -ExecutionPolicy Bypass`). La protección real va por AppLocker/App Control, logging de PowerShell y mínimo privilegio (ver [Hardening de Windows Server](../../devsecops/hardening/hardening-windows.md#logging-de-powershell-y-auditoria-avanzada)).

## Administración remota

### PowerShell Remoting sobre WinRM

**PowerShell Remoting** ejecuta comandos en otros equipos usando **WinRM** (*Windows Remote Management*, implementación de WS-Management):

| Puerto | Transporte | Comentario |
| --- | --- | --- |
| 5985/TCP | HTTP | El contenido va cifrado por Kerberos o NTLM, pero sin validar la identidad del servidor por certificado |
| 5986/TCP | HTTPS | Requiere un certificado en el servidor; obligatorio fuera de dominio o si cruzas redes no confiables |

En Windows Server (2012 y posteriores) el remoting viene **activado por defecto** en redes de dominio y privadas. En Windows cliente hay que activarlo con `Enable-PSRemoting` (inicia WinRM, crea el listener HTTP y las reglas de firewall). En el equipo de prueba **no** se activó; se comprobó el estado con lectura:

```powershell
Get-NetFirewallRule -Name 'WINRM-HTTP-In-TCP*' | Format-Table Name, Enabled, Profile, Direction, Action
Get-Item WSMan:\localhost\Client\TrustedHosts
```

```text title="Salida real (Windows 11)"
Name                      Enabled         Profile Direction Action
----                      -------         ------- --------- ------
WINRM-HTTP-In-TCP           False          Public   Inbound  Allow
WINRM-HTTP-In-TCP-NoScope   False Domain, Private   Inbound  Allow

Name         Value
----         -----
TrustedHosts
```

Las tres formas de usarlo:

```powershell
# 1) Sesión interactiva 1 a 1 (como ssh)
Enter-PSSession -ComputerName SRV-APP01
[SRV-APP01]: PS C:\> Get-Service W3SVC
[SRV-APP01]: PS C:\> Exit-PSSession

# 2) Un comando en muchos servidores en paralelo (fan-out); cada resultado trae PSComputerName
Invoke-Command -ComputerName SRV-APP01, SRV-APP02, SRV-APP03 -ScriptBlock {
    Get-CimInstance Win32_OperatingSystem | Select-Object Caption, LastBootUpTime
}

# 3) Sesión persistente reutilizable (evita reconectar en cada comando)
$s = New-PSSession -ComputerName SRV-APP01, SRV-APP02
Invoke-Command -Session $s -ScriptBlock { Get-HotFix | Select-Object -Last 1 }
Remove-PSSession $s
```

- **En dominio**: autentica con **Kerberos** y funciona por nombre (no por IP).
- **Fuera de dominio** (workgroup, VMs en la nube sin AD): Kerberos no está disponible; o usas HTTPS con certificado o añades el destino a **TrustedHosts** en el cliente (`Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'srv-app01' -Concatenate`). TrustedHosts solo dice "confío en este nombre sin poder verificarlo": limítalo a nombres concretos, nunca `*`.
- **HTTPS**: crea el listener con un certificado del servidor (`New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint <huella>`), abre 5986 en el firewall y conecta con `-UseSSL`.
- **Double hop** (doble salto): desde una sesión remota no puedes acceder a un tercer recurso (un share, otro servidor) porque tus credenciales no viajan. Soluciones: *Resource-based Kerberos constrained delegation*, pasar `-Credential` dentro del script o JEA; evita CredSSP salvo que sepas lo que implica.
- **JEA** (*Just Enough Administration*): endpoints de remoting que solo permiten ciertos cmdlets a ciertos grupos, para delegar sin dar admin completo.

Para conectar Ansible por WinRM o PSRP, ver [Ansible y Windows](../ansible/ansible-windows.md).

### OpenSSH Server en Windows

Windows incluye OpenSSH como *Feature on Demand*. Es la opción natural si administras desde Linux o macOS, o con PowerShell 7 (`Enter-PSSession -HostName srv-app01 -UserName admin` usa SSH en vez de WinRM).

| Versión | Estado de OpenSSH Server |
| --- | --- |
| Windows Server 2025 | **Instalado por defecto**; se activa en Server Manager (*Remote SSH Access*) o arrancando el servicio `sshd` |
| Windows Server 2019/2022, Windows 10/11 | Se instala con `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0` |

```powershell
# Consola elevada en el servidor (no ejecutado en el equipo de prueba)
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP'   # la crea la instalación; puerto 22
```

Detalles que cambian respecto a Linux:

- La configuración está en `C:\ProgramData\ssh\sshd_config`.
- Para cuentas del grupo **Administrators**, las llaves públicas van en `C:\ProgramData\ssh\administrators_authorized_keys` (no en el perfil del usuario), con permisos solo para `Administrators` y `SYSTEM`.
- La shell por defecto es `cmd.exe`; se cambia con el valor `DefaultShell` en `HKLM:\SOFTWARE\OpenSSH`.
- En Windows Server 2025, el grupo local **OpenSSH Users** limita quién puede entrar por SSH.

## Windows Server en la nube

| Aspecto | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Imágenes oficiales | AMIs de Windows Server (license included) | Imágenes de Marketplace `MicrosoftWindowsServer` | Imágenes públicas `windows-cloud` |
| Traer tu licencia | BYOL en Dedicated Hosts | **Azure Hybrid Benefit** (licencias con Software Assurance) | BYOL en sole-tenant nodes |
| Contraseña inicial | Se descifra con la key pair (*Get Windows password*) | Se define al crear la VM | `gcloud compute reset-windows-password` |
| Acceso sin IP pública | Session Manager / Fleet Manager (SSM Agent) | Azure Bastion, Run Command | IAP TCP forwarding |
| Parches gestionados | Patch Manager (Systems Manager) | Azure Update Manager (también on-premise con Arc) | VM Manager (OS patch management) |

La comparación de precios y modelos de pago está en [Máquinas virtuales](../../cloud/computo/maquinas-virtuales.md) y la parte de seguridad (imágenes endurecidas, acceso sin RDP público) en [Seguridad de máquinas virtuales](../../cloud/seguridad/seguridad-maquinas-virtuales.md).

## Casos de uso

### 1. Dejar listo un Server Core recién instalado

1. Inicia sesión: aparece `sconfig`. Opción 15 para ir a PowerShell si prefieres script.
2. Nombre, IP y DNS con el script de [configuración inicial](#lo-mismo-con-powershell-repetible-y-automatizable) (o opciones 2 y 8 de `sconfig`).
3. Opción 6 de `sconfig` (o Windows Update / tu herramienta de parches) hasta que no queden actualizaciones.
4. Une el equipo al dominio con `Add-Computer ... -Restart`.
5. Desde tu estación, comprueba que responde: `Test-WSMan SRV-APP01` y `Invoke-Command -ComputerName SRV-APP01 { hostname }`.
6. Instala solo los roles necesarios con `Install-WindowsFeature ... -IncludeManagementTools` y aplica la baseline ([Hardening de Windows Server](../../devsecops/hardening/hardening-windows.md)).

### 2. Inventario rápido de 30 servidores

```powershell
$servidores = Get-Content .\servidores.txt
Invoke-Command -ComputerName $servidores -ErrorAction SilentlyContinue -ErrorVariable fallos -ScriptBlock {
    $os = Get-CimInstance Win32_OperatingSystem
    [pscustomobject]@{
        Version     = $os.Caption
        Build       = $os.BuildNumber
        UltimoBoot  = $os.LastBootUpTime
        TipoInstal  = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').InstallationType
    }
} | Select-Object PSComputerName, Version, Build, UltimoBoot, TipoInstal |
    Export-Csv .\inventario.csv -NoTypeInformation -Encoding UTF8

$fallos | ForEach-Object { $_.TargetObject }   # servidores que no respondieron
```

`Invoke-Command` conecta en paralelo (32 a la vez por defecto, `-ThrottleLimit` lo cambia) y `-ErrorVariable` separa los que fallaron para revisarlos después.

### 3. ¿Es LTSC o Annual Channel? ¿Core o escritorio?

```powershell
Get-ComputerInfo | Select-Object WindowsProductName, OSDisplayVersion, WindowsInstallationType
```

`OSDisplayVersion` `23H2` indica Annual Channel; `WindowsInstallationType` `Server Core` indica que no hay escritorio (y que tendrás que administrarlo en remoto).

### 4. Administrar un Windows Server 2025 desde Linux por SSH

1. En el servidor: `Start-Service sshd` y `Set-Service sshd -StartupType Automatic`; comprueba la regla `OpenSSH-Server-In-TCP`.
2. Copia tu llave pública a `C:\ProgramData\ssh\administrators_authorized_keys` (si eres admin) y ajusta permisos con `icacls` como indica la documentación de Microsoft.
3. Opcional: `DefaultShell` a `C:\Program Files\PowerShell\7\pwsh.exe`.
4. Desde Linux: `ssh admin@srv-app01` o, con PowerShell 7, `Enter-PSSession -HostName srv-app01 -UserName admin`.

### 5. Instalar .NET Framework 3.5 en un servidor sin internet

`Install-WindowsFeature NET-Framework-Core` falla con `0x800F081F` porque los binarios no están en el disco. Monta el ISO de la **misma versión** y usa `Install-WindowsFeature NET-Framework-Core -Source D:\sources\sxs`.

## Problemas comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `Get-WindowsFeature : No se encuentra el término...` | Estás en Windows 11 (no existe el módulo ServerManager) | En cliente usa `Get-WindowsOptionalFeature` o `Get-WindowsCapability`; administra el servidor en remoto |
| `WinRM cannot process the request... TrustedHosts` | Conectas por IP o fuera de dominio, sin Kerberos | Usa el nombre en dominio, HTTPS con certificado o añade el nombre exacto a TrustedHosts |
| `Connecting to remote server failed... WinRM cannot complete the operation` | Firewall o servicio WinRM parado, o red marcada como pública | `Test-NetConnection srv -Port 5985`; en el servidor, `Enable-PSRemoting` y revisa el perfil de red |
| `Access is denied` en un share desde una sesión remota | **Double hop** | Delegación Kerberos basada en recursos, credenciales explícitas o JEA |
| `... cannot be loaded because running scripts is disabled on this system` | Execution policy `Restricted` | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` o firmar el script |
| `Get-Help` solo muestra la sintaxis | Ayuda no descargada | `Update-Help` (elevado) o `Get-Help <cmdlet> -Online` |
| El inventario dice "Windows 10" en un Windows 11 | `ProductName` del registro no se actualizó | Usa `Get-ComputerInfo` (`OsName`) o `Win32_OperatingSystem.Caption` |
| `0x800F081F` al instalar una feature | Faltan los binarios (Features on Demand) | `-Source` apuntando a `sources\sxs` del ISO de la misma versión |
| Pierdes la VM en la nube tras configurar IP fija | La IP del SO no coincide con la de la NIC en la plataforma | Deja Windows en DHCP y reserva la IP en la nube |

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Servidores (la práctica) | Comandos de administración, roles, Linux equivalente y automatización con Ansible | [Administración con PowerShell](windows-powershell-administracion.md), [Roles y servicios de Windows Server](windows-roles-servicios.md), [Linux: fundamentos de servidor](../linux/linux-fundamentos-servidor.md), [Ansible y Windows](../ansible/ansible-windows.md) |
| Cloud (el control) | Windows Server como VM: licencias, imágenes, acceso y parches gestionados | [Máquinas virtuales](../../cloud/computo/maquinas-virtuales.md), [Seguridad de máquinas virtuales](../../cloud/seguridad/seguridad-maquinas-virtuales.md), [Shared Responsibility Model](../../cloud/fundamentos/responsabilidad-compartida.md) |
| DevOps (la automatización) | Configurar servidores como código en vez de a mano | [Configuration management con Ansible](../../devops/iac/ansible.md), [Infrastructure as Code](../../devops/iac/infraestructura-como-codigo.md) |
| DevSecOps (la verificación) | Baselines, Server Core como reducción de superficie, vulnerabilidades de Windows | [Hardening de Windows Server](../../devsecops/hardening/hardening-windows.md), [CVE en Windows y Active Directory](../../devsecops/vulnerabilidades/cve-windows-active-directory.md) |
| Networking (la base) | Puertos de administración (5985/5986, 22, 3389) y acceso por bastión | [Puertos](../../recursos/puertos.md), [Seguridad de red](../../networking/avanzado/seguridad-red.md) |

## Referencias

- [Windows Server release information](https://learn.microsoft.com/en-us/windows/release-health/windows-server-release-info)
- [Canales de mantenimiento de Windows Server (LTSC y Annual Channel)](https://learn.microsoft.com/es-es/windows-server/get-started/servicing-channels-comparison)
- [Novedades de Windows Server 2025](https://learn.microsoft.com/es-es/windows-server/get-started/whats-new-windows-server-2025)
- [Opciones de instalación: Server Core y Desktop Experience](https://learn.microsoft.com/es-es/windows-server/get-started/install-options-server-core-desktop-experience)
- [Configurar Server Core con SConfig](https://learn.microsoft.com/es-es/windows-server/administration/server-core/server-core-sconfig)
- [Install-WindowsFeature (ServerManager)](https://learn.microsoft.com/en-us/powershell/module/servermanager/install-windowsfeature)
- [Windows Admin Center: introducción](https://learn.microsoft.com/es-es/windows-server/manage/windows-admin-center/overview) y [historial de versiones](https://learn.microsoft.com/en-us/windows-server/manage/windows-admin-center/support/release-history)
- [RSAT en Windows](https://learn.microsoft.com/es-es/troubleshoot/windows-server/system-management-components/remote-server-administration-tools)
- [Ciclo de vida de PowerShell](https://learn.microsoft.com/es-es/powershell/scripting/install/powershell-support-lifecycle)
- [Diferencias entre Windows PowerShell 5.1 y PowerShell 7](https://learn.microsoft.com/es-es/powershell/scripting/whats-new/differences-from-windows-powershell)
- [about_Execution_Policies](https://learn.microsoft.com/es-es/powershell/module/microsoft.powershell.core/about/about_execution_policies)
- [about_Remote_Requirements](https://learn.microsoft.com/es-es/powershell/module/microsoft.powershell.core/about/about_remote_requirements) y [Making the second hop in PowerShell Remoting](https://learn.microsoft.com/en-us/powershell/scripting/security/remoting/ps-remoting-second-hop)
- [OpenSSH para Windows: primeros pasos](https://learn.microsoft.com/es-es/windows-server/administration/openssh/openssh_install_firstuse)
- [Azure Hybrid Benefit para Windows Server](https://learn.microsoft.com/es-es/azure/virtual-machines/windows/hybrid-use-benefit-licensing)
