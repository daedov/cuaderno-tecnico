# Shared Responsibility Model

## ¿Qué es?

El **Shared Responsibility Model** (modelo de responsabilidad compartida) es el marco que define qué tareas de seguridad y operación le corresponden al **proveedor de la nube** y cuáles le corresponden al **cliente** (tú, como usuario/organización).

La idea central es simple:

> El proveedor es responsable de la seguridad **DE** la nube, *security OF the cloud* (la infraestructura física, el hardware, la red global, y el software que sostiene los servicios).
> El cliente es responsable de la seguridad **EN** la nube, *security IN the cloud* (cómo configura, usa y protege lo que despliega sobre esa infraestructura).

Este modelo **no elimina responsabilidades**, solo las reparte. Un error común es asumir que "está en la nube, entonces el proveedor lo protege". Eso es falso: la mayoría de brechas de seguridad (*security breaches*) en la nube ocurren por **misconfigurations** (malas configuraciones) **del lado del cliente** (buckets públicos, IAM mal definido, credenciales expuestas, etc.), no por fallas del proveedor.

## Capas típicas del modelo

En términos generales, las responsabilidades se dividen así, y varían según el modelo de servicio contratado:

<table class="rc-tabla">
<thead>
<tr>
<th>Capa</th>
<th>IaaS</th>
<th>PaaS</th>
<th>SaaS</th>
</tr>
</thead>
<tbody>
<tr>
<td>Instalaciones físicas (datacenters)</td>
<td class="rc-proveedor">Proveedor</td>
<td class="rc-proveedor">Proveedor</td>
<td class="rc-proveedor">Proveedor</td>
</tr>
<tr>
<td>Hardware e infraestructura de red global</td>
<td class="rc-proveedor">Proveedor</td>
<td class="rc-proveedor">Proveedor</td>
<td class="rc-proveedor">Proveedor</td>
</tr>
<tr>
<td>Virtualización / <em>hypervisor</em> (hipervisor)</td>
<td class="rc-proveedor">Proveedor</td>
<td class="rc-proveedor">Proveedor</td>
<td class="rc-proveedor">Proveedor</td>
</tr>
<tr>
<td>Almacenamiento y red física subyacente</td>
<td class="rc-proveedor">Proveedor</td>
<td class="rc-proveedor">Proveedor</td>
<td class="rc-proveedor">Proveedor</td>
</tr>
<tr>
<td>Sistema operativo (<em>patching</em> o parches, <em>hardening</em> o bastionado)</td>
<td class="rc-cliente"><strong>Cliente</strong></td>
<td class="rc-proveedor">Proveedor</td>
<td class="rc-proveedor">Proveedor</td>
</tr>
<tr>
<td>Runtime / middleware (motor de BD, lenguaje, contenedor)</td>
<td class="rc-cliente"><strong>Cliente</strong></td>
<td class="rc-proveedor">Proveedor</td>
<td class="rc-proveedor">Proveedor</td>
</tr>
<tr>
<td>Configuración de red (VPC, <em>subnets</em> o subredes, <em>firewalls</em>, <em>security groups</em>)</td>
<td class="rc-cliente"><strong>Cliente</strong></td>
<td class="rc-cliente"><strong>Cliente</strong> (parcial, según servicio)</td>
<td class="rc-proveedor">Proveedor</td>
</tr>
<tr>
<td>IAM (<em>Identity and Access Management</em>, gestión de identidades y accesos)</td>
<td class="rc-cliente"><strong>Cliente</strong></td>
<td class="rc-cliente"><strong>Cliente</strong></td>
<td class="rc-cliente"><strong>Cliente</strong></td>
</tr>
<tr>
<td>Configuración de la aplicación</td>
<td class="rc-cliente"><strong>Cliente</strong></td>
<td class="rc-cliente"><strong>Cliente</strong></td>
<td class="rc-proveedor">Proveedor (poca o ninguna personalización)</td>
</tr>
<tr>
<td>Datos y su clasificación / <em>encryption</em> (cifrado)</td>
<td class="rc-cliente"><strong>Cliente</strong></td>
<td class="rc-cliente"><strong>Cliente</strong></td>
<td class="rc-cliente"><strong>Cliente</strong></td>
</tr>
<tr>
<td><em>Compliance</em> (cumplimiento normativo) de los datos propios</td>
<td class="rc-cliente"><strong>Cliente</strong></td>
<td class="rc-cliente"><strong>Cliente</strong></td>
<td class="rc-cliente"><strong>Cliente</strong></td>
</tr>
</tbody>
</table>

El punto exacto donde se traza la línea **depende del modelo de servicio**:

- **IaaS** (ej. EC2, Compute Engine, VMs de Azure): el cliente asume más responsabilidad (SO, parches, runtime, red interna).
- **PaaS** (ej. RDS, Cloud SQL, App Service): el proveedor gestiona más (SO, parches, motor de base de datos).
- **SaaS** (ej. Google Workspace, Microsoft 365): el proveedor gestiona casi todo; el cliente solo controla datos, usuarios y configuración de acceso.

!!! note "En general, a mayor nivel de abstracción del servicio, menor responsabilidad operativa para el cliente, pero la responsabilidad sobre datos, identidades y configuración de acceso nunca desaparece."

## Diferencias por proveedor

