---
tags:
  - devsecops
  - hardening
  - windows
  - seguridad
  - cumplimiento
---

# Hardening de Windows Server

> Cómo reducir la superficie de ataque de Windows Server 2022 y 2025 con las baselines de Microsoft y CIS: GPO, Windows LAPS, Defender y ASR rules, Credential Guard, protocolos heredados, RDP, logging, BitLocker, firewall y parches, y cómo verificarlo solo con comandos de lectura.

!!! info "Dónde encaja"
    Una VM con Windows en la nube es **IaaS**: según el [Shared Responsibility Model](../../cloud/fundamentos/responsabilidad-compartida.md), el sistema operativo es tuyo. Lo específico de la nube (imágenes endurecidas, parches gestionados, acceso sin IP pública) está en [Seguridad de máquinas virtuales](../../cloud/seguridad/seguridad-maquinas-virtuales.md); el porqué y el ciclo del **hardening** (bastionado) en [Fundamentos de hardening](fundamentos-hardening.md); los marcos (CIS, NIST, ISO) en [Cumplimiento y gobierno](../gobierno-y-respuesta/cumplimiento.md). Aquí va lo que se configura **dentro** de Windows.

!!! warning "Sobre las salidas de ejemplo"
    Las salidas de esta nota se obtuvieron en un **Windows 11 Home (build 26200)**, sin elevación y **solo con comandos de lectura**; no son de Windows Server. Los cmdlets y claves de registro son los mismos, pero en un servidor unido a dominio verás otros valores.

## ¿Qué es?

Endurecer Windows es pasar de la configuración por defecto (pensada para que todo funcione) a una **security baseline** (línea base de seguridad): un conjunto documentado de valores para políticas, servicios, protocolos y auditoría. Las versiones de servidor vigentes son **Windows Server 2022** y **Windows Server 2025** (ambas LTSC; revisa el ciclo de vida de Microsoft antes de planificar).

Dos decisiones reducen superficie antes de tocar una sola política:

