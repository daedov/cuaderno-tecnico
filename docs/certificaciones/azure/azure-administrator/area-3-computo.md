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

**Azure Resource Manager** (ARM) es la capa por la que pasan todas las operaciones sobre recursos (portal, CLI, PowerShell, Terraform). Las **ARM templates** son JSON declarativo; **Bicep** es un lenguaje más legible que se **compila a ARM JSON**. El panorama de herramientas de IaC está en [Infrastructure as Code](../../../devops/iac/infraestructura-como-codigo.md).

| Sección de una ARM template | Para qué |
| --- | --- |
| `$schema`, `contentVersion` | Versión del esquema y de tu plantilla |
| `parameters` | Valores que se pasan al desplegar (con `allowedValues`, `defaultValue`, `minLength`…) |
| `variables` | Valores calculados reutilizables |
| `functions` | Funciones definidas por el usuario |
| `resources` | Lo que se crea: `type`, `apiVersion`, `name`, `location`, `properties`, `dependsOn` |
| `outputs` | Valores que devuelve el despliegue |

```bicep title="main.bicep"
@description('Nombre de la storage account')
@minLength(3)
@maxLength(24)
param storageName string

@allowed([ 'Standard_LRS', 'Standard_ZRS' ])
param sku string = 'Standard_LRS'

param location string = resourceGroup().location

resource st 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: { name: sku }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

output blobEndpoint string = st.properties.primaryEndpoints.blob
```

```bash title="Desplegar, previsualizar, exportar y convertir"
az deployment group what-if  -g rg-app --template-file main.bicep --parameters storageName=stdemo104
az deployment group create   -g rg-app --template-file main.bicep --parameters storageName=stdemo104
az group export -n rg-app > exportado.json          # exportar el resource group como ARM template
az bicep decompile --file exportado.json            # convertir ARM JSON a Bicep
az bicep build --file main.bicep                    # compilar Bicep a ARM JSON
```

| Scope de despliegue | Comando CLI |
| --- | --- |
| Resource group | `az deployment group create` |
| Subscription | `az deployment sub create` |
| Management group | `az deployment mg create` |
| Tenant | `az deployment tenant create` |

!!! tip "En el examen"
    - **Deployment mode**: **Incremental** (por defecto) agrega y actualiza sin borrar lo que no está en la plantilla; **Complete** borra del resource group lo que no esté en la plantilla.
    - En Bicep, `dependsOn` casi nunca hace falta: las dependencias se deducen al referenciar otro recurso (`st.id`).
    - Te pueden mostrar una plantilla y preguntar qué falla: un `allowedValues` que no incluye el valor pasado, un nombre que no cumple `minLength`, un `dependsOn` que falta en JSON.
    - Para desplegar desde el portal una plantilla exportada, a veces hay que **quitar propiedades** de solo lectura o parametrizar nombres.

## Máquinas virtuales

Una **virtual machine** (VM, máquina virtual) en Azure es un recurso que depende de otros: NIC, disco del sistema operativo, VNet/subnet y, opcionalmente, IP pública y NSG. La comparación con EC2 y Compute Engine está en [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md).

```bash title="Crear una VM Linux sin IP pública"
az vm create -g rg-vm -n vm-app01 \
  --image Ubuntu2404 --size Standard_D2s_v5 \
  --vnet-name vnet-app --subnet snet-app \
  --public-ip-address "" --nsg "" \
  --admin-username azureuser --generate-ssh-keys \
  --zone 1
```

### Tamaños

| Familia | Uso |
| --- | --- |
| **B** | *Burstable* (con ráfagas): cargas ligeras y variables |
| **D** | Propósito general |
| **E** | Memoria optimizada |
| **F** | CPU optimizada |
| **L** | Almacenamiento optimizado (discos locales rápidos) |
| **M** | Memoria muy grande (SAP HANA) |
| **N** | GPU |

**Cambiar el tamaño** (*resize*) reinicia la VM. Si el nuevo tamaño no está disponible en el clúster de hardware actual, hay que **detenerla y desasignarla** (*stop/deallocate*) primero. Si está en un availability set, puede que haya que desasignar todas las VMs del set.

