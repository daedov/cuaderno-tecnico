---
tags:
  - azure
  - certificacion
  - az-104
  - computo
  - iac
  - contenedores
---

# Deploy and manage Azure compute resources (20–25%)

> Desplegar con ARM templates y Bicep, crear y operar máquinas virtuales y Virtual Machine Scale Sets, contenedores con ACR, ACI y Container Apps, y aplicaciones web con App Service.

!!! info "Qué evalúa esta área"
    Cuatro grupos de habilidades del *study guide* vigente:

    - **Automate deployment of resources by using ARM templates or Bicep files**: interpretar, modificar, desplegar y exportar plantillas, y convertir ARM a Bicep.
    - **Create and configure virtual machines**: crear VMs, *encryption at host*, moverlas entre resource groups, subscriptions o regiones, tamaños, discos, availability zones y availability sets, y Virtual Machine Scale Sets.
    - **Provision and manage containers in the Azure portal**: Azure Container Registry, Azure Container Instances, Azure Container Apps, y su tamaño y escalado.
    - **Create and configure Azure App Service**: plans, escalado, certificados y TLS, dominios personalizados, backups, red y deployment slots.

    Vuelve al [resumen del examen](resumen-examen.md) para ver el resto.

## ARM templates y Bicep

**Azure Resource Manager** (ARM) es la capa por la que pasan todas las operaciones sobre recursos. Las **ARM templates** son JSON declarativo; **Bicep** es más legible y se **compila a ARM JSON**. Panorama de IaC en [Infrastructure as Code](../../../devops/iac/infraestructura-como-codigo.md).

Secciones de una ARM template: `$schema`, `contentVersion`, `parameters` (con `allowedValues`, `defaultValue`, `minLength`…), `variables`, `functions`, `resources` (`type`, `apiVersion`, `name`, `location`, `properties`, `dependsOn`) y `outputs`.

```bash title="Previsualizar, desplegar, exportar y convertir"
az deployment group what-if -g rg-app --template-file main.bicep --parameters storageName=stdemo104
az deployment group create  -g rg-app --template-file main.bicep --parameters storageName=stdemo104
az group export -n rg-app > exportado.json   # exportar el resource group como ARM template
az bicep decompile --file exportado.json     # convertir ARM JSON a Bicep
```

El scope se elige con el comando: `az deployment group | sub | mg | tenant create`.

!!! tip "En el examen"
    - **Deployment mode**: **Incremental** (por defecto) agrega y actualiza sin borrar lo que no está en la plantilla; **Complete** borra del resource group lo que no esté en la plantilla.
    - En Bicep, `dependsOn` casi nunca hace falta: las dependencias se deducen al referenciar otro recurso (`st.id`).
    - Te pueden mostrar una plantilla y preguntar qué falla: un `allowedValues` que no incluye el valor pasado, un nombre que no cumple `minLength`, un `dependsOn` que falta en JSON.
    - Para desplegar desde el portal una plantilla exportada, a veces hay que **quitar propiedades** de solo lectura o parametrizar nombres.

## Máquinas virtuales

Una VM depende de una NIC, un disco de SO, una VNet/subnet y, opcionalmente, IP pública y NSG. Series (B, D, E, F, L, M, N), cómo leer los nombres y el estado **Stopped (deallocated)** están en [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md).

- **Resize** reinicia la VM. Si el tamaño no está en el clúster actual, primero **stop/deallocate**; en un availability set puede que haya que desasignar todas las VMs del set.

!!! warning "Stopped vs Stopped (deallocated)"
    Apagar la VM desde el sistema operativo la deja en **Stopped**: se sigue cobrando el cómputo. Solo **Stopped (deallocated)** (desde el portal o `az vm deallocate`) deja de cobrar el cómputo; los discos se siguen cobrando.

### Discos y cifrado

| Tipo de managed disk | Uso |
| --- | --- |
| **Ultra Disk** | Latencia mínima e IOPS ajustables (bases de datos exigentes) |
| **Premium SSD v2** | IOPS y throughput ajustables por separado del tamaño |
| **Premium SSD** | Producción |
| **Standard SSD** | Web, desarrollo, cargas ligeras |
| **Standard HDD** | Backups, datos poco usados |

