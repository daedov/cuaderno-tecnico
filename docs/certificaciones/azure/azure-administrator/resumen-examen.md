---
tags:
  - azure
  - certificacion
  - az-104
---

# Azure Administrator Associate (AZ-104): resumen del examen

> Qué evalúa el examen AZ-104, cómo es el formato, cómo se reparten las áreas de habilidad y un plan de estudio con laboratorio práctico para obtener la certificación Microsoft Certified: Azure Administrator Associate.

!!! warning "Versión del temario"
    Estas notas siguen el *study guide* oficial con **skills measured as of April 17, 2026** (consultado en octubre de 2026). Microsoft actualiza el temario varias veces al año y publica los cambios en la sección *Change log* del study guide. La versión en **inglés** se actualiza primero; las traducciones (incluido el español) se actualizan unas ocho semanas después. Revisa el study guide antes de agendar.

Lo genérico de cualquier examen (ritmo, *flag for review*, palabras clave, *online proctored*, dumps) está en [Cómo preparar un examen](../../como-preparar-un-examen.md). Aquí solo va lo propio de AZ-104.

## ¿Qué es?

**Microsoft Certified: Azure Administrator Associate** es la certificación de nivel *Associate* (intermedio) para quien **implementa, administra y monitorea** un entorno de Azure: identidades, gobierno, almacenamiento, cómputo, redes virtuales, monitoreo y backup. Se obtiene aprobando **un solo examen: AZ-104**. Es el equivalente a la [Associate Cloud Engineer de Google Cloud](../../google-cloud/associate-cloud-engineer/resumen-examen.md).

## Formato del examen

| Dato | Valor |
| --- | --- |
| Código | **AZ-104: Microsoft Azure Administrator** |
| Duración | **100 minutos** para responder (unos 120 minutos de tiempo en la sala, con instrucciones y encuesta); 120/140 si el examen incluye laboratorios |
| Número de preguntas | No es fijo; Microsoft indica que la mayoría de sus exámenes tiene entre **40 y 60** |
| Tipos de pregunta | Opción múltiple, arrastrar y soltar, *hot area* (seleccionar en una imagen), *build list*, series de "¿esta solución cumple el objetivo?" (*Yes/No*), **case studies** (casos de estudio) y posibles **interactive components** (componentes interactivos o laboratorios) |
| Puntaje para aprobar | **700** en una escala de 1 a 1000 (es un puntaje escalado, no un 70 % de aciertos) |
| Precio | **165 USD** en Estados Unidos; el precio depende del país donde se presenta (en muchos países de Latinoamérica es menor) |
| Modalidad | Centro de Pearson VUE o en línea con supervisión (*online proctored*, OnVUE) |
| Idiomas | Inglés, **español**, japonés, chino simplificado, chino tradicional, coreano, francés, alemán, portugués (Brasil) e italiano |
| Validez | **12 meses**; se renueva gratis con un *renewal assessment* en línea en Microsoft Learn (dentro de los 6 meses previos al vencimiento) |
| Requisitos previos | Ninguno obligatorio |
| Reintentos | Puedes repetir a las 24 horas del primer intento; los siguientes tienen esperas mayores (ver *retake policy*) |

## Particularidades de los exámenes de Microsoft

!!! info "Microsoft Learn abierto durante el examen"
    En los exámenes de nivel Associate puedes abrir **Microsoft Learn** dentro del examen (solo `learn.microsoft.com`, sin Q&A ni tu perfil). El reloj no se detiene: úsalo para dudas puntuales (un nombre de comando, un límite), no para cada pregunta.

- **Case studies y series Yes/No**: al terminar una sección de caso de estudio o una serie de "¿esta solución cumple el objetivo?" **no puedes volver** a ella. Revisa antes de pasar.
- **Pausas**: si tomas un descanso, no puedes volver a las preguntas vistas antes de él.
- **¿Hay laboratorios?** La página del examen dice que *puede* haber componentes interactivos; Microsoft no publica en qué exámenes. La pantalla de introducción indica la duración y si hay laboratorios. Prepárate igual para hacer las tareas en el portal y con CLI.
- **Renovación anual gratuita**: a diferencia de AWS o Google, vence a los 12 meses, pero el *renewal assessment* no cuesta nada.

!!! tip "Trampas propias de AZ-104"
    - *Without downtime* (sin tiempo de inactividad) suele decidir entre dos opciones válidas (p. ej. availability zones, deployment slots).
    - Descarta por requisitos técnicos: tier mínimo (slots desde Standard), SKU (Bastion `/26`, Archive no en ZRS), región (vault de backup en la misma región que la VM), licencia (grupos dinámicos con P1).

## Objetivo profesional