!!! warning "Stopped vs Stopped (deallocated)"
    Apagar la VM desde el sistema operativo la deja en **Stopped**: se sigue cobrando el cómputo. Solo **Stopped (deallocated)** (desde el portal o `az vm deallocate`) deja de cobrar el cómputo; los discos se siguen cobrando.

### Discos

| Tipo de managed disk | Uso |
| --- | --- |
| **Ultra Disk** | Latencia mínima e IOPS ajustables (bases de datos exigentes) |
| **Premium SSD v2** | IOPS y throughput ajustables por separado del tamaño |
| **Premium SSD** | Producción |
| **Standard SSD** | Web, desarrollo, cargas ligeras |
| **Standard HDD** | Backups, datos poco usados |

- **OS disk**, **data disks** y **temporary disk** (disco temporal local: se pierde al redimensionar, desasignar o mover la VM; no guardes datos ahí).
- Se puede **aumentar** el tamaño de un disco, no reducirlo.
- **Snapshots** e **images** (*Azure Compute Gallery*) para copiar o crear VMs.
- **Host caching** (*None*, *ReadOnly*, *ReadWrite*) por disco.

```bash title="Agregar un data disk"
az vm disk attach -g rg-vm --vm-name vm-app01 --name vm-app01-data01 \
  --new --size-gb 128 --sku Premium_LRS
```

### Cifrado de discos

| Opción | Qué cifra |
| --- | --- |
| **SSE** (*server-side encryption*) con *platform-managed keys* | Los managed disks en reposo, siempre activo |
| SSE con **customer-managed keys** | Lo mismo con tu clave en Key Vault, vía un **disk encryption set** |
| **Encryption at host** | Además cifra el **disco temporal** y las **cachés** de los discos en el host, de extremo a extremo hasta el storage |
| **Azure Disk Encryption** (ADE) | Cifrado dentro del sistema operativo con BitLocker o DM-Crypt |

Para usar encryption at host hay que registrar la característica `EncryptionAtHost` en el resource provider `Microsoft.Compute` de la subscription y luego activarla en la VM (con la VM desasignada si ya existe).

```bash title="Encryption at host"
az feature register --namespace Microsoft.Compute --name EncryptionAtHost
az vm update -g rg-vm -n vm-app01 --set securityProfile.encryptionAtHost=true
```

!!! info "ADE frente a encryption at host"
    El *study guide* actual evalúa **encryption at host**. Microsoft anunció el retiro de Azure Disk Encryption (con fecha 15 de septiembre de 2028) y recomienda encryption at host para VMs nuevas. Revisa la doc si planeas usar ADE.

### Mover una VM

| Destino | Cómo |
| --- | --- |
| Otro resource group o subscription | **Move** del recurso (mueve la VM con sus discos y NIC; el resource ID cambia; la subscription destino debe estar en el mismo tenant) |
| Otra región | **Azure Resource Mover** (o replicar con Azure Site Recovery y hacer failover) |

### Alta disponibilidad: availability sets y availability zones

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

**Virtual Machine Scale Sets** (VMSS) crea y gestiona un grupo de VMs iguales con **autoscale** (escalado automático).

| Concepto | Detalle |
| --- | --- |
| **Orchestration mode** | **Flexible** (recomendado: VMs completas, mezcla de tamaños, zonas) o **Uniform** (instancias idénticas, modelo clásico) |
| **Autoscale** | Reglas por métrica (CPU > 70 % durante 10 min → +1) o por horario; mínimo, máximo y por defecto |
| **Scale-in policy** | Qué VM se elimina primero: *Default*, *NewestVM*, *OldestVM* |
| **Upgrade policy** | **Manual**, **Automatic** o **Rolling** para aplicar cambios del modelo a las instancias |
| Zonas | Repartir las instancias entre zonas |

