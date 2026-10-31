---
tags:
  - seguridad
  - cloud
  - aws
  - azure
  - gcp
  - computo
---

# Seguridad de máquinas virtuales

> Cómo endurecer y mantener seguras las VMs de Amazon EC2, Azure Virtual Machines y Compute Engine: imágenes endurecidas, parches, servicio de metadatos, discos cifrados, arranque verificado, acceso sin IP pública, agentes e inventario de vulnerabilidades.

!!! info "Antes de leer"
    Una VM es **IaaS**: según el [Shared Responsibility Model](../fundamentos/responsabilidad-compartida.md), el proveedor protege el hardware y el hipervisor, y **tú eres responsable del sistema operativo** (parches, configuración, usuarios), del software, de la red de la VM y de sus permisos. Conviene haber leído [Máquinas virtuales](../computo/maquinas-virtuales.md) (nombres de servicios, discos, metadatos) y [Seguridad de redes en la nube](seguridad-redes.md) (firewalls y acceso administrativo).

## Riesgos típicos

| Riesgo | Ejemplo o incidente conocido | Control que lo evita |
| --- | --- | --- |
| Robo de credenciales del servicio de metadatos vía **SSRF** (*Server-Side Request Forgery*) | Capital One (2019): un SSRF a través de un WAF mal configurado obtuvo credenciales de rol desde IMDSv1 y descargó datos de S3 | IMDSv2 obligatorio con hop limit 1; rol de la VM con permisos mínimos |
| Sistema operativo sin parchear | Explotación masiva de vulnerabilidades conocidas en servidores expuestos (ver [CVE de Linux y sistemas](../../devsecops/vulnerabilidades/cve-linux-sistemas.md)) | Patching automático con ventanas definidas; inventario de vulnerabilidades |
| VM con IP pública y SSH/RDP abiertos | Fuerza bruta y *credential stuffing* sobre RDP/SSH | Sin IP pública; acceso por Session Manager, Azure Bastion o IAP |
| Imagen base con configuración insegura o malware | AMIs/imágenes públicas de la comunidad con mineros o claves SSH dejadas dentro | Imágenes oficiales o CIS Hardened Images; *golden images* propias construidas en pipeline |
| Rootkits o bootkits | Malware que se carga antes del sistema operativo | Arranque verificado: NitroTPM + UEFI Secure Boot, Trusted Launch, Shielded VM |
| Discos o snapshots expuestos | Snapshots de EBS compartidos públicamente con datos sensibles | Cifrado con CMK, bloqueo público de snapshots e imágenes |
| VM con permisos excesivos | Service account por defecto con rol Editor o *scopes* completos en Compute Engine | Identidad dedicada por carga, least privilege |
| Claves SSH sin control | Claves de proyecto en metadatos que dan acceso a todas las VMs | OS Login / Entra ID login / EC2 Instance Connect; bloquear claves de proyecto |

## Controles por proveedor