- El **temporary disk** se pierde al redimensionar, desasignar o mover la VM.
- Un disco se puede **aumentar**, no reducir. **Host caching**: *None*, *ReadOnly*, *ReadWrite*.
- **Snapshots** e **images** (*Azure Compute Gallery*) para copiar o crear VMs.

| Opción de cifrado | Qué cifra |
| --- | --- |
| **SSE** con *platform-managed keys* | Los managed disks en reposo, siempre activo |
| SSE con **customer-managed keys** | Lo mismo con tu clave en Key Vault, vía un **disk encryption set** |
| **Encryption at host** | Además el **disco temporal** y las **cachés** en el host |
| **Azure Disk Encryption** (ADE) | Dentro del SO con BitLocker o DM-Crypt |

Encryption at host requiere registrar la característica `EncryptionAtHost` en `Microsoft.Compute` y activarla en la VM (desasignada si ya existe).

!!! info "ADE frente a encryption at host"
    El *study guide* actual evalúa **encryption at host**. Microsoft anunció el retiro de Azure Disk Encryption (con fecha 15 de septiembre de 2028) y recomienda encryption at host para VMs nuevas. Revisa la doc si planeas usar ADE.

### Mover una VM y alta disponibilidad

- Otro resource group o subscription → **Move** (con discos y NIC; el resource ID cambia; mismo tenant).
- Otra región → **Azure Resource Mover** (o Site Recovery y failover).

| Opción | Protege ante | SLA de VM (referencia) |
| --- | --- | --- |
| VM única con discos Premium SSD o superiores | Nada adicional | 99,9 % |
| **Availability set** | Fallo de rack (*fault domains*, hasta 3) y mantenimiento planificado (*update domains*, hasta 20, 5 por defecto) | 99,95 % |
| **Availability zones** | Caída de un datacenter completo (zona) | 99,99 % con 2 o más VMs en 2 o más zonas |

!!! tip "En el examen"
    - Una VM se pone en un availability set o en una zona **al crearla**; para cambiarla hay que recrearla (desde los discos).
    - Availability set y availability zone **no** se combinan en la misma VM.
    - "Sobrevivir a la caída de un datacenter" → **zonas**; "dentro de un mismo datacenter, ante fallos de rack" → **availability set**.

### Virtual Machine Scale Sets

| Concepto | Detalle |
| --- | --- |
| **Orchestration mode** | **Flexible** (recomendado: VMs completas, mezcla de tamaños, zonas) o **Uniform** (instancias idénticas) |
| **Autoscale** | Reglas por métrica (CPU > 70 % durante 10 min → +1) o por horario; mínimo, máximo y por defecto |
| **Scale-in policy** | *Default*, *NewestVM*, *OldestVM* |
| **Upgrade policy** | **Manual**, **Automatic** o **Rolling** |

Define siempre una regla de **scale in** además de la de *scale out*; si no, el scale set nunca vuelve a bajar. Autoscaling en general: [Resiliencia](../../../cloud/operacion-y-gobierno/resiliencia.md).

## Contenedores: ACR, ACI y Container Apps

Comparativa con otras nubes en [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md).

| Servicio | Lo que se pregunta |
| --- | --- |
| **ACR** | SKUs **Basic**, **Standard** y **Premium** (solo Premium: **geo-replication**, **private endpoints**, *content trust*). Admin user deshabilitado: usa **AcrPull** / **AcrPush** con managed identity. **ACR Tasks** (`az acr build`) construye sin Docker local |
| **ACI** | Contenedor o **container group** (como un pod). CPU y memoria fijas: para cambiarlas hay que **recrear**. **Sin autoscaling**. **Restart policy**: **Always** (por defecto), **OnFailure** o **Never**. IP pública con DNS o dentro de una VNet; monta Azure Files |
| **Container Apps** | Serverless sobre Kubernetes. **Environment** (red y logs compartidos), **revisions** con reparto de tráfico, **ingress** externo o interno, **scale rules** HTTP, TCP o **KEDA**; **min replicas 0** escala a cero. *Workload profiles*: **Consumption** o **Dedicated** |

| Necesidad | Servicio |
| --- | --- |
| Un contenedor simple o una tarea batch corta, sin escalado | **ACI** |
| Microservicios o APIs con autoscaling, escalar a cero, revisiones | **Container Apps** |
| Control total de Kubernetes | **AKS** (no está en el temario actual de AZ-104) |
| App web con runtime gestionado | **App Service** |

