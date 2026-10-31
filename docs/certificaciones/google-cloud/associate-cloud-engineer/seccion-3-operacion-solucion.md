---
tags:
  - gcp
  - certificacion
  - ace
  - observabilidad
  - kubernetes
---

# Sección 3: Ensuring the successful operation of a cloud solution (~30%)

> El día a día después del despliegue: operar VMs, GKE y Cloud Run, gestionar almacenamiento y bases de datos (backups, consultas, CMEK), mantener la red y vigilar todo con Cloud Monitoring y Cloud Logging.

!!! info "Qué evalúa esta sección"
    Según la guía oficial vigente:

    - **3.1 Managing compute resources**: conectarse a VMs, ver instancias, snapshots e images (y programar snapshots), inventario de GKE, acceso de GKE a Artifact Registry, node pools, recursos de Kubernetes (Pods, Services, StatefulSets), HPA y VPA, resource requests en Autopilot, nuevas versiones y traffic splitting en Cloud Run (y Cloud Run functions, GKE), autoscaling de Cloud Run, GPUs y TPUs, desplegar un agente en Agent Runtime, notebooks en Workbench y BigQuery, Cloud Workstations.
    - **3.2 Managing storage and data solutions**: seguridad de objetos, lifecycle, consultas, estimar costos, backups y restauración, estado de jobs (Dataflow, BigQuery), Database Center, CMEK.
    - **3.3 Managing networking resources**: ampliar el rango de una subnet, reservar IPs estáticas, rutas estáticas, Cloud DNS, Cloud NAT, firewall rules y Cloud NGFW policies.
    - **3.4 Monitoring and logging**: alertas, métricas personalizadas, audit logs, VPC Flow Logs y firewall logs, exportar logs, log buckets, Log Analytics y log router, filtrar logs, Cloud Trace, Cloud Profiler, Query Insights, Personalized Service Health, Ops Agent, Managed Service for Prometheus, Gemini Cloud Assist, Active Assist y Cloud Hub.

    Formato y laboratorio en el [resumen del examen](resumen-examen.md).

## Operar Compute Engine

