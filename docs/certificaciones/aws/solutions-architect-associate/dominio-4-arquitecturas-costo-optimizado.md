---
tags:
  - aws
  - certificacion
  - saa-c03
  - finops
  - arquitectura
---

# Dominio 4: Design Cost-Optimized Architectures (20%)

> Cumplir los requisitos al menor costo: clases de almacenamiento y lifecycle de S3, modelos de compra de cómputo, bases de datos del tamaño justo, costos de transferencia de red y las herramientas para medir y controlar el gasto.

!!! info "Qué evalúa este dominio"
    - **Task 4.1 – Cost-optimized storage**: clases y lifecycle de S3, Requester Pays, EBS SSD vs HDD, EFS/FSx, archivado y transferencia barata.
    - **Task 4.2 – Cost-optimized compute**: Spot, Reserved Instances, Savings Plans; tamaño de instancia; Lambda vs EC2 vs Fargate; producción vs no producción.
    - **Task 4.3 – Cost-optimized databases**: capacidad, caché, retención de snapshots, DynamoDB vs RDS vs serverless, formatos columnares, migración de motor.
    - **Task 4.4 – Cost-optimized network**: NAT gateway vs NAT instance, Direct Connect vs VPN, transferencia entre AZ y regiones, VPC endpoints, CDN.
    - En todas: **herramientas de costos** (Cost Explorer, Budgets, CUR, cost allocation tags, facturación multi-cuenta).

    Formato y resto de dominios en el [resumen del examen](resumen-examen.md).

## Herramientas de gestión de costos

