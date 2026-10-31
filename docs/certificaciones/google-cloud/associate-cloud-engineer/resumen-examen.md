---
tags:
  - gcp
  - certificacion
  - ace
---

# Google Cloud Associate Cloud Engineer: resumen del examen

> Qué evalúa la certificación Associate Cloud Engineer, cómo es el formato, cuánto pesa cada sección de la guía vigente, un plan de estudio de 6 semanas y un laboratorio práctico con `gcloud`, `gcloud storage` y `kubectl`.

## ¿Qué es?

**Associate Cloud Engineer** (ACE) es la certificación de nivel **Associate** (asociado) de Google Cloud. Demuestra que sabes **desplegar, operar y asegurar** aplicaciones e infraestructura en Google Cloud: proyectos y redes, VMs y clústeres de GKE, Cloud Run, almacenamiento y bases de datos, monitoreo y logs, IAM y service accounts.

Es muy práctica: muchas preguntas piden **el comando o el paso concreto** (qué flag de `gcloud`, qué rol de IAM, qué opción de la consola) más que el diseño de una arquitectura. Es el equivalente en Google Cloud de la [AZ-104](../../azure/azure-administrator/resumen-examen.md) de Azure.

Lo genérico de cualquier examen (gestión del tiempo, palabras clave comunes, examen en línea, renovación) está en [Cómo preparar un examen](../../como-preparar-un-examen.md).

!!! info "Guía vigente: versión 2026 (4 secciones)"
    La guía oficial se **reestructuró en 2026**: pasó de 5 secciones (la anterior separaba "planificar" e "implementar") a **4 secciones**, añadió herramientas de IA (Gemini Cloud Assist, Gemini CLI, Google Antigravity, Application Design Center), Cloud NGFW, Database Center, Cloud Hub y la plataforma de agentes **Gemini Enterprise Agent Platform** (antes Vertex AI). La página oficial indica que el examen "se actualizó para reflejar cambios recientes de marca": **los nombres de producto del examen son los de la guía vigente**. Muchos cursos y simulacros de terceros siguen la guía de 5 secciones: úsalos con cuidado.

## Formato del examen

| Aspecto | Detalle |
| --- | --- |
| Nivel | **Associate** |
| Preguntas | **50–60**, **multiple choice** (una correcta) y **multiple select** (varias correctas) |
| Duración | **2 horas** |
| Puntaje | Aprobado / no aprobado; Google **no publica** el puntaje mínimo ni el desglose por sección |
| Costo | **125 USD** (más impuestos según el país) |
| Modalidad | **Online proctored** o centro de pruebas **Pearson VUE** |
| Idiomas | Inglés, japonés, español y portugués |
| Prerrequisitos | Ninguno; se recomiendan **6 meses o más** de práctica con Google Cloud |
| Validez | **3 años** |
| Renovación | **Renewal exam** (1 hora, 20 preguntas, 75 USD, inglés y japonés, renueva 3 años) o una **ruta de renovación en Google Skills** (cursos o *skill badges*; según la página oficial, esa vía da validez de 1 año) |