El concepto es el mismo en las tres nubes principales, pero cada una lo documenta y matiza de forma distinta.

### AWS

- Lo llama oficialmente **"Shared Responsibility Model"**.
- Divide responsabilidades en "Security **of** the Cloud" (AWS) vs "Security **in** the Cloud" (cliente).
- Tiene una variante adicional para servicios **serverless** y **managed** (gestionados) (Lambda, Fargate, DynamoDB) donde AWS asume también el parcheo del SO y runtime, dejando al cliente enfocado en código, IAM y configuración de datos.
- Documentación de referencia: [aws.amazon.com/compliance/shared-responsibility-model](https://aws.amazon.com/compliance/shared-responsibility-model/)

### Azure

- Lo llama **"Shared Responsibility Model"** también, pero presenta una tabla más granular por tipo de servicio (On-prem → IaaS → PaaS → SaaS) mostrando explícitamente cómo la barra de responsabilidad del cliente se reduce progresivamente.
- Pone especial énfasis en la responsabilidad del cliente sobre **identidad** (Entra ID / Azure AD), ya que Microsoft la posiciona como el nuevo perímetro de seguridad (*identity is the new perimeter*).
- Documentación de referencia: [learn.microsoft.com/azure/security/fundamentals/shared-responsibility](https://learn.microsoft.com/en-us/azure/security/fundamentals/shared-responsibility)

### GCP

- Usa el término **"Shared Responsibility"** pero también promueve el concepto de **"Shared Fate"** (destino compartido), una capa adicional donde Google no solo delimita responsabilidades sino que se compromete activamente a ayudar al cliente a operar de forma segura (ej. configuraciones seguras por defecto, guías de *landing zones* (entornos base preconfigurados), soporte proactivo).
- Es la nube que más explícitamente reconoce que una separación rígida de responsabilidades no basta y busca reducir la carga de configuración del cliente.
- Documentación de referencia: [cloud.google.com/architecture/framework/security/shared-responsibility-shared-fate](https://cloud.google.com/architecture/framework/security/shared-responsibility-shared-fate)

## Resumen comparativo

| Aspecto | AWS | Azure | GCP |
|---|---|---|---|
| Nombre del modelo | Shared Responsibility Model | Shared Responsibility Model | Shared Responsibility + **Shared Fate** |
| Enfoque diferenciador | Distinción clara IaaS vs. managed/serverless | Énfasis fuerte en identidad como perímetro | Compromiso proactivo del proveedor ("destino compartido") |
| Granularidad documental | Por tipo de servicio | Por modelo (On-prem/IaaS/PaaS/SaaS) muy visual | Conceptual + guías de aterrizaje seguro |

## Conclusión práctica

Independientemente del proveedor, como responsable de infraestructura/DevOps siempre debes asumir que **tienes como responsabilidad**:

- La configuración de IAM (usuarios, roles, *least privilege* o mínimo privilegio).
- La configuración de red (quién puede entrar, qué puertos, qué está expuesto a internet).
- El *encryption* (cifrado) y la clasificación de los datos.
- El *patching* (parches) del sistema operativo **si usas IaaS**.
- El *monitoring* (monitoreo) y la *incident response* (respuesta ante incidentes) en tu propio entorno.

!!! warning "Regla práctica"

    Si tú lo configuraste, tú lo aseguras. Si el proveedor lo entrega gestionado, tu responsabilidad se reduce, pero no desaparece, sigues siendo responsable de los datos y de quién accede a ellos.

Los modelos IaaS, PaaS y SaaS con ejemplos de cada proveedor están en [Modelos de servicio y regiones](modelos-de-servicio-y-regiones.md).

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Qué te toca en cada modelo de servicio y en cada tipo de cómputo; IAM, red y cifrado como responsabilidades del cliente | [Modelos de servicio y regiones](modelos-de-servicio-y-regiones.md), [Máquinas virtuales](../computo/maquinas-virtuales.md), [Serverless](../computo/serverless.md), [IAM](iam-comparativa.md), [Redes en la nube](../redes-y-datos/redes.md), [Fundamentos de seguridad cloud](../seguridad/fundamentos-seguridad-cloud.md) |
| DevOps (la automatización) | Automatizar el *patching* y la configuración de lo que es tuyo | [Ansible](../../devops/iac/ansible.md), [Infrastructure as Code](../../devops/iac/infraestructura-como-codigo.md) |
| DevSecOps (la verificación) | Verificar de forma continua que tu parte está bien configurada (CSPM, benchmarks) | [Fundamentos DevSecOps](../../devsecops/fundamentos-devsecops.md), [Cumplimiento y gobierno](../../devsecops/gobierno-y-respuesta/cumplimiento.md), [Seguridad de IaC](../../devsecops/infraestructura-y-contenedores/seguridad-iac.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 22: Endurecer un servidor Linux con Ansible y medirlo con Lynis y OpenSCAP](../../laboratorios/devsecops/hardening-linux-ansible.md) |

## Referencias

- [Modelo de Responsabilidad Compartida AWS](https://aws.amazon.com/es/compliance/shared-responsibility-model/)
- [Modelo de Responsabilidad Compartida Azure](https://learn.microsoft.com/es-es/azure/security/fundamentals/shared-responsibility)
- [Modelo de Responsabilidad Compartida GCP](https://cloud.google.com/architecture/framework/security/shared-responsibility-shared-fate)