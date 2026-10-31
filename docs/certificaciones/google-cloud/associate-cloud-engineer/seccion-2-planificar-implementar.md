---
tags:
  - gcp
  - certificacion
  - ace
  - computo
  - redes
  - iac
---

# Sección 2: Planning and implementing a cloud solution (~30%)

> Cómo elegir y crear los recursos de una solución en Google Cloud: cómputo (Compute Engine, GKE, Cloud Run, Cloud Run functions), almacenamiento y bases de datos, redes y las herramientas de IaC e IA con las que se despliegan.

!!! info "Qué evalúa esta sección"
    Según la guía oficial vigente:

    - **2.1 Compute**: elegir entre Compute Engine, GKE, Cloud Run, Cloud Run functions y Agent Runtime; lanzar VMs (availability policy, SSH keys); elegir discos (zonal y regional Persistent Disk, Hyperdisk); MIG autoescalado con instance template; OS Login; VM Manager; Spot VMs y custom machine types; instalar `kubectl`; GKE Autopilot, regional y privado; desplegar en GKE y en serverless (eventos de Pub/Sub, Cloud Storage, Eventarc); GPUs o TPUs.
    - **2.2 Storage and data**: elegir y desplegar productos de datos y de almacenamiento, clases de Cloud Storage, carga de datos y redundancia multirregión.
    - **2.3 Networking**: VPC y subnets (custom mode, Shared VPC, VPC Network Peering), firewall rules y Cloud NGFW policies, Tags y service accounts en reglas, conectividad (Cloud VPN, Peering, Cloud Interconnect), load balancers y Network Service Tiers.
    - **2.4 Tooling**: IaC (Fabric FAST, Config Connector, Terraform, Helm) y herramientas de IA (Gemini CLI, Google Antigravity, Gemini Cloud Assist, Application Design Center).

    Formato y laboratorio en el [resumen del examen](resumen-examen.md).

## Elegir el cómputo

| Si el enunciado dice… | Elige |
| --- | --- |
| Control del sistema operativo, software con licencia por host, *lift and shift* | **Compute Engine** |
| Contenedores con necesidades de Kubernetes (StatefulSets, DaemonSets, operadores, Helm) | **GKE** (Autopilot por defecto) |
| Contenedor HTTP o *job* sin estado, escalar a cero, mínimo esfuerzo operativo | **Cloud Run** (services o jobs) |
| Código pequeño que reacciona a un evento (archivo subido, mensaje de Pub/Sub) | **Cloud Run functions** |
| Desplegar un agente de IA construido con un framework de agentes | **Agent Runtime** (Gemini Enterprise Agent Platform, antes Vertex AI Agent Engine) |

**App Engine** no aparece en la guía vigente: si una pregunta antigua pide "PaaS para una web sin gestionar servidores", hoy la respuesta es **Cloud Run**. Conceptos generales en [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md), [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md) y [Serverless](../../../cloud/computo/serverless.md).

## Compute Engine

### Machine types y modelos de pago

- **Machine families**: general-purpose (E2, N2, N4, C3, C4…), compute-optimized (C2, H3…), memory-optimized (M1–M3, X4), storage-optimized (Z3) y accelerator-optimized (A2, A3, G2…).
- **Custom machine types**: vCPU y memoria a medida (`--custom-cpu=6 --custom-memory=20GB`, en E2, N2, N2D, N4 y N1) cuando ningún tipo predefinido encaja.
- **Spot VMs**: hasta 60–91% más baratas; Google puede hacer **preemption** con 30 segundos de aviso. Sin duración máxima (las antiguas *preemptible VMs* duraban 24 horas como mucho).
- **Sustained use discounts** (automáticos en algunas series) y **committed use discounts** (CUD, 1 o 3 años).

### Availability policy y acceso SSH

| Opción | Valores |
| --- | --- |
| `--maintenance-policy` | `MIGRATE` (**live migration**, por defecto) o `TERMINATE` (obligatorio con GPUs en muchos tipos y con Spot) |
| `--restart-on-failure` | Reiniciar la VM si el host falla |
| `--provisioning-model` | `STANDARD` o `SPOT` (con `--instance-termination-action=STOP` o `DELETE`) |

