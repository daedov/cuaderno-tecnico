---
tags:
  - computo
  - aws
  - azure
  - gcp
---

# Máquinas virtuales: AWS, Azure y GCP

> Cómo se llaman, cómo se eligen y cómo se pagan las máquinas virtuales en Amazon EC2, Azure Virtual Machines y Google Compute Engine.

## ¿Qué es una máquina virtual en la nube?

Una **VM** (*virtual machine*, máquina virtual) es un servidor que corre sobre el hardware del proveedor. Tú eliges CPU, memoria, disco, red y sistema operativo, y el proveedor se encarga del centro de datos, el hardware y la virtualización.

Es el servicio **IaaS** por excelencia. Según el [Shared Responsibility Model](../fundamentos/responsabilidad-compartida.md), en una VM **tú gestionas** el sistema operativo (*patching*, *hardening*), el software instalado, la red (firewall, puertos abiertos) y los datos.

!!! note "Sobre los nombres en esta nota"
    Los servicios y opciones aparecen con el **nombre oficial que usa cada proveedor**, porque así se usan en el trabajo, en la documentación y en las certificaciones, junto con su traducción o una explicación en español.

### Términos que conviene conocer

| Término | Qué significa |
| --- | --- |
| **Burstable** (rendimiento con picos) | VM con un rendimiento de CPU base bajo que puede subir por momentos (*burst*, "ráfaga") usando créditos acumulados cuando estuvo poco usada |
| **Spot** | Capacidad sobrante del proveedor, mucho más barata, que el proveedor puede recuperar en cualquier momento |
| **On-demand** / **pay-as-you-go** | Pagar por el tiempo de uso, sin compromiso |
| **Rightsizing** | Ajustar el tamaño de la VM a lo que realmente usa, para no pagar de más |
| **Deallocate** | En Azure, liberar el hardware de una VM detenida para que deje de cobrarse el cómputo |
| **Live migration** | Mover una VM encendida a otro host sin reiniciarla |
| **BYOL** (*Bring Your Own License*) | Usar licencias propias (Windows Server, SQL Server) en la nube |

## Vista rápida

| | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Servicio | **Amazon EC2** | **Azure Virtual Machines** | **Compute Engine** |
| Nombre de una VM | Instance (instancia) | Virtual machine (máquina virtual) | VM instance (instancia de VM) |
| Tamaño de la VM | Instance type (tipo de instancia) | VM size (tamaño de VM) | Machine type (tipo de máquina) |
| Imagen del sistema | AMI (*Amazon Machine Image*) | Image (Azure Marketplace, Azure Compute Gallery) | Image (public image, custom image) |
| Disco principal | EBS volume (*Elastic Block Store*) | Managed disk | Persistent Disk / Hyperdisk |
| Grupo de VMs que escala solo | Auto Scaling group | Virtual Machine Scale Set (VMSS) | Managed instance group (MIG) |
| Plantilla para crear VMs | Launch template | Definida en el propio Scale Set | Instance template |
| Firewall | Security group | Network security group (NSG) | VPC firewall rules |
| Procesador ARM propio | AWS Graviton | Azure Cobalt | Google Axion |

## Familias de máquinas

Cada proveedor agrupa sus VMs según el uso para el que están pensadas. AWS las llama **instance families** (familias de instancias), Azure **VM series** (series de VM) y Google Cloud **machine families** (familias de máquinas).

| Uso | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| **General purpose** (uso general, equilibrio CPU/memoria) | General purpose: M, T | General purpose: D, B | General-purpose: E2, N2, N2D, N4, C3, C4 |
| **Burstable** | Burstable performance instances: T (`t3`, `t4g`) | B-series (burstable) | Shared-core machine types: `e2-micro`, `e2-small`, `e2-medium` |
| **Compute optimized** (más CPU por GB de memoria) | Compute optimized: C | Compute optimized: F | Compute-optimized: C2, C2D, H3 |
| **Memory optimized** (más memoria por vCPU) | Memory optimized: R, X | Memory optimized: E, M | Memory-optimized: M1, M2, M3, X4 |
| **Storage optimized** (disco local rápido) | Storage optimized: I, D | Storage optimized: L | Storage-optimized: Z3 |
| **Accelerated computing** (GPU y otros aceleradores) | Accelerated computing: P, G, Inf, Trn | GPU accelerated: NC, ND, NV | Accelerator-optimized: A2, A3, G2 |
| **HPC** (*High Performance Computing*, cómputo de alto rendimiento) | HPC optimized: Hpc | High performance compute: H | Compute-optimized: H3 |
| **ARM** | Graviton: familias con `g` (`m7g`, `c7g`, `t4g`) | Cobalt / Ampere: series con `p` (`Dpsv6`, `Epsv6`) | Axion / Ampere: C4A, T2A |