```bash title="Scale set con autoscale por CPU"
az vmss create -g rg-vm -n vmss-web --orchestration-mode Flexible \
  --image Ubuntu2404 --vm-sku Standard_B2s --instance-count 2 \
  --zones 1 2 3 --admin-username azureuser --generate-ssh-keys
az monitor autoscale create -g rg-vm --resource vmss-web \
  --resource-type Microsoft.Compute/virtualMachineScaleSets \
  --name as-vmss-web --min-count 2 --max-count 6 --count 2
az monitor autoscale rule create -g rg-vm --autoscale-name as-vmss-web \
  --condition "Percentage CPU > 70 avg 10m" --scale out 1
az monitor autoscale rule create -g rg-vm --autoscale-name as-vmss-web \
  --condition "Percentage CPU < 30 avg 10m" --scale in 1
```

Siempre define una regla de **scale in** además de la de *scale out*; si no, el scale set crece y nunca vuelve a bajar. El concepto agnóstico de autoscaling está en [Resiliencia](../../../cloud/operacion-y-gobierno/resiliencia.md).

## Contenedores: ACR, ACI y Container Apps

Comparativa con otras nubes en [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md); fundamentos de imágenes en [Docker](../../../devops/contenedores/docker.md).

### Azure Container Registry

**Azure Container Registry** (ACR) es el registry privado de imágenes de contenedor y artefactos OCI.

| SKU | Diferencias clave |
| --- | --- |
| **Basic** | Almacenamiento y throughput menores; para aprender y desarrollo |
| **Standard** | Producción típica |
| **Premium** | **Geo-replication**, **private endpoints**, más almacenamiento y throughput, *content trust* |

- El **admin user** viene deshabilitado; lo recomendado es dar **AcrPull** a la managed identity de quien descarga y **AcrPush** al pipeline.
- **ACR Tasks** construyen imágenes en la nube (`az acr build`) sin Docker local.

```bash title="Crear un registry y construir una imagen en la nube"
az acr create -g rg-cont -n acrcuaderno104 --sku Basic
az acr build -r acrcuaderno104 -t web:1.0 .
```

### Azure Container Instances

**Azure Container Instances** (ACI) ejecuta un contenedor o un **container group** (grupo de contenedores que comparten red y almacenamiento, como un pod) sin gestionar servidores.

- Tamaño: CPU y memoria por contenedor, definidos al crear. Para cambiarlos hay que **recrear** el container group.
- **No tiene autoscaling**: escalas creando más container groups.
- **Restart policy**: **Always** (por defecto), **OnFailure** o **Never** (tareas que terminan).
- Puede tener IP pública con etiqueta DNS o desplegarse dentro de una VNet; puede montar Azure Files.

```bash title="Contenedor en ACI"
az container create -g rg-cont -n aci-web \
  --image mcr.microsoft.com/azuredocs/aci-helloworld \
  --cpu 1 --memory 1.5 --ports 80 --ip-address Public \
  --dns-name-label aci-web-cuaderno --os-type Linux --restart-policy OnFailure
```

### Azure Container Apps

**Azure Container Apps** es una plataforma serverless de contenedores basada en Kubernetes (sin gestionarlo), con escalado automático por eventos.

| Concepto | Qué es |
| --- | --- |
| **Environment** | Límite compartido (red, logs) para varias container apps |
| **Revision** | Versión inmutable de la app; puedes repartir tráfico entre revisiones |
| **Ingress** | Exposición HTTP externa o interna |
| **Scale rules** | HTTP (peticiones concurrentes), TCP o eventos vía **KEDA** (colas, Service Bus…); **min replicas 0** permite escalar a cero |
| **Workload profiles** | **Consumption** (pagas por uso) o **Dedicated** (hardware dedicado) |

```bash title="Container App que escala de 0 a 5 réplicas"
az containerapp env create -g rg-cont -n cae-cuaderno -l eastus
az containerapp create -g rg-cont -n ca-web --environment cae-cuaderno \
  --image mcr.microsoft.com/k8se/quickstart:latest \
  --target-port 80 --ingress external \
  --cpu 0.5 --memory 1.0Gi --min-replicas 0 --max-replicas 5 \
  --scale-rule-name http-rule --scale-rule-type http --scale-rule-http-concurrency 50
```

