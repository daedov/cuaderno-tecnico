# Google Cloud (gcloud CLI)
| Comando | Descripción |
|---------|-------------|
| `gcloud init` | Inicializar configuración (cuenta, proyecto, región) |
| `gcloud auth login` | Iniciar sesión con una cuenta de Google |
| `gcloud auth application-default login` | Autenticar credenciales para SDKs/apps locales |
| `gcloud config set project <proyecto>` | Establecer proyecto activo |
| `gcloud config list` | Ver configuración activa |
| `gcloud projects list` | Listar proyectos disponibles |
| `gcloud compute instances list` | Listar instancias de Compute Engine |
| `gcloud compute instances create <nombre>` | Crear instancia de Compute Engine |
| `gcloud compute ssh <instancia>` | Conectarse por SSH a una instancia |
| `gcloud container clusters list` | Listar clústeres de GKE |
| `gcloud container clusters get-credentials <cluster>` | Configurar kubectl para un clúster GKE |
| `gcloud functions deploy <nombre>` | Desplegar una Cloud Function |
| `gcloud functions logs read <nombre>` | Ver logs de una Cloud Function |
| `gcloud run deploy <servicio>` | Desplegar un servicio en Cloud Run |
| `gcloud run services list` | Listar servicios de Cloud Run |
| `gcloud storage ls gs://<bucket>` | Listar contenido de un bucket |
| `gcloud storage cp <origen> gs://<destino>` | Copiar archivo hacia/desde Cloud Storage |
| `gcloud iam service-accounts list` | Listar cuentas de servicio |
| `gcloud logging read "<filtro>"` | Consultar logs de Cloud Logging |
| `bq query --use_legacy_sql=false '<consulta SQL>'` | Ejecutar consulta en BigQuery |
| `bq ls <dataset>` | Listar tablas de un dataset de BigQuery |

## Organización, proyectos y APIs
| Comando | Descripción |
|---------|-------------|
| `gcloud organizations list` | Ver las organizaciones a las que tienes acceso |
| `gcloud resource-manager folders create --display-name=<nombre> --organization=<org-id>` | Crear una carpeta |
| `gcloud projects create <proyecto> --folder=<folder-id>` | Crear un proyecto dentro de una carpeta |
| `gcloud projects move <proyecto> --folder=<folder-id>` | Mover un proyecto a otra carpeta |
| `gcloud projects delete <proyecto>` | Borrar un proyecto (queda 30 días en *pending deletion*) |
| `gcloud config set compute/region <región>` | Región por defecto |
| `gcloud config set compute/zone <zona>` | Zona por defecto |
| `gcloud org-policies describe <constraint> --project=<proyecto> --effective` | Ver la organization policy que aplica de verdad |
| `gcloud org-policies set-policy <politica.yaml>` | Aplicar una organization policy |
| `gcloud services list --enabled` | Ver APIs habilitadas |
| `gcloud services list --available --filter="name:<api>"` | Buscar una API |
| `gcloud services enable <api>.googleapis.com` | Habilitar una API |
| `gcloud compute regions describe <región>` | Ver cuotas y uso de una región |
| `gcloud compute regions list` / `gcloud compute zones list` | Listar regiones y zonas |

## Facturación
| Comando | Descripción |
|---------|-------------|
| `gcloud billing accounts list` | Listar cuentas de facturación |
| `gcloud billing projects link <proyecto> --billing-account=<id>` | Vincular un proyecto a una cuenta de facturación |
| `gcloud billing projects describe <proyecto>` | Ver qué cuenta de facturación usa un proyecto |
| `gcloud billing budgets create --billing-account=<id> --display-name=<nombre> --budget-amount=100USD --threshold-rule=percent=0.9` | Crear un presupuesto con alerta al 90 % |