Cost Explorer, Budgets, Cost and Usage Report, cost allocation tags y consolidated billing están en [Cloud Practitioner: Dominio 4](../cloud-practitioner/dominio-4-facturacion-precios-soporte.md); prácticas de FinOps en [FinOps y costos](../../../cloud/fundamentos/finops-costos.md#herramientas-nativas-de-costos). Las pistas que más salen en SAA:

| Pista en el examen | Herramienta |
| --- | --- |
| "Analizar tendencias de gasto por servicio" | **Cost Explorer** |
| "Avisar cuando el gasto (o el pronóstico) supere X" | **AWS Budgets** |
| "Análisis por hora, recurso y etiqueta con SQL propio" | **Cost and Usage Report** (Data Exports, CUR 2.0) en S3 + Athena |
| "Saber cuánto gasta cada departamento" | **Cost allocation tags** |
| "Instancias sobredimensionadas" | **AWS Compute Optimizer** (EC2, ASG, EBS, Lambda, ECS en Fargate) |
| "Recursos ociosos, EIP sin usar" | **AWS Trusted Advisor** |

## Almacenamiento

### Clases de almacenamiento de S3

Para qué sirve cada clase está en [Amazon S3 storage classes](../cloud-practitioner/dominio-3-tecnologia-servicios.md#amazon-s3-storage-classes). Todas tienen 11 nueves de durabilidad; para decidir el costo importan la AZ, el **mínimo facturable** y la recuperación:

| Clase | AZ | Mínimo facturable | Acceso y recuperación |
| --- | --- | --- | --- |
| **S3 Standard** | ≥3 | – | Milisegundos, sin cargo |
| **S3 Intelligent-Tiering** | ≥3 | – | Milisegundos; tarifa de monitoreo por objeto, sin cargo de recuperación |
| **S3 Standard-IA** | ≥3 | 30 días, 128 KB por objeto | Milisegundos, cargo por GB |
| **S3 One Zone-IA** | **1** | 30 días, 128 KB | Milisegundos, cargo por GB; solo datos **recreables** |
| **S3 Glacier Instant Retrieval** | ≥3 | 90 días | Milisegundos, cargo por GB más alto |
| **S3 Glacier Flexible Retrieval** | ≥3 | 90 días | Expedited 1–5 min; Standard 3–5 h; Bulk 5–12 h |
| **S3 Glacier Deep Archive** | ≥3 | 180 días | Standard hasta 12 h; Bulk hasta 48 h |
| **S3 Express One Zone** | **1** | – | Rendimiento máximo, no ahorro (ver [Dominio 3](dominio-3-arquitecturas-alto-rendimiento.md#rendimiento-de-s3)) |

**Intelligent-Tiering** mueve cada objeto solo: Frequent → Infrequent Access (30 días sin acceso) → Archive Instant Access (90 días); opcionalmente Archive Access y Deep Archive Access. Si se vuelve a leer, regresa a Frequent. Los objetos de menos de 128 KB no cambian de capa.

!!! warning "El servicio Amazon Glacier original"
    El servicio independiente de *vaults* no acepta clientes nuevos desde el 15 de diciembre de 2025. Si una pregunta habla de "Glacier", piensa en las clases S3 Glacier.

### Lifecycle rules

- **Transition actions** (mover de clase) y **expiration actions** (borrar), también para versiones antiguas (*noncurrent versions*) y **multipart uploads incompletos**.
- Para pasar a Standard-IA o One Zone-IA, el objeto debe llevar al menos 30 días en su clase; por defecto, los de menos de 128 KB no se transicionan.
- Borrar antes del mínimo facturable cobra los días restantes: no mandes a Deep Archive datos que se borran al mes.

Ejemplo típico: Standard → Standard-IA (30 días) → Glacier Flexible Retrieval → Deep Archive (365 días) → expiración (~7 años). En la API, `GLACIER` es Glacier Flexible Retrieval y `GLACIER_IR` es Glacier Instant Retrieval.

!!! tip "En el examen"
    "Acceso impredecible" → **Intelligent-Tiering**. "Se accede poco pero cuando se pide debe estar al instante" → **Standard-IA** o **Glacier Instant Retrieval** (si es aún menos frecuente). "Se puede regenerar" → **One Zone-IA**. "Retener 7 años, recuperación en 48 h aceptable" → **Deep Archive**. "Recuperar en minutos en casos urgentes" → Glacier Flexible Retrieval con **Expedited**.

### Otras palancas de costo en almacenamiento

- **S3 Requester Pays**: quien descarga paga la transferencia y las peticiones. **Storage Lens** y **Storage Class Analysis** para detectar qué mover.
- **EBS**: **gp2 → gp3**; **st1/sc1** para datos secuenciales; borrar volúmenes sin adjuntar; **EBS Snapshots Archive** y **Recycle Bin**. Tipos en el [Dominio 3](dominio-3-arquitecturas-alto-rendimiento.md#tipos-de-volumen-ebs).
- **EFS**: lifecycle a Infrequent Access y Archive; One Zone para datos no críticos. **Backups**: AWS Backup con lifecycle a cold storage.
- **Transferir al menor costo**: la entrada a S3 no se cobra; agrupa archivos en vez de millones de PUT; DataSync o dispositivo físico si la red no alcanza (ver [Dominio 3](dominio-3-arquitecturas-alto-rendimiento.md#transferencia-de-datos-hibrida-y-migracion)).

## Cómputo

### Modelos de compra

On-Demand, Savings Plans (Compute vs EC2 Instance), Reserved Instances (Standard vs Convertible, regional vs zonal), Spot, Dedicated Hosts, Dedicated Instances y Capacity Reservations, con su árbol de decisión, están en [Modelos de compra de cómputo](../cloud-practitioner/dominio-4-facturacion-precios-soporte.md#modelos-de-compra-de-computo). Lo que añade SAA:

| Opción | Descuento máximo aproximado | Detalle de arquitectura |
| --- | --- | --- |
| **Compute Savings Plans** | Hasta ~66% | Cubre EC2 de cualquier familia y región, **Fargate y Lambda**: la respuesta si la tecnología va a cambiar |
| **EC2 Instance Savings Plans** / **Standard RI** | Hasta ~72% | Una familia y región; las RI también existen para RDS, ElastiCache, Redshift, OpenSearch |
| **Convertible RI** | Hasta ~66% | Cambiables por otras de igual o mayor valor |
| **Database Savings Plans** | Hasta ~35% | $/hora por 1 año en varios motores, familias y regiones (anunciado en diciembre de 2025; revisa los servicios cubiertos) |
| **Spot** | Hasta ~90% | Aviso de **2 minutos**; batch, CI, big data, contenedores stateless |

- Memoriza el **orden** de los descuentos, no el número exacto. AWS recomienda **Savings Plans** sobre RI para EC2, Fargate y Lambda.
- Una **zonal RI** reserva capacidad en una AZ; una regional solo da descuento. Las **Capacity Reservations** se combinan con Savings Plans.
- **Mixed instances policy** en un ASG: base On-Demand cubierta por Savings Plans + el resto en Spot con varias familias (*price-capacity-optimized*).

### Elegir el servicio y el tamaño

| Patrón de carga | Opción más económica habitual |
| --- | --- |
| Tráfico esporádico, eventos cortos | **Lambda** (cero cuando no hay tráfico) |
| Contenedores con carga variable sin gestionar nodos | **Fargate** (Fargate Spot para tareas tolerantes) |
| Carga continua, alta y predecible | EC2 con Savings Plans, o ECS/EKS sobre EC2 |
| Dev que solo se usa en horario laboral | Apagar fuera de horario (Instance Scheduler, scheduled scaling a 0) |
| Instancias de arranque lento que se paran y arrancan | **EC2 hibernation** (RAM al volumen raíz cifrado) |

- **Rightsizing** con Compute Optimizer y la familia correcta; **Graviton** (ARM) para mejor precio-rendimiento si el software es compatible.
- **Producción vs no producción**: dev puede ir en una AZ, con Spot y apagado de noche.
- **Load balancer**: si no necesitas L7, un NLB puede bastar; un solo ALB con reglas por host o path sirve a varias aplicaciones.

## Bases de datos

| Escenario | Opción costo-eficiente |
| --- | --- |
| Relacional intermitente o impredecible (dev, apps internas) | **Aurora Serverless v2** (escala por ACU) |
| DynamoDB con tráfico estable | **Provisioned** con auto scaling (y reserved capacity) |
| DynamoDB con tráfico impredecible o nuevo | **On-demand** |
| Lecturas repetidas que encarecen la base | **ElastiCache** o **DAX**; o read replicas |
| Series temporales (IoT, métricas) | Base purpose-built (Amazon Timestream; para clientes nuevos, Timestream for InfluxDB) |
| Analítica sobre grandes volúmenes | Formato **columnar**: Redshift o Parquet en S3 + Athena |
| Datos antiguos que casi no se consultan | Exportar a S3 (snapshot export a Parquet); **TTL** en DynamoDB |
| Licencias de Oracle o SQL Server caras | Migrar a Aurora PostgreSQL/MySQL con **DMS** y conversión de esquema |
| Uso estable de RDS/Aurora/ElastiCache | Reserved Instances (reserved nodes) o **Database Savings Plans** |

- Ajusta la **retención** y frecuencia de snapshots al RPO real; los snapshots manuales no expiran solos.
- **RDS storage auto scaling** en vez de sobreaprovisionar; **RDS Proxy** evita instancias más grandes solo por número de conexiones.

## Red

### Costos de transferencia de datos

La tabla básica (entrada gratis; salida, entre AZ y entre regiones se cobran; origen → CloudFront gratis) está en [Cloud Practitioner: Dominio 4](../cloud-practitioner/dominio-4-facturacion-precios-soporte.md). En arquitecturas SAA suman además: el tráfico **procesado por un NAT gateway** (por GB, además de la hora) y la salida por **Direct Connect** (más barata que por internet). Guía visual oficial: [Overview of data transfer costs for common architectures](https://aws.amazon.com/blogs/architecture/overview-of-data-transfer-costs-for-common-architectures/).

### NAT gateway: cuántos y cuál

| Opción | Costo y disponibilidad | Cuándo |
| --- | --- | --- |
| **Un NAT gateway por AZ** | Más horas; alta disponibilidad y sin tráfico entre AZ | Producción |
| **Un NAT gateway compartido** | Menos horas, pero tráfico entre AZ y single point of failure | Desarrollo o pruebas |
| **NAT instance** (EC2) | Puede ser más barato con poco tráfico; gestionas parches y HA, desactivas source/destination check | Casos muy pequeños |
| **Regional NAT gateway** | Modo nuevo (noviembre de 2025): se extiende solo a las AZ con cargas | Revisa precios y si el examen ya lo considera |

Los **gateway endpoints** de S3 y DynamoDB son gratis y eliminan el cargo de NAT para ese tráfico; los **interface endpoints** cuestan, pero pueden salir más baratos que el NAT con volumen alto.

### Conectividad y entrega de contenido

- **VPN vs Direct Connect**: con volumen moderado, VPN suele ser lo más económico; DX tiene costo fijo de puerto pero abarata grandes volúmenes salientes. Elige la velocidad de DX según el uso real.
- **CloudFront** reduce peticiones al origen y salida de datos.
- **VPC peering vs Transit Gateway**: peering no cobra por hora; Transit Gateway cobra por attachment y por GB, pero simplifica muchas VPC. Con pocas VPC, peering es más barato.
- **Tráfico local**: recursos muy conversadores en la misma AZ si la disponibilidad lo permite; IPs privadas. **Throttling** y caché de API Gateway para no escalar el backend por abusos.

!!! tip "En el examen"
    "Instancias privadas leen mucho de S3 y la factura de NAT es alta" → **gateway endpoint**. "Reducir costo de NAT en un entorno de pruebas" → **un solo NAT gateway** (aceptando menos disponibilidad). "Contenido estático para usuarios globales con menor costo de salida" → **CloudFront + S3 con OAC**.

## Casos de uso

1. **Logs muy consultados la primera semana, retención de 5 años** → lifecycle Standard → Standard-IA (30 días) → Glacier Flexible o Deep Archive → expiración a 5 años.
2. **Renderizado nocturno que puede reintentar** → **Spot** con varias familias y checkpoints en S3.
3. **EC2 estable con migración parcial a Fargate y Lambda el año próximo** → **Compute Savings Plans**.
4. **Software licenciado por socket físico** → **Dedicated Hosts**.
5. **Base relacional de desarrollo que se usa a ratos** → **Aurora Serverless v2**.
6. **Aviso cuando el gasto proyectado de cada proyecto supere su presupuesto** → cost allocation tags + **Budgets** sobre el pronóstico.
7. **Dataset público de 50 TB sin pagar la salida** → **S3 Requester Pays**.

## Preguntas de práctica

**1.** Una empresa tiene archivos que se acceden con frecuencia los primeros 30 días; después se consultan unas pocas veces al año pero deben estar disponibles en milisegundos. Pasado 1 año, pueden tardar hasta 12 horas en recuperarse y deben guardarse 10 años. ¿Qué lifecycle es MÁS costo-eficiente?

- A. Standard → Standard-IA (30 días) → Glacier Deep Archive (365 días) → expirar a 10 años
- B. Standard → One Zone-IA (30 días) → Glacier Flexible Retrieval (365 días)
- C. Intelligent-Tiering desde el día 1 sin reglas
- D. Standard → Glacier Flexible Retrieval (30 días) → expirar a 10 años

??? success "Respuesta"
    **A.** Standard-IA da acceso en milisegundos con menor costo; Deep Archive cumple las 12 h y es lo más barato a largo plazo. Glacier Instant Retrieval también serviría en el tramo intermedio si el acceso es muy raro. **B**: One Zone-IA arriesga datos no recreables y no los borra a los 10 años. **C** no aprovecha Deep Archive salvo que se active la capa opcional, y no expira. **D** rompe el requisito de milisegundos.

**2.** Un Auto Scaling group procesa trabajos por lotes tolerantes a interrupciones y necesita además 2 instancias siempre disponibles para tareas críticas, durante los próximos 3 años. ¿Qué combinación minimiza el costo?

- A. Todo On-Demand
- B. Todo Spot
- C. Savings Plan para las 2 instancias base y Spot para el resto (mixed instances policy)
- D. Dedicated Hosts para todo

??? success "Respuesta"
    **C.** Base estable con compromiso y capacidad variable en Spot. **A** es lo más caro. **B** arriesga las tareas críticas. **D** es caro y no se pide aislamiento.

**3.** Instancias EC2 en subnets privadas de tres AZ suben 20 TB al mes a S3 a través de un NAT gateway. ¿Cómo reducir el costo con el MENOR esfuerzo?

- A. Reemplazar el NAT gateway por NAT instances
- B. Crear un gateway endpoint para S3 y añadirlo a las route tables privadas
- C. Mover las instancias a subnets públicas
- D. Usar S3 Transfer Acceleration

??? success "Respuesta"
    **B.** El tráfico a S3 deja de pasar por el NAT (sin cargo por GB procesado) y el endpoint es gratuito. **A** añade gestión. **C** empeora la seguridad. **D** cuesta más y no evita el NAT.

**4.** Una tabla DynamoDB tiene tráfico estable de unas 500 escrituras/s todo el día, todos los días. Hoy está en modo on-demand. ¿Qué cambio reduce el costo?

- A. Cambiar a provisioned con auto scaling
- B. Añadir DAX
- C. Activar global tables
- D. Activar DynamoDB Streams

??? success "Respuesta"
    **A.** Con tráfico predecible, provisioned (más reserved capacity, si aplica) suele ser más barato que pagar por petición. **B** acelera lecturas, no abarata escrituras. **C** y **D** añaden costo.

**5.** Un entorno de pruebas en una VPC con dos AZ tiene un NAT gateway en cada AZ. El equipo quiere reducir costos y acepta menor disponibilidad. ¿Qué hacer?

- A. Eliminar un NAT gateway y enrutar ambas subnets privadas al que queda
- B. Cambiar los NAT gateways por Internet Gateways en subnets privadas
- C. Añadir un tercer NAT gateway
- D. Usar Direct Connect

??? success "Respuesta"
    **A.** Un solo NAT reduce las horas facturadas; el costo es tráfico entre AZ y un single point of failure, aceptable en pruebas. **B** convierte las subnets en públicas. **C** sube el costo. **D** no tiene relación y es caro.

**6.** Una empresa necesita analizar sus costos de AWS por hora, por recurso y por etiqueta, con consultas SQL propias. ¿Qué usar?

- A. AWS Budgets
- B. AWS Cost and Usage Report (Data Exports) en S3 consultado con Athena
- C. AWS Trusted Advisor
- D. Cost Explorer con vista mensual

??? success "Respuesta"
    **B.** El CUR es el dataset de facturación más granular y se consulta con Athena. **A** alerta, no analiza en detalle. **C** da recomendaciones. **D** no permite SQL propio a ese nivel de detalle.

## Para profundizar

- [FinOps y costos](../../../cloud/fundamentos/finops-costos.md): cómo se cobra la nube, tags, showback y optimización.
- [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md#clases-de-almacenamiento): clases de almacenamiento comparadas entre nubes.
- [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md#modelos-de-pago): modelos de pago entre nubes.
- [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md#tagging-y-labels): estrategia de tagging.
- [TI y negocio](../../../negocio/ti-y-negocio.md): CapEx vs OpEx, TCO y ROI.
- [Pruebas de infraestructura](../../../devops/iac/pruebas-infraestructura.md): entornos efímeros y costo en el pipeline.

## Referencias

- [Exam guide SAA-C03: Domain 4](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03/solutions-architect-associate-03-domain4.html)
- [Amazon S3 storage classes](https://aws.amazon.com/s3/storage-classes/)
- [What are Savings Plans?](https://docs.aws.amazon.com/savingsplans/latest/userguide/what-is-savings-plans.html)
- [Database Savings Plans (anuncio)](https://aws.amazon.com/about-aws/whats-new/2025/12/database-savings-plans-savings/)
- [AWS NAT Gateway regional availability (anuncio)](https://aws.amazon.com/about-aws/whats-new/2025/11/aws-nat-gateway-regional-availability/)
- [AWS Well-Architected: Cost Optimization Pillar](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html)
