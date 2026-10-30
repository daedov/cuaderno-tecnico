## Google Cloud (gcloud CLI)
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

!!! example "Practica en el laboratorio"
    - [Lab 00: Preparar el entorno de laboratorio](../../laboratorios/fundamentos/preparar-entorno.md)