!!! warning "Datos que cambian"
    Precio, idiomas, proveedor de pruebas y vías de renovación cambian con frecuencia. Revisa la [página oficial](https://cloud.google.com/learn/certification/cloud-engineer) antes de agendar; en especial, confirma que el español ya esté disponible para la versión 2026 de la guía.

## Objetivo profesional

Para quien **despliega, opera y asegura** soluciones en Google Cloud y monitorea varios proyectos, apoyándose en herramientas de IA. Roles: [Cloud Engineer](../../roles-profesionales.md#cloud-engineer), [Support / Cloud Operations](../../roles-profesionales.md#support-cloud-operations), y [DevOps Engineer](../../roles-profesionales.md#devops-engineer) o [SRE](../../roles-profesionales.md#site-reliability-engineer-sre) que empiezan en Google Cloud. Después: [Terraform Associate](../../hashicorp/terraform-associate/resumen-examen.md), una Professional de Google Cloud según el rol (Cloud Architect, DevOps, Security, Network; ver [Otras certificaciones](../../otras-certificaciones.md#google-cloud)) o CKA si trabajas mucho con GKE.

## Secciones y peso

| Sección | Peso | Qué cubre | Nota |
| --- | --- | --- | --- |
| 1. Setting up a cloud solution environment | **~20%** | Jerarquía de recursos, organization policies, Cloud Identity, APIs, cuotas, Cloud Asset Inventory, Workforce Identity Federation, facturación | [Sección 1](seccion-1-entorno-solucion-cloud.md) |
| 2. Planning and implementing a cloud solution | **~30%** | Cómputo (Compute Engine, GKE, Cloud Run, Cloud Run functions, Agent Runtime), almacenamiento y datos, diseño de redes, IaC y herramientas de IA | [Sección 2](seccion-2-planificar-implementar.md) |
| 3. Ensuring the successful operation of a cloud solution | **~30%** | Operar VMs, GKE y Cloud Run; snapshots, backups y CMEK; redes del día a día; Cloud Monitoring y Cloud Logging | [Sección 3](seccion-3-operacion-solucion.md) |
| 4. Configuring access and security | **~20%** | IAM (roles, herencia, custom roles), service accounts, impersonation, credenciales de corta duración, Workload Identity Federation | [Sección 4](seccion-4-acceso-seguridad.md) |

Sobre 50–60 preguntas, las secciones 2 y 3 son el **60%** del examen (unas 15–18 preguntas cada una): cómputo, datos y redes, primero para crearlos y después para operarlos.

## Servicios que más aparecen

La guía no publica una lista cerrada; estos son los que más salen en sus *considerations*. La lista completa está en la [guía oficial](https://services.google.com/fh/files/misc/associate_cloud_engineer_exam_guide_english.pdf).

| Categoría | Servicios clave |
| --- | --- |
| Organización y facturación | Resource Manager, Organization Policy Service, Cloud Billing, Cloud Asset Inventory |
| Identidad | Cloud IAM, Cloud Identity, service accounts, Workload y Workforce Identity Federation |
| Cómputo | Compute Engine (MIGs, Spot VMs, OS Login), GKE, Cloud Run, Cloud Run functions |
| Almacenamiento y datos | Cloud Storage, Persistent Disk / Hyperdisk, Filestore, Cloud SQL, Spanner, Firestore, Bigtable, BigQuery |
| Redes | VPC, Shared VPC, VPC Network Peering, firewall rules y Cloud NGFW, Cloud Load Balancing, Cloud NAT, Cloud DNS |
| Operación | Cloud Monitoring, Cloud Logging (log sinks), Ops Agent |
| Herramientas | gcloud CLI, Cloud Shell, kubectl, Terraform, Infrastructure Manager |

!!! note "Servicios retirados o en segundo plano"
    - **Cloud Deployment Manager** llegó a su fin de soporte el **31 de marzo de 2026**. Su sucesor es **Infrastructure Manager** (Terraform gestionado). Si un simulacro lo da como respuesta, está desactualizado.
    - **Container Registry** fue reemplazado por **Artifact Registry**.
    - **Cloud Functions** ahora se llama **Cloud Run functions**.
    - **App Engine** sigue disponible, pero **no aparece en la guía vigente**; hoy la respuesta preferida es Cloud Run.
    - **`gsutil`** es la herramienta heredada de Cloud Storage; la recomendada es **`gcloud storage`**.

## Plan de estudio de 6 semanas

Pensado para 6–8 horas por semana con práctica real en un proyecto de pruebas. Si ya trabajas con Google Cloud, compáctalo en 3–4 semanas.

| Semana | Tema | Qué hacer |
| --- | --- | --- |
| 1 | Sección 1 | [Sección 1](seccion-1-entorno-solucion-cloud.md), [modelos de servicio y regiones](../../../cloud/fundamentos/modelos-de-servicio-y-regiones.md) y [gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md). Crea un proyecto, un **budget con alertas** y practica `gcloud config` |
| 2 | Sección 2: cómputo | [Sección 2](seccion-2-planificar-implementar.md), [máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md) y [contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md). Práctica: MIG con autoscaling, Cloud Run, clúster Autopilot |
| 3 | Sección 2: datos y redes | [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md) y [redes](../../../cloud/redes-y-datos/redes.md). Práctica: VPC custom, firewall rules, Cloud NAT, bucket con lifecycle |
| 4 | Sección 3 | [Sección 3](seccion-3-operacion-solucion.md) y [observabilidad nativa](../../../monitoreo/nube/observabilidad-nativa.md). Práctica: snapshot schedule, traffic splitting en Cloud Run, alerta, log sink a BigQuery |
| 5 | Sección 4 | [Sección 4](seccion-4-acceso-seguridad.md) e [IAM comparativa](../../../cloud/fundamentos/iam-comparativa.md). Práctica: custom role, impersonation, Workload Identity Federation for GKE |
| 6 | Repaso | *Sample questions* oficiales, preguntas de práctica de cada nota y el laboratorio de abajo sin mirar la documentación |

## Recursos oficiales gratuitos

| Recurso | Para qué sirve |
| --- | --- |
| **Exam guide** | La fuente de verdad: secciones, pesos y *considerations* |
| **Sample questions** | Formulario oficial con preguntas del estilo del examen |
| **Google Skills** (antes Google Cloud Skills Boost) | Ruta *Cloud Engineer* con laboratorios en proyectos temporales |
| **Documentación de Google Cloud** | Sobre todo las páginas "Choose…" (cómputo, almacenamiento, base de datos, load balancer) |

## Laboratorio práctico

Un recorrido corto por las cuatro secciones en un **proyecto de pruebas**, desde **Cloud Shell** (trae `gcloud`, `kubectl` y Terraform). Los comandos de cada paso están en su sección y en las guías de comandos de [gcloud](../../../recursos/comandos/google-cli.md) y [kubectl](../../../recursos/comandos/kubectl.md).

!!! danger "Costos y limpieza"
    VMs, GKE, Cloud NAT y load balancers **cobran por hora**. Usa un proyecto solo para el laboratorio, crea primero el budget y al terminar **borra el proyecto completo**: detiene la facturación de todo (queda 30 días en *pending deletion*).

1. **Entorno** (S1): crear proyecto, vincular billing, budget con umbrales 50% y 90%, habilitar APIs de Compute, GKE y Cloud Run.

    ```bash
    gcloud projects create "$PROJECT_ID" --name="ACE lab"
    gcloud billing projects link "$PROJECT_ID" --billing-account=XXXXXX-XXXXXX-XXXXXX
    gcloud services enable compute.googleapis.com container.googleapis.com run.googleapis.com
    ```

2. **Red y VM** (S2): VPC custom + subnet con Private Google Access, firewall para SSH por IAP (`35.235.240.0/20`), instance template Spot sin IP externa, MIG con autoscaling y `gcloud compute ssh --tunnel-through-iap`.
3. **Cloud Storage** (S2 y S3): bucket con uniform bucket-level access y public access prevention, `gcloud storage cp` y una [regla de lifecycle](seccion-3-operacion-solucion.md#cloud-storage-objetos-y-lifecycle).
4. **Contenedores** (S2 y S3): `gcloud run deploy` de la imagen `hello`, clúster `create-auto`, `get-credentials`, `kubectl create deployment` y `expose --type=LoadBalancer`.
5. **Operación y acceso** (S3 y S4): `gcloud logging read` con filtro de severidad, crear una service account, darle `roles/storage.objectViewer` y revisar la política con `get-iam-policy`.
6. **Limpieza**: `kubectl delete service` (libera el load balancer), borrar el clúster y `gcloud projects delete`.

!!! tip "Practica también desde la consola"
    El examen pregunta por comandos y por pasos de la consola. Repite el laboratorio una vez solo con la consola y otra con [Terraform](../../../devops/iac/terraform-basico.md).

## Palabras clave y trampas propias

Las genéricas (*cost-effective*, *operational overhead*, *audit*…) están en [Cómo preparar un examen](../../como-preparar-un-examen.md#palabras-clave-que-deciden-la-respuesta). Las propias de ACE:

| Palabra clave | Qué suele indicar |
| --- | --- |
| **Google-recommended practices** | Servicio gestionado, mínimo privilegio, grupos en vez de usuarios, sin claves de service account |
| **Minimize operational overhead** | Cloud Run, GKE Autopilot, Cloud SQL, BigQuery antes que VMs autogestionadas |
| **Fault-tolerant batch** / **minimize cost** | Spot VMs, Nearline/Coldline/Archive, lifecycle, escalado a cero |
| **Least privilege** | **Predefined role** más acotado o **custom role**; nunca basic roles |
| **Global**, **strong consistency**, relacional con escala horizontal | Spanner |
| **Analytics**, **SQL sobre petabytes**, **data warehouse** | BigQuery |
| **Audit** / "quién hizo qué" | Cloud Audit Logs (Admin Activity, Data Access) |
| **Long-term log retention** / análisis externo | Log sink a Cloud Storage, BigQuery o Pub/Sub |
| **Without external IP** | IAP TCP forwarding para SSH, Cloud NAT para salir, Private Google Access para APIs |

## Para profundizar

- Base: [Modelos de servicio y regiones](../../../cloud/fundamentos/modelos-de-servicio-y-regiones.md), [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md), [FinOps y costos](../../../cloud/fundamentos/finops-costos.md)
- Servicios: [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md), [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md), [Redes en la nube](../../../cloud/redes-y-datos/redes.md), [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md)
- Operación y seguridad: [Observabilidad nativa](../../../monitoreo/nube/observabilidad-nativa.md), [IAM comparativa](../../../cloud/fundamentos/iam-comparativa.md)
- Comandos: [gcloud CLI](../../../recursos/comandos/google-cli.md), [kubectl](../../../recursos/comandos/kubectl.md), [Terraform](../../../recursos/comandos/terraform.md)

!!! example "Practica en el laboratorio"
    - [Lab 20: Google Cloud: desplegar un contenedor en Cloud Run](../../../laboratorios/cloud/gcp-cloud-run.md)

## Referencias

- [Associate Cloud Engineer (página oficial)](https://cloud.google.com/learn/certification/cloud-engineer)
- [Associate Cloud Engineer exam guide (PDF)](https://services.google.com/fh/files/misc/associate_cloud_engineer_exam_guide_english.pdf)
- [Renewal exam guide (PDF)](https://services.google.com/fh/files/misc/associate_cloud_engineer_renewal_exam_guide_english.pdf)
- [Google Skills](https://www.skills.google/)
- [gcloud CLI overview](https://cloud.google.com/sdk/gcloud)
- [Deployment Manager deprecation](https://cloud.google.com/deployment-manager/docs/deprecations)
