---
tags:
  - gcp
  - certificacion
  - ace
  - iam
  - seguridad
---

# Sección 4: Configuring access and security (~20%)

> Cómo se dan y se controlan los permisos en Google Cloud: allow policies, herencia en la jerarquía, tipos de roles, custom roles, service accounts, impersonation, credenciales de corta duración y Workload Identity Federation.

!!! info "Qué evalúa esta sección"
    Según la guía oficial vigente:

    - **4.1 Managing IAM**: ver y crear IAM policies, asignar roles y entender la herencia en la jerarquía de la organización, gestionar los tipos de roles y definir custom roles.
    - **4.2 Managing service accounts**: crear service accounts (incluidas las gestionadas por Google), usarlas con permisos mínimos, asignarlas a recursos, gestionar sus permisos, impersonation, credenciales de corta duración, service accounts con aplicaciones en GKE y Workload Identity Federation.

    Formato y laboratorio en el [resumen del examen](resumen-examen.md).

## Cómo funciona Cloud IAM

Principals, roles, allow policies, role bindings, IAM Conditions y deny policies están explicados en [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md#google-cloud-iam). En resumen: **principal + role + recurso** donde se adjunta la allow policy. Formatos de principal que salen en los comandos:

| Principal | Formato en el binding |
| --- | --- |
| Cuenta de Google o Cloud Identity / grupo | `user:ana@ejemplo.com` / `group:devops@ejemplo.com` |
| Service account | `serviceAccount:app@PROJECT.iam.gserviceaccount.com` |
| Dominio completo | `domain:ejemplo.com` |
| Identidades federadas | `principal://…` o `principalSet://…` |
| Público | `allUsers` / `allAuthenticatedUsers` (evítalo) |

```bash
gcloud projects get-iam-policy app-prod-4821 --format=yaml
gcloud projects add-iam-policy-binding app-prod-4821 \
  --member="group:dba@ejemplo.com" --role="roles/cloudsql.admin"
gcloud projects add-iam-policy-binding app-prod-4821 \
  --member="user:contratista@ejemplo.com" --role="roles/compute.viewer" \
  --condition='expression=request.time < timestamp("2026-12-31T23:59:59Z"),title=hasta-fin-de-ano'
```

!!! warning "`set-iam-policy` reemplaza todo"
    `gcloud projects set-iam-policy` **sobrescribe** la política completa. Para añadir o quitar un rol usa `add-iam-policy-binding` / `remove-iam-policy-binding`. Si usas `set-iam-policy`, parte de un `get-iam-policy` reciente (el `etag` evita pisar cambios concurrentes).

### Herencia en la jerarquía

La **effective policy** de un recurso es la **unión** de su allow policy y las de sus ancestros (proyecto, folders, organización): un rol en la organización aplica a todo; en un recurso (bucket, topic, secret), solo a él. Un permiso heredado **no se puede quitar más abajo** con una allow policy: para bloquear existen las **IAM deny policies** y, para limitar configuraciones, las [organization policies](seccion-1-entorno-solucion-cloud.md#organization-policies).

!!! tip "En el examen"
    "Un usuario tiene un permiso que no debería en un proyecto, pero el binding no aparece en el proyecto" → revisa la **herencia** (folder u organización). **Policy Troubleshooter** y **Policy Analyzer** responden "¿por qué tiene (o no) este acceso?" y "¿quién tiene acceso a qué?".

## Tipos de roles

Basic, predefined y custom roles se comparan en [IAM comparativa](../../../cloud/fundamentos/iam-comparativa.md#google-cloud-iam). Lo que pregunta el examen de los **custom roles**:

- Se crean a nivel de **organización** o de **proyecto** (no de folder).
- Tú los mantienes: si Google añade permisos a un servicio, tu custom role no los recibe.
- Tienen **launch stage** (`ALPHA`, `BETA`, `GA`, `DEPRECATED`, `DISABLED`); algunos permisos no se admiten.
- Se puede partir de un rol existente (`gcloud iam roles copy`).

```bash
gcloud iam roles create lectorVmsYLogs --project=app-prod-4821 \
  --title="Lector de VMs y logs" --stage=GA \
  --permissions=compute.instances.get,compute.instances.list,logging.logEntries.list
```

!!! tip "En el examen"
    - La respuesta "dar **Owner/Editor**" casi siempre es incorrecta: busca el **predefined role** más acotado.
    - "Ningún rol predefinido cumple sin dar permisos de más" → **custom role**.
    - "Custom role para toda la organización" → crearlo en la **organización**; no existen custom roles de folder.
    - Asigna roles a **grupos**, no a usuarios individuales.

## Service accounts

Una **service account** es una identidad para **aplicaciones y workloads**. Es a la vez un **principal** (recibe roles) y un **recurso** (tiene su propia allow policy: quién puede usarla).

| Tipo | Quién la crea | Ejemplo |
| --- | --- | --- |
| **User-managed** | Tú | `api-pagos@app-prod-4821.iam.gserviceaccount.com` |
| **Default service account** | Google al habilitar ciertos servicios (Compute Engine, App Engine) | `PROJECT_NUMBER-compute@developer.gserviceaccount.com` |
| **Service agents** (Google-managed) | Google, para que un servicio actúe sobre tus recursos | `service-PROJECT_NUMBER@gcp-sa-…iam.gserviceaccount.com` |

!!! warning "La Compute Engine default service account"
    Históricamente recibía **Editor** en el proyecto. En organizaciones nuevas lo impide la organization policy `iam.automaticIamGrantsForDefaultServiceAccounts`. Buena práctica: una **service account propia por aplicación** con solo los roles necesarios.

```bash
gcloud iam service-accounts create api-pagos --display-name="API de pagos"
gcloud run deploy pagos --image=us-central1-docker.pkg.dev/app-prod-4821/apps/pagos:2.0.0 \
  --region=us-central1 --service-account=api-pagos@app-prod-4821.iam.gserviceaccount.com
```

Para **adjuntar** una service account a un recurso, quien despliega necesita **Service Account User** **sobre esa service account**; si no, cualquiera que cree VMs podría "tomar prestados" sus permisos. En Compute Engine, los **access scopes** son heredados: usa `cloud-platform` y controla los permisos solo con IAM.

| Rol (sobre la service account) | Permite |
| --- | --- |
| **Service Account User** | Adjuntarla a recursos y ejecutar operaciones como ella (`iam.serviceAccounts.actAs`) |
| **Service Account Token Creator** | Generar **tokens de corta duración** (impersonation) |
| **Service Account Admin** | Crear, editar, deshabilitar y gestionar su política |
| **Service Account Key Admin** | Crear y borrar claves (evítalo) |
| **Workload Identity User** | Que una identidad federada o de GKE la use |

## Impersonation y credenciales de corta duración

Las **service account keys** (JSON) son credenciales de larga duración: Google recomienda **no crearlas** (y se bloquean con `iam.disableServiceAccountKeyCreation`). Ver [IAM comparativa](../../../cloud/fundamentos/iam-comparativa.md#google-cloud-iam).

| Necesidad | Solución sin claves |
| --- | --- |
| Código en una VM, Cloud Run, GKE | **Service account adjunta** (credenciales por el metadata server) |
| Una persona prueba con los permisos de una service account | **Impersonation** con Token Creator |
| Tu equipo local con librerías cliente | **Application Default Credentials**: `gcloud auth application-default login` |
| CI/CD, apps en AWS, Azure u on-premises | **Workload Identity Federation** |

```bash
gcloud storage ls gs://app-prod-4821-datos \
  --impersonate-service-account=api-pagos@app-prod-4821.iam.gserviceaccount.com
gcloud config set auth/impersonate_service_account api-pagos@app-prod-4821.iam.gserviceaccount.com
```

Por detrás, la **Service Account Credentials API** (`iamcredentials.googleapis.com`) emite access tokens OAuth 2.0, ID tokens (OIDC) o firma JWTs de vida corta (1 hora por defecto).

!!! tip "En el examen"
    - "Una desarrolladora debe probar con los permisos exactos de la app sin descargar claves" → **impersonation** con **Service Account Token Creator** sobre esa service account.
    - "Un despliegue falla con `iam.serviceAccounts.actAs`" → falta **Service Account User** sobre la service account que se adjunta.
    - Cualquier opción que diga "create a service account key and store it…" suele ser la trampa, salvo que no exista alternativa.

## Service accounts en GKE

**Workload Identity Federation for GKE** (antes "Workload Identity") permite que los Pods usen IAM **sin claves** y sin heredar la service account del node. Viene activado en Autopilot; en Standard se activa con `--workload-pool=PROJECT_ID.svc.id.goog`. Dos formas:

- **Directo a la Kubernetes service account** (recomendado): dar el rol al `principal://…/subject/ns/NAMESPACE/sa/KSA`. No todos los servicios lo admiten.
- **Vinculando a una IAM service account**: `roles/iam.workloadIdentityUser` para `serviceAccount:PROJECT_ID.svc.id.goog[NAMESPACE/KSA]` y anotar la KSA con `iam.gke.io/gcp-service-account`.

El Pod usa `serviceAccountName: <KSA>` y las librerías obtienen credenciales solas. Ver [Seguridad de Kubernetes](../../../devsecops/infraestructura-y-contenedores/seguridad-kubernetes.md).

## Workload Identity Federation

Permite que workloads **fuera de Google Cloud** (GitHub Actions, GitLab, AWS, Azure, cualquier IdP OIDC o SAML) obtengan credenciales de corta duración intercambiando su token en el **Security Token Service** de Google.

- **Workload identity pool**: agrupa identidades externas (por ejemplo, "ci-cd").
- **Provider**: confía en un emisor (`https://token.actions.githubusercontent.com`) con **attribute mapping** y una **attribute condition** que **limita qué identidades** se aceptan (por ejemplo, solo tu organización de GitHub).
- **Acceso**: roles directos al `principalSet://` del pool o impersonar una service account con **Workload Identity User**.

Ejemplo completo con GitHub Actions en [Secretos e identidades](../../../devsecops/identidades-y-pipeline/secretos-identidades.md).

!!! tip "En el examen"
    "El pipeline de CI/CD externo necesita desplegar en Google Cloud sin guardar claves" → **Workload Identity Federation**. Sin **attribute condition**, cualquier repositorio del mismo emisor podría intentar usar tu pool.

## Casos de uso

1. **Datos debe consultar BigQuery sin crear ni borrar datasets.** → `roles/bigquery.dataViewer` + `roles/bigquery.jobUser` al grupo.
2. **Auditoría ve la configuración de todos los proyectos sin cambiar nada.** → Rol de lectura (`roles/iam.securityReviewer` y `roles/viewer`, o custom) en la **organización**, a un grupo.
3. **Cloud Run lee un secreto y escribe en un bucket.** → Service account propia con `secretmanager.secretAccessor` sobre el secreto y `storage.objectCreator` sobre el bucket.
4. **Contratista con lectura hasta fin de año.** → Binding con **IAM Condition** de fecha.
5. **GitHub Actions despliega a Cloud Run.** → Workload Identity Federation con attribute condition + service account `deployer` con `run.developer` e `iam.serviceAccountUser` sobre la de runtime.
6. **Pods de GKE leen de Pub/Sub sin claves.** → Workload Identity Federation for GKE.
7. **SRE reproduce un error de permisos de la app.** → Impersonation con Token Creator temporal.
8. **Service account key en un repositorio público.** → Borrar o deshabilitar la clave, revisar audit logs, migrar a credenciales sin claves e impedir nuevas con la organization policy.

## Preguntas de práctica

**1.** Un grupo de desarrolladores debe poder iniciar y detener VMs en un proyecto, pero no crearlas ni borrarlas. Ningún rol predefinido encaja exactamente. ¿Qué haces?

- A. Darles Editor en el proyecto
- B. Crear un custom role con `compute.instances.start` y `compute.instances.stop` (y los de lectura necesarios) y asignarlo al grupo
- C. Darles Compute Admin
- D. Crear una service account key para cada desarrollador

??? success "Respuesta"
    **B.** Un custom role da exactamente los permisos necesarios. A y C dan muchos más permisos. D es una mala práctica y no resuelve el alcance.

**2.** Una usuaria tiene acceso de Owner a un proyecto, pero en la allow policy del proyecto no aparece. ¿Cuál es la explicación más probable?

- A. Es un error de caché de la consola
- B. El rol se hereda de un folder o de la organización
- C. Tiene una service account key
- D. Las IAM Conditions están desactivadas

??? success "Respuesta"
    **B.** La política efectiva incluye los bindings de los ancestros. Revisa con Policy Analyzer o Policy Troubleshooter.

**3.** Al desplegar en Cloud Run con `--service-account=runtime@…` obtienes un error de permiso `iam.serviceAccounts.actAs`. ¿Qué rol falta y dónde?

- A. Cloud Run Admin en el proyecto
- B. Service Account User sobre la service account `runtime@…`
- C. Service Account Key Admin en el proyecto
- D. Owner en el proyecto

??? success "Respuesta"
    **B.** `actAs` se concede con Service Account User sobre la service account que se adjunta. A no incluye ese permiso sobre otras service accounts por sí solo. C es para claves. D funciona pero viola el mínimo privilegio.

**4.** Un pipeline de GitLab alojado fuera de Google Cloud debe desplegar recursos. Seguridad prohíbe las claves de service account. ¿Qué configuras?

- A. Una service account key guardada como variable protegida
- B. Workload Identity Federation con un provider OIDC de GitLab y una attribute condition del proyecto
- C. Workforce Identity Federation
- D. Una cuenta de usuario compartida

??? success "Respuesta"
    **B.** Workload Identity Federation intercambia el token OIDC del pipeline por credenciales de corta duración. A usa claves. C es para personas. D es inseguro y no auditable.

**5.** Una ingeniera quiere ejecutar comandos de `gcloud` con los permisos de una service account sin descargar claves. ¿Qué necesita?

- A. Service Account User sobre la service account
- B. Service Account Token Creator sobre la service account y usar `--impersonate-service-account`
- C. Workload Identity User en el proyecto
- D. Una clave JSON temporal

??? success "Respuesta"
    **B.** La impersonation genera tokens de corta duración y requiere Token Creator. A sirve para adjuntarla a recursos. C es para identidades federadas o de GKE. D es justo lo que se quiere evitar.

**6.** ¿Dónde puedes crear un custom role?

- A. En la organización, en folders y en proyectos
- B. Solo en proyectos
- C. En la organización y en proyectos
- D. En cualquier recurso

??? success "Respuesta"
    **C.** Los custom roles existen a nivel de organización o de proyecto. No hay custom roles de folder.

## Para profundizar

- [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md): principals, roles y allow policies comparados con AWS IAM y Azure RBAC.
- [Seguridad de cifrado y secretos](../../../cloud/seguridad/seguridad-cifrado-secretos.md), [Seguridad de logging y detección](../../../cloud/seguridad/seguridad-logging-deteccion.md): Cloud KMS, Secret Manager y auditoría.
- [Secretos e identidades](../../../devsecops/identidades-y-pipeline/secretos-identidades.md): OIDC entre pipeline y nube.
- [Seguridad de Kubernetes](../../../devsecops/infraestructura-y-contenedores/seguridad-kubernetes.md).
- [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md).

## Referencias

- [IAM overview](https://cloud.google.com/iam/docs/overview)
- [Custom roles](https://cloud.google.com/iam/docs/creating-custom-roles)
- [Best practices for using service accounts](https://cloud.google.com/iam/docs/best-practices-service-accounts)
- [Service account impersonation](https://cloud.google.com/iam/docs/service-account-impersonation)
- [Workload Identity Federation for GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