| Acceso SSH | Cómo |
| --- | --- |
| **OS Login** (recomendado) | Acceso Linux ligado a IAM: metadata `enable-oslogin=TRUE` + `roles/compute.osLogin` (o `osAdminLogin` con sudo). Admite 2FA; se fuerza con `compute.requireOsLogin` |
| **Metadata SSH keys** | Claves públicas en la metadata del proyecto o la VM; difícil de auditar y revocar |
| **IAP TCP forwarding** | SSH a VMs **sin IP externa**: firewall desde `35.235.240.0/20` + rol **IAP-secured Tunnel User** |

**VM Manager** agrupa **OS patch management**, **OS inventory management** y **OS policies**; necesita el agente OS Config.

### Discos

| Opción | Cuándo |
| --- | --- |
| **Persistent Disk zonal** (`pd-balanced`, `pd-ssd`, `pd-standard`) | Uso general, en una zona |
| **Regional Persistent Disk** | Replicación síncrona entre **dos zonas**: HA de bases de datos autogestionadas |
| **Hyperdisk** (Balanced, Extreme, Throughput, ML, Balanced High Availability) | IOPS y throughput **configurables independientes del tamaño**; series como C4 y N4 solo admiten Hyperdisk |
| **Local SSD** | Disco físico efímero del host: caché o scratch; se pierde al detener la VM |

### Instance templates y managed instance groups

Un **managed instance group** (MIG) crea VMs idénticas desde un **instance template** (inmutable: para cambiarlo creas uno nuevo). Ofrece **autoscaling** (CPU, uso del load balancer, métricas de Monitoring o *schedules*), **autohealing** con health check, **rolling updates** (`max-surge`, `max-unavailable`) y puede ser **zonal** o **regional**.

```bash
gcloud compute instance-groups managed set-autoscaling web-mig --region=us-central1 \
  --min-num-replicas=2 --max-num-replicas=10 --target-cpu-utilization=0.65
gcloud compute instance-groups managed rolling-action start-update web-mig \
  --region=us-central1 --version=template=web-tpl-v3 --max-surge=3 --max-unavailable=0
```

!!! tip "En el examen"
    - "Escalar VMs según carga y reemplazar las que fallan" → **MIG + autoscaling + autohealing**. Un *unmanaged instance group* no escala ni se repara.
    - "Sobrevivir a la caída de una zona" → **regional MIG**.
    - "Batch barato que tolera interrupciones" → **Spot VMs**.
    - "La aplicación necesita 6 vCPU y 20 GB y los tipos predefinidos sobran" → **custom machine type**.

### GPUs y TPUs

**GPU** (NVIDIA L4, A100, H100…) para aceleración general (entrenamiento, inferencia, gráficos, HPC, CUDA), con machine types A2, A3, G2 o adjuntas a N1. **Cloud TPU** para entrenamiento e inferencia **a gran escala** (JAX, PyTorch/XLA, TensorFlow), como TPU VMs o node pools de GKE. Comprueba disponibilidad por zona y cuota.

## GKE