Pensada para quien administra Azure en el día a día y coordina con redes, seguridad, bases de datos y DevOps; el study guide pide práctica con PowerShell, Azure CLI, el portal, ARM o Bicep y Entra ID (AZ-900 es opcional si empiezas de cero). Sirve para [Cloud Engineer](../../roles-profesionales.md#cloud-engineer), [Infrastructure Engineer / SysAdmin](../../roles-profesionales.md#infrastructure-engineer-sysadmin-moderno) y [Support / Cloud Operations](../../roles-profesionales.md#support-cloud-operations). Es **prerrequisito obligatorio** de AZ-305 (arquitectura) y una de las vías para AZ-400 (DevOps); también siguen AZ-700 (redes), SC-500 (seguridad) o [Terraform Associate](../../hashicorp/terraform-associate/resumen-examen.md). Ver [Otras certificaciones](../../otras-certificaciones.md#microsoft-azure).

## Áreas de habilidad y su peso

| Área (*skill area*) | Peso | Nota |
| --- | --- | --- |
| Manage Azure identities and governance | 20–25 % | [Área 1](area-1-identidades-gobierno.md) |
| Implement and manage storage | 15–20 % | [Área 2](area-2-almacenamiento.md) |
| Deploy and manage Azure compute resources | 20–25 % | [Área 3](area-3-computo.md) |
| Implement and manage virtual networking | 15–20 % | [Área 4](area-4-redes-virtuales.md) |
| Monitor and maintain Azure resources | 10–15 % | [Área 5](area-5-monitoreo-mantenimiento.md) |

### Qué cambió en la versión del 17 de abril de 2026

Según el *change log* oficial, los cambios fueron **menores** dentro de los grupos de habilidades (sin áreas nuevas). Algunos puntos que conviene notar en el temario actual:

- **Encryption at host** para VMs (en lugar de Azure Disk Encryption).
- **Azure Container Apps** junto a ACI y ACR; **AKS no aparece** en el temario.
- **Soft delete de blobs y containers** y **snapshots/soft delete de Azure Files**.
- Monitoreo con **Azure Monitor Insights** y **Connection monitor**.
- En identidades, el foco está en **roles integrados**; los custom roles no se nombran.

### Servicios que más salen

| Área | Servicios y conceptos principales |
| --- | --- |
| Identidades y gobierno | Entra ID (grupos dinámicos, licencias, B2B, SSPR), RBAC, management groups, Azure Policy, locks, tags, budgets, Advisor |
| Storage | Redundancia (LRS a RA-GZRS), SAS y stored access policies, private endpoints, Blob (tiers, lifecycle, versioning, soft delete), Azure Files, AzCopy |
| Cómputo | ARM/Bicep, VMs (discos, encryption at host, availability sets y zones), VMSS, ACR, ACI, Container Apps, App Service (plans, slots) |
| Redes | VNets, peering, UDRs, NSGs, ASGs, Bastion, service y private endpoints, Azure DNS, Load Balancer |
| Monitoreo y mantenimiento | Azure Monitor (KQL, alertas, action groups), Network Watcher, Azure Backup, Azure Site Recovery |

Fuera del foco (aparecen como distractores): AKS, Azure Firewall en detalle, VPN Gateway y ExpressRoute en profundidad, Azure Functions, bases de datos. La lista completa está en el [study guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-104).

## Plan de estudio de 6 semanas

| Semana | Tema | Práctica |
| --- | --- | --- |
| 1 | Área 1: Entra ID, RBAC, Policy, locks, tags, costos | Crear usuarios y grupos dinámicos, asignar roles en distintos scopes, asignar la policy *Allowed locations*, crear un budget |
| 2 | Área 4: redes virtuales | VNets, peering hub-spoke, NSG/ASG, UDR, Bastion, DNS privado, load balancer; diagnosticar con Network Watcher |
| 3 | Área 3 (I): ARM/Bicep y VMs | Desplegar con Bicep y `what-if`, discos, availability zones, VMSS con autoscale |
| 4 | Área 3 (II): contenedores y App Service | ACR + ACI + Container Apps; web app con slot de staging y swap |
| 5 | Área 2: storage | Redundancia, SAS y stored access policies, lifecycle, versioning, Azure Files, AzCopy |
| 6 | Área 5 y repaso | Diagnostic settings, KQL, alertas; backup y restore de una VM; test failover con Site Recovery; *practice assessment* y repaso de errores |

!!! tip "Orden recomendado"
    Empezar por identidades y redes ayuda: casi todas las preguntas de cómputo y storage dependen de permisos, subnets y NSGs.

## Recursos oficiales gratuitos

| Recurso | Para qué |
| --- | --- |
| [Study guide AZ-104](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-104) | El temario vigente y el change log |
| [Página de la certificación](https://learn.microsoft.com/es-es/credentials/certifications/azure-administrator/) | Formato, idiomas, agenda, renovación y rutas de aprendizaje (curso AZ-104T00) |
| [Practice Assessment](https://learn.microsoft.com/en-us/credentials/certifications/exams/az-104/practice/assessment?assessment-type=practice&assessmentId=21) | Preguntas de práctica oficiales y gratuitas |
| [Exam sandbox](https://aka.ms/examdemo) | Probar la interfaz y los tipos de pregunta |
| [Laboratorios del curso en GitHub](https://github.com/MicrosoftLearning/AZ-104-MicrosoftAzureAdministrator) | Instrucciones de los laboratorios oficiales del curso |
| [Cuenta gratuita de Azure](https://azure.microsoft.com/es-es/free/) | Crédito inicial y servicios gratuitos para practicar |

## Laboratorio práctico

Un recorrido corto por gobierno, red y diagnóstico en una subscription de pruebas, con **Azure Cloud Shell** (ya trae `az`). Un lab guiado más completo está en [Lab: Azure VNet, NSG y una VM](../../../laboratorios/cloud/azure-vnet-vm.md).

!!! danger "Costos y limpieza"
    Todo se crea en **un solo resource group** para borrarlo al final. Crea un **budget** con alerta antes de empezar. Si activaste backup, primero detén la protección y borra los datos (el soft delete puede retener el vault 14 días). Network Watcher crea `NetworkWatcherRG` en cada región; no cuesta por sí solo, pero los flow logs y connection monitors sí.

```bash title="Gobierno, red y diagnóstico"
RG=rg-az104-lab; LOC=eastus
az group create -n $RG -l $LOC --tags env=lab owner=dani
RG_ID=$(az group show -n $RG --query id -o tsv)
# Policy integrada "Allowed locations" y lock de no borrado
az policy assignment create --name solo-eastus --scope "$RG_ID" \
  --policy e56962a6-4747-49cd-b67b-bf8b01975c4c \
  --params '{"listOfAllowedLocations":{"value":["eastus"]}}'
az lock create --name no-borrar --resource-group $RG --lock-type CanNotDelete
az role assignment list --scope "$RG_ID" --include-inherited -o table
# VNet con NSG en la subnet y VM sin IP pública
az network vnet create -g $RG -n vnet-lab --address-prefixes 10.10.0.0/16 \
  --subnet-name snet-app --subnet-prefixes 10.10.1.0/24
az network nsg create -g $RG -n nsg-app
az network vnet subnet update -g $RG --vnet-name vnet-lab -n snet-app --network-security-group nsg-app
az vm create -g $RG -n vm-lab --image Ubuntu2404 --size Standard_B2s \
  --vnet-name vnet-lab --subnet snet-app --public-ip-address "" --nsg "" \
  --admin-username azureuser --generate-ssh-keys
az network watcher test-ip-flow -g $RG --vm vm-lab --direction Inbound \
  --protocol TCP --local 10.10.1.4:22 --remote 10.10.1.10:50000
```

```bash title="Limpieza"
# El lock impide borrar el resource group: quítalo primero
az lock delete --name no-borrar --resource-group rg-az104-lab
az group delete -n rg-az104-lab --yes --no-wait
```

## Para profundizar

| Tema | Nota del cuaderno |
| --- | --- |
| Identidad y RBAC en las tres nubes | [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md) |
| Gobierno y costos | [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md), [FinOps y costos](../../../cloud/fundamentos/finops-costos.md) |
| Storage y redundancia | [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md) |
| Cómputo y contenedores | [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md), [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md) |
| Redes | [Redes en la nube](../../../cloud/redes-y-datos/redes.md) |
| Monitoreo y DR | [Observabilidad nativa](../../../cloud/operacion-y-gobierno/observabilidad-nativa.md), [Resiliencia](../../../cloud/operacion-y-gobierno/resiliencia.md) |

## Referencias

- [Study guide del examen AZ-104 (inglés, se actualiza primero)](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-104)
- [Microsoft Certified: Azure Administrator Associate](https://learn.microsoft.com/es-es/credentials/certifications/azure-administrator/)
- [Duración y experiencia del examen](https://learn.microsoft.com/es-es/credentials/support/exam-duration-exam-experience)
- [Renovar la certificación de Microsoft](https://learn.microsoft.com/es-es/credentials/certifications/renew-your-microsoft-certification)
- [Directiva de repetición de exámenes](https://learn.microsoft.com/es-es/credentials/support/retake-policy)
- [Documentación de la CLI de Azure](https://learn.microsoft.com/es-es/cli/azure/)