| Necesidad | Servicio |
| --- | --- |
| Un contenedor simple o una tarea batch corta, sin escalado | **ACI** |
| Microservicios o APIs con autoscaling, escalar a cero, revisiones | **Container Apps** |
| Control total de Kubernetes | **AKS** (no está en el temario actual de AZ-104) |
| App web con runtime gestionado | **App Service** |

## Azure App Service

**App Service** hospeda aplicaciones web, APIs y back-ends móviles (código o contenedor) sin administrar servidores. Las apps corren en un **App Service plan**, que define la región, el sistema operativo, el tier y el número de instancias.

| Tier del plan | Para qué | Lo que habilita |
| --- | --- | --- |
| **Free (F1)** / **Shared (D1)** | Pruebas | Infraestructura compartida, sin escalado ni SLA |
| **Basic (B)** | Desarrollo y pruebas | Instancias dedicadas, escalado manual, dominios personalizados con TLS |
| **Standard (S)** | Producción | **Autoscale**, **deployment slots** (hasta 5), backups |
| **Premium (P v3 y siguientes)** | Producción exigente | Más instancias y slots (hasta 20), más rendimiento |
| **Isolated (I v2)** | Aislamiento total | **App Service Environment** dentro de tu VNet |

!!! info "Límites cambiantes"
    El número máximo de instancias y slots por tier, y las versiones de hardware (Pv3, Pv4…), cambian. Para el examen basta con la regla: **autoscale y slots desde Standard**; **dominios personalizados con TLS desde Basic**.

### Escalado

- **Scale up** (vertical): cambiar el tier o el tamaño del plan.
- **Scale out** (horizontal): más instancias, manual o con **autoscale** por métricas u horario. Todas las apps del plan escalan juntas.
- **Automatic scaling** (escalado automático por la plataforma según tráfico HTTP) está disponible en algunos tiers Premium.

### Dominios personalizados y TLS

1. Crear en el DNS un registro **CNAME** (subdominio, p. ej. `www`) o **A** (dominio raíz) más un **TXT** `asuid.<subdominio>` de verificación.
2. Agregar el dominio en **Custom domains** de la app.
3. Agregar un certificado: **App Service managed certificate** (gratis, se renueva solo), uno importado desde **Key Vault** o un PFX subido. Crear el **TLS/SSL binding** (*SNI SSL*).
4. Activar **HTTPS Only** y una versión mínima de TLS.

### Backups

App Service hace **automatic backups** de la app y su configuración en los tiers que lo admiten, y permite **custom backups** a una storage account propia (con programación, retención y opcionalmente la base de datos conectada). Revisa en la doc qué tiers incluyen cada tipo.

### Red de App Service

| Dirección | Función |
| --- | --- |
| Entrada (*inbound*) | **Access restrictions** (reglas por IP, service tag o subnet), **private endpoint** (la app solo se accede desde la VNet) |
| Salida (*outbound*) | **VNet integration** (la app llega a recursos privados de una VNet), **Hybrid Connections** |

### Deployment slots

Los **deployment slots** (ranuras de implementación) son copias vivas de la app con su propio hostname (`app-staging.azurewebsites.net`). Despliegas en *staging*, pruebas, y haces **swap** con producción: el cambio es instantáneo y reversible (otro swap).

- **Slot settings** (*deployment slot setting*, configuración "pegajosa"): las app settings y connection strings marcadas así **no** viajan en el swap (por ejemplo, la cadena de conexión a la base de datos de pruebas).
- **Swap with preview** aplica primero la configuración de destino para validar antes de completar.
- **Traffic %** envía un porcentaje del tráfico de producción a otro slot (pruebas canary).
- **Auto swap** hace el swap automáticamente tras desplegar en un slot.

```bash title="Slot de staging y swap"
az appservice plan create -g rg-web -n plan-web --sku S1 --is-linux
az webapp create -g rg-web -p plan-web -n app-cuaderno104 --runtime "NODE:20-lts"
az webapp deployment slot create -g rg-web -n app-cuaderno104 --slot staging
az webapp deployment slot swap -g rg-web -n app-cuaderno104 --slot staging --target-slot production
```

Las estrategias blue/green y canary en general están en [Despliegue continuo](../../../devops/ci-cd/despliegue-continuo.md).

