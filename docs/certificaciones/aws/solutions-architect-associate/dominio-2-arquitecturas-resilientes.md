---
tags:
  - aws
  - certificacion
  - saa-c03
  - resiliencia
  - arquitectura
---

# Dominio 2: Design Resilient Architectures (26%)

> Arquitecturas que escalan y no se caen: desacoplar con colas y eventos, escalar horizontalmente con Auto Scaling y load balancers, replicar datos entre AZ y regiones, y elegir la estrategia de disaster recovery que cumpla el RTO y el RPO.

!!! info "Qué evalúa este dominio"
    - **Task 2.1 – Design scalable and loosely coupled architectures**: colas, pub/sub y eventos, microservicios stateless, escalado horizontal, load balancing, contenedores y serverless, Step Functions, read replicas.
    - **Task 2.2 – Design highly available and/or fault-tolerant architectures**: AZ, regiones y Route 53; estrategias de DR con RTO/RPO; failover; RDS Proxy; service quotas en standby; mejorar apps legacy sin cambiar código.

    Formato y resto de dominios en el [resumen del examen](resumen-examen.md).

## Mensajería y eventos: SQS, SNS, EventBridge, Kinesis

Desacoplar (*loosely coupled*) significa que A deja el trabajo en un intermediario y B lo procesa a su ritmo; la teoría está en [Integración y APIs](../../../cloud/arquitectura/integracion-apis.md#colas-pubsub-y-streaming). Patrón típico: ALB → web tier → **SQS** → workers en Auto Scaling según mensajes en cola → base Multi-AZ, con una DLQ para los fallidos.

| Servicio | Modelo | Entrega y orden | Retención | Úsalo cuando |
| --- | --- | --- | --- | --- |
| **SQS Standard** | Cola, un consumidor por mensaje (pull) | **At-least-once**; orden *best effort*; throughput casi ilimitado | 1 minuto a 14 días (4 por defecto) | Desacoplar y absorber picos (*queue-based load leveling*) |
| **SQS FIFO** | Cola | **Exactly-once processing** y orden por *message group ID* | Igual | El orden importa; throughput más limitado |
| **Amazon SNS** | **Pub/sub**, push a muchos suscriptores | At-least-once; SNS FIFO para orden | No retiene | **Fan-out**: un evento a varias colas, Lambdas, email, HTTP |
| **Amazon EventBridge** | **Event bus** con reglas por contenido | At-least-once | Archivo y replay opcionales | Eventos de AWS, SaaS y microservicios; EventBridge Scheduler |
| **Kinesis Data Streams** | **Streaming** con shards; varios consumidores leen el mismo flujo | Orden por partition key en el shard | 24 h por defecto, hasta 365 días | Tiempo real, reprocesar, varios consumidores |
| **Amazon MQ** | Broker ActiveMQ o RabbitMQ | Según protocolo | Según broker | Migrar apps con JMS, AMQP, MQTT o STOMP **sin reescribir** |

Detalles de SQS que se preguntan:

- **Visibility timeout**: si el procesamiento tarda más, el mensaje reaparece y se procesa dos veces; ajústalo al tiempo real.
- **Dead-letter queue (DLQ)**: tras `maxReceiveCount` intentos fallidos. **Long polling** (hasta 20 s) reduce respuestas vacías y costo. **Delay queue**: hasta 15 minutos.
- Mensaje máximo de **1 MiB** desde agosto de 2025 (antes 256 KiB); para más, payload en S3 y referencia en el mensaje (Extended Client Library).

!!! tip "En el examen"
    - "Un pedido debe procesarse una sola vez y en orden" → **SQS FIFO**.
    - "Un evento debe llegar a tres sistemas distintos que lo procesan de forma independiente" → **SNS + varias colas SQS (fan-out)**.
    - "Reaccionar a eventos de servicios de AWS o de un SaaS (Zendesk, Datadog) y enrutarlos según el contenido" → **EventBridge**.
    - "Varios consumidores leen el mismo flujo en tiempo real y se necesita reprocesar" → **Kinesis Data Streams** (en SQS, un mensaje consumido se borra).
    - "Migrar una app con ActiveMQ sin cambiar código" → **Amazon MQ**.

### Orquestación y APIs

- **AWS Step Functions**: máquina de estados con reintentos, ramas, esperas y aprobación humana. **Standard** (hasta 1 año, exactly-once) vs **Express** (hasta 5 minutos, alto volumen, más barato).
- **Amazon API Gateway**: **REST API** (caché, API keys y usage plans, WAF, endpoints privados), **HTTP API** (más simple y barata, JWT) y **WebSocket API**. El **throttling** protege el backend. Ver [Serverless](../../../cloud/computo/serverless.md#api-gateway-delante-de-las-funciones).

## Cómputo escalable

Para escalar horizontalmente, las instancias deben ser **stateless**: sesión en **ElastiCache** o **DynamoDB**, archivos en **S3** o **EFS**. Qué es cada servicio de cómputo en [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md) y [Serverless](../../../cloud/computo/serverless.md); para decidir:

| Opción | Cuándo |
| --- | --- |
| EC2 + Auto Scaling group | Control del SO, software legacy, licencias |
| **ECS** o **EKS** sobre EC2 | Contenedores con GPU, instancias específicas o Spot |
| ECS o EKS con **Fargate** | Contenedores sin administrar nodos ("menos gestión = Fargate") |
| **AWS Lambda** | Eventos cortos (máximo 15 minutos), tráfico irregular |
| **Elastic Beanstalk** | Subir código web rápido; AWS crea ELB, ASG y despliegues |

**ECS vs EKS**: ECS es el orquestador propio de AWS (más simple); EKS es Kubernetes gestionado (portabilidad, equipo que ya sabe Kubernetes).

## Load balancing y Auto Scaling

El ELB quita los targets que fallan el **health check**; ALB vs NLB vs GWLB en el [Dominio 3](dominio-3-arquitecturas-alto-rendimiento.md#load-balancers-alb-vs-nlb-vs-gwlb).

| Política de Auto Scaling | Cuándo |
| --- | --- |
| **Target tracking** | Por defecto: mantener una métrica (CPU 50%, `ALBRequestCountPerTarget`, mensajes por instancia) |
| **Step scaling** | Escalones según cuánto se supera la alarma (**simple scaling** es su versión legacy) |
| **Scheduled** | Picos conocidos: lunes 8:00, cierre de mes |
| **Predictive** | ML sobre el historial: escala **antes** de picos cíclicos |

- **Health check de ELB** en el ASG para reemplazar instancias cuya aplicación no responde (por defecto solo mira el estado de EC2).
- **Launch template** (los launch configurations están obsoletos); **lifecycle hooks** para acciones al lanzar o terminar; **warm pools** para apps de arranque lento.
- **Workers con SQS**: target tracking sobre mensajes visibles por instancia (*backlog per instance*).

!!! tip "En el examen"
    "Tráfico alto todos los lunes a las 9:00" → **scheduled**. "La app tarda 10 minutos en arrancar y el pico es diario y predecible" → **predictive** (o warm pools). "Mantener la CPU cerca del 60%" → **target tracking**. "Las instancias fallan pero el ASG no las reemplaza" → activar **health check de ELB**.

## Alta disponibilidad de bases de datos

| Opción | Qué resuelve | Replicación | ¿Se lee la réplica? | Failover |
| --- | --- | --- | --- | --- |
| **RDS Multi-AZ (instancia)** | **Disponibilidad** ante fallo de AZ | Síncrona a un standby | **No** | Automático, mismo endpoint (1–2 min aprox.) |
| **RDS Multi-AZ DB cluster** | Disponibilidad + algo de lectura | Semisíncrona a **dos** standbys (MySQL, PostgreSQL) | Sí | Más rápido |
| **RDS read replicas** | **Escalar lecturas** | **Asíncrona**, misma región o cross-region | Sí | Manual: se **promueve** |
| **Aurora** | HA y rendimiento | 6 copias en 3 AZ; hasta 15 réplicas con almacenamiento compartido | Sí (reader endpoint) | Automático, normalmente menos de un minuto |
| **Aurora Global Database** | DR entre regiones y lecturas globales | Asíncrona, lag típico menor a 1 s | Sí en secundarias | RPO de segundos, RTO de minutos |
| **DynamoDB global tables** | Multi-región **activo-activo** | Asíncrona multi-activa (opción de consistencia fuerte multi-región) | Sí, y se escribe en cada región | No hay failover |

- **RDS Proxy**: pool de conexiones delante de RDS/Aurora; evita agotar conexiones con muchas Lambdas y acelera el failover **sin cambiar el código** (solo el endpoint).
- **ElastiCache** con réplicas Multi-AZ (Valkey/Redis OSS) para que la caché no sea un punto único de falla.

!!! tip "En el examen"
    Multi-AZ = **disponibilidad** (no escala lecturas). Read replica = **rendimiento de lectura** (no da failover automático). Si piden ambos, son dos funciones distintas. "Reportes pesados ralentizan la base de producción" → **read replica** y apuntar los reportes ahí. "RPO de 1 segundo y RTO de 1 minuto entre regiones para una base relacional" → **Aurora Global Database**.

## Route 53 y failover

Routing policies: **Simple** (un recurso, sin health checks), **Weighted** (canary, A/B, migración gradual), **Latency** (región de menor latencia), **Failover** (DR activo-pasivo con health check), **Geolocation** (por país: contenido localizado o restricciones legales), **Geoproximity** (por distancia, con **bias** para mover tráfico), **Multivalue answer** (hasta 8 registros sanos al azar) e **IP-based** (por CIDR de origen).

**Alias record**: apunta a ALB, CloudFront, S3 website o API Gateway, **funciona en el zone apex** (`ejemplo.com`), a diferencia de un CNAME, y sus consultas a recursos AWS no tienen costo.

## Estrategias de disaster recovery

Teoría de RTO/RPO en [Continuidad de negocio](../../../negocio/continuidad-negocio.md#rto-rpo-y-mtpd); estrategias por proveedor en [Resiliencia](../../../cloud/operacion-y-gobierno/resiliencia.md#estrategias-de-disaster-recovery).

| Estrategia | Qué hay en la región de DR | RPO / RTO típicos | Costo |
| --- | --- | --- | --- |
| **Backup and restore** | Solo backups (AWS Backup, snapshots copiados, S3 CRR) | Horas / horas | El más bajo |
| **Pilot light** | Datos replicados en vivo; cómputo apagado (AMIs, IaC listos) | Minutos / decenas de minutos | Bajo |
| **Warm standby** | Copia completa **a escala reducida** | Segundos a minutos / minutos | Medio |
| **Multi-site active-active** | Producción completa en dos o más regiones | Casi cero / casi cero | El más alto |

- **AWS Elastic Disaster Recovery (DRS)**: replicación continua a nivel de bloque de servidores (on-premises o EC2), recuperación en minutos; para legacy **sin cambiar código**.
- **Service quotas**: en pilot light y warm standby, verifica **antes** que la región de DR tiene cuotas para escalar.
- **Infraestructura inmutable**: reemplazar desde una AMI o plantilla, no parchear en vivo; así DR es idéntico a producción.
- **Observabilidad**: CloudWatch dispara Auto Scaling y alarmas; **X-Ray** (*distributed tracing*) muestra qué microservicio causa latencia o errores. Ver [Observabilidad nativa](../../../monitoreo/nube/observabilidad-nativa.md).

!!! tip "En el examen"
    Lee los números: "RPO de 24 horas, mínimo costo" → backup and restore. "RTO de minutos, costo moderado" → warm standby. "La base de datos debe estar siempre replicada pero el cómputo puede arrancar en 30 minutos" → pilot light. "Cero tiempo de caída" → active-active.

## Casos de uso

1. **Pagos que no dan abasto en Black Friday** → SQS + workers en Auto Scaling por mensajes en cola; FIFO con `MessageGroupId` = cliente si importa el orden.
2. **Usuarios pierden la sesión al escalar** → sesión en ElastiCache o DynamoDB (sticky sessions como parche).
3. **Cientos de Lambdas agotan conexiones de RDS** → **RDS Proxy**.
4. **Seguir si cae una región, RTO 15 min, presupuesto moderado** → warm standby: Aurora Global Database + ASG mínimo + Route 53 failover.
5. **Proceso de 6 pasos con reintentos y espera humana de días** → **Step Functions Standard**.
6. **Servidor Windows on-premises crítico necesita DR sin cambios** → **Elastic Disaster Recovery**.
7. **App global que responda desde la región más cercana y retire la que falla** → Route 53 latency + health checks (Global Accelerator si piden IPs fijas y failover más rápido).

## Preguntas de práctica

**1.** Una aplicación procesa transacciones bancarias recibidas desde una API. Cada transacción debe procesarse exactamente una vez y en el orden en que llega por cuenta de cliente. ¿Qué solución cumple con el MENOR esfuerzo operativo?

- A. SQS Standard con deduplicación en la aplicación
- B. SQS FIFO usando el ID de cuenta como message group ID
- C. SNS Standard con suscripción de Lambda
- D. Kinesis Data Streams con un shard por cliente

??? success "Respuesta"
    **B.** FIFO garantiza orden por grupo y exactly-once processing, y los grupos permiten paralelizar entre cuentas. **A** exige lógica propia y no garantiza orden. **C** no garantiza orden ni exactly-once. **D** no escala (un shard por cliente) y añade gestión.

**2.** Los reportes de BI saturan la base de datos MySQL en RDS de producción, que ya tiene Multi-AZ. ¿Qué cambio resuelve el problema?

- A. Enviar los reportes al standby de Multi-AZ
- B. Crear una read replica y dirigir los reportes a su endpoint
- C. Aumentar el tamaño de la instancia del standby
- D. Activar backups automáticos con retención de 35 días

??? success "Respuesta"
    **B.** Las read replicas sirven lecturas. **A** no es posible: el standby de una instancia Multi-AZ no acepta conexiones. **C** no ayuda por lo mismo. **D** no tiene relación con la carga de lectura.

**3.** Una empresa requiere RPO de 1 hora y RTO de 4 horas para una aplicación interna, al menor costo posible, en otra región. ¿Qué estrategia elegir?

- A. Multi-site active-active
- B. Warm standby
- C. Pilot light
- D. Backup and restore con copias entre regiones mediante AWS Backup

??? success "Respuesta"
    **D.** Un RTO de horas permite restaurar desde backups, la opción más barata; con copias cada hora se cumple el RPO. **A**, **B** y **C** cumplen, pero cuestan más.

**4.** Una aplicación en un Auto Scaling group detrás de un ALB devuelve errores 500 porque el proceso web se cuelga, pero las instancias siguen en estado "running" y el ASG no las reemplaza. ¿Qué hacer?

- A. Cambiar a una política de step scaling
- B. Configurar el ASG para usar health checks de ELB
- C. Activar el detailed monitoring de CloudWatch
- D. Añadir una segunda AZ

??? success "Respuesta"
    **B.** Con el health check de ELB, el ASG considera no sana una instancia que falla el health check del target group y la reemplaza. **A** cambia cómo se escala, no cómo se detectan fallos. **C** da métricas cada minuto, no reemplaza. **D** no resuelve el proceso colgado.

**5.** Un sistema de pedidos publica un evento por cada pedido. Facturación, inventario y analítica deben recibir **cada** evento y procesarlo de forma independiente, aunque uno de ellos esté caído un rato. ¿Qué diseño es correcto?

- A. Una cola SQS compartida por los tres consumidores
- B. Un tópico SNS con tres colas SQS suscritas
- C. Tres llamadas HTTP síncronas desde el servicio de pedidos
- D. Una función Lambda que escribe en las tres bases de datos

??? success "Respuesta"
    **B.** Fan-out con SNS + SQS: cada consumidor tiene su cola durable y procesa a su ritmo. **A** reparte cada mensaje a un solo consumidor. **C** acopla y falla si uno está caído. **D** acopla todo en una función.

**6.** Una aplicación debe tolerar la caída de una AZ **sin degradación**. Con 2 AZ necesita 6 instancias en total para atender la carga normal. ¿Cuál es el mínimo de instancias para ser fault tolerant ante la caída de una AZ?

- A. 6 (3 por AZ)
- B. 8 (4 por AZ)
- C. 12 (6 por AZ)
- D. 7 (4 en una AZ y 3 en la otra)

??? success "Respuesta"
    **C.** Si cae una AZ, la otra debe tener sola las 6 instancias. **A** es solo HA: con una AZ caída quedan 3. **B** deja 4 y **D** deja 3 o 4. Dato útil: con **3 AZ** bastarían 9 (3 por AZ), porque al caer una quedan 6; por eso repartir en más AZ abarata la tolerancia a fallos.

## Para profundizar

- [Resiliencia](../../../cloud/operacion-y-gobierno/resiliencia.md): HA, autoscaling, health checks y DR comparados entre nubes.
- [Integración y APIs](../../../cloud/arquitectura/integracion-apis.md) y [Estilos de arquitectura](../../../cloud/arquitectura/estilos-arquitectura.md): colas, pub/sub, streaming, saga y outbox.
- [Arquitecturas de referencia](../../../cloud/arquitectura/arquitecturas-referencia.md): web de tres capas y multi-región activo-pasivo.
- [Balanceo y alta disponibilidad de red](../../../networking/avanzado/balanceo-alta-disponibilidad.md) y [Servicios de red](../../../networking/intermedio/servicios-red.md) (DNS).
- [Continuidad de negocio](../../../negocio/continuidad-negocio.md) y [Niveles de servicio](../../../negocio/niveles-de-servicio.md): de dónde salen RTO, RPO y SLA.
- [Despliegue continuo](../../../devops/ci-cd/despliegue-continuo.md): blue/green y canary con weighted routing.

## Referencias

- [Exam guide SAA-C03: Domain 2](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03/solutions-architect-associate-03-domain2.html)
- [Disaster Recovery of Workloads on AWS (whitepaper)](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-workloads-on-aws.html)
- [Amazon SQS aumenta el tamaño máximo de mensaje a 1 MiB](https://aws.amazon.com/about-aws/whats-new/2025/08/amazon-sqs-max-payload-size-1mib/)
- [Multi-AZ deployments for Amazon RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)
- [Route 53 routing policies](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy.html)
- [AWS Well-Architected: Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html)