## Azure App Service

Las apps corren en un **App Service plan** (región, SO, tier e instancias).

| Tier del plan | Para qué | Lo que habilita |
| --- | --- | --- |
| **Free (F1)** / **Shared (D1)** | Pruebas | Infraestructura compartida, sin escalado ni SLA |
| **Basic (B)** | Desarrollo y pruebas | Instancias dedicadas, escalado manual, dominios personalizados con TLS |
| **Standard (S)** | Producción | **Autoscale**, **deployment slots** (hasta 5), backups |
| **Premium (P v3 y siguientes)** | Producción exigente | Más instancias y slots (hasta 20), más rendimiento |
| **Isolated (I v2)** | Aislamiento total | **App Service Environment** dentro de tu VNet |

!!! info "Límites cambiantes"
    El número máximo de instancias y slots por tier, y las versiones de hardware (Pv3, Pv4…), cambian. Para el examen basta con la regla: **autoscale y slots desde Standard**; **dominios personalizados con TLS desde Basic**.

- **Escalado**: *scale up* = cambiar tier; *scale out* = más instancias (manual o autoscale). Todas las apps del plan escalan juntas. **Automatic scaling** por tráfico HTTP en algunos tiers Premium.
- **Dominio y TLS**: **CNAME** (subdominio) o **A** (raíz) + **TXT** `asuid.<subdominio>`; agregar en *Custom domains*; certificado **App Service managed** (gratis, se renueva solo), de **Key Vault** o PFX; **TLS/SSL binding** (SNI); **HTTPS Only**.
- **Backups**: *automatic backups* en los tiers que lo admiten y *custom backups* a una storage account propia.
- **Red**: entrada con **access restrictions** o **private endpoint**; salida con **VNet integration** o **Hybrid Connections**.

### Deployment slots

Copias vivas de la app con su propio hostname. Despliegas en *staging* y haces **swap** con producción: instantáneo y reversible.

- **Slot settings** (configuración "pegajosa"): app settings y connection strings marcadas así **no** viajan en el swap.
- **Swap with preview** valida con la configuración de destino antes de completar.
- **Traffic %** manda un porcentaje del tráfico a otro slot (canary). **Auto swap** hace el swap tras desplegar.

Blue/green y canary en general: [Despliegue continuo](../../../devops/ci-cd/despliegue-continuo.md).

## Casos de uso

1. Misma infraestructura en dev, test y prod con distintos tamaños → **Bicep** con un archivo de parámetros por entorno y `what-if`.
2. VM que sobrevive a la caída de un datacenter → dos o más VMs en **availability zones** distintas detrás de un load balancer.
3. Picos de tráfico los viernes → **VMSS** (o App Service Standard+) con autoscale por CPU y regla programada.
4. Contenedor nocturno que procesa archivos y termina → **ACI** con restart policy **Never** u OnFailure (o un *job* de Container Apps).
5. API en contenedores que escala a cero → **Container Apps** con `min-replicas 0` y regla HTTP.
6. Nueva versión sin caída y con vuelta atrás → App Service **Standard+** con slot `staging` y **swap**; connection string como slot setting.
7. Cifrar también disco temporal y cachés → **Encryption at host**.
8. Trasladar una VM a otra región → **Azure Resource Mover** (o Site Recovery).

## Preguntas de práctica

**1.** Despliegas una plantilla ARM en modo **Complete** en un resource group que tiene una VM no incluida en la plantilla. ¿Qué pasa con la VM?

- A. Se conserva sin cambios.
- B. Se elimina.
- C. Se detiene pero se conserva.
- D. El despliegue falla.

??? success "Respuesta"
    **B.** En modo Complete, Resource Manager borra los recursos del resource group que no están en la plantilla. A describe el modo Incremental. C y D no ocurren.

**2.** Quieres cambiar una VM de `Standard_D2s_v5` a una serie que no está disponible en el clúster de hardware actual. ¿Qué haces primero?

- A. Crear un snapshot del disco del SO.
- B. Detener y desasignar la VM.
- C. Moverla a otro resource group.
- D. Quitarle la IP pública.