## IAM y service accounts
| Comando | Descripción |
|---------|-------------|
| `gcloud projects get-iam-policy <proyecto> --flatten="bindings[].members" --format="table(bindings.role,bindings.members)"` | Ver quién tiene qué rol |
| `gcloud projects add-iam-policy-binding <proyecto> --member=group:<grupo> --role=<rol>` | Dar un rol (mejor a grupos que a usuarios) |
| `gcloud projects add-iam-policy-binding <proyecto> --member=<miembro> --role=<rol> --condition='expression=request.time < timestamp("<fecha>"),title=<título>'` | Dar un rol con condición (por ejemplo, acceso temporal) |
| `gcloud projects remove-iam-policy-binding <proyecto> --member=<miembro> --role=<rol>` | Quitar un rol |
| `gcloud iam roles describe roles/<rol>` | Ver los permisos de un rol predefinido |
| `gcloud iam roles create <id> --project=<proyecto> --file=<rol.yaml>` | Crear un custom role (también con `--organization`) |
| `gcloud iam roles update <id> --project=<proyecto> --add-permissions=<permiso>` | Añadir permisos a un custom role |
| `gcloud iam service-accounts create <nombre> --display-name="<texto>"` | Crear una service account |
| `gcloud iam service-accounts add-iam-policy-binding <sa-email> --member=user:<usuario> --role=roles/iam.serviceAccountTokenCreator` | Permitir que alguien suplante (*impersonate*) a la service account |
| `gcloud iam service-accounts get-iam-policy <sa-email>` | Ver quién puede usar la service account |
| `gcloud iam service-accounts disable <sa-email>` | Desactivar una service account sin borrarla |
| `gcloud compute instances set-service-account <vm> --zone=<zona> --service-account=<sa-email> --scopes=cloud-platform` | Cambiar la service account de una VM (debe estar detenida) |
| `gcloud <comando> --impersonate-service-account=<sa-email>` | Ejecutar un comando como la service account |
| `gcloud auth print-access-token --impersonate-service-account=<sa-email>` | Obtener un token de corta duración |
| `gcloud config set auth/impersonate_service_account <sa-email>` | Suplantar siempre en esta configuración |
| `gcloud iam workload-identity-pools create <pool> --location=global` | Crear un pool de Workload Identity Federation |
| `gcloud iam workload-identity-pools providers create-oidc <proveedor> --location=global --workload-identity-pool=<pool> --issuer-uri=<url> --attribute-mapping="google.subject=assertion.sub"` | Añadir un proveedor OIDC (por ejemplo, GitHub Actions) |

## Compute Engine
| Comando | Descripción |
|---------|-------------|
| `gcloud compute machine-types list --zones=<zona> --filter="name~^<familia>"` | Ver tipos de máquina disponibles |
| `gcloud compute accelerator-types list --filter="zone:<zona>"` | Ver GPUs disponibles en una zona |
| `gcloud compute instances create <vm> --zone=<zona> --machine-type=<tipo> --image-family=debian-12 --image-project=debian-cloud` | Crear una VM |
| `gcloud compute instances create <vm> --zone=<zona> --provisioning-model=SPOT` | Crear una Spot VM |
| `gcloud compute instances list --filter="status=RUNNING" --format="table(name,zone,status)"` | Listar VMs filtrando y con formato |
| `gcloud compute instances stop <vm> --zone=<zona>` | Detener una VM |
| `gcloud compute instances set-machine-type <vm> --zone=<zona> --machine-type=<tipo>` | Cambiar el tamaño (con la VM detenida) |
| `gcloud compute ssh <vm> --zone=<zona> --tunnel-through-iap` | SSH sin IP externa, a través de IAP |
| `gcloud compute snapshots create <snapshot> --source-disk=<disco> --source-disk-zone=<zona>` | Snapshot de un disco |
| `gcloud compute snapshots list` / `delete <snapshot>` | Listar o borrar snapshots |
| `gcloud compute resource-policies create snapshot-schedule <nombre> --region=<región> --daily-schedule --start-time=04:00 --max-retention-days=14` | Programar snapshots diarios |
| `gcloud compute images create <imagen> --source-disk=<disco> --source-disk-zone=<zona> --family=<familia>` | Crear una imagen personalizada |
| `gcloud compute instance-templates create <plantilla> --machine-type=<tipo> --image-family=<familia> --image-project=<proyecto-imagen>` | Crear una instance template |
| `gcloud compute instance-groups managed create <mig> --template=<plantilla> --size=<n> --region=<región>` | Crear un managed instance group regional |
| `gcloud compute instance-groups managed set-autoscaling <mig> --region=<región> --max-num-replicas=<n> --target-cpu-utilization=0.6` | Activar autoscaling por CPU |
| `gcloud compute instance-groups managed rolling-action start-update <mig> --version=template=<plantilla> --region=<región>` | Actualizar el MIG a una plantilla nueva (rolling update) |