Lo básico de Kubernetes está en [Kubernetes](../../../devops/contenedores/kubernetes.md) y la comparación Autopilot/Standard en [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md#google-cloud). Lo que añade el examen:

| | **Autopilot** (recomendado) | **Standard** |
| --- | --- | --- |
| Nodes y pago | Los gestiona Google; pagas por **recursos que piden los Pods** | Node pools tuyos; pagas las VMs |
| Tipo de clúster | Siempre **regional** | Zonal o regional |
| Seguridad | Endurecido, Workload Identity Federation for GKE activado | Configurable |

Un **regional cluster** replica control plane y nodes en varias zonas (el zonal tiene un solo control plane). Un **private cluster** (`--enable-private-nodes`) tiene nodes sin IP pública, endpoint restringido con **authorized networks**, salida por **Cloud NAT** y requiere **VPC-native** (alias IP, por defecto).

```bash
gcloud components install kubectl gke-gcloud-auth-plugin
gcloud container clusters create-auto apps --region=us-central1 --enable-private-nodes
gcloud container clusters get-credentials apps --region=us-central1
```

!!! tip "En el examen"
    "Contenedores, Kubernetes y mínimo esfuerzo de operar nodes" → **Autopilot**. "Necesito DaemonSets privilegiados / tipo de nodo muy específico / control del SO" → **Standard**. `get-credentials` es lo que configura `kubectl` para hablar con el clúster.

## Cloud Run y Cloud Run functions

- **Services**: HTTP/gRPC, escalan según peticiones (incluso **a cero**); cada despliegue crea una **revision** inmutable.
- **Jobs**: tareas que terminan (batch, migraciones).
- **Cloud Run functions** (antes Cloud Functions): escribes la función y Google la empaqueta y despliega en Cloud Run.
- **Eventos**: **Eventarc** lleva eventos de Cloud Storage, Pub/Sub o Cloud Audit Logs a un servicio o función. Triggers y modelo de pago en [Serverless](../../../cloud/computo/serverless.md).

```bash
gcloud run deploy api --source=. --region=us-central1 --no-allow-unauthenticated
```

!!! tip "En el examen"
    - Un **Pub/Sub push subscription** también puede invocar Cloud Run directamente.
    - "Eventos de muchos servicios de Google Cloud con filtros" → **Eventarc**.
    - Traffic splitting y autoscaling de Cloud Run: [Sección 3](seccion-3-operacion-solucion.md#cloud-run-revisiones-trafico-y-autoscaling).

## Almacenamiento

Tipos de almacenamiento (object, block, file) comparados en [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md). En Google Cloud: **Cloud Storage** (objetos), **Persistent Disk / Hyperdisk** (bloques), **Filestore** (NFS gestionado, `ReadWriteMany` en GKE), **NetApp Volumes** (NFS/SMB empresarial) y **Managed Lustre** (HPC e IA).

### Cloud Storage: clases y ubicación

| Storage class | Acceso típico | Duración mínima | Costo de recuperación |
| --- | --- | --- | --- |
| **Standard** | Frecuente | Ninguna | No |
| **Nearline** | Menos de una vez al mes | **30 días** | Sí |
| **Coldline** | Menos de una vez al trimestre | **90 días** | Sí, mayor |
| **Archive** | Menos de una vez al año | **365 días** | Sí, el mayor |

Todas tienen **la misma latencia** (milisegundos) y durabilidad. **Autoclass** mueve objetos según su uso. La **location** puede ser **region**, **dual-region** o **multi-region**. Lifecycle y seguridad de objetos en la [Sección 3](seccion-3-operacion-solucion.md#cloud-storage-objetos-y-lifecycle).

**Cargar datos**: pocos archivos → `gcloud storage cp` (`gsutil cp` es heredado); copias grandes o programadas desde otra nube, URLs u on-premises → **Storage Transfer Service**; decenas o cientos de TB sin buen ancho de banda → **Transfer Appliance**; de Cloud Storage a BigQuery → `bq load` o tablas externas.

## Bases de datos y productos de datos

| Necesidad | Producto | Notas |
| --- | --- | --- |
| Relacional (MySQL, PostgreSQL, SQL Server) regional, app tradicional | **Cloud SQL** | HA con standby en otra zona; read replicas; hasta decenas de TB |
| PostgreSQL de alto rendimiento, transaccional + analítica | **AlloyDB for PostgreSQL** | Motor columnar para analítica |
| Relacional **global**, consistencia fuerte, escala horizontal, 99,999% | **Spanner** | Regional o multirregión |
| Documentos NoSQL para apps web y móviles, tiempo real | **Firestore** | Serverless, nativo o compatible con MongoDB |
| NoSQL wide-column, **baja latencia y enorme volumen** (IoT, series temporales) | **Bigtable** | API de HBase; row key crítica |
| **Data warehouse** con SQL, petabytes | **BigQuery** | Serverless; por bytes leídos o capacidad |

Otros: **Memorystore** (caché Valkey, Redis, Memcached), **Pub/Sub** (mensajería global, at-least-once, push o pull), **Managed Service for Apache Kafka** (sin cambiar clientes Kafka) y **Dataflow** (batch y streaming con Apache Beam, serverless).

**Redundancia multirregión**: Cloud Storage dual o multi-region; Spanner y Firestore multirregión; BigQuery en `US`/`EU` con **cross-region replication** opcional; Cloud SQL y AlloyDB con **cross-region read replicas** promovibles. Ver [Resiliencia](../../../cloud/operacion-y-gobierno/resiliencia.md).

## Redes: diseño

Los conceptos generales (VPC, subnets, firewall stateful, peering, VPN, Interconnect, load balancers) están en [Redes en la nube](../../../cloud/redes-y-datos/redes.md). Recuerda que en Google Cloud la **VPC es global** y las **subnets regionales**. La operación del día a día (ampliar subnets, IPs, rutas, NAT, DNS) está en la [Sección 3](seccion-3-operacion-solucion.md#operar-la-red).

### VPC y subnets

**Auto mode** crea una subnet por región en `10.128.0.0/9` (pruebas; puede solaparse con otras redes). **Custom mode**: tú creas cada subnet y su rango (**producción**).

```bash
gcloud compute networks create prod-vpc --subnet-mode=custom
gcloud compute networks subnets create prod-us --network=prod-vpc --region=us-central1 \
  --range=10.20.0.0/22 --enable-private-ip-google-access --enable-flow-logs
```

**Private Google Access** (por subnet) permite que VMs **sin IP externa** lleguen a APIs de Google.

### Compartir y conectar VPCs

| Opción | Cuándo |
| --- | --- |
| **Shared VPC** | Un **host project** comparte subnets con **service projects**; red administrada por un equipo central |
| **VPC Network Peering** | Conectar VPCs administradas por separado; **no transitivo**, rangos sin solapamiento |
| **Cloud VPN** (HA VPN, 99,99%) | Conexión rápida y barata por internet con on-premises u otra nube |
| **Cloud Interconnect** (Dedicated o Partner) | Mucho tráfico, latencia estable, sin internet |
| **Network Connectivity Center** | Hub-and-spoke con muchas VPCs y sitios |

!!! tip "En el examen"
    "Equipo de red central y proyectos de cada área usando la misma red" → **Shared VPC** (rol **Compute Network User** en las subnets para los service projects). "A está en peering con B y B con C; A no llega a C" → el peering **no es transitivo**.

### Firewall rules y Cloud NGFW policies

Cada VPC tiene dos **implied rules** de prioridad 65535 que no se borran: **deny all ingress** y **allow all egress**. Las reglas son **stateful**, con prioridad 0 (más alta) a 65535, y sus **targets** pueden ser todas las VMs, **network tags** o **service accounts**.

| Firewall policy (Cloud NGFW) | Se asocia a | Para qué |
| --- | --- | --- |
| **Hierarchical** | Organization o folder | Reglas obligatorias para todos; `goto_next` para delegar |
| **Global network** | Una VPC (todas las regiones) | Reglas con **secure Tags** gobernados por IAM, FQDN y geolocalización |
| **Regional network** | Una VPC en una región | Reglas por región |

Los **secure Tags** son mejores que los **network tags**: cambiarlos requiere permisos de IAM, mientras que un network tag lo añade quien edite la VM. **Cloud NGFW Standard** (FQDN, geolocalización, threat intelligence) y **Enterprise** (IPS) cuestan aparte.

```bash
gcloud compute firewall-rules create allow-web --network=prod-vpc --direction=INGRESS \
  --action=ALLOW --rules=tcp:80,tcp:443 --source-ranges=0.0.0.0/0 --target-tags=web
```

### Load balancers y Network Service Tiers

| Load balancer | Capa | Alcance | Ejemplo |
| --- | --- | --- | --- |
| **Application Load Balancer** externo global | L7 | Global, IP anycast | Web pública multirregión, Cloud CDN, Cloud Armor |
| **Application Load Balancer** regional / interno | L7 | Regional o cross-region interno | Microservicios internos |
| **Proxy Network Load Balancer** | L4 (TCP, SSL) | Global o regional | TCP con terminación TLS |
| **Passthrough Network Load Balancer** | L4 (TCP, UDP, ICMP…) | Regional | UDP, juegos, **preservar la IP de origen** |

**Network Service Tiers**: **Premium** (por defecto) usa la red global de Google desde cerca del usuario y admite balanceo global y regional; **Standard** viaja por internet público hasta la región, es más barato y **solo regional**.

## Herramientas: IaC e IA

| Herramienta | Cuándo |
| --- | --- |
| **Terraform** | IaC declarativo multicloud ([Terraform básico](../../../devops/iac/terraform-basico.md)) |
| **Infrastructure Manager** | Terraform gestionado por Google (estado, ejecuciones, previews); **sucesor de Deployment Manager** |
| **Fabric FAST** | Módulos de Terraform (Cloud Foundation Fabric) para montar una **landing zone** |
| **Config Connector** | Gestionar recursos de Google Cloud como **custom resources** de Kubernetes (`kubectl`, GitOps) |
| **Helm** | Charts para desplegar apps en GKE |
| **Gemini Cloud Assist** / **Gemini CLI** / **Google Antigravity** | Asistente de IA en la consola (diseño, incidencias, costos) / agente de IA en la terminal / IDE agéntico que implementa cambios de código |
| **Application Design Center** | Diseño visual con plantillas que generan Terraform y despliegan con Infrastructure Manager |

Lo que proponga la IA pasa por revisión y `terraform plan` ([Seguridad de IaC](../../../devsecops/infraestructura-y-contenedores/seguridad-iac.md)).

## Casos de uso

1. **Procesamiento nocturno de imágenes que puede reintentarse.** → MIG de **Spot VMs** o Cloud Run jobs.
2. **API en contenedor con tráfico irregular, sin equipo de operaciones.** → **Cloud Run** con escalado a cero y autenticación con IAM.
3. **Miniatura cada vez que se sube una foto a un bucket.** → **Cloud Run function** con trigger de Cloud Storage (Eventarc).
4. **Pedidos en América, Europa y Asia con consistencia fuerte.** → **Spanner** multirregión.
5. **Telemetría de millones de sensores por clave y tiempo.** → **Bigtable**.
6. **Auditoría que se guarda 7 años y casi nunca se lee.** → Cloud Storage **Archive** con retention policy.
7. **Varias áreas con proyectos propios y un equipo de red central.** → **Shared VPC**.
8. **Web global con TLS, CDN y protección DDoS.** → **Global external Application Load Balancer** + Cloud CDN + Cloud Armor en Premium Tier.
9. **VMs sin IP pública que leen Cloud Storage y actualizan paquetes.** → **Private Google Access** + **Cloud NAT**.
10. **Landing zone de una organización nueva como código.** → **Fabric FAST** o Terraform propio, con **Infrastructure Manager** o un pipeline.

## Preguntas de práctica

**1.** Una aplicación batch tolerante a fallos corre 6 horas cada noche. Quieres minimizar costos en Compute Engine. ¿Qué usas?

- A. Committed use discounts de 3 años
- B. Spot VMs en un managed instance group
- C. Sole-tenant nodes
- D. VMs `e2-micro`

??? success "Respuesta"
    **B.** Spot VMs son mucho más baratas y la carga tolera interrupciones; el MIG las recrea. A sirve para uso constante 24/7. C es para aislamiento o licencias por host. D probablemente no tenga la capacidad necesaria.

**2.** Necesitas un clúster de Kubernetes con el menor esfuerzo operativo, pagando por los recursos que piden los Pods. ¿Qué creas?

- A. `gcloud container clusters create` con node autoprovisioning
- B. `gcloud container clusters create-auto`
- C. Un MIG con kubeadm
- D. Cloud Run

??? success "Respuesta"
    **B.** Autopilot gestiona los nodes y factura por los recursos de los Pods. A es Standard (sigues pagando VMs). C es autogestionado. D no es Kubernetes.

**3.** Una VPC de producción debe permitir HTTPS desde internet solo a las VMs del frontend. ¿Cuál es la mejor regla?

- A. Ingress allow `tcp:443` desde `0.0.0.0/0` con target **todas las instancias**
- B. Ingress allow `tcp:443` desde `0.0.0.0/0` con target la **service account** del frontend
- C. Egress allow `tcp:443` hacia `0.0.0.0/0`
- D. Borrar la implied rule de deny ingress

??? success "Respuesta"
    **B.** Limita la regla a las VMs que corren con la service account del frontend (más difícil de cambiar que un network tag). A expone todas las VMs. C es de salida. D no se puede: las implied rules no se borran.

**4.** Necesitas una base de datos relacional para una aplicación con usuarios en tres continentes, escrituras en todos ellos y disponibilidad de 99,999%. ¿Qué eliges?

- A. Cloud SQL con read replicas
- B. Bigtable multirregión
- C. Spanner con configuración multirregión
- D. BigQuery

??? success "Respuesta"
    **C.** Spanner es relacional, global, con consistencia fuerte y SLA de 99,999% en multirregión. A solo escribe en la primaria. B no es relacional. D es analítico.

**5.** Dos VPCs en proyectos de equipos distintos deben comunicarse con IPs privadas, y cada equipo quiere administrar su red. ¿Qué usas?

- A. Shared VPC
- B. VPC Network Peering
- C. Cloud NAT
- D. Una firewall policy jerárquica

??? success "Respuesta"
    **B.** Peering conecta VPCs administradas por separado (sin solapamiento de rangos). A centraliza la administración en un host project. C es para salida a internet. D no conecta redes.

**6.** Guardas logs que se consultan una vez al trimestre durante una auditoría. ¿Qué clase de Cloud Storage es más rentable?

- A. Standard
- B. Nearline
- C. Coldline
- D. Archive

??? success "Respuesta"
    **C.** Coldline está pensada para acceso menor a una vez por trimestre (mínimo 90 días). Archive tiene menor costo de almacenamiento pero mayor costo de recuperación y está pensada para menos de una vez al año. Nearline es para acceso mensual.

**7.** Quieres usar Terraform en Google Cloud con un servicio gestionado que guarde el estado y ejecute los despliegues. ¿Qué eliges?

- A. Cloud Deployment Manager
- B. Infrastructure Manager
- C. Config Connector
- D. Cloud Build con estado local

??? success "Respuesta"
    **B.** Infrastructure Manager ejecuta Terraform de forma gestionada. A está retirado y usaba YAML/Jinja, no Terraform. C gestiona recursos desde Kubernetes, no Terraform. D pierde el estado entre ejecuciones.

## Para profundizar

- Cómputo: [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md), [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md), [Serverless](../../../cloud/computo/serverless.md), [Kubernetes](../../../devops/contenedores/kubernetes.md)
- Datos y redes: [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md), [Redes en la nube](../../../cloud/redes-y-datos/redes.md), [Balanceo y alta disponibilidad](../../../networking/avanzado/balanceo-alta-disponibilidad.md)
- IaC: [Infrastructure as Code](../../../devops/iac/infraestructura-como-codigo.md)
- Comandos: [gcloud](../../../recursos/comandos/google-cli.md), [kubectl](../../../recursos/comandos/kubectl.md), [Helm](../../../recursos/comandos/helm.md)

!!! example "Practica en el laboratorio"
    - [Lab 20: Google Cloud: desplegar un contenedor en Cloud Run](../../../laboratorios/cloud/gcp-cloud-run.md)

## Referencias

- [Choose a compute option (Google Cloud)](https://cloud.google.com/docs/choosing-a-compute-option)
- [Managed instance groups](https://cloud.google.com/compute/docs/instance-groups)
- [GKE Autopilot overview](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [Cloud Storage classes](https://cloud.google.com/storage/docs/storage-classes)
- [Cloud NGFW overview](https://cloud.google.com/firewall/docs/about-firewalls)
- [Choose a load balancer](https://cloud.google.com/load-balancing/docs/choosing-load-balancer)