## Casos de uso

1. **Desplegar la misma infraestructura en dev, test y prod con distintos tamaños.** → Un archivo **Bicep** con parámetros y un archivo de parámetros por entorno; `what-if` antes de cada despliegue.
2. **Una VM debe sobrevivir a la caída de un datacenter de la región.** → Al menos dos VMs en **availability zones** distintas detrás de un load balancer.
3. **Una tienda online tiene picos de tráfico los viernes por la tarde.** → **VMSS** (o App Service Standard+) con autoscale por CPU y una regla programada para los viernes.
4. **Ejecutar cada noche un contenedor que procesa archivos y termina.** → **ACI** con restart policy **Never** u OnFailure (o un *job* de Container Apps).
5. **Una API en contenedores debe escalar a cero sin tráfico y crecer con las peticiones.** → **Container Apps** con `min-replicas 0` y regla HTTP.
6. **Publicar una nueva versión de la web sin caída y con vuelta atrás inmediata.** → App Service **Standard** o superior con **deployment slot** `staging` y **swap**; la cadena de conexión como slot setting.
7. **Cumplimiento exige cifrar también el disco temporal y las cachés de la VM.** → **Encryption at host**.
8. **Trasladar una VM a otra región.** → **Azure Resource Mover** (o Site Recovery).

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
| Azure Functions y serverless | [Serverless](../../../cloud/computo/serverless.md) |
| ARM, Bicep y Terraform | [Infrastructure as Code](../../../devops/iac/infraestructura-como-codigo.md), [Terraform](../../../devops/iac/terraform-basico.md) |
| Imágenes de contenedor y Kubernetes | [Docker](../../../devops/contenedores/docker.md), [Kubernetes](../../../devops/contenedores/kubernetes.md) |
| Blue/green, canary y slots en el pipeline | [Despliegue continuo](../../../devops/ci-cd/despliegue-continuo.md) |
| Escaneo de plantillas e imágenes | [Seguridad de IaC](../../../devsecops/infraestructura-y-contenedores/seguridad-iac.md), [Seguridad de contenedores](../../../devsecops/infraestructura-y-contenedores/seguridad-contenedores.md) |

!!! example "Practica en el laboratorio"
    - [Lab 19: Azure: VNet
    - NSG y una VM con Azure CLI](../../../laboratorios/cloud/azure-vnet-vm.md)

## Referencias

- [Study guide del examen AZ-104](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-104)
- [Estructura y sintaxis de las plantillas ARM](https://learn.microsoft.com/es-es/azure/azure-resource-manager/templates/syntax)
- [¿Qué es Bicep?](https://learn.microsoft.com/es-es/azure/azure-resource-manager/bicep/overview)
- [Modos de implementación de Azure Resource Manager](https://learn.microsoft.com/es-es/azure/azure-resource-manager/templates/deployment-modes)
- [Tamaños de máquinas virtuales](https://learn.microsoft.com/es-es/azure/virtual-machines/sizes/overview)
- [Tipos de discos administrados](https://learn.microsoft.com/es-es/azure/virtual-machines/disks-types)
- [Cifrado del lado del servidor y cifrado en el host](https://learn.microsoft.com/es-es/azure/virtual-machines/disk-encryption)
- [Opciones de disponibilidad de las máquinas virtuales](https://learn.microsoft.com/es-es/azure/virtual-machines/availability)
- [Modos de orquestación de Virtual Machine Scale Sets](https://learn.microsoft.com/es-es/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-orchestration-modes)
- [Niveles de servicio de Azure Container Registry](https://learn.microsoft.com/es-es/azure/container-registry/container-registry-skus)
- [Azure Container Instances](https://learn.microsoft.com/es-es/azure/container-instances/container-instances-overview)
- [Escalado en Azure Container Apps](https://learn.microsoft.com/es-es/azure/container-apps/scale-app)
- [Información general de los planes de App Service](https://learn.microsoft.com/es-es/azure/app-service/overview-hosting-plans)
- [Entornos de ensayo en App Service (deployment slots)](https://learn.microsoft.com/es-es/azure/app-service/deploy-staging-slots)
