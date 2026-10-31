---
tags:
  - gcp
  - certificacion
  - ace
  - gobernanza
  - finops
---

# Sección 1: Setting up a cloud solution environment (~20%)

> Cómo se prepara el terreno en Google Cloud antes de desplegar nada: jerarquía de recursos, organization policies, usuarios y grupos, APIs, cuotas, inventario de recursos, federación de identidades y facturación.

!!! info "Qué evalúa esta sección"
    Según la guía oficial vigente:

    - **1.1 Setting up cloud projects and accounts**: crear la jerarquía de recursos, aplicar organization policies, dar roles de IAM en un proyecto, gestionar usuarios y grupos en Cloud Identity (manual y automatizado), habilitar APIs, preparar Google Cloud Observability, revisar cuotas y pedir aumentos, crear organizaciones independientes (*standalone*), preparar la red, verificar disponibilidad de productos por región y zona, Cloud Asset Inventory con Gemini Cloud Assist y Workforce Identity Federation.
    - **1.2 Managing billing configuration**: crear billing accounts, vincular proyectos, crear budgets y alertas, y configurar billing export.

    Formato, plan de estudio y laboratorio en el [resumen del examen](resumen-examen.md).

## Jerarquía de recursos

**Organization → Folders → Projects → Resources**. El concepto y la herencia de permisos están en [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md#google-cloud-iam) y la comparación con AWS y Azure en [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md). Lo que pregunta el examen:

| Nivel | Detalles que pregunta el examen |
| --- | --- |
| **Organization** (organización) | Nodo raíz ligado a un dominio de **Cloud Identity** o **Google Workspace**; se crea al verificar el dominio. Roles clave: **Organization Administrator** y **Project Creator** |
| **Folder** (carpeta) | Agrupa proyectos (área, entorno, equipo), se anidan; heredan IAM y organization policies a muchos proyectos de una vez |
| **Project** (proyecto) | Habilita APIs, factura, contiene recursos. **Project name** (editable), **project ID** (único global, inmutable) y **project number** (lo asigna Google) |
| **Resource** (recurso) | Pertenece a un solo proyecto |

**Standalone organization**: sin Google Workspace, se registra el dominio en **Cloud Identity Free** y se verifica. Sin organización no hay folders ni organization policies. La herencia de allow policies se ve en la [Sección 4](seccion-4-acceso-seguridad.md#herencia-en-la-jerarquia).

!!! tip "En el examen"
    - "Separar entornos / equipos y aplicar políticas comunes" → **folders**.
    - "Aislar recursos, cuotas y facturación" → **projects distintos**.
    - El **project ID** no se puede cambiar; el **project name** sí.

## Organization policies

El **Organization Policy Service** pone **guardrails** (barreras de protección) sobre **qué configuraciones** se permiten, sin importar los permisos de IAM. IAM dice **quién** puede actuar; las organization policies dicen **qué** se puede configurar. Se heredan hacia abajo.

| Constraint (restricción) | Para qué |
| --- | --- |
| `constraints/gcp.resourceLocations` | Limitar las regiones donde se crean recursos (residencia de datos) |
| `constraints/compute.vmExternalIpAccess` | Prohibir VMs con IP externa |
| `constraints/iam.allowedPolicyMemberDomains` | Solo dar roles a identidades del propio dominio (*domain restricted sharing*) |
| `constraints/iam.disableServiceAccountKeyCreation` | Prohibir la creación de service account keys |
| `constraints/compute.requireOsLogin` | Obligar a usar OS Login en las VMs |
| `constraints/storage.publicAccessPrevention` | Impedir buckets públicos |

Las organizaciones nuevas reciben varias **activadas por defecto** (*secure by default*). Tipos: **list** (permitir o denegar valores), **boolean** y **custom constraints** (reglas propias con CEL). La política efectiva de un proyecto se ve con `gcloud org-policies describe <constraint> --effective`.

## Usuarios y grupos

Google Cloud **no tiene usuarios propios**: las personas son cuentas de **Cloud Identity** o **Google Workspace** (o federadas). Lo que premia el examen:

- Dar roles a **Google groups**, no a usuarios sueltos (tipos de roles y bindings en la [Sección 4](seccion-4-acceso-seguridad.md)).
- Automatizar altas con **Google Cloud Directory Sync** (GCDS, desde Active Directory o LDAP) o **SCIM** desde un IdP como **Microsoft Entra ID** u Okta, con **SSO** (*Single Sign-On*).

### Workforce Identity Federation

Permite que **personas** de un IdP externo (Entra ID, Okta, cualquier OIDC o SAML 2.0) usen la consola y la API **sin sincronizar sus cuentas** a Cloud Identity. Se crea un **workforce pool** a nivel de **organización** y un **provider** con el mapeo de atributos.

| Necesidad | Solución |
| --- | --- |
| Personas con cuentas en Cloud Identity/Workspace, sincronizadas desde AD | **GCDS** + SSO |
| Personas del IdP externo sin cuentas en Google | **Workforce Identity Federation** |
| **Workloads** (pipelines, apps en AWS/Azure/on-prem) sin claves | **Workload Identity Federation** ([Sección 4](seccion-4-acceso-seguridad.md#workload-identity-federation)) |

!!! tip "En el examen"
    *Workforce* = personas. *Workload* = máquinas y aplicaciones. Si el enunciado dice "employees" y "without creating accounts in Cloud Identity", es Workforce.

## APIs, cuotas y disponibilidad por ubicación

- **APIs**: se habilitan **por proyecto**. El error "API has not been used in project… or it is disabled" se resuelve con `gcloud services enable <api>.googleapis.com`.
- **Quotas** (cuotas): limitan el uso (vCPUs por región, peticiones por minuto). Se consultan y se pide aumento en **IAM & Admin > Quotas & System Limits** (**Cloud Quotas**). Los **system limits** no se aumentan.
- **Productos por región y zona**: no todos los machine types, GPUs o servicios existen en todas partes. Compruébalo con `gcloud compute machine-types list` y `gcloud compute accelerator-types list` filtrando por zona. Ver [Modelos de servicio y regiones](../../../cloud/fundamentos/modelos-de-servicio-y-regiones.md).

!!! tip "En el examen"
    "No se pueden crear más VMs en una región / error `QUOTA_EXCEEDED`" → revisar cuotas y **pedir un aumento**, o usar otra región. No es un problema de IAM. `PERMISSION_DENIED` sí es de IAM.

## Observabilidad, red e inventario desde el primer día

- **Metrics scope**: un proyecto "de monitoreo" que ve las métricas de varios ([Sección 3](seccion-3-operacion-solucion.md#cloud-monitoring)).
- **Red inicial**: cada proyecto trae una **default VPC** en **auto mode** con reglas permisivas. En producción se borra (o se impide con `compute.skipDefaultNetworkCreation`) y se crea una **custom mode VPC** ([Sección 2](seccion-2-planificar-implementar.md#vpc-y-subnets)).
- **Cloud Asset Inventory**: inventario de recursos y políticas de IAM con **historial de 35 días**. Busca (`gcloud asset search-all-resources`, `search-all-iam-policies`), exporta a BigQuery o Cloud Storage y crea **feeds** a Pub/Sub cuando algo cambia. **Gemini Cloud Assist** responde en lenguaje natural sobre esos recursos.

## Facturación

| Pieza | Qué es |
| --- | --- |
| **Cloud Billing account** | Paga uno o varios proyectos. Un proyecto se vincula a **una sola** billing account a la vez. Puede ser **self-serve** (tarjeta) o **invoiced** (factura mensual); los datos del pagador están en el **payments profile** |
| **Budget** | Monto mensual, trimestral o anual con **threshold rules** sobre gasto real o pronosticado |
| **Billing export** | Detalle a **BigQuery** (standard usage cost, detailed usage cost y pricing) para SQL o Looker Studio |

| Rol | Puede |
| --- | --- |
| **Billing Account Administrator** | Gestionar la billing account, vincular proyectos, ver costos |
| **Billing Account User** | **Vincular proyectos** a la billing account (junto con un rol en el proyecto) |
| **Billing Account Viewer** | Ver costos y transacciones |
| **Project Billing Manager** | Vincular o desvincular **un proyecto** a una billing account |

```bash
gcloud billing projects link app-prod-4821 --billing-account=0X0X0X-0X0X0X-0X0X0X
```

!!! warning "Un budget no corta el gasto"
    Los budgets **solo avisan** (correo o canales de Cloud Monitoring). Para reaccionar, conéctalo a un **tema de Pub/Sub** y una función que, por ejemplo, desvincule la facturación o apague recursos. Desvincular la facturación detiene los servicios del proyecto.

!!! tip "En el examen"
    - "Analizar costos por label o servicio con SQL / dashboards" → **billing export a BigQuery** (actívalo pronto: no es retroactivo).
    - "Finanzas debe ver costos pero no tocar recursos" → **Billing Account Viewer**.
    - "Un desarrollador debe poder vincular su proyecto" → **Billing Account User** en la cuenta + permisos en el proyecto.
    - "Avisar antes de pasarse" → budget con umbral sobre **forecasted spend**.

## Casos de uso

1. **Políticas distintas por entorno en una empresa con varias áreas.** → Folders por entorno (o área y entorno) con organization policies en cada folder.
2. **Los datos deben quedarse en Sudamérica.** → `gcp.resourceLocations` con `in:southamerica-locations` en la organización o el folder.
3. **Bajas en Active Directory deben quitar acceso a Google Cloud.** → GCDS (o SCIM desde Entra ID) + roles asignados a grupos.
4. **Consultora con Okta que no quiere cuentas en Cloud Identity.** → Workforce Identity Federation con provider OIDC/SAML de Okta.
5. **No se pueden crear más GPUs en `us-central1`.** → Cloud Quotas (pedir aumento) y verificar el tipo de GPU en otras zonas.
6. **Dashboard de costos por equipo.** → Labels `equipo=` + billing export a BigQuery + Looker Studio.
7. **Saber cada día qué VMs con IP pública hay en la organización.** → Cloud Asset Inventory (`search-all-resources` o export a BigQuery) y feed a Pub/Sub.
8. **Un proyecto de pruebas no debe pasar de 50 USD al mes.** → Budget + Pub/Sub + función que desvincule la billing account al 100%.

## Preguntas de práctica

**1.** Tu empresa quiere que ningún proyecto de la carpeta "Producción" pueda crear VMs con IP externa. ¿Qué haces?

- A. Crear una firewall rule que bloquee el tráfico de salida.
- B. Aplicar la organization policy `compute.vmExternalIpAccess` en el folder "Producción".
- C. Quitar el rol Compute Admin a todos los usuarios.
- D. Crear un custom role sin el permiso `compute.instances.create`.

??? success "Respuesta"
    **B.** Las organization policies limitan **configuraciones** y se heredan a todos los proyectos del folder. A no impide asignar la IP. C y D impiden crear VMs en general, no solo con IP externa.

**2.** Un analista de finanzas debe ver el costo de todos los proyectos de una billing account, sin poder modificar nada. ¿Qué rol le das?

- A. Billing Account Administrator
- B. Billing Account User
- C. Billing Account Viewer
- D. Viewer (basic role) en cada proyecto

??? success "Respuesta"
    **C.** Billing Account Viewer ve costos y transacciones. A permite administrar. B permite vincular proyectos. D da acceso de lectura a recursos, no a la facturación.

**3.** Necesitas analizar el gasto de los últimos meses por label `equipo` con consultas SQL. ¿Qué debes configurar?

- A. Un budget por equipo.
- B. Billing export a BigQuery.
- C. Un log sink de Cloud Logging a BigQuery.
- D. Cloud Asset Inventory export.

??? success "Respuesta"
    **B.** El billing export (detailed usage cost) incluye labels y se consulta con SQL. A solo alerta. C exporta logs, no costos. D exporta inventario, no costos. Recuerda: el export no trae datos anteriores a su activación.

**4.** Un script falla con el error "Compute Engine API has not been used in project … or it is disabled". ¿Cuál es el siguiente paso?

- A. Dar el rol Compute Admin a la cuenta del script.
- B. Ejecutar `gcloud services enable compute.googleapis.com` en el proyecto.
- C. Pedir un aumento de cuota.
- D. Vincular el proyecto a otra billing account.

??? success "Respuesta"
    **B.** El mensaje indica que la **API** no está habilitada en el proyecto. A sería para un error de permisos (`PERMISSION_DENIED`), C para `QUOTA_EXCEEDED`.

**5.** El personal de una empresa se autentica en Microsoft Entra ID. Quieren acceder a la consola de Google Cloud con esas credenciales **sin** sincronizar usuarios a Cloud Identity. ¿Qué usas?

- A. Workload Identity Federation
- B. Google Cloud Directory Sync
- C. Workforce Identity Federation
- D. Service accounts con claves para cada persona

??? success "Respuesta"
    **C.** Workforce Identity Federation es para personas sin cuentas en Cloud Identity. A es para workloads. B sincroniza cuentas (justo lo que no quieren). D es una mala práctica.

**6.** ¿Qué afirmación sobre los budgets de Cloud Billing es correcta?

- A. Detienen los recursos automáticamente al llegar al 100%.
- B. Solo pueden alertar sobre gasto real, no pronosticado.
- C. Envían alertas y pueden publicar en Pub/Sub para automatizar acciones.
- D. Se configuran por VM.

??? success "Respuesta"
    **C.** Los budgets alertan por correo, canales de Monitoring o Pub/Sub. No detienen nada por sí solos (A), admiten umbrales sobre *forecasted spend* (B) y se definen por billing account con filtros de proyectos, servicios o labels (D).

## Para profundizar

- [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md): landing zone, jerarquía y guardrails comparados con AWS Organizations y Azure management groups.
- [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md): principals, roles y allow policies.
- [FinOps y costos](../../../cloud/fundamentos/finops-costos.md): labels, showback y optimización.
- [Modelos de servicio y regiones](../../../cloud/fundamentos/modelos-de-servicio-y-regiones.md): regiones, zonas y cómo elegir.
- [Comandos de gcloud](../../../recursos/comandos/google-cli.md).

## Referencias

- [Resource hierarchy](https://cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy)
- [Organization Policy Service](https://cloud.google.com/resource-manager/docs/organization-policy/overview)
- [Workforce Identity Federation](https://cloud.google.com/iam/docs/workforce-identity-federation)
- [Cloud Asset Inventory](https://cloud.google.com/asset-inventory/docs/overview)
- [Cloud Billing: create budgets](https://cloud.google.com/billing/docs/how-to/budgets)
- [Export Cloud Billing data to BigQuery](https://cloud.google.com/billing/docs/how-to/export-data-bigquery)
