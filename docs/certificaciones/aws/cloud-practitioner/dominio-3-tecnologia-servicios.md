---
tags:
  - aws
  - certificacion
  - clf-c02
  - computo
  - redes
  - almacenamiento
---

# Dominio 3: Cloud Technology and Services (34%)

> El catálogo de AWS que el examen pide reconocer: formas de desplegar, infraestructura global, cómputo, bases de datos, redes, almacenamiento, IA y analítica, integración y otros servicios.

!!! info "Qué evalúa este dominio"
    Es el dominio **con más peso**. Según la guía oficial de CLF-C02, ocho *task statements*:

    - **3.1** Formas de desplegar y operar: consola, API, SDK, CLI, **IaC**; modelos cloud, híbrido y on-premises.
    - **3.2** Infraestructura global: **Regions, Availability Zones, edge locations**; cuándo usar varias AZ o varias regiones.
    - **3.3** Cómputo: EC2 instance types, contenedores (ECS, EKS), serverless (Fargate, Lambda), auto scaling, load balancers.
    - **3.4** Bases de datos: EC2 vs gestionadas, RDS, Aurora, DynamoDB, ElastiCache, migración (DMS, SCT).
    - **3.5** Redes: componentes de una VPC, security groups vs network ACLs, Route 53, VPN y Direct Connect.
    - **3.6** Almacenamiento: object, block y file, S3 storage classes, EBS vs instance store, EFS, FSx, Storage Gateway, lifecycle, AWS Backup.
    - **3.7** IA/ML y analítica: SageMaker AI, Lex y otros servicios de IA; Athena, Kinesis, Glue, Quick Sight.
    - **3.8** Otras categorías: SQS/SNS/EventBridge, Connect, SES, CodeBuild/CodePipeline/X-Ray, WorkSpaces/AppStream 2.0/WorkSpaces Secure Browser, Amplify, IoT Core.

    Vuelve al [resumen del examen](resumen-examen.md) para el plan de estudio.

## Formas de desplegar y operar en AWS

- **Console** para tareas **puntuales** (*one-time operations*); **CLI** para scripts (ver [comandos de AWS CLI](../../../recursos/comandos/aws-cli.md)); **SDKs** y **API** para integrar AWS en tu aplicación.
- **Infrastructure as code (IaC)**: **CloudFormation**, CDK, Terraform. Para procesos **repetibles** y entornos iguales (ver [Infrastructure as Code](../../../devops/iac/infraestructura-como-codigo.md)).
- **AWS Elastic Beanstalk** (**PaaS**): subes el código y crea EC2, load balancer y auto scaling.
- **Amazon Lightsail**: servidores, bases de datos y balanceadores con **precio mensual fijo y simple**.
- **Deployment models**: **cloud** (todo en AWS), **hybrid** (on-premises + nube: Direct Connect, **AWS Outposts**, Storage Gateway) y **on-premises** (*private cloud*).

!!! tip "En el examen"
    - "Mismo entorno en varias regiones de forma **repetible**" → **CloudFormation**. "Subir código y que AWS gestione el resto" → **Elastic Beanstalk**.
    - "Precio mensual predecible" → **Lightsail**. "Servicios de AWS **en tu datacenter**" → **Outposts**.

## Infraestructura global