## Redes
| Comando | Descripción |
|---------|-------------|
| `gcloud compute networks create <vpc> --subnet-mode=custom` | Crear una VPC en modo custom |
| `gcloud compute networks subnets create <subnet> --network=<vpc> --region=<región> --range=<cidr>` | Crear una subnet |
| `gcloud compute networks subnets expand-ip-range <subnet> --region=<región> --prefix-length=<n>` | Ampliar una subnet (solo se puede agrandar) |
| `gcloud compute firewall-rules create <regla> --network=<vpc> --allow=tcp:22 --source-ranges=35.235.240.0/20` | Permitir SSH solo desde IAP |
| `gcloud compute network-firewall-policies create <política> --global` | Crear una Cloud NGFW policy |
| `gcloud compute addresses create <nombre> --global` | IP externa estática global (para load balancer) |
| `gcloud compute addresses create <nombre> --region=<región>` | IP externa estática regional |
| `gcloud compute addresses create <nombre> --region=<región> --subnet=<subnet> --addresses=<ip>` | Reservar una IP interna |
| `gcloud compute routes create <ruta> --network=<vpc> --destination-range=<cidr> --next-hop-instance=<vm> --next-hop-instance-zone=<zona>` | Ruta estática a través de una VM appliance |
| `gcloud compute routers create <router> --network=<vpc> --region=<región>` | Crear un Cloud Router |
| `gcloud compute routers nats create <nat> --router=<router> --region=<región> --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges` | Cloud NAT para VMs sin IP externa |
| `gcloud dns managed-zones create <zona> --dns-name=<dominio>. --visibility=private --networks=<vpc> --description="<texto>"` | Zona DNS privada |
| `gcloud dns record-sets create <nombre>.<dominio>. --zone=<zona> --type=A --ttl=300 --rrdatas=<ip>` | Crear un registro DNS |

## GKE y Artifact Registry
| Comando | Descripción |
|---------|-------------|
| `gcloud components install kubectl gke-gcloud-auth-plugin` | Instalar kubectl y el plugin de autenticación |
| `gcloud container clusters create-auto <cluster> --region=<región>` | Crear un clúster Autopilot |
| `gcloud container clusters create <cluster> --zone=<zona> --num-nodes=<n>` | Crear un clúster Standard |
| `gcloud container clusters delete <cluster> --region=<región>` | Borrar un clúster |
| `gcloud container node-pools create <pool> --cluster=<cluster> --zone=<zona> --machine-type=<tipo> --enable-autoscaling --min-nodes=1 --max-nodes=5` | Añadir un node pool con autoscaling |
| `gcloud container node-pools delete <pool> --cluster=<cluster> --zone=<zona>` | Borrar un node pool |
| `gcloud artifacts repositories create <repo> --repository-format=docker --location=<región>` | Crear un repositorio de imágenes |
| `gcloud auth configure-docker <región>-docker.pkg.dev` | Configurar Docker para subir a Artifact Registry |

Los comandos de `kubectl` están en [Kubernetes](kubectl.md).

## Cloud Run, Cloud Run functions y Eventarc
| Comando | Descripción |
|---------|-------------|
| `gcloud run deploy <servicio> --image=<imagen> --region=<región>` | Desplegar una imagen |
| `gcloud run deploy <servicio> --source=.` | Desplegar desde código fuente (Cloud Build construye la imagen) |
| `gcloud run deploy <servicio> --image=<imagen> --no-traffic --tag=<tag>` | Desplegar una revisión sin enviarle tráfico, con URL propia |
| `gcloud run services update-traffic <servicio> --region=<región> --to-revisions=<revisión>=10` | Mandar el 10 % del tráfico a una revisión (canary) |
| `gcloud run services update-traffic <servicio> --region=<región> --to-latest` | Mandar todo el tráfico a la última revisión |
| `gcloud run services update <servicio> --region=<región> --min-instances=1 --max-instances=10` | Ajustar el autoscaling |
| `gcloud functions deploy <función> --gen2 --runtime=python312 --region=<región> --source=. --entry-point=<función> --trigger-bucket=<bucket>` | Función que se dispara al subir un archivo a un bucket |
| `gcloud eventarc triggers create <trigger> --location=<región> --destination-run-service=<servicio> --event-filters="type=google.cloud.storage.object.v1.finalized" --event-filters="bucket=<bucket>" --service-account=<sa-email>` | Trigger de Eventarc hacia Cloud Run |

