---
tags:
  - azure
  - certificacion
  - az-104
  - iam
  - gobernanza
---

# Manage Azure identities and governance (20–25%)

> Usuarios, grupos y licencias en Microsoft Entra ID, permisos con Azure RBAC y gobierno de suscripciones con management groups, Azure Policy, locks, tags y control de costos.

!!! info "Qué evalúa esta área"
    Según el *study guide* vigente (*skills measured as of April 17, 2026*), esta área tiene tres grupos de habilidades:

    - **Manage Microsoft Entra users and groups**: crear usuarios y grupos, gestionar sus propiedades, licencias, usuarios externos y **SSPR** (*self-service password reset*, restablecimiento de contraseña de autoservicio).
    - **Manage access to Azure resources**: roles integrados de Azure, asignarlos en distintos *scopes* e interpretar asignaciones de acceso.
    - **Manage Azure subscriptions and governance**: Azure Policy, *resource locks*, tags, resource groups, subscriptions, costos (alertas, budgets, Azure Advisor) y management groups.

    Es, junto con cómputo, el área con más peso del examen. Vuelve al [resumen del examen](resumen-examen.md) para ver el resto.

## Microsoft Entra ID: usuarios y grupos

Qué es Entra ID, el tenant, los service principals y las managed identities está en [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md#azure-microsoft-entra-id-azure-rbac). Para el examen:

| Tipo de usuario | Cómo se crea |
| --- | --- |
| **Member** (miembro) | Portal, CLI/PowerShell o en bloque con CSV (*bulk create*) |
| **Guest** (invitado) | Invitación B2B (*Invite external user*) |
| Usuario sincronizado | **Microsoft Entra Connect Sync** o **Cloud Sync** desde el AD local; se edita **en el origen**, no en Entra ID |

| Membership type | Cómo entran los miembros | Requisito |
| --- | --- | --- |
| **Assigned** (asignada) | Alguien los agrega a mano | Ninguno |
| **Dynamic user** | Regla sobre atributos del usuario, p. ej. `(user.department -eq "Ventas")` | Licencia Entra ID P1 |
| **Dynamic device** | Regla sobre atributos del dispositivo (solo security groups) | Licencia Entra ID P1 |

Los grupos **Security** dan acceso a recursos, apps y licencias; los **Microsoft 365** son para colaboración (buzón, SharePoint, Teams).

!!! tip "En el examen"
    - "Que los usuarios entren y salgan del grupo **automáticamente** según su departamento" → **dynamic membership** (requiere P1).
    - Un grupo dinámico **no** admite agregar miembros a mano. Si te piden ambas cosas, la respuesta no es un grupo dinámico.
    - Los grupos de dispositivos dinámicos solo pueden ser **Security**, no Microsoft 365.

**Licencias**: mejor con **group-based licensing** (la licencia se asigna al grupo; requiere al menos P1). El usuario necesita **usage location** o la asignación falla. Puedes desactivar *service plans* concretos.

**Usuarios externos**: **Microsoft Entra B2B collaboration** invita **guest users** que entran con su propia identidad (Entra, cuenta Microsoft, Google o código por correo). Quién puede invitar y a qué dominios se controla en **External collaboration settings**. **Microsoft Entra External ID** agrupa B2B y la identidad de clientes.

### Self-service password reset (SSPR)

| Configuración | Opciones |
| --- | --- |
| Alcance | **None**, **Selected** (un grupo) o **All** |
| Métodos | Authenticator, correo, móvil, teléfono de oficina, preguntas de seguridad; se exigen 1 o 2 |
| Registro y notificaciones | Pedir registro al iniciar sesión; avisar al usuario y a los admins |
| *Password writeback* | Escribir la nueva contraseña en el AD local (usuarios sincronizados) |

!!! warning "Licencias y matices de SSPR"
    - El restablecimiento (no solo el cambio) de contraseña para usuarios de la nube requiere **P1** o un plan de Microsoft 365 que lo incluya; *password writeback* también requiere P1.
    - Los **administradores** siempre tienen SSPR activado con una política más estricta (dos métodos), independientemente de lo que configures para el resto.
    - Microsoft está moviendo la gestión de métodos de SSPR a la política unificada de **Authentication methods**. Revisa la doc vigente si el portal no coincide con estas notas.

!!! tip "En el examen"
    "Probar SSPR solo con un grupo piloto" → alcance **Selected**. Las preguntas de seguridad no sirven como método para administradores.

## Acceso a recursos con Azure RBAC

El modelo (*principal + role + scope*), la herencia hacia abajo y la diferencia entre roles de Entra y roles de Azure están en [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md#azure-microsoft-entra-id-azure-rbac). Lo que añade el examen:

| Built-in role | Qué permite |
| --- | --- |
| **Owner** | Todo, incluido asignar roles a otros |
| **Contributor** | Crear y gestionar todos los recursos, **sin** asignar roles |
| **Reader** | Ver recursos, sin cambiar nada |
| **User Access Administrator** | Solo gestionar el acceso (asignar roles) |
| **Role Based Access Control Administrator** | Asignar roles, y se puede limitar con condiciones qué roles y a quién |
| Roles por servicio | P. ej. **Virtual Machine Contributor**, **Network Contributor**, **Storage Account Contributor**, **Storage Blob Data Reader** |

- Scopes: root management group → management group → subscription → resource group → resource. Lo asignado se **hereda** hacia abajo.
- Los permisos son **aditivos**: Reader en la subscription + Contributor en un resource group = Contributor en ese resource group.
- Los **deny assignments** bloquean aunque un rol permita; no los creas tú, los crean servicios como Azure Blueprints o *deployment stacks*.
- En **Access control (IAM)**: **Check access** (roles de alguien en ese scope, con heredados), **Role assignments** (columna *Scope*: "This resource" o "(Inherited)") y **Roles** (`Actions`, `NotActions`, `DataActions`, `NotDataActions`).
- **Custom roles**: JSON con esas cuatro listas y `AssignableScopes`. El study guide actual se centra en roles integrados.

!!! warning "Control plane vs data plane"
    Roles como **Contributor** o **Storage Account Contributor** gestionan el recurso (*control plane*, plano de control). Leer blobs con identidad de Entra necesita un rol de *data plane* (plano de datos) como **Storage Blob Data Reader**. Un Owner de la storage account puede leer los blobs porque puede obtener las *access keys*, no porque tenga un rol de datos.

Un **Global Administrator** (rol de Entra, scope tenant o *administrative unit*) no ve las subscriptions por defecto, pero puede activar *Access management for Azure resources* para darse **User Access Administrator** en el root management group (uso excepcional).

!!! tip "En el examen"
    - "Que pueda crear VMs pero no dar permisos a nadie" → **Contributor** (o Virtual Machine Contributor si solo son VMs).
    - "Que pueda gestionar usuarios del directorio" → rol de **Entra**, no de Azure.
    - Asigna a **grupos** y en el scope más bajo que cumpla el requisito (*least privilege*, mínimo privilegio).

## Subscriptions, resource groups y management groups

| Nivel | Detalles que se preguntan |
| --- | --- |
| **Management group** | Agrupa subscriptions para aplicar policies y RBAC en bloque. Hasta 6 niveles (sin contar root ni subscriptions); una subscription tiene un solo padre |
| **Subscription** | Límite de facturación, cuotas y acceso. Confía en **un** tenant; se puede mover de management group o transferir su facturación |
| **Resource group** | Cada recurso está en **uno solo**; borrarlo borra todo. Su ubicación solo indica dónde van los metadatos; los recursos pueden estar en otra región |

Al **mover recursos** entre resource groups o subscriptions, el *resource ID* cambia, ambos resource groups quedan bloqueados para escritura durante la operación y no todos los recursos admiten moverse. Landing zones y estrategia multi-suscripción: [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md).

## Azure Policy

**Azure Policy** evalúa la **configuración** de los recursos. RBAC dice **quién** puede actuar; Policy dice **cómo** deben quedar los recursos.

| Concepto | Qué es |
| --- | --- |
| **Policy definition** | Una regla en JSON (condición + efecto) |
| **Initiative** (*policy set definition*) | Varias definitions que se asignan juntas |
| **Assignment** | Aplicar una definition o initiative a un scope, con parámetros y exclusiones |
| **Exemption** | Excepción temporal o permanente |
| **Remediation task** | Corrige recursos existentes (para `Modify` y `DeployIfNotExists`) |

| Effect | Qué hace |
| --- | --- |
| **Deny** | Bloquea la creación o el cambio |
| **Audit** | Permite, pero marca *non-compliant* |
| **Append** / **Modify** | Agrega o cambia propiedades o tags |
| **DeployIfNotExists** / **AuditIfNotExists** | Despliega / marca si falta un recurso complementario (extensión, diagnostic setting) |
| **DenyAction** | Bloquea acciones concretas, como borrar |
| **Disabled** | Desactiva la regla sin quitar la asignación |

!!! tip "En el examen"
    - "Impedir crear recursos fuera de East US" → policy **Allowed locations** con efecto **Deny**.
    - "Que todo recurso herede el tag `costCenter` de su resource group" → **Inherit a tag from the resource group** (efecto `Modify`) + **remediation task** para los recursos que ya existían.
    - `Modify` y `DeployIfNotExists` necesitan una **managed identity** en la asignación para poder corregir.
    - Una policy con `Deny` **no** borra ni cambia los recursos existentes: solo los reporta como no conformes.

## Resource locks y tags

| Lock | Efecto |
| --- | --- |
| **CanNotDelete** (*Delete* en el portal) | Se puede leer y modificar, pero no borrar |
| **ReadOnly** (*Read-only*) | Se puede leer, pero no modificar ni borrar |

- Se heredan: un lock en el resource group protege todos sus recursos.
- Solo afectan al *control plane*. Un ReadOnly en una storage account no impide escribir blobs con una SAS, pero **sí** impide listar las *access keys* (es una operación POST), lo que rompe al portal y a herramientas que dependen de ellas.
- Para crear o quitar locks hace falta `Microsoft.Authorization/locks/*`: **Owner** o **User Access Administrator** lo tienen; **Contributor** no.

Los **tags** **no se heredan** del resource group ni de la subscription: para eso usas Azure Policy. Hasta 50 por recurso, resource group o subscription, y no todos los tipos de recurso los aceptan. Estrategia de tagging: [FinOps y costos](../../../cloud/fundamentos/finops-costos.md).

## Costos: budgets, alertas y Azure Advisor

| Herramienta | Para qué |
| --- | --- |
| **Cost analysis** (Microsoft Cost Management) | Gasto por servicio, resource group, tag, región |
| **Budgets** | Monto por periodo con alertas sobre el gasto **real** o **pronosticado** (*forecasted*) |
| **Cost alerts** | Alertas de budget, de anomalías y de crédito |
| **Azure Advisor** | Recomendaciones en cinco categorías: Cost, Security, Reliability, Operational Excellence y Performance |
| **Pricing calculator** / **TCO calculator** | Estimar costos antes de desplegar / comparar con on-premises |

!!! warning "Un budget no apaga nada"
    Un budget **solo avisa**. Si quieres reaccionar (apagar VMs, por ejemplo) lo conectas a un **action group** que dispare un runbook de Azure Automation, una Logic App o una Function.

Ahorros que aparecen en Advisor y en el examen: **Reservations** (1 o 3 años), **Azure savings plan for compute**, **Azure Hybrid Benefit** (licencias de Windows Server y SQL Server) y **Spot VMs**.

## Casos de uso

1. Nuevos empleados de Ventas con acceso al CRM y licencia automáticos → grupo de seguridad **dinámico** con licencia y app asignadas al grupo (P1).
2. Auditor externo que ve una subscription durante un mes → **guest** B2B con **Reader** en la subscription; quitarlo al terminar (o *access reviews*).
3. Producción no puede tener recursos fuera de dos regiones → **Allowed locations** con `Deny` en el **management group** de producción.
4. Nadie debe borrar por error la VNet compartida → lock **CanNotDelete** en el resource group de red.
5. Correo cuando el gasto previsto supere el 90 % → **budget** con alerta sobre el costo **forecasted**.
6. Soporte reinicia VMs pero no crea redes ni da permisos → **Virtual Machine Contributor** (o custom role con `Microsoft.Compute/virtualMachines/restart/action`) al grupo en el resource group.
7. Demasiadas llamadas por contraseñas olvidadas → **SSPR** con alcance All y dos métodos; *password writeback* si vienen del AD local.

## Preguntas de práctica

**1.** Asignaste a Laura el rol **Reader** en la subscription `sub-prod` y el rol **Contributor** en el resource group `rg-web` de esa subscription. ¿Qué puede hacer en `rg-web`?

- A. Solo leer, porque el rol más restrictivo gana.
- B. Crear y modificar recursos, pero no asignar roles.
- C. Todo, incluido asignar roles.
- D. Nada, porque hay un conflicto de asignaciones.

??? success "Respuesta"
    **B.** Azure RBAC es **aditivo**: en `rg-web` suma Reader (heredado) y Contributor, y Contributor no incluye asignar roles. A es falso porque no hay "el más restrictivo gana" (eso solo pasaría con un deny assignment). C sería Owner. D no existe en RBAC.

**2.** Debes impedir que se borre una storage account, pero las aplicaciones deben poder seguir cambiando su configuración. ¿Qué usas?

- A. Lock ReadOnly en la storage account.
- B. Lock CanNotDelete en la storage account.
- C. Asignar Reader a todos los usuarios.
- D. Policy con efecto Audit.

??? success "Respuesta"
    **B.** CanNotDelete permite modificar pero no borrar. A impediría cambios (y además bloquearía listar las *access keys*). C quita permisos a todos, no solo el borrado. D solo reporta, no impide nada.

**3.** Creaste una policy **Inherit a tag from the resource group** con efecto Modify. Los recursos nuevos reciben el tag, pero los 200 recursos que ya existían no. ¿Qué haces?

- A. Volver a crear la asignación con efecto Deny.
- B. Crear una **remediation task** para la asignación.
- C. Aplicar un lock ReadOnly al resource group.
- D. Esperar 24 horas: Policy los corregirá solo.

??? success "Respuesta"
    **B.** `Modify` actúa en creaciones y actualizaciones; para lo existente necesitas una remediation task (que usa la managed identity de la asignación). A bloquearía, no corregiría. C impediría justamente que se apliquen tags. D: la evaluación periódica marca el incumplimiento, pero no corrige.

**4.** Quieres que los usuarios de un grupo piloto prueben el restablecimiento de contraseña antes de abrirlo a toda la empresa. ¿Qué configuras?

- A. SSPR con alcance **All** y un método.
- B. SSPR con alcance **Selected** apuntando al grupo piloto.
- C. Conditional Access que exija MFA al grupo piloto.
- D. Password writeback para el grupo piloto.

??? success "Respuesta"
    **B.** Selected limita SSPR a un grupo. A lo abre a todos. C no habilita el restablecimiento. D es para escribir la contraseña en el AD local y no limita el alcance.

**5.** Un usuario con el rol **Global Administrator** en Entra ID no ve ninguna subscription en el portal de Azure. ¿Por qué?

- A. Le falta una licencia P2.
- B. Los roles de Entra ID no dan permisos sobre recursos de Azure por defecto.
- C. El tenant no tiene management groups.
- D. Debe tener MFA activado.

??? success "Respuesta"
    **B.** Roles de Entra y roles de Azure son sistemas distintos. Puede elevar su acceso (*Access management for Azure resources*) para obtener User Access Administrator en el root, pero no lo tiene por defecto. A, C y D no explican la falta de acceso.

**6.** Un budget mensual de 1 000 USD en una subscription de pruebas llegó al 100 %. ¿Qué pasa con las VMs?

- A. Se detienen automáticamente.
- B. Se desasignan y se conservan los discos.
- C. Siguen funcionando; el budget solo envía alertas, salvo que conectes una acción.
- D. La subscription se deshabilita.

??? success "Respuesta"
    **C.** Los budgets avisan; para actuar necesitas un action group con un runbook, Logic App o Function. A, B y D no ocurren por un budget (D puede pasar en subscriptions con límite de gasto, como algunas de prueba, pero no por un budget).

**7.** ¿Qué rol mínimo necesita una persona para crear y quitar resource locks en un resource group?

- A. Contributor.
- B. Reader.
- C. User Access Administrator u Owner.
- D. Storage Account Contributor.

??? success "Respuesta"
    **C.** Los locks requieren `Microsoft.Authorization/locks/*`, que tienen Owner y User Access Administrator. Contributor excluye `Microsoft.Authorization/*/Write` y `Delete`. B y D tampoco lo incluyen.

## Para profundizar

| Tema | Nota del cuaderno |
| --- | --- |
| Entra ID, RBAC y equivalencias con AWS y Google Cloud | [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md) |
| Landing zones, guardrails, tagging, jerarquía | [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md) |
| Budgets, reservas, savings plans, showback | [FinOps y costos](../../../cloud/fundamentos/finops-costos.md) |
| Policy as code y escaneo de configuraciones | [Seguridad de IaC](../../../devsecops/infraestructura-y-contenedores/seguridad-iac.md), [CSPM](../../../devsecops/escaneos/cspm.md) |
| Identidades de workloads y OIDC desde el pipeline | [Secretos e identidades](../../../devsecops/identidades-y-pipeline/secretos-identidades.md) |
| Práctica guiada | [Lab: Azure VNet, NSG y una VM con Azure CLI](../../../laboratorios/cloud/azure-vnet-vm.md) |

## Referencias

- [Study guide del examen AZ-104](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-104)
- [Reglas de pertenencia dinámica a grupos](https://learn.microsoft.com/es-es/entra/identity/users/groups-dynamic-membership)
- [Cómo funciona SSPR](https://learn.microsoft.com/es-es/entra/identity/authentication/concept-sspr-howitworks)
- [Roles integrados de Azure](https://learn.microsoft.com/es-es/azure/role-based-access-control/built-in-roles)
- [Estructura de definición de Azure Policy: efectos](https://learn.microsoft.com/es-es/azure/governance/policy/concepts/effect-basics)
- [Bloqueo de recursos](https://learn.microsoft.com/es-es/azure/azure-resource-manager/management/lock-resources)