!!! info "Burstable en Google Cloud"
    Google Cloud no usa la palabra *burstable* como nombre de categoría: las llama **shared-core machine types** (comparten un núcleo físico con otras VMs) y explica que pueden hacer *bursting* de CPU por periodos cortos. En la práctica cumplen el mismo papel que la familia T de AWS y la serie B de Azure.

!!! tip "Para empezar"
    Para pruebas y cargas pequeñas, una VM **burstable** (`t3.micro` / `t4g.micro`, `B1s` / `B2ts_v2`, `e2-micro`) suele bastar y es la más barata. Para producción, empieza con **general purpose** y ajusta con *rightsizing* según lo que midas.

## Cómo leer los nombres

=== "AWS"

    ```text
    m7g.xlarge
    │││  └── size: nano, micro, small, medium, large, xlarge, 2xlarge…
    ││└───── atributos: g = Graviton (ARM), a = AMD, i = Intel, d = disco local NVMe, n = red mejorada
    │└────── generación: 7
    └─────── familia: m = general purpose
    ```

=== "Azure"

    ```text
    Standard_D4as_v5
             │││││ └── versión: v5
             ││││└──── s = admite Premium SSD
             │││└───── a = AMD (p = ARM, d = disco temporal local)
             ││└────── 4 vCPU
             │└─────── familia: D = general purpose
             └──────── tier: Standard
    ```

=== "Google Cloud"

    ```text
    n2-standard-4
    │   │        └── número de vCPU: 4
    │   └─────────── tipo: standard (4 GB/vCPU), highmem (8 GB/vCPU), highcpu (1 GB/vCPU)
    └─────────────── machine series: n2
    ```

!!! info "Custom machine types en Google Cloud"
    Google Cloud permite crear **custom machine types** (tipos de máquina personalizados): tú eliges exactamente cuántas vCPU y cuánta memoria quieres, por ejemplo `n2-custom-6-20480` (6 vCPU y 20 GB). En AWS y Azure solo se puede elegir entre tamaños fijos.

## Modelos de pago

| Modelo | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| **On-demand** (sin compromiso) | On-Demand Instances | Pay-as-you-go | On-demand |
| **Commitment** (compromiso de 1 o 3 años a cambio de descuento) | Savings Plans, Reserved Instances (RI) | Azure Reservations, Azure savings plan for compute | Committed use discounts (CUD) |
| **Descuento automático** por uso continuo | No existe | No existe | Sustained use discounts (SUD), en algunas series como N1 y N2 |
| **Spot** (capacidad sobrante que puede interrumpirse) | Spot Instances | Azure Spot Virtual Machines | Spot VMs (antes *preemptible VMs*) |
| Aviso antes de interrumpir una VM Spot | 2 minutos | 30 segundos | 30 segundos |
| **BYOL** (licencias propias de Windows Server/SQL Server) | BYOL en Dedicated Hosts | **Azure Hybrid Benefit** | BYOL en sole-tenant nodes |

- Las VMs **Spot** pueden costar hasta un 90 % menos, pero el proveedor puede recuperarlas en cualquier momento. Sirven para trabajos que toleran interrupciones: *batch processing* (procesamiento por lotes), CI/CD, renderizado. No para bases de datos ni servicios *stateful* (con estado).
- Los **Savings Plans**, **Reservations** y **CUD** dan descuentos importantes en cargas estables que están encendidas todo el tiempo.
- Azure suele ser la opción más barata para **cargas Windows** si la organización ya tiene licencias, gracias a Azure Hybrid Benefit.

!!! warning "Una VM detenida también cuesta"
    Al detener una VM deja de cobrarse el cómputo, pero **los discos, las IPs públicas reservadas y los *snapshots* (copias instantáneas de disco) siguen cobrándose**. En Azure, además, la VM tiene que quedar en estado **Stopped (deallocated)**: si solo se apaga el sistema operativo desde dentro, queda en *Stopped* y **se sigue pagando el cómputo**.

## Discos