Explicada a fondo en [Modelos de servicio y regiones](../../../cloud/fundamentos/modelos-de-servicio-y-regiones.md#infraestructura-global). Lo esencial:

| Componente | Qué es | Para qué sirve |
| --- | --- | --- |
| **Region** (región) | Zona geográfica con varias AZ aisladas (las nuevas tienen al menos 3) | **Soberanía de datos**, cercanía a usuarios, DR |
| **Availability Zone (AZ)** | Uno o varios datacenters con energía, red y refrigeración **independientes**, con baja latencia entre sí | **High availability**: no comparten puntos únicos de fallo |
| **Edge location** | Punto de presencia para caché y red cerca del usuario | **CloudFront**, **Route 53**, Global Accelerator, Shield |
| **Local Zone** / **Outposts** | Extensión de una región cerca de una gran ciudad / hardware de AWS en tu datacenter | Latencia de milisegundos; datos que se quedan on-premises |

**Cómo elegir región**: **compliance**, **proximity** (latencia), **service availability** y **pricing**.

!!! tip "En el examen"
    - "**Highly available**" / caída de un datacenter → **multi-AZ**. "**Disaster recovery** regional" → **multi-región**.
    - "Los datos no pueden salir del país" → región dentro del país. "Latencia baja en otro continente" → región cercana o **CloudFront**.
    - Una AZ **no** es necesariamente un solo datacenter. No lanzas EC2 en una edge location.

## Servicios de cómputo

Detalle en [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md), [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md) y [Serverless](../../../cloud/computo/serverless.md). Los modelos de compra están en el [Dominio 4](dominio-4-facturacion-precios-soporte.md#modelos-de-compra-de-computo).

| Familia de EC2 | Uso típico |
| --- | --- |
| **General purpose** (M, T) | Equilibrio CPU/memoria: servidores web, desarrollo |
| **Compute optimized** (C) | Mucha CPU: batch, servidores de juegos, HPC, codificación de video |
| **Memory optimized** (R, X) | Mucha memoria: bases de datos en memoria, análisis en tiempo real |
| **Storage optimized** (I, D) | Disco local con IOPS altas: OLTP, data warehousing |
| **Accelerated computing** (P, G, Inf, Trn) | GPU y aceleradores: machine learning, gráficos |

- **EC2 Auto Scaling**: añade o quita instancias según la demanda (**elasticidad**) y reemplaza las que fallan.
- **Elastic Load Balancing (ELB)**: reparte tráfico entre AZ con **health checks**. **ALB** (capa 7, HTTP), **NLB** (capa 4, IP fija), **Gateway LB** (appliances de terceros).

- Contenedores: **ECS** (orquestador propio de AWS), **EKS** (**Kubernetes** gestionado), **ECR** (registro de imágenes), **Fargate** (contenedores **serverless** en ECS o EKS). **AWS Batch**: miles de trabajos por lotes.
- **AWS Lambda**: funciones **serverless** por eventos; pagas por petición y duración; **máximo 15 minutos**.

!!! tip "En el examen"
    - "Código **sin gestionar servidores**, por eventos" → **Lambda** (si dura más de 15 minutos, no sirve).
    - "Contenedores sin gestionar servidores" → **Fargate**. "Kubernetes gestionado" → **EKS**.
    - **ELB** reparte tráfico y **Auto Scaling** añade instancias: son complementarios.

## Bases de datos

Detalle en [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md). Base de datos en **EC2** solo si necesitas acceso al SO o un motor no soportado; si no, **gestionada** (menos esfuerzo operativo: tú solo gestionas esquema, datos y acceso). Migración con **DMS** y **SCT** ([Dominio 1](dominio-1-conceptos-cloud.md)).

| Servicio | Tipo | Característica clave |
| --- | --- | --- |
| **Amazon RDS** | Relacional gestionada | MySQL, PostgreSQL, MariaDB, Oracle, SQL Server, Db2; **Multi-AZ** y **read replicas** |
| **Amazon Aurora** | Relacional compatible con MySQL y PostgreSQL | Más rendimiento, 6 copias en 3 AZ; opción serverless |
| **Amazon DynamoDB** | **NoSQL** clave-valor, serverless | Milisegundos de un dígito a cualquier escala; **global tables** |
| **Amazon ElastiCache** | **En memoria** (Valkey, Redis OSS, Memcached) | Caché de lecturas, sesiones |
| **Amazon DocumentDB** | Documentos (compatible con MongoDB) | Migrar MongoDB |
| **Amazon Neptune** | Grafos | Redes sociales, recomendaciones, fraude |
| **Amazon Redshift** | **Data warehouse** | Analítica SQL sobre petabytes |

!!! tip "En el examen"
    - "Relacional, gestionada, menor esfuerzo" → **RDS**. "Alto rendimiento MySQL/PostgreSQL" → **Aurora**.
    - "Consultas analíticas sobre muchos datos históricos" → **Redshift** (no RDS).
    - **Multi-AZ** = alta disponibilidad; **read replicas** = escalar lecturas.

## Servicios de red

Detalle en [Redes en la nube](../../../cloud/redes-y-datos/redes.md).

- **Amazon VPC**: red privada aislada en una región. **Subnet**: rango de IPs en **una AZ**; pública si tiene ruta a un **internet gateway**.
- **NAT gateway**: recursos privados **salen** a internet sin ser accesibles desde fuera. **Route table**: a dónde va el tráfico.
- **VPC peering** / **Transit Gateway** (hub para muchas VPC); **PrivateLink**: acceso privado a servicios sin internet.

### Security groups vs network ACLs

Comparación completa en [Redes en la nube](../../../cloud/redes-y-datos/redes.md#firewalls-stateful-y-stateless).

| | **Security group** | **Network ACL** |
| --- | --- | --- |
| Nivel | **Instancia** (interfaz de red) | **Subnet** |
| Estado | **Stateful**: la respuesta se permite sola | **Stateless**: hay que permitir ida y vuelta |
| Reglas | Solo **allow** | **Allow y deny** |
| Por defecto | Niega lo entrante, permite lo saliente | La NACL por defecto permite todo |

### DNS, CDN y conectividad

- **Route 53**: **DNS** gestionado, registro de dominios, health checks y enrutamiento (latencia, geolocalización, failover, ponderado).
- **CloudFront**: **CDN** que cachea en edge locations. **Global Accelerator**: red de AWS e IPs anycast fijas para TCP/UDP (no cachea).
- **API Gateway**: crear, publicar y proteger APIs (a menudo delante de Lambda).

| Conectividad on-premises ↔ AWS | Cómo funciona | Cuándo |
| --- | --- | --- |
| **Site-to-Site VPN** | Túnel IPsec cifrado **por internet** | Rápido y barato; rendimiento variable |
| **Client VPN** | VPN para usuarios individuales | Teletrabajo hacia la VPC |
| **Direct Connect** | Conexión **física privada dedicada**, sin internet | Ancho de banda alto y constante; tarda semanas |

!!! tip "En el examen"
    - "Firewall de **instancia**, stateful" → **security group**. "De **subred**, con deny" → **network ACL**.
    - "**Privada y dedicada**" → **Direct Connect**. "Cifrada por internet, rápida" → **Site-to-Site VPN**.

## Servicios de almacenamiento

Detalle en [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md).

| Tipo | Servicio | Clave |
| --- | --- | --- |
| **Object** | **Amazon S3** | Objetos en **buckets** por HTTP; 11 nueves de durabilidad. Backups, data lakes, webs estáticas |
| **Block** | **Amazon EBS** | Disco **persistente** de **una** EC2 en **una AZ**; snapshots a S3 |
| Block efímero | **Instance store** | Disco del host; **se pierde** al detener o terminar |
| **File** | **Amazon EFS** | NFS **compartido** por muchas instancias Linux, multi-AZ |
| File especializado | **Amazon FSx** | Windows File Server (SMB), NetApp ONTAP, OpenZFS, Lustre |
| Híbrido | **AWS Storage Gateway** | **Caché** local con los datos en AWS (File, Volume, Tape Gateway) |

### Amazon S3 storage classes

| Storage class | Acceso | Detalle clave |
| --- | --- | --- |
| **S3 Standard** | Frecuente | Por defecto; varias AZ; milisegundos |
| **S3 Intelligent-Tiering** | **Desconocido o cambiante** | Mueve objetos entre tiers según el uso, sin costo de recuperación (pequeño cargo de monitoreo) |
| **S3 Standard-IA** | Poco frecuente, pero rápido | Más barato, **cobro por recuperación**; mínimo 30 días |
| **S3 One Zone-IA** | Poco frecuente, datos **re-creables** | Una sola AZ: más barata, se pierde si falla esa AZ |
| **S3 Express One Zone** | Muy frecuente, latencia mínima | Una AZ, alto rendimiento |
| **S3 Glacier Instant Retrieval** | ~1 vez por trimestre | Recuperación en **milisegundos**; mínimo 90 días |
| **S3 Glacier Flexible Retrieval** | 1–2 veces al año | **Minutos a horas**; mínimo 90 días |
| **S3 Glacier Deep Archive** | Largo plazo (7–10 años) | **La más barata**; **horas** (hasta 12 h estándar); mínimo 180 días |

**Lifecycle policies**: **mueven** objetos a una clase más barata o los **borran** tras un tiempo (p. ej. Standard → Standard-IA a los 30 días → Deep Archive a los 365 → borrar a los 7 años). **AWS Backup** centraliza backups de EBS, RDS, DynamoDB, EFS, FSx y más, en varias cuentas; **Elastic Disaster Recovery** replica servidores para recuperarlos en AWS.

!!! tip "En el examen"
    - "Acceso **desconocido**" → **Intelligent-Tiering**. "Archivo más barato, se puede esperar horas" → **Glacier Deep Archive**. "Poco consultado pero **al instante**" → **Glacier Instant Retrieval**.
    - "Disco de **una** instancia" → **EBS**. "Compartido Linux" → **EFS**. "Compartido Windows (SMB)" → **FSx for Windows File Server**.

## IA/ML y analítica

Bedrock y la IA generativa están en [AI Practitioner](../ai-practitioner/resumen-examen.md). Aquí basta reconocer cada servicio por la frase del enunciado:

| Frase en la pregunta | Servicio |
| --- | --- |
| "Construir, entrenar y desplegar **un modelo propio**" | **SageMaker AI** |
| "**Chatbot** de voz o texto" | **Lex** |
| "Leer en voz alta" (texto a voz) / "llamadas grabadas a texto" (voz a texto) | **Polly** / **Transcribe** |
| "Traducir" | **Translate** |
| "**Sentimiento**, entidades o temas de un texto" (NLP) | **Comprehend** |
| "**Rostros**, objetos o contenido inapropiado en imágenes o video" | **Rekognition** |
| "Datos de **documentos escaneados**, facturas, formularios" | **Textract** |
| "Asistente de **IA generativa**" para datos de la empresa o para programar en AWS | **Amazon Q** (Q Business / Q Developer) |
| "**SQL serverless sobre S3**" (pagas por datos escaneados) | **Athena** |
| "Datos en **streaming**, tiempo real" | **Kinesis** |
| "**ETL** serverless", "catálogo de metadatos" | **Glue** |
| "Data warehouse" / "big data con Spark o Hadoop" / "búsqueda en logs" | **Redshift** / **EMR** / **OpenSearch Service** |
| "**Dashboards**, BI" | **Quick Sight** (antes QuickSight, hoy dentro de Amazon Quick) |

## Otros servicios en alcance

Patrones de integración en [Integración y APIs](../../../cloud/arquitectura/integracion-apis.md).

| Necesidad | Servicio |
| --- | --- |
| **Cola** que **desacopla** componentes (un consumidor por mensaje) | **Amazon SQS** |
| **Pub/sub**: un mensaje a **muchos** suscriptores (email, SMS, SQS, Lambda) | **Amazon SNS** |
| **Bus de eventos** con reglas; *scheduler* | **Amazon EventBridge** |
| Orquestar flujos de trabajo con pasos | **AWS Step Functions** |
| **Contact center** / **emails** transaccionales | **Amazon Connect** / **Amazon SES** |
| CI / pipeline de CI/CD / **trazar** peticiones | **CodeBuild** / **CodePipeline** / **X-Ray** |
| **Escritorio virtual** / **transmitir una aplicación** / navegador seguro sin VPN | **WorkSpaces** / **AppStream 2.0** / **WorkSpaces Secure Browser** |
| Frontends web y móviles full-stack / dispositivos IoT | **Amplify** / **IoT Core** |

Gestión y operación: **Systems Manager** (flotas, parches, Session Manager sin SSH abierto), **Organizations** y **Control Tower** (ver [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md)), **Service Catalog**, **Service Quotas** y **CloudWatch**.

!!! tip "En el examen"
    - "Que no se pierdan pedidos si el procesamiento cae" → **SQS**, no SNS.
    - "Contact center" → **Connect**, no SNS ni SES.

## Casos de uso

1. Web que debe seguir si cae un datacenter → EC2 en **varias AZ** con **ELB** y **Auto Scaling**.
2. Procesar imágenes al subirlas a S3 (20 segundos) → **Lambda** por eventos de S3.
3. Kubernetes on-premises que pasa a AWS → **EKS** (con Fargate si no quieren gestionar nodos).
4. Logs de auditoría por 7 años, casi nunca consultados → **Glacier Deep Archive** con **lifecycle policy**.
5. Conexión privada y estable de 10 Gbps al datacenter → **Direct Connect** (VPN de respaldo).
6. Chatbot por voz en un call center → **Connect** con **Lex**.
7. Servicio de pedidos que pierde peticiones en picos → **SQS** entre frontend y procesamiento.

## Preguntas de práctica

**1.** ¿Qué afirmación describe correctamente las Availability Zones?

- A. Son ubicaciones de caché de CloudFront
- B. Son ubicaciones aisladas dentro de una región, sin puntos únicos de fallo compartidos
- C. Cada una está en un país diferente
- D. Son lo mismo que una región

??? success "Respuesta"
    **B.** Las AZ están aisladas (energía, red, refrigeración) pero dentro de una región. A describe edge locations; C y D son incorrectas.

**2.** Una empresa quiere ejecutar contenedores sin aprovisionar ni gestionar servidores ni clústeres de EC2. ¿Qué servicio debe usar?

- A. Amazon EC2
- B. AWS Fargate
- C. Amazon Lightsail
- D. AWS Outposts

??? success "Respuesta"
    **B.** Fargate es el motor serverless para contenedores en ECS y EKS. A exige gestionar instancias; C es un servicio simplificado de servidores; D lleva hardware de AWS a tu datacenter.

**3.** Una empresa guarda informes que se consultan con frecuencia los primeros 30 días y casi nunca después, pero deben conservarse 5 años. ¿Cuál es la solución MÁS rentable?

- A. Guardar todo en S3 Standard
- B. Usar una S3 Lifecycle policy que mueva los objetos a S3 Glacier Deep Archive tras 30 días
- C. Guardar todo en volúmenes EBS
- D. Guardar todo en instance store

??? success "Respuesta"
    **B.** La lifecycle policy automatiza el paso a la clase más barata cuando ya no se consultan. A cuesta más; C es almacenamiento en bloque más caro y ligado a una instancia; D se pierde al detener la instancia.

**4.** ¿Cuál es una diferencia entre security groups y network ACLs?

- A. Los security groups son stateless y las network ACLs stateful
- B. Los security groups actúan a nivel de instancia y las network ACLs a nivel de subnet
- C. Los security groups admiten reglas deny
- D. Las network ACLs solo se aplican a Amazon RDS

??? success "Respuesta"
    **B.** A está al revés; C es falso (solo allow); D es falso.

**5.** Una aplicación necesita una base de datos relacional compatible con PostgreSQL, gestionada, con alto rendimiento y datos replicados en varias AZ. ¿Qué servicio encaja MEJOR?

- A. Amazon DynamoDB
- B. Amazon Aurora
- C. Amazon ElastiCache
- D. Amazon Neptune

??? success "Respuesta"
    **B.** Aurora es relacional, compatible con PostgreSQL y MySQL, y replica en 3 AZ. A es NoSQL; C es caché en memoria; D es de grafos.

**6.** ¿Qué servicio permite consultar con SQL estándar datos almacenados en Amazon S3 sin gestionar infraestructura?

- A. Amazon Redshift
- B. Amazon Athena
- C. Amazon Kinesis
- D. AWS Glue

??? success "Respuesta"
    **B.** Athena es serverless y consulta directamente sobre S3. A es un data warehouse donde normalmente cargas los datos; C es para streaming; D es ETL y catálogo.

**7.** ¿Cuáles DOS servicios ayudan a desacoplar componentes de una aplicación? (Elige dos.)

- A. Amazon SQS
- B. Amazon SNS
- C. Amazon EBS
- D. AWS Direct Connect
- E. Amazon Route 53

??? success "Respuesta"
    **A y B.** SQS (colas) y SNS (pub/sub) permiten que los componentes se comuniquen sin depender directamente unos de otros. C es almacenamiento en bloque; D es conectividad dedicada; E es DNS.

**8.** Una empresa necesita extraer automáticamente campos (nombre, importe, fecha) de miles de facturas escaneadas. ¿Qué servicio debe usar?

- A. Amazon Rekognition
- B. Amazon Comprehend
- C. Amazon Textract
- D. Amazon Polly

??? success "Respuesta"
    **C.** Textract extrae texto, formularios y tablas de documentos. A analiza imágenes y video (rostros, objetos); B analiza texto ya digital; D convierte texto en voz.

## Para profundizar

- [Modelos de servicio y regiones](../../../cloud/fundamentos/modelos-de-servicio-y-regiones.md): infraestructura global.
- [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md), [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md) y [Serverless](../../../cloud/computo/serverless.md)
- [Redes en la nube](../../../cloud/redes-y-datos/redes.md) y [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md)
- [Resiliencia](../../../cloud/operacion-y-gobierno/resiliencia.md): multi-AZ, multi-región y disaster recovery
- [Integración y APIs](../../../cloud/arquitectura/integracion-apis.md)

## Referencias

- [Exam guide CLF-C02: Domain 3](https://docs.aws.amazon.com/aws-certification/latest/cloud-practitioner-02/cloud-practitioner-02-domain3.html)
- [AWS Global Infrastructure](https://aws.amazon.com/about-aws/global-infrastructure/)
- [Amazon S3 storage classes](https://aws.amazon.com/s3/storage-classes/)
- [Control traffic with security groups and network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/infrastructure-security.html)