| Prioridad | Control | AWS | Azure | Google Cloud |
| --- | --- | --- | --- | --- |
| **Imprescindible** | Servicio de metadatos protegido | IMDSv2 (`HttpTokens=required`), *instance metadata defaults* por cuenta y región | IMDS solo accesible desde la VM y con cabecera `Metadata: true` | Metadata server con cabecera `Metadata-Flavor: Google`; endpoints *legacy* desactivados |
| **Imprescindible** | Sin IP pública + acceso administrativo gestionado | Session Manager, EC2 Instance Connect Endpoint | Azure Bastion, JIT VM access | IAP TCP forwarding + OS Login |
| **Imprescindible** | Patching | AWS Systems Manager Patch Manager | Azure Update Manager | VM Manager (OS patch management) |
| **Imprescindible** | Discos cifrados | EBS encryption by default (por región), CMK en AWS KMS | SSE con PMK siempre activo; *encryption at host*; CMK con disk encryption sets | Cifrado por defecto; CMEK con Cloud KMS |
| **Imprescindible** | Identidad de la VM con permisos mínimos | IAM role (*instance profile*) | Managed identity | Service account dedicada (no la default), scope `cloud-platform` + IAM |
| **Imprescindible** | Vulnerabilidades e inventario | Amazon Inspector, SSM Inventory | Microsoft Defender for Servers (Defender Vulnerability Management, *agentless scanning*) | VM Manager (OS inventory), Security Command Center |
| Recomendado | Arranque verificado | NitroTPM + UEFI Secure Boot | Trusted Launch (Secure Boot + vTPM), confidential VMs | Shielded VM (Secure Boot, vTPM, integrity monitoring), Confidential VM |
| Recomendado | Imágenes endurecidas | CIS Hardened Images (AWS Marketplace), EC2 Image Builder | CIS Hardened Images (Azure Marketplace), Azure VM Image Builder, Azure Compute Gallery | CIS Hardened Images (Google Cloud Marketplace), imágenes personalizadas con Packer |
| Recomendado | Login con identidad de la nube | EC2 Instance Connect | Microsoft Entra ID login para VMs | OS Login (con 2FA opcional) |
| Recomendado | Detección en runtime y EDR | GuardDuty Runtime Monitoring, GuardDuty Malware Protection for EC2 | Defender for Servers con Microsoft Defender for Endpoint | VM Threat Detection (Security Command Center) |
| Recomendado | Bloqueo público de imágenes y snapshots | Block public access para AMIs y para EBS snapshots | Acceso a discos restringido (*network access policy*, sin exportación pública) | IAM en imágenes y snapshots (sin `allUsers`) |
| Recomendado | Consola serie desactivada | EC2 Serial Console desactivada a nivel cuenta | Serial console solo para administradores | Org policy `compute.disableSerialPortAccess` |

!!! note "Agentes que cambiaron"
    En Azure, el **Log Analytics agent (MMA)** se retiró en agosto de 2024: el agente vigente es **Azure Monitor Agent (AMA)**. Algunas recomendaciones antiguas aún lo mencionan. En AWS, Inspector escanea EC2 a través del **SSM Agent** o en modo *agentless* sobre snapshots; en Google Cloud, VM Manager usa el **OS Config agent**, incluido en la mayoría de imágenes públicas.

## Buenas prácticas