| Tipo | AWS (EBS volume types) | Azure (Managed disk types) | Google Cloud (disk types) |
| --- | --- | --- | --- |
| HDD económico | Throughput Optimized HDD (`st1`), Cold HDD (`sc1`) | Standard HDD | Standard Persistent Disk (`pd-standard`) |
| SSD de uso general | **General Purpose SSD (`gp3`)** | Standard SSD, Premium SSD | **Balanced Persistent Disk (`pd-balanced`)**, Hyperdisk Balanced |
| SSD de alto rendimiento | Provisioned IOPS SSD (`io2` Block Express) | Premium SSD v2, Ultra Disk | SSD Persistent Disk (`pd-ssd`), Hyperdisk Extreme |
| Disco local temporal | Instance store | Temporary disk | Local SSD |

!!! danger "Los discos locales son temporales"
    El **instance store** de AWS, el **temporary disk** de Azure (normalmente `D:` en Windows o `/mnt` en Linux) y los **Local SSD** de GCP **pierden los datos** cuando la VM se detiene o cambia de host. Nunca guardes ahí datos que necesites conservar.

## High availability (alta disponibilidad) y scaling (escalado)

| | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Repartir VMs entre zonas | Availability Zones (AZ) | Availability zones | Zones |
| Repartir VMs dentro de una zona | Spread placement groups | Availability sets | Spread placement policies |
| Grupo de VMs que escala solo | Auto Scaling group + launch template | Virtual Machine Scale Set | Managed instance group + instance template |
| Load balancer (balanceador de carga) | Elastic Load Balancing (ALB, NLB) | Azure Load Balancer, Application Gateway | Cloud Load Balancing |

!!! info "Live migration en Google Cloud"
    Compute Engine hace **live migration**: durante el mantenimiento del hardware mueve las VMs a otro host **sin reiniciarlas**. En AWS y Azure el mantenimiento planificado puede requerir reiniciar o mover la VM, aunque se avisa con antelación.

## Acceso y seguridad

| | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| SSH/RDP sin abrir puertos a internet | Session Manager (AWS Systems Manager), EC2 Instance Connect Endpoint | Azure Bastion | Identity-Aware Proxy (IAP) TCP forwarding |
| Iniciar sesión con la identidad de la nube | EC2 Instance Connect | Microsoft Entra ID login | OS Login |
| Permisos de la VM hacia otros servicios | IAM role (*instance profile*) | Managed identity | Attached service account |
| Secure boot (arranque verificado) | NitroTPM, UEFI Secure Boot | Trusted Launch | Shielded VM |
| Confidential computing (memoria cifrada mientras se usa) | AWS Nitro Enclaves, AMD SEV-SNP | Azure confidential VMs | Confidential VM |
| Servicio de metadatos dentro de la VM | Instance Metadata Service (IMDS) | Azure Instance Metadata Service (IMDS) | Metadata server |

Para la parte de permisos, ver [IAM: AWS, Azure y GCP](../identidad-y-seguridad/iam-comparativa.md).

!!! tip "Instance metadata"
    En los tres proveedores, el servicio de metadatos responde en `169.254.169.254` desde dentro de la VM y es de donde la VM obtiene sus credenciales temporales. En AWS conviene exigir **IMDSv2** (con token) para evitar ataques **SSRF** (*Server-Side Request Forgery*) que roben esas credenciales.

## Free tier (capa gratuita)

Las condiciones cambian a menudo, así que conviene revisarlas antes de crear recursos:

- **AWS Free Tier**: las cuentas nuevas reciben créditos durante los primeros meses y tienen acceso a instancias pequeñas (`t3.micro`, `t4g.micro`).
- **Azure free account**: créditos para el primer mes y 750 horas al mes de VMs B-series pequeñas durante 12 meses.
- **Google Cloud Free Program**: créditos de *Free Trial* para nuevos clientes y una VM `e2-micro` dentro del *Free Tier* (siempre gratuita) en algunas regiones de EE. UU.

## Comandos básicos

| Comando | Descripción |
| --- | --- |
| `aws ec2 describe-instances` | Listar instances de EC2 |
| `aws ec2 start-instances --instance-ids <id>` | Encender una instance |
| `aws ec2 stop-instances --instance-ids <id>` | Detener una instance |
| `az vm list -o table` | Listar VMs de Azure |
| `az vm start -g <resource-group> -n <vm>` | Encender una VM |
| `az vm deallocate -g <resource-group> -n <vm>` | Detener y hacer *deallocate* de una VM (deja de cobrarse el cómputo) |
| `gcloud compute instances list` | Listar VM instances de Compute Engine |
| `gcloud compute instances start <vm> --zone <zona>` | Encender una VM |
| `gcloud compute instances stop <vm> --zone <zona>` | Detener una VM |
| `gcloud compute ssh <vm> --tunnel-through-iap` | Conectarse por SSH a través de IAP |