## Cloud Storage
| Comando | Descripción |
|---------|-------------|
| `gcloud storage buckets create gs://<bucket> --location=<región> --default-storage-class=<clase> --uniform-bucket-level-access` | Crear un bucket |
| `gcloud storage cp -r <carpeta> gs://<bucket>/<ruta>/` | Subir una carpeta |
| `gcloud storage buckets update gs://<bucket> --lifecycle-file=<lifecycle.json>` | Aplicar reglas de lifecycle |
| `gcloud storage buckets update gs://<bucket> --versioning` | Activar versionado |
| `gcloud storage buckets add-iam-policy-binding gs://<bucket> --member=<miembro> --role=roles/storage.objectViewer` | Dar acceso a un bucket |
| `gcloud storage sign-url gs://<bucket>/<objeto> --duration=1h --impersonate-service-account=<sa-email>` | URL firmada de acceso temporal |
| `gcloud storage service-agent --project=<proyecto> --authorize-cmek=<id-de-clave-kms>` | Permitir que Cloud Storage use una clave CMEK |

## Bases de datos y BigQuery
| Comando | Descripción |
|---------|-------------|
| `gcloud sql instances create <instancia> --database-version=POSTGRES_16 --region=<región> --tier=<tier> --availability-type=REGIONAL` | Crear Cloud SQL con alta disponibilidad |
| `gcloud sql connect <instancia> --user=postgres` | Conectarse (o usar Cloud SQL Auth Proxy) |
| `gcloud sql backups create --instance=<instancia>` | Backup bajo demanda |
| `gcloud sql backups list --instance=<instancia>` | Listar backups |
| `gcloud sql backups restore <backup-id> --restore-instance=<instancia>` | Restaurar un backup |
| `gcloud spanner instances create <instancia> --config=<config> --processing-units=100 --description="<texto>"` | Crear una instancia de Spanner |
| `gcloud spanner databases execute-sql <bd> --instance=<instancia> --sql="<consulta>"` | Consultar Spanner |
| `gcloud firestore backups schedules create --database='(default)' --recurrence=daily --retention=14d` | Backups diarios de Firestore |
| `bq mk --location=<ubicación> --dataset <proyecto>:<dataset>` | Crear un dataset |
| `bq load --source_format=CSV --autodetect <dataset>.<tabla> gs://<bucket>/<archivo>.csv` | Cargar un CSV desde Cloud Storage |
| `bq query --use_legacy_sql=false --dry_run '<consulta>'` | Estimar los bytes que leerá una consulta (costo) sin ejecutarla |
| `bq ls -j --max_results=10` | Ver el estado de los últimos jobs |
| `gcloud dataflow jobs list --region=<región> --status=active` | Ver jobs de Dataflow activos |

## Cifrado, logs e inventario
| Comando | Descripción |
|---------|-------------|
| `gcloud kms keyrings create <keyring> --location=<región>` | Crear un key ring |
| `gcloud kms keys create <clave> --keyring=<keyring> --location=<región> --purpose=encryption` | Crear una clave de cifrado |
| `gcloud logging read '<filtro>' --limit=10` | Consultar logs (por ejemplo, `severity>=ERROR`) |
| `gcloud logging sinks create <sink> <destino> --log-filter='<filtro>'` | Exportar logs a Cloud Storage, BigQuery o Pub/Sub |
| `gcloud logging sinks create <sink> <destino> --organization=<org-id> --include-children` | Sink agregado de toda la organización |
| `gcloud logging buckets update _Default --location=global --retention-days=90` | Cambiar la retención de logs |
| `gcloud logging metrics create <métrica> --description="<texto>" --log-filter='<filtro>'` | Métrica basada en logs (para alertas) |
| `gcloud asset search-all-resources --scope=organizations/<org-id>` | Inventario de recursos de la organización |
| `gcloud asset search-all-iam-policies --scope=projects/<proyecto> --query="<filtro>"` | Buscar quién tiene acceso a qué |
| `gcloud recommender recommendations list --project=<proyecto> --location=<zona> --recommender=google.compute.instance.MachineTypeRecommender` | Recomendaciones de rightsizing de VMs |

!!! example "Practica en el laboratorio"
    - [Lab 00: Preparar el entorno de laboratorio](../../laboratorios/fundamentos/preparar-entorno.md)

