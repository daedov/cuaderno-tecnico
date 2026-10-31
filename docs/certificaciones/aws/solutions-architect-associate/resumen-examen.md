---
tags:
  - aws
  - certificacion
  - saa-c03
  - arquitectura
---

# AWS Certified Solutions Architect – Associate (SAA-C03)

> Qué evalúa el examen de Solutions Architect – Associate, cómo es el formato, cuánto pesa cada dominio y un plan de estudio de 6 semanas para diseñar arquitecturas en AWS seguras, resilientes, de alto rendimiento y con costos optimizados.

!!! info "Versión verificada"
    Datos revisados en octubre de 2026 en la [guía oficial del examen](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03/solutions-architect-associate-03.html) y en la [página de la certificación](https://aws.amazon.com/es/certification/certified-solutions-architect-associate/). La versión vigente sigue siendo **SAA-C03**; AWS no ha publicado una guía SAA-C04 (los sitios de terceros que hablan de "SAA-C04" no tienen fuente oficial). Revisa ambas páginas antes de agendar.

Lo genérico (estrategia del día del examen, palabras clave comunes, examen en línea) está en [Cómo preparar un examen](../../como-preparar-un-examen.md).

## ¿Qué es?

Es la certificación de nivel **Associate** (asociado) para el rol de **solutions architect** (arquitecto/a de soluciones). Valida que sabes diseñar soluciones basadas en el [Well-Architected Framework](../../../cloud/fundamentos/well-architected.md). A diferencia de [Cloud Practitioner](../cloud-practitioner/resumen-examen.md), no basta con saber *qué* es un servicio: el examen da un escenario con requisitos (seguridad, disponibilidad, rendimiento, costo, poco esfuerzo operativo) y pide **la mejor** de varias opciones que técnicamente funcionarían.

## Formato del examen

| Aspecto | Detalle |
| --- | --- |
| Código | SAA-C03 |
| Preguntas | 65: **50 puntuables** y 15 no puntuables (no sabes cuáles son) |
| Tipos de pregunta | **Multiple choice** (1 correcta de 4) y **multiple response** (2 o más correctas de 5 o más) |
| Duración | 130 minutos (2 minutos por pregunta) |
| Puntaje | Escala de 100 a 1,000; aprueba con **720** |
| Modelo de puntuación | **Compensatorio**: no necesitas aprobar cada dominio, solo el total |
| Costo | 150 USD (más impuestos o tipo de cambio) |
| Modalidad | Centro Pearson VUE o en línea con supervisión (*online proctored*) |
| Idiomas | Inglés, francés, italiano, japonés, coreano, portugués (Brasil), español (Latinoamérica), español (España), chino simplificado y tradicional |
| Validez | 3 años |

!!! note "Idioma italiano"
    La página oficial indica que la versión en italiano se retira después del 31 de diciembre de 2026.

## Objetivo profesional

Para quien ya diseña soluciones en AWS (AWS pide **al menos 1 año de experiencia práctica**). Sirve para [Cloud Architect / Solutions Architect](../../roles-profesionales.md#cloud-architect-solutions-architect), [Cloud Engineer](../../roles-profesionales.md#cloud-engineer) y [DevOps Engineer](../../roles-profesionales.md#devops-engineer); es la certificación de AWS que más aparece en ofertas. Siguiente paso: [Terraform Associate](../../hashicorp/terraform-associate/resumen-examen.md), o Solutions Architect – Professional (SAP-C03 desde noviembre de 2026), DevOps Engineer – Professional o Security – Specialty según el rol ([Otras certificaciones](../../otras-certificaciones.md#aws-el-resto-del-catalogo)).

Ayuda llegar con soltura en redes (CIDR, subnets, routing, NAT, DNS: ver [Networking](../../../networking/basico/direccionamiento-ip.md)), IAM, el [Shared Responsibility Model](../../../cloud/fundamentos/responsabilidad-compartida.md) y conceptos como acoplamiento, escalado horizontal y RTO/RPO.

## Dominios y peso

| Dominio | Peso | Task statements | Nota |
| --- | --- | --- | --- |
| 1. Design Secure Architectures | 30% | 1.1 acceso seguro a recursos · 1.2 cargas y aplicaciones seguras · 1.3 controles de seguridad de datos | [Dominio 1](dominio-1-arquitecturas-seguras.md) |
| 2. Design Resilient Architectures | 26% | 2.1 arquitecturas escalables y desacopladas · 2.2 alta disponibilidad y tolerancia a fallos | [Dominio 2](dominio-2-arquitecturas-resilientes.md) |
| 3. Design High-Performing Architectures | 24% | 3.1 almacenamiento · 3.2 cómputo elástico · 3.3 bases de datos · 3.4 redes · 3.5 ingesta y transformación de datos | [Dominio 3](dominio-3-arquitecturas-alto-rendimiento.md) |
| 4. Design Cost-Optimized Architectures | 20% | 4.1 almacenamiento · 4.2 cómputo · 4.3 bases de datos · 4.4 redes | [Dominio 4](dominio-4-arquitecturas-costo-optimizado.md) |

Con 50 preguntas puntuables son unas 15, 13, 12 y 10 por dominio.

## Servicios dentro y fuera de alcance

Los que más salen (lista completa en [In-Scope AWS Services](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03/saa-03-in-scope-services.html)):

| Categoría | En alcance |
| --- | --- |
| Cómputo | EC2, Auto Scaling, Lambda, Fargate, ECS, EKS, Batch, Outposts |
| Almacenamiento | S3, EBS, EFS, FSx, Storage Gateway, AWS Backup |
| Bases de datos | RDS, Aurora, DynamoDB, ElastiCache, Redshift |
| Redes | VPC, Route 53, CloudFront, Global Accelerator, ELB, Direct Connect, VPN, PrivateLink, Transit Gateway |
| Integración | SQS, SNS, EventBridge, Step Functions, API Gateway |
| Analítica | Athena, Glue, EMR, Kinesis, Amazon Data Firehose |
| Seguridad | IAM, IAM Identity Center, Cognito, KMS, Secrets Manager, ACM, WAF, Shield, GuardDuty, Macie |
| Gestión y costos | Organizations, CloudTrail, CloudWatch, Config, Systems Manager, Compute Optimizer, Cost Explorer, Budgets |
| Migración | DMS, DataSync, Application Migration Service, Transfer Family |

**Fuera de alcance** (ejemplos): Lightsail, IoT, CDK y SDKs, CodeBuild/CodeDeploy/CodeCommit, CloudShell, MWAA, GameLift.

!!! warning "Nombres y servicios que cambiaron"
    - **Amazon Quick** es el nombre actual en la guía (antes Amazon QuickSight). **Amazon Data Firehose** se llamaba Kinesis Data Firehose.
    - **Snow Family** sigue en la guía, pero AWS dejó de vender Snowcone (noviembre de 2024) y desde el 7 de noviembre de 2025 Snowball Edge solo está disponible para clientes existentes. Ver [Dominio 3](dominio-3-arquitecturas-alto-rendimiento.md#transferencia-de-datos-hibrida-y-migracion).
    - El servicio original **Amazon Glacier** basado en *vaults* ya no acepta clientes nuevos (desde el 15 de diciembre de 2025); se usan las **clases S3 Glacier** dentro de S3.

## Plan de estudio sugerido (6 semanas)

| Semana | Foco | Práctica |
| --- | --- | --- |
| 1 | Fundamentos: regiones y AZ, IAM a fondo, VPC (subnets, route tables, SG vs NACL, NAT) | Crea una VPC de 2 AZ con subnets públicas y privadas; asume un rol entre cuentas |
| 2 | Dominio 1: Organizations, SCP, KMS, Secrets Manager, Cognito, WAF/Shield, VPC endpoints | Cifra un bucket con SSE-KMS y restringe el acceso con una bucket policy + gateway endpoint |
| 3 | Dominio 2: SQS/SNS/EventBridge, ELB, Auto Scaling, RDS Multi-AZ y read replicas, Route 53, DR | Monta ALB + Auto Scaling group con target tracking; simula la caída de una instancia |
| 4 | Dominio 3: EBS/EFS/FSx, S3 rendimiento, DynamoDB/DAX/ElastiCache, CloudFront vs Global Accelerator, Kinesis, Athena/Glue | Consulta un CSV en S3 con Athena; conviértelo a Parquet con Glue y compara el costo escaneado |
| 5 | Dominio 4: clases de S3 y lifecycle, Savings Plans/RI/Spot, costos de transferencia y NAT, herramientas de costos | Crea una lifecycle rule y un AWS Budget con alerta |
| 6 | Repaso: preguntas de práctica, puntos débiles, whitepapers de DR y Well-Architected | Official Practice Question Set + un examen de práctica completo cronometrado |

!!! tip "Cómo estudiar las tablas de decisión"
    Para cada fila de las tablas "X vs Y" de los dominios, escribe **la palabra clave del escenario** que te haría elegir esa opción ("sub-millisecond", "SMB", "exactly-once", "static IP"). El examen se gana reconociendo esas palabras.

## Palabras clave propias de SAA

Además de las [genéricas](../../como-preparar-un-examen.md#palabras-clave-que-deciden-la-respuesta):

| Frase en la pregunta | Qué suele significar |
| --- | --- |
| Highly available | Multi-AZ como mínimo |
| Without changing the application code | RDS Proxy, ELB, Auto Scaling, Storage Gateway |
| Decouple | SQS, SNS, EventBridge |
| Near real-time / real-time | Kinesis Data Streams (real-time) vs Data Firehose (near real-time) |
| Infrequently accessed but needs immediate retrieval | S3 Standard-IA o Glacier Instant Retrieval |
| MOST secure | Además del mínimo privilegio: tráfico privado con VPC endpoints |

## Recursos oficiales gratuitos

| Recurso | Para qué |
| --- | --- |
| [Guía oficial del examen](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03/solutions-architect-associate-03.html) | Dominios, task statements y servicios en alcance; fuente de verdad |
| [AWS Skill Builder](https://skillbuilder.aws/) | Exam Prep Standard Course y **Official Practice Question Set** (gratis); el Official Practice Exam y AWS Cloud Quest requieren suscripción |
| [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html) | Los cuatro dominios mapean a Security, Reliability, Performance Efficiency y Cost Optimization |
| [Whitepaper de disaster recovery](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-workloads-on-aws.html) | Estrategias de DR con RTO/RPO, muy preguntadas |
| [AWS Architecture Center](https://aws.amazon.com/architecture/) | Arquitecturas de referencia y diagramas |

## Para profundizar

- [Redes](../../../cloud/redes-y-datos/redes.md) y [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md): base comparativa de cada servicio.
- [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md) y [Resiliencia](../../../cloud/operacion-y-gobierno/resiliencia.md).
- [Arquitecturas de referencia](../../../cloud/arquitectura/arquitecturas-referencia.md).
- [Infrastructure as Code](../../../devops/iac/infraestructura-como-codigo.md): construir estas arquitecturas como código.
- [Continuidad de negocio](../../../negocio/continuidad-negocio.md): de dónde salen RTO/RPO y SLA.
- [Lab 17: AWS: VPC con subnets públicas y privadas y una EC2](../../../laboratorios/cloud/aws-vpc-ec2.md).

## Referencias

- [AWS Certified Solutions Architect – Associate](https://aws.amazon.com/es/certification/certified-solutions-architect-associate/)
- [Exam guide SAA-C03](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03/solutions-architect-associate-03.html)
- [In-Scope AWS Services](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03/saa-03-in-scope-services.html)
- [Out-of-Scope AWS Services](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03/saa-03-out-of-scope-services.html)
- [AWS Skill Builder](https://skillbuilder.aws/)
- [AWS Snow device updates (AWS Storage Blog)](https://aws.amazon.com/blogs/storage/aws-snow-device-updates/)