## Con Terraform

El recurso principal para crear una VM en cada proveedor (ver [Terraform](../../devops/iac/terraform-basico.md)):

| Proveedor | Recurso |
| --- | --- |
| AWS | `aws_instance` |
| Azure | `azurerm_linux_virtual_machine` / `azurerm_windows_virtual_machine` |
| Google Cloud | `google_compute_instance` |

!!! note "En Azure una VM necesita más piezas"
    En Azure la VM, la network interface (NIC), la public IP address y el managed disk son **recursos separados** dentro de un **resource group**. En AWS y GCP la interfaz de red se crea junto con la instance.

## Conclusión práctica

- Las tres ofrecen prácticamente lo mismo: elige según **dónde está el resto de tu infraestructura** y las **licencias** que ya tiene la organización.
- Empieza con una VM pequeña **general purpose** o **burstable**, mide el uso real de CPU y memoria y haz *rightsizing* (ajusta el tamaño).
- Usa **Spot** para cargas que toleran interrupciones, y **Savings Plans / Reservations / CUD** solo para lo que esté encendido de forma estable.
- Considera los procesadores **ARM** (Graviton, Cobalt, Axion): suelen dar mejor precio por rendimiento si tu software es compatible.
- Antes de crear una VM, pregúntate si un *managed service* (servicio gestionado: [contenedores](contenedores-gestionados.md), [serverless](serverless.md), [base de datos gestionada](../redes-y-datos/almacenamiento-datos.md)) te ahorra administrar el sistema operativo.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Alternativas de cómputo; red y firewall de la VM; permisos; costos y alta disponibilidad | [Contenedores gestionados](contenedores-gestionados.md), [Serverless](serverless.md), [Redes en la nube](../redes-y-datos/redes.md), [IAM](../identidad-y-seguridad/iam-comparativa.md), [FinOps y costos](../fundamentos/finops-costos.md), [Resiliencia](../operacion-y-gobierno/resiliencia.md) |
| DevOps (la automatización) | Crear VMs con IaC, configurarlas con Ansible y desplegar sobre ellas | [Terraform](../../devops/iac/terraform-basico.md), [Ansible](../../devops/iac/ansible.md), [Linux, redes y scripting](../../devops/fundamentos/linux-redes-scripting.md), [Despliegue continuo](../../devops/ci-cd/despliegue-continuo.md) |
| DevSecOps (la verificación) | *Hardening* con CIS Benchmarks, reglas abiertas a internet, IMDSv2 | [Cumplimiento y gobierno](../../devsecops/gobierno-y-respuesta/cumplimiento.md), [Seguridad de IaC](../../devsecops/infraestructura-y-contenedores/seguridad-iac.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 17: AWS: VPC con subnets públicas y privadas y una EC2](../../laboratorios/cloud/aws-vpc-ec2.md), [Lab 19: Azure: VNet, NSG y una VM con Azure CLI](../../laboratorios/cloud/azure-vnet-vm.md) |

## Referencias

- [Amazon EC2 instance types](https://aws.amazon.com/es/ec2/instance-types/)
- [Amazon EC2 instance type naming conventions](https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html)
- [Tamaños de máquinas virtuales en Azure](https://learn.microsoft.com/es-es/azure/virtual-machines/sizes/overview)
- [Convenciones de nomenclatura de tamaños de VM en Azure](https://learn.microsoft.com/es-es/azure/virtual-machines/vm-naming-conventions)
- [Compute Engine machine families](https://cloud.google.com/compute/docs/machine-resource)
- [Compute Engine shared-core machine types](https://cloud.google.com/compute/docs/general-purpose-machines#sharedcore)
- [Spot VMs en Google Cloud](https://cloud.google.com/compute/docs/instances/spot)
- [Comparación de servicios de AWS y Azure](https://learn.microsoft.com/es-es/azure/architecture/aws-professional/)
- [Comparación de servicios de Google Cloud con AWS y Azure](https://cloud.google.com/docs/get-started/aws-azure-gcp-service-comparison)