??? success "Respuesta"
    **B.** Al desasignarla, Azure puede ubicarla en otro clúster con el tamaño nuevo. A es buena práctica pero no habilita el cambio. C y D no afectan al tamaño disponible.

**3.** Tienes una VM creada sin availability set. ¿Cómo la colocas en un availability set existente?

- A. Desde la hoja *Availability + scaling* de la VM.
- B. Con `az vm update --availability-set`.
- C. Recreando la VM a partir de sus discos dentro del availability set.
- D. Moviéndola al resource group del availability set.

??? success "Respuesta"
    **C.** El availability set solo se asigna al crear la VM. A y B no existen para este cambio. D no la agrega al set.

**4.** Un equipo despliega una app en un slot `staging` y hace swap con producción. Tras el swap, producción apunta a la base de datos de pruebas. ¿Qué faltó?

- A. Usar el tier Premium.
- B. Marcar la connection string como **deployment slot setting** en ambos slots.
- C. Activar Auto swap.
- D. Configurar VNet integration.

??? success "Respuesta"
    **B.** Las configuraciones marcadas como slot setting se quedan en su slot durante el swap. A no cambia el comportamiento. C haría el swap automático, con el mismo problema. D no tiene relación.

**5.** Necesitas un contenedor que procese mensajes de una cola de Service Bus, escale según la longitud de la cola y llegue a cero réplicas sin mensajes. ¿Qué servicio usas?

- A. Azure Container Instances.
- B. Azure Container Apps con una regla de escalado KEDA.
- C. App Service plan Basic.
- D. Una VM con Docker.

??? success "Respuesta"
    **B.** Container Apps escala por eventos con KEDA y admite cero réplicas. A no tiene autoscaling. C no escala automáticamente en Basic ni por cola. D requiere gestionar todo a mano.

**6.** ¿Qué necesitas para que una VM de Azure descargue imágenes de un ACR sin usar el admin user?

- A. Habilitar anonymous pull en el registry Basic.
- B. Asignar el rol **AcrPull** a la managed identity de la VM en el registry.
- C. Asignar **Owner** en la subscription a la VM.
- D. Usar un registry Premium.

??? success "Respuesta"
    **B.** Es el patrón recomendado de mínimo privilegio. A expone imágenes y no está disponible en todos los SKU. C es excesivo. D no es requisito.

**7.** Debes garantizar el SLA del 99,99 % para una carga en VMs. ¿Qué despliegas?

- A. Una VM con Premium SSD.
- B. Dos VMs en un availability set.
- C. Dos o más VMs en dos o más availability zones.
- D. Una VM en un scale set con una instancia.

??? success "Respuesta"
    **C.** Es la configuración con SLA de 99,99 %. A da 99,9 %. B da 99,95 %. D sigue siendo una sola instancia.

## Para profundizar

| Tema | Nota del cuaderno |
| --- | --- |
| VMs, familias, discos y modelos de pago en las tres nubes | [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md) |
| ACI, Container Apps y AKS frente a ECS, EKS, Cloud Run y GKE | [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md) |
| ARM, Bicep y Terraform | [Infrastructure as Code](../../../devops/iac/infraestructura-como-codigo.md), [Terraform](../../../devops/iac/terraform-basico.md) |
| Imágenes de contenedor | [Docker](../../../devops/contenedores/docker.md) |
| Blue/green, canary y slots en el pipeline | [Despliegue continuo](../../../devops/ci-cd/despliegue-continuo.md) |
| Práctica guiada | [Lab: Azure VNet, NSG y una VM con Azure CLI](../../../laboratorios/cloud/azure-vnet-vm.md) |

## Referencias

- [Study guide del examen AZ-104](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-104)
- [Modos de implementación de Azure Resource Manager](https://learn.microsoft.com/es-es/azure/azure-resource-manager/templates/deployment-modes)
- [Cifrado del lado del servidor y cifrado en el host](https://learn.microsoft.com/es-es/azure/virtual-machines/disk-encryption)
- [Opciones de disponibilidad de las máquinas virtuales](https://learn.microsoft.com/es-es/azure/virtual-machines/availability)
- [Escalado en Azure Container Apps](https://learn.microsoft.com/es-es/azure/container-apps/scale-app)
- [Entornos de ensayo en App Service (deployment slots)](https://learn.microsoft.com/es-es/azure/app-service/deploy-staging-slots)