1. **Pregúntate primero si necesitas una VM.** Un servicio gestionado (contenedores, serverless, base de datos gestionada) te quita la responsabilidad del sistema operativo.
2. **Imagen dorada (*golden image*) construida en pipeline**: parte de una imagen oficial o CIS, aplica *hardening* (CIS Benchmark del sistema operativo), instala agentes, escanéala y publícala versionada. Las VMs no se parchean "a mano": se reemplazan o se parchean con el servicio gestionado. El proceso (Packer, roles de Ansible, verificación con Lynis/OpenSCAP) está en [Hardening como código](../../devsecops/hardening/hardening-como-codigo.md); los servicios de cada nube, en [Pipeline de imágenes](#pipeline-de-imagenes-golden-images).
3. **IMDSv2 / metadatos protegidos y hop limit 1.** En AWS, fija los *instance metadata defaults* de la cuenta para que toda instancia nueva exija token.
4. **Ninguna IP pública.** La VM vive en subnet privada; entra por Session Manager, Bastion o IAP y sale por NAT.
5. **Parches automáticos con ventanas y reportes de cumplimiento.** Define baselines (qué clasificaciones, cuántos días de espera) y revisa el estado de cumplimiento cada semana.
6. **Cifrado de disco con CMK donde lo exija el cumplimiento**, cifrado por defecto activado y bloqueo público de snapshots e imágenes (ver [Seguridad de cifrado y secretos](seguridad-cifrado-secretos.md)).
7. **Arranque verificado** en todas las VMs que lo soporten.
8. **Una identidad por carga de trabajo** con permisos mínimos; nunca claves de acceso dentro de la VM (ver [Seguridad de identidades](seguridad-identidades.md)).
9. **Agentes de seguridad y logs**: agente de gestión (SSM Agent, AMA, OS Config / Ops Agent), EDR y logs del sistema enviados a la plataforma central (ver [Seguridad de logging y detección](seguridad-logging-deteccion.md)).

=== "AWS"

    - `aws ec2 modify-instance-metadata-defaults --http-tokens required` (cambio de configuración, no de lectura) fija IMDSv2 para la región; además, Amazon Linux 2023 y muchas AMIs recientes ya se registran como "solo IMDSv2".
    - En nodos con contenedores (por ejemplo, EKS) un **hop limit de 1** impide que los pods lleguen al IMDS y roben las credenciales del nodo; úsalo cuando los pods tengan su propia identidad (EKS Pod Identity o IRSA).
    - Session Manager registra las sesiones en CloudWatch Logs o S3 y sustituye a los *bastion hosts* y a las claves SSH.
    - Activa el **cifrado EBS por defecto** en cada región que uses: no es global.

=== "Azure"

    - **Trusted Launch** es el tipo de seguridad por defecto para VMs Gen2 nuevas en las herramientas actuales; las VMs antiguas Gen1 no lo soportan.
    - **Encryption at host** cifra también discos temporales y cachés. Azure Disk Encryption (ADE, basada en BitLocker/DM-Crypt) está anunciada para retirarse; para VMs nuevas Microsoft recomienda *encryption at host*.
    - **Azure Update Manager** con `patchMode = AutomaticByPlatform` aplica parches críticos y de seguridad respetando la disponibilidad; con *maintenance configurations* defines tus ventanas.
    - **JIT VM access** (Defender for Servers Plan 2) abre el puerto solo por un tiempo y solo a la IP de quien lo pide; preferible a una regla permanente, aunque Bastion es aún mejor.

=== "Google Cloud"

    - No uses la **Compute Engine default service account**: históricamente recibe el rol Editor. Aplica la org policy `iam.automaticIamGrantsForDefaultServiceAccounts` y crea una service account por carga.
    - **Shielded VM** viene activado en la mayoría de imágenes públicas con vTPM e integrity monitoring, pero **Secure Boot está desactivado por defecto**: actívalo.
    - Activa **OS Login** (`enable-oslogin=TRUE`) para que el acceso SSH dependa de IAM y bloquea las claves SSH de proyecto.
    - Org policies útiles: `compute.vmExternalIpAccess`, `compute.requireOsLogin`, `compute.requireShieldedVm`, `compute.disableSerialPortAccess`.

## Pipeline de imágenes (golden images)

Para construir la *golden image* puedes usar Packer (ver [Hardening como código](../../devsecops/hardening/hardening-como-codigo.md#golden-images-con-packer-y-ansible)) o el builder gestionado de cada proveedor:

| | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Servicio | **EC2 Image Builder** | **Azure VM Image Builder** | No hay un builder gestionado equivalente: **Packer en Cloud Build** |
| Cómo se define | Image recipe + components (YAML de AWSTOE) + infrastructure y distribution configuration | Image template (JSON/Bicep) con customizers `Shell`, `PowerShell`, `File`, `WindowsUpdate` | `cloudbuild.yaml` que ejecuta el builder de comunidad de Packer |
| Hardening incluido | Componentes de **STIG** gestionados por Amazon; componentes **CIS** al suscribirte a una CIS Hardened Image del Marketplace | Plantilla de ejemplo con la Azure Windows security baseline; tus scripts o Ansible | Tus provisioners (Ansible, scripts) |
| Escaneo | Integración con Amazon Inspector durante el pipeline | Microsoft Defender for Cloud sobre las VMs creadas | Escaneo de la VM o de la imagen con tus herramientas en el pipeline |
| Publicación | AMI distribuida a regiones y cuentas (AWS RAM, Organizations) | **Azure Compute Gallery** (versiones y réplicas) | Compute Engine image, opcionalmente en una image family |
| Costo | El servicio no cobra; pagas la instancia de build, EBS, S3 e Inspector | Pagas la VM de build, el almacenamiento y la red | Pagas Cloud Build y la VM temporal |

=== "AWS"

    - Los **componentes** tienen fases `build`, `validate` y `test`: si un test falla, la imagen no se distribuye.
    - Una **CIS Hardened Image** del AWS Marketplace (con costo por hora) da acceso a un componente CIS Level 1 que se ejecuta al final de la receta, después de tus cambios.
    - Combínalo con una restricción de organización para lanzar solo AMIs aprobadas (ver [Gobernanza](../operacion-y-gobierno/gobernanza.md)).

=== "Azure"

    - VM Image Builder **usa Packer por debajo** y crea un resource group temporal `IT_<rg>_<plantilla>_<guid>` en tu suscripción.
    - Necesita una **user-assigned managed identity** con permisos para leer artefactos y escribir en la Compute Gallery.
    - Las **CIS Hardened Images** también están en Azure Marketplace.

=== "Google Cloud"

    - La guía oficial construye y publica en Artifact Registry el builder de comunidad de Packer y lo usa desde Cloud Build. La service account de Cloud Build necesita `Compute Instance Admin (v1)` y `Service Account User`.
    - Agrupa las imágenes en una **image family** para que las VMs usen siempre la última versión aprobada.
    - Las **CIS Hardened Images** están en Google Cloud Marketplace.

## Cómo verificarlo

Solo comandos de lectura.

=== "AWS"

    ```bash
    # IMDSv2, IP pública y rol de cada instancia
    aws ec2 describe-instances --query \
      "Reservations[].Instances[].{id:InstanceId,imds:MetadataOptions.HttpTokens,hop:MetadataOptions.HttpPutResponseHopLimit,ip:PublicIpAddress,perfil:IamInstanceProfile.Arn}" \
      --output table

    # Valores por defecto de la región
    aws ec2 get-instance-metadata-defaults
    aws ec2 get-ebs-encryption-by-default
    aws ec2 get-snapshot-block-public-access-state
    aws ec2 get-image-block-public-access-state

    # ¿Las instancias están gestionadas por Systems Manager y al día en parches?
    aws ssm describe-instance-information --query "InstanceInformationList[].{id:InstanceId,ping:PingStatus,agente:AgentVersion}"
    aws ssm list-compliance-summaries

    # Inspector activo y hallazgos críticos de EC2
    aws inspector2 batch-get-account-status
    aws inspector2 list-findings --filter-criteria \
      '{"resourceType":[{"comparison":"EQUALS","value":"AWS_EC2_INSTANCE"}],"severity":[{"comparison":"EQUALS","value":"CRITICAL"}]}' \
      --query "findings[].{titulo:title,recurso:resources[0].id}"
    ```

=== "Azure"

    ```bash
    # VMs con IP pública
    az vm list -d --query "[].{vm:name,rg:resourceGroup,ipPublica:publicIps}" -o table

    # Trusted Launch, Secure Boot, vTPM y encryption at host
    az vm show -g <rg> -n <vm> --query \
      "{tipo:securityProfile.securityType,secureBoot:securityProfile.uefiSettings.secureBootEnabled,vtpm:securityProfile.uefiSettings.vTpmEnabled,encAtHost:securityProfile.encryptionAtHost,parches:osProfile.linuxConfiguration.patchSettings.patchMode}"

    # Estado de parches de todas las VMs (Azure Update Manager vía Resource Graph)
    az graph query -q "patchassessmentresources | where type =~ 'microsoft.compute/virtualmachines/patchassessmentresults' | project id, properties.availablePatchCountByClassification"

    # Recomendaciones no cumplidas de Defender for Servers
    az security assessment list \
      --query "[?status.code=='Unhealthy' && contains(displayName, 'vulnerability findings')].{rec:displayName,recurso:resourceDetails.Id}" -o table
    ```

=== "Google Cloud"

    ```bash
    # IP externa, Secure Boot y service account de cada VM
    gcloud compute instances list --format="table(name,zone.basename(),networkInterfaces[].accessConfigs[0].natIP.list(),shieldedInstanceConfig.enableSecureBoot,serviceAccounts[].email.list())"

    # Metadatos de proyecto (OS Login, claves SSH de proyecto)
    gcloud compute project-info describe --format="yaml(commonInstanceMetadata.items)"

    # Inventario de paquetes y trabajos de parcheo
    gcloud compute os-config inventories list --location=<zona>
    gcloud compute os-config patch-jobs list

    # Hallazgos de Security Health Analytics sobre VMs
    gcloud scc findings list organizations/<org-id> --location=global \
      --filter='category="PUBLIC_IP_ADDRESS" AND state="ACTIVE"'
    ```

| Control | AWS Security Hub CSPM | Microsoft Defender for Cloud (MCSB) | Security Command Center (Security Health Analytics) |
| --- | --- | --- | --- |
| Metadatos protegidos | EC2.8 (IMDSv2), EC2.170 (launch templates), AutoScaling.3 | — | `LEGACY_METADATA_ENABLED` (nodos GKE) |
| Sin IP pública | EC2.9, EC2.25, Autoscaling.5 | *Internet-facing virtual machines should be protected with network security groups* | `PUBLIC_IP_ADDRESS` |
| Patching y gestión | SSM.1, SSM.2, SSM.3 | *System updates should be installed on your machines* | (VM Manager; OS config agent) |
| Vulnerabilidades | Inspector.1 | *Machines should have vulnerability findings resolved* | Hallazgos de vulnerabilidad de SCC |
| Cifrado de discos | EC2.3, EC2.7, EC2.181 | *Virtual machines and virtual machine scale sets should have encryption at host enabled*; *Linux/Windows virtual machines should enable Azure Disk Encryption or EncryptionAtHost* | `DISK_CMEK_DISABLED` (si exiges CMEK) |
| Snapshots públicos | EC2.1, EC2.182 | — | — |
| Arranque verificado | — | *Secure Boot should be enabled on supported Windows virtual machines*; *vTPM should be enabled on supported virtual machines*; *Guest Attestation extension should be installed…* | `SHIELDED_VM_DISABLED`, `COMPUTE_SECURE_BOOT_DISABLED` |
| Acceso SSH | — | *Authentication to Linux machines should require SSH keys* | `OS_LOGIN_DISABLED`, `COMPUTE_PROJECT_WIDE_SSH_KEYS_ALLOWED`, `COMPUTE_SERIAL_PORTS_ENABLED` |
| Identidad de la VM | — | — | `DEFAULT_SERVICE_ACCOUNT_USED`, `FULL_API_ACCESS` |

## Configuración segura con IaC

Los fragmentos de Terraform con estos controles (y los guardrails de organización, cuando aplican) están en las páginas por proveedor: [AWS](terraform/aws.md#maquinas-virtuales), [Azure](terraform/azure.md#maquinas-virtuales) y [Google Cloud](terraform/google-cloud.md#maquinas-virtuales).

## Errores comunes

- Exigir IMDSv2 en las instancias pero no en los **launch templates** o en la configuración por defecto: la próxima instancia vuelve a nacer con IMDSv1.
- Usar la service account por defecto de Compute Engine con scope "acceso completo a todas las APIs".
- Parchear "cuando haya tiempo", sin baseline ni reporte de cumplimiento.
- Instalar el agente de seguridad en la imagen pero no darle a la VM el rol o la red que necesita para reportar (por ejemplo, sin endpoints de SSM en una subnet privada).
- Dejar **snapshots** y **AMIs** compartidos públicamente o con cuentas externas que nadie revisa.
- Activar Shielded VM y dar por hecho que Secure Boot está encendido.
- Guardar claves de acceso a la nube en `~/.aws/credentials` dentro de la VM en vez de usar el rol de la instancia.
- Abrir RDP/SSH con JIT y olvidar que la regla queda permanente si se crea a mano fuera de JIT.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Servicio de VMs y sus opciones; red, identidad, cifrado y logs de la VM | [Máquinas virtuales](../computo/maquinas-virtuales.md), [Seguridad de redes](seguridad-redes.md), [Seguridad de identidades](seguridad-identidades.md), [Seguridad de cifrado y secretos](seguridad-cifrado-secretos.md), [Seguridad de logging y detección](seguridad-logging-deteccion.md) |
| DevOps (la automatización) | Construir *golden images* y configurar las VMs como código | [Ansible](../../devops/iac/ansible.md), [Terraform](../../devops/iac/terraform-basico.md), [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md) |
| DevSecOps (la verificación) | *Hardening* del sistema operativo con CIS, escaneo de IaC, vulnerabilidades del sistema operativo con SLA | [Fundamentos de hardening](../../devsecops/hardening/fundamentos-hardening.md), [Hardening de Linux](../../devsecops/hardening/hardening-linux.md), [Hardening de Windows](../../devsecops/hardening/hardening-windows.md), [Hardening como código](../../devsecops/hardening/hardening-como-codigo.md), [Cumplimiento y gobierno](../../devsecops/gobierno-y-respuesta/cumplimiento.md), [Seguridad de IaC](../../devsecops/infraestructura-y-contenedores/seguridad-iac.md), [CVE de Linux y sistemas](../../devsecops/vulnerabilidades/cve-linux-sistemas.md), [Detección y respuesta](../../devsecops/gobierno-y-respuesta/deteccion-respuesta.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 22: Endurecer un servidor Linux con Ansible y medirlo con Lynis y OpenSCAP](../../laboratorios/devsecops/hardening-linux-ansible.md) |

## Referencias

- [Security in Amazon EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-security.html)
- [Use IMDSv2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-IMDS-new-instances.html)
- [AWS Systems Manager Patch Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager.html)
- [Amazon Inspector](https://docs.aws.amazon.com/inspector/latest/user/what-is-inspector.html)
- [NitroTPM](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/nitrotpm.html)
- [Procedimientos recomendados de seguridad para cargas de trabajo IaaS en Azure](https://learn.microsoft.com/es-es/azure/security/fundamentals/iaas)
- [Trusted Launch para máquinas virtuales de Azure](https://learn.microsoft.com/es-es/azure/virtual-machines/trusted-launch)
- [Azure Update Manager](https://learn.microsoft.com/es-es/azure/update-manager/overview)
- [Microsoft Cloud Security Benchmark: postura y administración de vulnerabilidades](https://learn.microsoft.com/es-es/security/benchmark/azure/mcsb-posture-vulnerability-management)
- [Recomendaciones de proceso de Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/recommendations-reference-compute)
- [Compute Engine security best practices](https://cloud.google.com/compute/docs/security-best-practices)
- [Shielded VM](https://cloud.google.com/compute/shielded-vm/docs/shielded-vm)
- [VM Manager](https://cloud.google.com/compute/vm-manager/docs/overview)
- [OS Login](https://cloud.google.com/compute/docs/oslogin)
- [CIS Hardened Images](https://www.cisecurity.org/cis-hardened-images)
- [EC2 Image Builder](https://docs.aws.amazon.com/imagebuilder/latest/userguide/what-is-image-builder.html), [componentes de hardening STIG](https://docs.aws.amazon.com/imagebuilder/latest/userguide/ib-stig.html) y [componentes de hardening CIS](https://docs.aws.amazon.com/imagebuilder/latest/userguide/toe-cis.html)
- [Azure VM Image Builder](https://learn.microsoft.com/es-es/azure/virtual-machines/image-builder-overview)
- [Construir imágenes de VM con Packer en Cloud Build](https://cloud.google.com/build/docs/building/build-vm-images-with-packer)