Para cambiar el machine type (`set-machine-type`), la VM debe estar **detenida**. Una VM detenida no cobra cómputo, pero **sí discos e IPs estáticas reservadas**. Para conectarte sin IP externa: `gcloud compute ssh --tunnel-through-iap` ([Sección 2](seccion-2-planificar-implementar.md#availability-policy-y-acceso-ssh)).

### Snapshots e images

| | **Snapshot** | **Image** (custom image) | **Machine image** |
| --- | --- | --- | --- |
| Qué copia | Un disco, de forma **incremental** | Un disco de arranque, para crear VMs nuevas | Toda la VM: discos, metadata, configuración |
| Uso típico | Backup y restauración | "Golden image" en instance templates | Clonar o respaldar una VM completa |
| Ámbito | Global (restaurable en otra región) | Global; se agrupan en **image families** | Global |

```bash
gcloud compute resource-policies create snapshot-schedule diario \
  --region=us-central1 --start-time=04:00 --daily-schedule --max-retention-days=14
gcloud compute disks add-resource-policies web-1 --zone=us-central1-a --resource-policies=diario
```

!!! tip "En el examen"
    "Backups automáticos diarios de los discos" → **snapshot schedule** (resource policy) adjunto al disco. "Crear VMs nuevas siempre con la última versión de la imagen" → **image family**. "Mover una VM a otra zona" → snapshot (o machine image) y crear la VM en la zona nueva.

## Operar GKE

Objetos de Kubernetes (Deployment, StatefulSet, Service, Ingress, DaemonSet) en [Kubernetes](../../../devops/contenedores/kubernetes.md); comandos de inventario y rollout (`kubectl get`, `describe`, `logs`, `rollout undo`) en la [chuleta de kubectl](../../../recursos/comandos/kubectl.md). Para el examen: **StatefulSet** = Pods con identidad y disco propio; **DaemonSet** = un Pod por node (limitado en Autopilot).

**Artifact Registry** (Container Registry está retirado): para descargar imágenes de un repositorio **privado**, la service account de los nodes necesita **Artifact Registry Reader** (`roles/artifactregistry.reader`).

### Node pools y autoscaling

En **GKE Standard** los nodes van en **node pools**. Para cambiar el machine type se crea un pool nuevo, se migran los Pods y se borra el viejo.

```bash
gcloud container node-pools create highmem --cluster=batch --zone=us-central1-a \
  --machine-type=n2-highmem-4 --num-nodes=1 --enable-autoscaling --min-nodes=0 --max-nodes=4
gcloud container clusters resize batch --node-pool=default-pool --num-nodes=2 --zone=us-central1-a
```

| Escalado | Qué escala | Cómo |
| --- | --- | --- |
| **Horizontal Pod Autoscaler** (HPA) | Número de Pods | CPU, memoria o métricas: `kubectl autoscale deploy api --cpu-percent=60 --min=2 --max=10` |
| **Vertical Pod Autoscaler** (VPA) | Requests de CPU y memoria | Recomienda o ajusta; `--enable-vertical-pod-autoscaling` en el clúster |
| **Cluster autoscaler** | Nodes de un pool | `--enable-autoscaling` en el node pool (en Autopilot lo hace Google) |

!!! warning "Autopilot y resource requests"
    En **Autopilot** pagas por los **requests** de los Pods; Google ajusta valores fuera de rango y aplica valores por defecto si no los defines. Requests altos son dinero desperdiciado; bajos causan expulsiones o throttling. Para GPUs o hardware específico usa **ComputeClasses** o `nodeSelector`.

## Cloud Run: revisiones, tráfico y autoscaling

Cada despliegue crea una **revision**. Puedes desplegarla **sin tráfico**, probarla con una URL con **tag** y moverle tráfico de a poco (*canary*).

```bash
gcloud run deploy api --image=us-central1-docker.pkg.dev/app-prod-4821/apps/api:1.5.0 \
  --region=us-central1 --no-traffic --tag=candidata
gcloud run services update-traffic api --region=us-central1 --to-tags=candidata=10
gcloud run services update-traffic api --region=us-central1 --to-revisions=api-00041-xoz=100   # rollback
```

| Parámetro | Efecto |
| --- | --- |
| `--min-instances` | Instancias siempre listas: evita **cold starts**, pero cobra aunque no haya tráfico |
| `--max-instances` | Tope de escalado: protege presupuesto y bases de datos de abajo |
| `--concurrency` | Peticiones simultáneas por instancia (por defecto 80); bajarla escala antes |

El traffic splitting también existe en **Cloud Run functions** y en **GKE** (Gateway API o service mesh). Estrategias en [Despliegue continuo](../../../devops/ci-cd/despliegue-continuo.md).

## IA, aceleradores y entornos de desarrollo

- **GPUs en una VM**: detenida, `--maintenance-policy=TERMINATE` y machine type compatible (`--accelerator=type=nvidia-l4,count=1` o G2/A3). En GKE, node pools con GPU o TPU.
- **Agent Runtime** (antes Vertex AI Agent Engine): despliegas un agente (por ejemplo con Agent Development Kit) con el SDK; Google gestiona escalado, sesiones y memoria.
- **Workbench**: JupyterLab gestionado; los notebooks también se crean en **BigQuery Studio**.
- **Cloud Workstations**: entornos de desarrollo gestionados definidos por **configurations** que controla el equipo de plataforma.

## Cloud Storage: objetos y lifecycle

| Mecanismo | Uso |
| --- | --- |
| **Uniform bucket-level access** | Permisos solo con IAM a nivel de bucket (recomendado); desactiva las ACLs por objeto |
| **Public access prevention** | Impide que el bucket o sus objetos se hagan públicos |
| **Signed URLs** | Acceso temporal a un objeto sin cuenta de Google |
| **Object Versioning** | Guarda versiones anteriores al sobrescribir o borrar |
| **Retention policy** / **Bucket Lock** | Impide borrar antes de cierto tiempo (cumplimiento, WORM) |
| **Soft delete** | Recuperar objetos borrados (7 días por defecto) |
| **CMEK** | Cifrado con claves propias de Cloud KMS |

```json title="lifecycle.json"
{
  "rule": [
    {"action": {"type": "SetStorageClass", "storageClass": "NEARLINE"}, "condition": {"age": 30}},
    {"action": {"type": "Delete"}, "condition": {"age": 2555}}
  ]
}
```

Se aplica con `gcloud storage buckets update gs://BUCKET --lifecycle-file=lifecycle.json`. Concepto de lifecycle en [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md#object-storage).

!!! tip "En el examen"
    - "Mover a una clase más barata después de N días" o "borrar después de N días" → **lifecycle rule** (no un script con cron).
    - "Compartir un archivo temporalmente con alguien sin cuenta de Google" → **signed URL**.
    - "Nadie, ni un admin, puede borrar durante 7 años" → **retention policy con Bucket Lock**.

## Bases de datos: consultas, backups y costos

- `bq query --dry_run` muestra **cuántos bytes leería** una consulta: en on-demand pagas por bytes, así que estima el costo antes de ejecutar. Para el resto, **Pricing Calculator**.
- Estado de jobs: `bq ls -j` (BigQuery) y `gcloud dataflow jobs list` (Dataflow).
- **Database Center**: vista única de toda la flota de bases de datos (inventario, salud, recomendaciones, Gemini). **Query Insights** e **index advisor** (Cloud SQL y AlloyDB) encuentran consultas lentas y proponen índices.

| Producto | Backup | Restauración |
| --- | --- | --- |
| **Cloud SQL** | Automáticos y bajo demanda; **point-in-time recovery** (PITR) | `gcloud sql backups restore` sobre una instancia (sobrescribe) o clonar a un momento |
| **AlloyDB** | Continuos (PITR) y bajo demanda | Clúster nuevo |
| **Spanner** | Backups y **PITR** (versiones hasta 7 días) | Base nueva |
| **Firestore** | Programados, PITR, export/import a Cloud Storage | Base nueva |
| **Bigtable** | Backups de tablas | Tabla nueva |

### CMEK

Con **CMEK** (*customer-managed encryption keys*) usas una clave de **Cloud KMS** que tú controlas (rotación, deshabilitación, auditoría); concepto en [Seguridad de cifrado y secretos](../../../cloud/seguridad/seguridad-cifrado-secretos.md#envelope-encryption-y-modelos-de-clave). Lo que más se olvida: dar a la **service agent** del servicio el rol **Cloud KMS CryptoKey Encrypter/Decrypter** sobre la clave, y crear la clave en la **misma ubicación** que el recurso.

## Operar la red

El diseño (VPC, firewall, load balancers) está en la [Sección 2](seccion-2-planificar-implementar.md#redes-diseno); aquí, las tareas del día a día.

```bash
gcloud compute networks subnets expand-ip-range prod-us --region=us-central1 --prefix-length=21
gcloud compute addresses create web-ip --region=us-central1      # IP externa estática regional
gcloud compute routers nats create nat-us --router=nat-router --region=us-central1 \
  --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges
gcloud dns managed-zones create interna --dns-name="interno.ejemplo.com." \
  --visibility=private --networks=prod-vpc --description="Zona interna"
```

Las **rutas estáticas** (`gcloud compute routes create`) envían un rango (por ejemplo, on-premises) a un next hop como una VM appliance. Para depurar firewall: **firewall rules logging** y **Connectivity Tests** ([Troubleshooting de red](../../../networking/avanzado/troubleshooting-red.md)).

!!! tip "En el examen"
    - "La subnet se quedó sin IPs" → `expand-ip-range` (sin downtime), siempre que el nuevo rango no se solape. Solo se agranda, nunca se reduce.
    - "La IP pública cambia al reiniciar la VM" → **reservar una IP estática**. Una IP reservada **sin usar** también cobra.
    - "VMs privadas necesitan descargar parches" → **Cloud NAT** (solo salida).
    - "Nombres internos que no se vean desde internet" → **Cloud DNS private zone**.

## Cloud Monitoring

Conceptos de métricas, logs, trazas y alarmas en [Observabilidad nativa](../../../cloud/operacion-y-gobierno/observabilidad-nativa.md). Lo propio de Google Cloud:

- **Metrics scope**: un proyecto central ve métricas de hasta cientos de proyectos.
- **Alerting policies**: condición (umbral, ausencia de datos, PromQL) + **notification channels** (correo, SMS, Slack, PagerDuty, Pub/Sub, webhooks). **Uptime checks** desde varias ubicaciones.
- **Custom metrics**: desde la app (OpenTelemetry o API, prefijo `custom.googleapis.com/`) o **log-based metrics** (`gcloud logging metrics create` con un filtro).
- **Ops Agent**: métricas y logs del SO y de apps en Compute Engine. Sin él solo ves métricas del hipervisor, **no memoria ni uso del disco** desde dentro.
- **Managed Service for Prometheus**: métricas Prometheus (integrado en GKE) consultadas con PromQL.

## Cloud Logging

- **Log Router**: envía cada log según los **sinks** (filtros de inclusión y exclusión).
- **Log buckets**: `_Required` (Admin Activity, System Event, Access Transparency; **400 días**, fijo), `_Default` (lo demás, 30 días por defecto, configurable) y buckets propios. Con **Log Analytics** se consultan con SQL.
- **Destinos de un sink**: Cloud Storage (archivo barato), BigQuery (análisis), Pub/Sub (SIEM, sistemas externos), otro log bucket u otro proyecto. Los **aggregated sinks** en la organización o un folder (`--include-children`) recogen todos los proyectos.
- Tras crear el sink, da a su **writer identity** permiso de escritura en el destino.

```bash
gcloud logging sinks create audit-a-bq \
  bigquery.googleapis.com/projects/seguridad-central/datasets/audit_logs \
  --organization=123456789012 --include-children \
  --log-filter='logName:"cloudaudit.googleapis.com"'
gcloud logging read 'resource.type="gce_instance" AND severity>=ERROR' --limit=20
```

### Audit logs, VPC Flow Logs y firewall logs

| Log | Se activa | Qué registra |
| --- | --- | --- |
| **Admin Activity audit logs** | Siempre, gratis, no se desactivan | Cambios de configuración ("quién creó o borró qué") |
| **System Event audit logs** | Siempre | Acciones de Google sobre tus recursos (live migration…) |
| **Data Access audit logs** | **Desactivados por defecto** (salvo BigQuery); por servicio en la configuración de auditoría de IAM | Lecturas de datos y configuración; mucho volumen y costo |
| **Policy Denied audit logs** | Por defecto (excluibles en el sink) | Accesos denegados por políticas (p. ej., VPC Service Controls) |
| **VPC Flow Logs** | Por subnet (`--enable-flow-logs`) | Muestra de flujos de red |
| **Firewall Rules Logging** | Por regla (`--enable-logging`) | Conexiones permitidas o denegadas por esa regla |

### Diagnóstico y salud

| Herramienta | Para qué |
| --- | --- |
| **Cloud Trace** / **Cloud Profiler** / **Error Reporting** | Latencia entre servicios / CPU y memoria por función / agrupar excepciones |
| **Personalized Service Health** | Incidentes de Google Cloud que **afectan a tus proyectos**, con alertas |
| **Active Assist** (Recommender) | VMs inactivas, rightsizing, IPs y discos sin usar, roles excesivos |
| **Cloud Hub** | Vista central de incidentes, mantenimientos, salud de App Hub y alertas |
| **Gemini Cloud Assist** | Investigaciones con IA y ayuda para consultas y alertas |

!!! tip "En el examen"
    - "Ver memoria de la VM" → instalar **Ops Agent**.
    - "Guardar audit logs varios años de forma barata" → **sink a Cloud Storage** (con lifecycle a Archive).
    - "Analizar logs con SQL" → sink a **BigQuery** o log bucket con **Log Analytics**.
    - "Enviar logs a un SIEM on-premises" → sink a **Pub/Sub**.
    - "Auditar quién **leyó** datos de un bucket" → activar **Data Access audit logs** para Cloud Storage.
    - "Alerta si aparece un error concreto en los logs" → **log-based metric** + alerting policy (o una log-based alert).

## Casos de uso

1. **Restaurar una VM al estado de ayer tras una actualización fallida.** → Disco desde el snapshot programado y VM nueva con él.
2. **Probar una nueva versión en Cloud Run con el 5% de los usuarios.** → `--no-traffic --tag`, luego `update-traffic --to-tags=tag=5` y subir gradualmente.
3. **App en GKE con picos diarios.** → HPA + cluster autoscaler en el node pool (o Autopilot).
4. **Subnet `/24` sin IPs.** → `expand-ip-range` a `/23` o `/22`.
5. **Audit logs de toda la organización en un lugar durante 5 años.** → Aggregated sink a Cloud Storage con retention policy.
6. **Saber cuánto cuesta una consulta de BigQuery antes de ejecutarla.** → `bq query --dry_run`.
7. **La empresa debe controlar y poder revocar las claves de un bucket.** → CMEK con Cloud KMS + permiso a la service agent de Cloud Storage.
8. **Ver incidentes de Google Cloud que afectan a tus proyectos.** → **Personalized Service Health**.

## Preguntas de práctica

**1.** Necesitas que una API en Cloud Run responda sin cold starts en horario laboral. ¿Qué ajustas?

- A. `--concurrency=1`
- B. `--min-instances` mayor que 0
- C. `--max-instances=1`
- D. Un HPA

??? success "Respuesta"
    **B.** Las instancias mínimas quedan calientes (cobran aunque no haya tráfico). A hace escalar más, no evita cold starts. C limita el escalado. D es de Kubernetes, no de Cloud Run.

**2.** En Cloud Monitoring no ves el uso de memoria de tus VMs de Compute Engine. ¿Qué haces?

- A. Activar VPC Flow Logs
- B. Instalar el Ops Agent en las VMs
- C. Activar Data Access audit logs
- D. Crear un uptime check

??? success "Respuesta"
    **B.** La memoria se mide desde dentro del sistema operativo con el Ops Agent. A son flujos de red. C son lecturas de datos. D mide disponibilidad externa.

**3.** Seguridad pide conservar los audit logs de todos los proyectos de la organización 7 años al menor costo. ¿Qué configuras?

- A. Aumentar la retención del bucket `_Default` de cada proyecto a 7 años
- B. Un aggregated sink a nivel de organización hacia Cloud Storage con lifecycle a Archive
- C. Un sink por proyecto hacia BigQuery
- D. Exportar manualmente cada mes con `gcloud logging read`

??? success "Respuesta"
    **B.** Un aggregated sink con `--include-children` captura todos los proyectos, y Cloud Storage Archive es lo más barato para retener años. A es más caro y proyecto por proyecto. C funciona pero cuesta más y es más trabajo. D es manual y propenso a errores.

**4.** La subnet `10.20.0.0/24` se quedó sin direcciones y no puedes detener las VMs. ¿Qué haces?

- A. Crear una subnet nueva y mover las VMs
- B. `gcloud compute networks subnets expand-ip-range` con un prefijo menor, por ejemplo `/22`
- C. Cambiar la VPC a auto mode
- D. Reducir el rango a `/26` y volver a ampliarlo

??? success "Respuesta"
    **B.** Ampliar el rango primario no requiere downtime (si no se solapa con otras subnets ni rutas). A implica recrear VMs. C no amplía nada. D: los rangos no se pueden reducir.

**5.** Los Pods de GKE fallan con `ImagePullBackOff` al descargar desde un repositorio privado de Artifact Registry del mismo proyecto. ¿Cuál es la causa más probable?

- A. Falta Cloud NAT
- B. La service account de los nodes no tiene `roles/artifactregistry.reader`
- C. El clúster es Autopilot
- D. Falta una firewall rule de ingress

??? success "Respuesta"
    **B.** Los nodes descargan las imágenes con su service account. A afectaría a registries de internet, no a Artifact Registry con Private Google Access. C no impide descargar. D no aplica a descargas salientes.

**6.** Quieres saber quién leyó objetos de un bucket con datos sensibles. ¿Qué activas?

- A. Admin Activity audit logs
- B. Data Access audit logs de Cloud Storage
- C. VPC Flow Logs
- D. Object Versioning

??? success "Respuesta"
    **B.** Las lecturas de datos se registran en Data Access audit logs, que vienen desactivados por defecto. A registra cambios de configuración (siempre activo). C es tráfico de red. D guarda versiones, no accesos.

**7.** Un bucket con CMEK no puede escribir objetos tras crear la clave en Cloud KMS. ¿Qué falta?

- A. Habilitar Object Versioning
- B. Dar a la service agent de Cloud Storage el rol Cloud KMS CryptoKey Encrypter/Decrypter sobre la clave
- C. Dar Owner al usuario
- D. Mover la clave a la región `global`

??? success "Respuesta"
    **B.** El servicio cifra con su service agent, que necesita ese rol sobre la clave. A no tiene relación. C viola el mínimo privilegio y no resuelve el permiso del servicio. D: la clave debe estar en una ubicación compatible con el bucket, no necesariamente global.

## Para profundizar

- [Observabilidad nativa](../../../cloud/operacion-y-gobierno/observabilidad-nativa.md) y [Observabilidad](../../../devops/operacion/observabilidad.md)
- [Resiliencia](../../../cloud/operacion-y-gobierno/resiliencia.md) y [Continuidad de negocio](../../../negocio/continuidad-negocio.md)
- [Kubernetes](../../../devops/contenedores/kubernetes.md) y [Seguridad de Kubernetes](../../../devsecops/infraestructura-y-contenedores/seguridad-kubernetes.md)
- [Redes en la nube](../../../cloud/redes-y-datos/redes.md) y [Troubleshooting de red](../../../networking/avanzado/troubleshooting-red.md)
- Comandos: [gcloud](../../../recursos/comandos/google-cli.md) y [kubectl](../../../recursos/comandos/kubectl.md)

## Referencias

- [Snapshots y snapshot schedules](https://cloud.google.com/compute/docs/disks/scheduled-snapshots)
- [Cloud Run: rollouts, rollbacks y traffic migration](https://cloud.google.com/run/docs/rollouts-rollbacks-traffic-migration)
- [Cloud Storage lifecycle](https://cloud.google.com/storage/docs/lifecycle)
- [CMEK](https://cloud.google.com/kms/docs/cmek)
- [Routing and storage overview (Cloud Logging)](https://cloud.google.com/logging/docs/routing/overview)
- [Cloud Audit Logs](https://cloud.google.com/logging/docs/audit)