- **Server Core** (sin escritorio) en vez de *Desktop Experience*: menos binarios, menos parches y menos superficie de ataque (comparación completa en [Windows Server: fundamentos](../../servidores/windows/windows-server-fundamentos.md#server-core-vs-desktop-experience)).
- **Roles mínimos**: instala solo los roles y features que el servidor necesita (`Get-WindowsFeature | Where-Object Installed` para revisarlos).

## Baselines de referencia

| Baseline | Quién la publica | Cómo se entrega | Cuándo usarla |
| --- | --- | --- | --- |
| **Microsoft Security Baselines** | Microsoft | GPO exportadas en el **Security Compliance Toolkit** (SCT), una por versión (p. ej. *Windows Server 2025 Security Baseline – 2602*, de febrero de 2026) | Punto de partida natural; perfiles *Member Server* y *Domain Controller* |
| **CIS Microsoft Windows Server Benchmark** | Center for Internet Security | PDF + *Build Kits* (GPO) para miembros de CIS SecureSuite | Cuando auditores o clientes piden CIS; **Level 1** (base razonable) y **Level 2** (más restrictivo) |
| **DISA STIG** | Departamento de Defensa de EE. UU. | XCCDF + GPO | Sector público/defensa o contratos que lo exijan |

El SCT incluye dos herramientas clave:

| Herramienta | Para qué sirve |
| --- | --- |
| **Policy Analyzer** | Compara GPO entre sí o contra la configuración efectiva del equipo; detecta conflictos y valores redundantes |
| **LGPO.exe** | Exporta, importa y aplica políticas locales (útil en servidores fuera de dominio, golden images y laboratorios) |

```powershell
# Exportar la política local actual a una carpeta (no cambia el sistema): úsala para comparar en Policy Analyzer
.\LGPO.exe /b C:\temp\lgpo-backup
```

!!! tip "No apliques la baseline tal cual"
    Microsoft la publica como **referencia**. Impórtala en una GPO nueva, compárala con lo que ya tienes (Policy Analyzer), aplícala primero a una OU de prueba y documenta cada desviación como excepción con justificación, dueño y caducidad.

## GPO y su alcance

Las **Group Policy Objects** (objetos de directiva de grupo) se aplican en orden **LSDOU** (Local → Site → Domain → OU); cómo funcionan la precedencia, *Enforced* y el filtrado está en [Roles y servicios: Group Policy](../../servidores/windows/windows-roles-servicios.md#precedencia-lsdou). Algunas directivas solo valen a nivel de dominio (política de contraseñas de cuentas de dominio, salvo con *Fine-Grained Password Policies*).

| Escenario | Dónde vive la configuración |
| --- | --- |
| Servidores unidos a Active Directory | GPO enlazadas a OUs separadas por rol (DC, servidores de archivos, IIS…) |
| Servidores fuera de dominio / golden image | Política local con LGPO, DSC o [Ansible](../../devops/iac/ansible.md) |
| Equipos gestionados desde la nube | Microsoft Intune (*security baselines* y perfiles de Endpoint security) |
| VMs en Azure o híbridas con Arc | **Azure Machine Configuration** para auditar o aplicar la baseline |

```powershell
# Qué GPO se aplicaron y cuáles se filtraron (lectura; el alcance de equipo requiere elevación)
gpresult /scope computer /h C:\temp\gpresult.html
```

## Cuentas y administradores locales

- **Windows LAPS** (*Local Administrator Password Solution*, integrado en Windows desde las actualizaciones de abril de 2023): genera una contraseña única y rotada para la cuenta de administrador local de cada equipo y la guarda en Active Directory o en Microsoft Entra ID. Evita el clásico **lateral movement** (movimiento lateral) con la misma contraseña de admin en todos los servidores. El LAPS heredado (MSI aparte) está obsoleto.
- Deshabilita o renombra la cuenta integrada `Administrator` y deja `Guest` deshabilitada.
- Deniega el inicio de sesión **por red y por RDP** a las cuentas locales con el SID conocido `S-1-5-113` (*Local account*) o `S-1-5-114` (*Local account and member of Administrators group*), como hacen las baselines.
- Pocas cuentas en `Administrators`; nada de cuentas de servicio con privilegios de dominio (usa **gMSA**, *group Managed Service Accounts*).

```powershell
# Cmdlets del módulo LAPS (presentes en Windows 11 y Windows Server 2019+ actualizados)
Get-LapsDiagnostics                                   # diagnóstico de la política aplicada
Get-LapsADPassword -Identity SRV-APP01 -AsPlainText   # leer la contraseña (requiere permiso delegado)
Get-LocalUser | Select-Object Name, Enabled           # cuentas locales y si están habilitadas
```

## Microsoft Defender Antivirus y ASR rules

Defender Antivirus viene en Windows Server 2016 y posteriores. Lo mínimo: protección en tiempo real, protección en la nube, **Tamper Protection** (impide que malware o un admin desactive Defender localmente) y firmas actualizadas.

Las **Attack Surface Reduction rules** (reglas de reducción de la superficie de ataque) bloquean comportamientos típicos de malware. Cada regla tiene un GUID y una acción: `0` desactivada, `1` bloquear, `2` auditar, `6` advertir.

| Regla | GUID |
| --- | --- |
| Block abuse of exploited vulnerable signed drivers | `56a863a9-875e-4185-98a7-b882c64b5ce5` |
| Block credential stealing from the Windows local security authority subsystem | `9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2` |
| Block persistence through WMI event subscription | `e6db77e5-3df2-4cf1-b95a-636979351e5b` |
| Block process creations originating from PSExec and WMI commands | `d1e49aac-8f56-4280-b9ba-993a6d77406c` |
| Block executable content from email client and webmail | `be9ba2d9-53ea-4cdc-84e5-9b1eeee46550` |

Las tres primeras son las *standard protection rules* que Microsoft recomienda activar casi siempre. Despliégalas por GPO o Intune; el equivalente en PowerShell (solo en un equipo de laboratorio) sería:

```powershell
# Primero en modo auditoría (2): revisa eventos 1122 en Microsoft-Windows-Windows Defender/Operational
Add-MpPreference -AttackSurfaceReductionRules_Ids 9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2 `
                 -AttackSurfaceReductionRules_Actions AuditMode
```

!!! warning "Ojo con PSExec y WMI"
    *Block process creations originating from PSExec and WMI commands* rompe Microsoft Configuration Manager y herramientas de administración remota que usan WMI. Audita antes de bloquear.

## Credential Guard y LSA protection

- **LSA protection** (`RunAsPPL`): ejecuta `lsass.exe` como proceso protegido para que herramientas como Mimikatz no lean su memoria. Valor `1` = activado con bloqueo UEFI; `2` = activado sin bloqueo UEFI (lo que activa por defecto Windows 11 22H2 en instalaciones nuevas compatibles).
- **Credential Guard**: usa **VBS** (*Virtualization-Based Security*) para aislar los secretos de NTLM y Kerberos fuera del sistema operativo normal. Viene activado por defecto en equipos compatibles con Windows 11 22H2+ Enterprise/Education y en Windows Server 2025 (verifica los requisitos y las excepciones, como los controladores de dominio).

```powershell
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name RunAsPPL
Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard |
  Select-Object SecurityServicesConfigured, SecurityServicesRunning, VirtualizationBasedSecurityStatus
```

```text title="Salida real (Windows 11 Home)"
RunAsPPL                          : 2
SecurityServicesConfigured        : {2}
SecurityServicesRunning           : {2, 7}
VirtualizationBasedSecurityStatus : 2
```

`VirtualizationBasedSecurityStatus = 2` significa VBS en ejecución; en `SecurityServicesRunning`, `1` sería Credential Guard y `2` la integridad de memoria (HVCI). Aquí no aparece `1` porque Windows 11 Home no incluye Credential Guard.

## Protocolos heredados

| Protocolo | Riesgo | Qué hacer |
| --- | --- | --- |
| **SMBv1** | EternalBlue/WannaCry ([CVE en Windows y AD](../vulnerabilidades/cve-windows-active-directory.md#eternalblue-ms17-010-cve-2017-0144)) | Quitar la feature `SMB1Protocol`; no viene instalado por defecto desde Windows Server 2019 |
| **SMB sin firma** | Relay de NTLM | Exigir firma SMB (Windows Server 2025 y Windows 11 24H2 la exigen por defecto en más escenarios; verifica tu caso) |
| **NTLM** | Relay, pass-the-hash | `LmCompatibilityLevel = 5` (solo NTLMv2); auditar uso de NTLM antes de restringirlo; NTLMv1 se eliminó en Windows 11 24H2 y Windows Server 2025 |
| **LLMNR / NetBIOS / WPAD** | Envenenamiento de nombres en la LAN (Responder) | Desactivar LLMNR por GPO (*Turn off multicast name resolution*) y NetBIOS sobre TCP/IP |
| **TLS 1.0/1.1** | Cifrado débil | Desactivados por defecto en versiones recientes; verifícalo en servidores antiguos |
| **Print Spooler** en DCs y servidores sin impresoras | [PrintNightmare](../vulnerabilidades/cve-windows-active-directory.md#printnightmare-cve-2021-34527) | Detener y deshabilitar el servicio |
| **PowerShell 2.0** | Evita AMSI y el logging moderno | Quitar la feature donde siga instalada (Microsoft la retiró de Windows 11 24H2 y Windows Server 2025) |

```powershell
Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol, RequireSecuritySignature, EncryptData
Get-SmbClientConfiguration | Select-Object RequireSecuritySignature, EnableInsecureGuestLogons
```

```text title="Salida real (Windows 11 Home)"
EnableSMB1Protocol       : False
RequireSecuritySignature : False
EncryptData              : False

RequireSecuritySignature  : False
EnableInsecureGuestLogons : True
```

En un servidor endurecido esperarías `RequireSecuritySignature : True` en ambos y `EnableInsecureGuestLogons : False`.

## RDP

- **NLA** (*Network Level Authentication*): autentica antes de crear la sesión; mitiga ataques previos al login como BlueKeep ([CVE en Windows y AD](../vulnerabilidades/cve-windows-active-directory.md#bluekeep-cve-2019-0708)).
- **Nunca expuesto a internet**: accede por VPN, RD Gateway, Azure Bastion o equivalentes (ver [Seguridad de red](../../networking/avanzado/seguridad-red.md)). El puerto 3389 abierto a `0.0.0.0/0` es una de las vías de entrada de ransomware más comunes.
- Restringe *Allow log on through Remote Desktop Services* a un grupo concreto, limita el *scope* de la regla de firewall a las IPs de administración y considera **Remote Credential Guard** para no dejar credenciales en el servidor.

```powershell
# 1 = NLA exigida; fDenyTSConnections 1 = RDP deshabilitado
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections
```

En el equipo de prueba ambos valen `1`: NLA exigida y RDP deshabilitado.

## Logging de PowerShell y auditoría avanzada

Sin logs no hay detección (ver [Detección y respuesta](../gobierno-y-respuesta/deteccion-respuesta.md)). Activa por GPO (*Administrative Templates > Windows Components > Windows PowerShell*):

- **Script Block Logging**: registra el código que se ejecuta, incluso ofuscado, en el evento **4104** de `Microsoft-Windows-PowerShell/Operational`.
- **Module Logging** (evento 4103) y **PowerShell Transcription** a una carpeta protegida o recogida por el SIEM.

Y la **Advanced Audit Policy** (directiva de auditoría avanzada), con *Force audit policy subcategory settings* activado para que no la pise la política básica:

| Evento | Qué indica |
| --- | --- |
| 4624 / 4625 | Inicio de sesión correcto / fallido |
| 4672 | Inicio de sesión con privilegios especiales (admin) |
| 4688 | Creación de proceso (activa también la línea de comandos en el evento) |
| 4720 / 4732 | Cuenta creada / añadida a un grupo local de seguridad |
| 1102 | Log de seguridad borrado |
| 7045 | Servicio instalado (evento del log System) |

```powershell
auditpol /get /category:*      # requiere consola elevada
Get-WinEvent -ListLog Security | Select-Object LogName, MaximumSizeInBytes, LogMode
```

!!! note "Probado sin elevación"
    En el equipo de prueba `auditpol /get /category:*` devolvió el error `0x00000522` (*el cliente no dispone de un privilegio requerido*): necesita una consola de administrador. En sistemas en español, los nombres de categoría también salen traducidos, por eso es mejor usar `/category:*` o los GUID.

## BitLocker

Cifra los discos para que un disco robado o un snapshot copiado no sirva. En servidores físicos suele bastar **TPM**; en portátiles, **TPM + PIN**. Guarda las claves de recuperación en AD o Entra ID y usa XTS-AES 256 para discos nuevos. En la nube, el cifrado de disco del proveedor cubre parte de esto (ver [Seguridad de máquinas virtuales](../../cloud/seguridad/seguridad-maquinas-virtuales.md)).

```powershell
Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, ProtectionStatus, EncryptionMethod
manage-bde -status C:
```

Ambos requieren elevación: sin ella, `Get-BitLockerVolume` devuelve *Acceso denegado*.

## Firewall de Windows

Los tres perfiles (Domain, Private, Public) activados, entrada bloqueada por defecto, salida permitida (o restringida en servidores críticos) y log de paquetes descartados:

```powershell
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction, LogBlocked
```

```text title="Salida real (Windows 11 Home)"
Name    Enabled DefaultInboundAction DefaultOutboundAction LogBlocked
----    ------- -------------------- --------------------- ----------
Domain     True        NotConfigured         NotConfigured      False
Private    True        NotConfigured         NotConfigured      False
Public     True        NotConfigured         NotConfigured      False
```

`NotConfigured` significa que se usa el valor por defecto (bloquear entrada, permitir salida). Las baselines piden fijarlo **explícitamente** por GPO y activar `LogBlocked`, para que nadie lo cambie en local sin dejar rastro.

## Parches: Windows Update y WSUS

- Define anillos (*rings*): piloto → general, con ventanas de mantenimiento y SLA de remediación según severidad (ver [Detección y respuesta](../gobierno-y-respuesta/deteccion-respuesta.md)).
- **WSUS** sigue funcionando pero Microsoft lo anunció como *deprecated* (sin nuevas funciones) en 2024; para nuevos despliegues mira **Azure Update Manager** (también para servidores on-premise con Azure Arc), Intune/Windows Autopatch para clientes, y **Hotpatch** en Windows Server 2025 (parches sin reinicio; revisa requisitos y licenciamiento).

Cómo ver los parches instalados (`Get-HotFix`) e instalarlos desde la línea de comandos: [Administración con PowerShell: actualizaciones](../../servidores/windows/windows-powershell-administracion.md#actualizaciones).

## Active Directory en lo esencial

Endurecer cada servidor no basta si el dominio es débil. Las ideas mínimas:

- **Tier model** (modelo por niveles), hoy dentro del *Enterprise access model* de Microsoft: Tier 0 (DCs, PKI, identidad), Tier 1 (servidores), Tier 2 (estaciones). Una cuenta de Tier 0 **nunca** inicia sesión en un nivel inferior.
- **PAW** (*Privileged Access Workstations*) para administrar, cuentas admin separadas de las de uso diario y el grupo **Protected Users** para cuentas privilegiadas.
- Parchear DCs con prioridad: muchas de las vulnerabilidades más graves de Windows afectan a AD ([Zerologon](../vulnerabilidades/cve-windows-active-directory.md#zerologon-cve-2020-1472) y el resto en [CVE en Windows y Active Directory](../vulnerabilidades/cve-windows-active-directory.md)).
- Herramientas de evaluación de solo lectura como **PingCastle** o **Purple Knight** dan una foto rápida del riesgo del dominio.

## Cómo verificarlo

| Control | Comando de verificación (solo lectura) |
| --- | --- |
| SMBv1 deshabilitado | `(Get-SmbServerConfiguration).EnableSMB1Protocol` |
| Firma SMB | `(Get-SmbServerConfiguration).RequireSecuritySignature` |
| Defender activo y protegido | `Get-MpComputerStatus` (`RealTimeProtectionEnabled`, `IsTamperProtected`) |
| ASR rules | `(Get-MpPreference).AttackSurfaceReductionRules_Ids` y `_Actions` |
| LSA protection | `Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Lsa -Name RunAsPPL` |
| VBS / Credential Guard | `Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard` |
| NLA en RDP | registro `RDP-Tcp\UserAuthentication = 1` |
| Firewall | `Get-NetFirewallProfile` |
| BitLocker (elevado) | `Get-BitLockerVolume` |
| Auditoría (elevado) | `auditpol /get /category:*` |
| Windows LAPS | `Get-LapsDiagnostics` |

```text title="Get-MpComputerStatus y Get-MpPreference: salida real (Windows 11 Home)"
AMRunningMode             : Normal
AntivirusEnabled          : True
RealTimeProtectionEnabled : True
IsTamperProtected         : True
AMProductVersion          : 4.18.26090.9

AttackSurfaceReductionRules_Ids     :          # vacío: ninguna ASR rule configurada
AttackSurfaceReductionRules_Actions :
```

### HardeningKitty

**HardeningKitty** (proyecto open source de scip AG) compara el equipo con *finding lists* en CSV: Microsoft Security Baselines (p. ej. `finding_list_msft_security_baseline_windows_server_2025_2602_member_machine.csv`), CIS, DISA STIG y BSI. Tiene tres modos: **Audit** (solo lee), **Config** (exporta la configuración actual) y **HailMary** (aplica la lista entera, peligroso fuera de un laboratorio).

```powershell
Import-Module .\HardeningKitty.psd1
Invoke-HardeningKitty -Mode Audit `
  -FileFindingList .\lists\finding_list_msft_security_baseline_windows_11_25h2_machine.csv `
  -SkipMachineInformation -Log -Report
```

```text title="Salida real abreviada: HardeningKitty 0.9.4 en modo Audit, sin elevación (Windows 11 Home)"
[*] Is Admin: False
[$] Finding list verified as official (signature valid).
[+] ID 10000, Account lockout duration, Result=10, Recommended=10, Severity=Passed
[!] ID 10102, Password must meet complexity requirements, Method secedit requires admin privileges. Test skipped.
[$] ID 10220, Network security: LAN Manager authentication level, Result=3, Recommended=5, Severity=Medium
[$] ID 10622, Configure SMB v1 server, Result=1, Recommended=0, Severity=Medium
[$] ID 10650, DNS Client: Turn off multicast name resolution (LLMNR), Result=1, Recommended=0, Severity=Medium
[$] ID 10700, Local Security Authority: Configures LSASS to run as a protected process, Result=2, Recommended=1, Severity=Medium
[$] ID 10977, Microsoft Defender Antivirus: Microsoft Defender Exploit Guard: Attack Surface Reduction rules, Result=0, Recommended=1, Severity=Medium
[+] ID 11006, Windows PowerShell: Turn on PowerShell Script Block Logging (Invocation), Result=0, Recommended=0, Severity=Passed
[!] During the execution of HardeningKitty errors occurred due to missing admin rights or tools. Total errors: 50
[*] Your HardeningKitty score is: 2.86. HardeningKitty Statistics: Total checks: 388 - Passed: 59, Low: 11, Medium: 318, High: 0.
```

Cómo leerlo:

- Un equipo doméstico sin GPO tiene una puntuación baja contra una baseline empresarial: es lo esperado. Lo útil es la **lista de diferencias**, priorizada por severidad.
- Sin elevación, 50 comprobaciones (`secedit`, `auditpol`, `accesschk`) se **saltan**; para un resultado completo, ejecútalo como administrador en el servidor (sigue siendo solo lectura en modo Audit).
- Fíjate en el ID 10622: `Get-SmbServerConfiguration` dice que SMBv1 está desactivado, pero la baseline pide además el **valor de política explícito**, que no existe. Estado efectivo y política declarada son cosas distintas; la auditoría mide la segunda.
- HardeningKitty avisa si el sistema no está en `en-US`: algunas comprobaciones dependientes del idioma pueden dar falsos positivos.

### CIS-CAT

**CIS-CAT Lite** (gratuito, subconjunto de benchmarks) y **CIS-CAT Pro** (miembros de CIS SecureSuite) evalúan contra los CIS Benchmarks y generan un informe HTML con el porcentaje de cumplimiento por perfil (Level 1 / Level 2). No se ejecutó para esta nota.

## Errores comunes

- **Romper producción por endurecer sin probar**: aplicar la baseline completa (o HardeningKitty en modo HailMary) a todos los servidores a la vez. Restringir NTLM, exigir firma SMB o activar ASR en bloqueo puede tumbar aplicaciones antiguas, impresoras o agentes. Siempre: auditar → OU piloto → despliegue gradual con plan de vuelta atrás.
- Confundir **política** con **estado efectivo** (ver el caso SMBv1 de arriba) y no fijar explícitamente los valores críticos.
- Usar la misma contraseña de administrador local en todos los servidores en lugar de Windows LAPS.
- RDP expuesto a internet "solo temporalmente".
- Activar logging sin enviarlo a ningún sitio: los logs locales se borran (evento 1102) o se sobrescriben.
- Excepciones permanentes sin dueño ni fecha de revisión.
- Medir una sola vez: sin verificación periódica, el **configuration drift** (deriva de configuración) devuelve los valores inseguros.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Imágenes endurecidas, parches gestionados y acceso sin IP pública para VMs Windows | [Seguridad de máquinas virtuales](../../cloud/seguridad/seguridad-maquinas-virtuales.md), [Seguridad de identidades](../../cloud/seguridad/seguridad-identidades.md), [Seguridad de logging y detección](../../cloud/seguridad/seguridad-logging-deteccion.md) |
| DevOps (la automatización) | Aplicar la baseline como código y en golden images | [Configuration management con Ansible](../../devops/iac/ansible.md), [Hardening como código](hardening-como-codigo.md) |
| DevSecOps (la verificación) | Ciclo de hardening, otras plataformas, marcos y vulnerabilidades | [Fundamentos de hardening](fundamentos-hardening.md), [Hardening de Linux](hardening-linux.md), [Hardening de servicios](hardening-servicios.md), [Cumplimiento y gobierno](../gobierno-y-respuesta/cumplimiento.md), [CVE en Windows y Active Directory](../vulnerabilidades/cve-windows-active-directory.md), [Detección y respuesta](../gobierno-y-respuesta/deteccion-respuesta.md) |
| Networking (la base) | Segmentación, firewalls y acceso administrativo por bastión o VPN | [Seguridad de red](../../networking/avanzado/seguridad-red.md), [Puertos](../../recursos/puertos.md) |
| Laboratorios (la práctica) | El mismo ciclo medir → endurecer → medir, en Linux | [Lab 22: Endurecer un servidor Linux con Ansible y medirlo con Lynis y OpenSCAP](../../laboratorios/devsecops/hardening-linux-ansible.md) |
| Negocio TI (el porqué) | Excepciones como riesgo aceptado, con dueño y caducidad | [Gobierno y riesgo de TI](../../negocio/gobierno-riesgo-ti.md) |

## Referencias

- [Microsoft: Security baselines](https://learn.microsoft.com/es-es/windows/security/operating-system-security/device-management/windows-security-configuration-framework/windows-security-baselines)
- [Microsoft Security Compliance Toolkit](https://www.microsoft.com/en-us/download/details.aspx?id=55319)
- [Windows LAPS: introducción](https://learn.microsoft.com/es-es/windows-server/identity/laps/laps-overview)
- [Referencia de las ASR rules](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference)
- [Credential Guard](https://learn.microsoft.com/es-es/windows/security/identity-protection/credential-guard/)
- [Protección adicional de LSA](https://learn.microsoft.com/es-es/windows-server/security/credentials-protection-and-management/configuring-additional-lsa-protection)
- [Detectar, habilitar y deshabilitar SMBv1, SMBv2 y SMBv3](https://learn.microsoft.com/es-es/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3)
- [PowerShell: registro en Windows (about_Logging_Windows)](https://learn.microsoft.com/es-es/powershell/module/microsoft.powershell.core/about/about_logging_windows)
- [Advanced security audit policy settings](https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/advanced-security-audit-policy-settings)
- [Enterprise access model (modelo de acceso empresarial)](https://learn.microsoft.com/es-es/security/privileged-access-workstations/privileged-access-access-model)
- [CIS Microsoft Windows Server Benchmarks](https://www.cisecurity.org/benchmark/microsoft_windows_server)
- [CIS-CAT Pro y CIS-CAT Lite](https://www.cisecurity.org/cybersecurity-tools/cis-cat-pro)
- [DISA STIGs](https://public.cyber.mil/stigs/)
- [HardeningKitty (GitHub)](https://github.com/scipag/HardeningKitty)
