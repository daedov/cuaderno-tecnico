---
tags:
  - aws
  - certificacion
  - saa-c03
  - arquitectura
  - computo
  - redes
---

# Dominio 3: Design High-Performing Architectures (24%)

> Elegir el almacenamiento, el cómputo, la base de datos, la red y el pipeline de datos adecuados para la latencia, las IOPS y el throughput que pide cada escenario.

!!! info "Qué evalúa este dominio"
    - **Task 3.1 – Storage**: S3, EFS, EBS y almacenamiento híbrido que cumplan el rendimiento y escalen.
    - **Task 3.2 – Compute**: tipos de instancia, Auto Scaling, Lambda (memoria), contenedores, Batch, EMR; métricas de escalado.
    - **Task 3.3 – Databases**: tipo de base según el patrón de acceso, capacidad, read replicas, proxies y caché.
    - **Task 3.4 – Network**: CloudFront y Global Accelerator, load balancing, conectividad entre VPC e híbrida.
    - **Task 3.5 – Data ingestion and transformation**: Kinesis, DataSync, Storage Gateway, Glue, Athena, Lake Formation; conversión CSV a Parquet.

    Formato y resto de dominios en el [resumen del examen](resumen-examen.md). Los costos (clases de S3, modelos de compra) están en el [Dominio 4](dominio-4-arquitecturas-costo-optimizado.md).

## Almacenamiento

Qué es S3, EBS, instance store, EFS y FSx está en [Cloud Practitioner](../cloud-practitioner/dominio-3-tecnologia-servicios.md) y en [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md). Aquí, cómo elegir por rendimiento.

### Tipos de volumen EBS

| Tipo | Medio | Rendimiento | Casos de uso |
| --- | --- | --- | --- |
| **gp3** | SSD | 3,000 IOPS y 125 MiB/s de base, independientes del tamaño; IOPS y throughput aprovisionables aparte (desde septiembre de 2025, hasta 80,000 IOPS, 2,000 MiB/s y 64 TiB) | **Por defecto**: boot, apps, bases medianas |
| gp2 | SSD | IOPS ligadas al tamaño (3 IOPS por GiB) con burst | Legacy: migra a gp3 |
| **io2 Block Express** | SSD | Hasta 256,000 IOPS, latencia submilisegundo, mayor durabilidad | Bases críticas con IOPS sostenidas (Oracle, SQL Server, SAP HANA) |
| io1 | SSD | IOPS aprovisionadas | Legacy frente a io2 |
| **st1** | HDD | Throughput alto y barato | Big data, logs: lectura **secuencial** |
| **sc1** | HDD | El más barato | Datos fríos secuenciales |

- Los HDD **no pueden ser volumen de arranque**. **Multi-Attach**: solo io1/io2, misma AZ, con sistema de archivos de clúster.
- EBS vive en **una AZ**: para moverlo, **snapshot** y nuevo volumen (las snapshots se copian entre regiones).
- Las cifras máximas cambian: revisa la [documentación de tipos de volumen](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volume-types.html).

!!! tip "En el examen"
    "IOPS altas y sostenidas para una base de datos" → **io2**. "Rendimiento predecible, buen costo" → **gp3**. "Procesamiento secuencial de grandes archivos de log, barato" → **st1**. "La máxima I/O posible y los datos se pueden perder" → **instance store**.

### EFS vs FSx

| Servicio | Protocolo | Clientes | Úsalo cuando |
| --- | --- | --- | --- |
| **Amazon EFS** | NFS v4 | Linux | Compartido elástico, sin aprovisionar; throughput **Elastic** (recomendado), Provisioned o Bursting |
| **FSx for Windows File Server** | **SMB** | Windows | Carpetas compartidas Windows, **Active Directory**, DFS |
| **FSx for Lustre** | Lustre | Linux | **HPC**, ML, renderizado; lee un bucket S3 como sistema de archivos |
| **FSx for NetApp ONTAP** | NFS, SMB **e iSCSI** | Linux, Windows, macOS | Migrar NetApp, multiprotocolo |
| **FSx for OpenZFS** | NFS | Linux, macOS | Migrar ZFS, baja latencia, snapshots y clones |

!!! tip "En el examen"
    "Windows" o "SMB" o "Active Directory" → **FSx for Windows**. "HPC", "sub-millisecond", "procesar datos de S3 en paralelo" → **FSx for Lustre**. "Linux compartido entre muchas instancias en varias AZ" → **EFS**. "Varios protocolos a la vez" → **FSx for NetApp ONTAP**.

### Rendimiento de S3

- S3 escala por **prefijo**: al menos 3,500 PUT/COPY/POST/DELETE y 5,500 GET/HEAD por segundo **por prefijo**; más prefijos, más rendimiento.
- **Multipart upload**: recomendado desde 100 MB, obligatorio por encima de 5 GB. **Byte-range fetches**: descargar partes en paralelo.
- **S3 Transfer Acceleration**: subidas por las edge locations de CloudFront para usuarios lejanos.
- **S3 Express One Zone**: una AZ, latencia de milisegundos de un dígito, *directory buckets*, para ML y analítica intensiva.

## Cómputo de alto rendimiento

Familias de instancia (M/T general, C cómputo, R/X memoria, I/D almacenamiento, P/G/Inf/Trn aceleradas) en [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md#familias-de-maquinas).

| Placement group | Cómo coloca | Para qué |
| --- | --- | --- |
| **Cluster** | Juntas en una AZ, red de baja latencia y alto throughput | HPC, apps muy acopladas (+ **EFA** para MPI) |
| **Spread** | Cada instancia en hardware distinto (máximo 7 por AZ por grupo) | Pocas instancias críticas que no deben fallar juntas |
| **Partition** | Particiones en racks separados | Hadoop, Cassandra, Kafka |

- **Lambda**: la CPU es proporcional a la **memoria** (128 MB a 10,240 MB); máximo 15 minutos. **Provisioned concurrency** elimina cold starts; **reserved concurrency** reserva y limita. Ver [Serverless](../../../cloud/computo/serverless.md#cold-starts).
- **AWS Batch**: lotes en contenedores (incluido Spot) para jobs de más de 15 minutos. **Amazon EMR**: Spark, Hadoop, Hive, Presto.
- **Edge**: **Outposts** (racks de AWS en tu datacenter), **Local Zones** (cerca de grandes ciudades), **Wavelength** (redes 5G).

!!! tip "En el examen"
    "Procesamiento que tarda 2 horas" → no es Lambda: **Batch**, ECS/Fargate o EC2. "Baja latencia entre nodos HPC" → **cluster placement group** (+ EFA). "Evitar que un fallo de hardware tumbe varias instancias críticas" → **spread**.

## Bases de datos según el patrón de acceso

| Necesidad | Servicio |
| --- | --- |
| Relacional estándar (MySQL, PostgreSQL, MariaDB, Oracle, SQL Server, Db2) | **RDS** |
| Relacional de alto rendimiento | **Aurora**; **Aurora Serverless v2** para carga variable |
| Clave-valor o documentos, milisegundos a cualquier escala | **DynamoDB** |
| Caché, sesiones, leaderboards | **ElastiCache** |
| Data warehouse OLAP | **Redshift** |
| MongoDB / grafos / Cassandra | **DocumentDB** / **Neptune** / **Keyspaces** |
| Búsqueda de texto y logs | **OpenSearch Service** |

**DynamoDB**: modos **on-demand** (tráfico impredecible) y **provisioned** (RCU/WCU con auto scaling; costo en el [Dominio 4](dominio-4-arquitecturas-costo-optimizado.md#bases-de-datos)). 1 **RCU** = 1 lectura fuerte/s de hasta 4 KB (o 2 eventuales); 1 **WCU** = 1 escritura/s de hasta 1 KB; ítem máximo 400 KB. **DAX**: caché **compatible con la API**, lecturas en **microsegundos** sin cambiar la lógica. **Streams** para disparar Lambdas; **TTL** borra sin costo de escritura; **GSI** (otra partition key, se crea después) vs **LSI** (misma partition key, solo al crear la tabla).

| ElastiCache | Valkey / Redis OSS | Memcached |
| --- | --- | --- |
| Estructuras | Ricas (sorted sets, hashes, pub/sub) | Clave-valor simple |
| Replicación, Multi-AZ, persistencia | Sí | No |
| Escalado | Shards y réplicas | Nodos; multihilo |
| Úsalo cuando | Sesiones, leaderboards, HA | Caché simple y desechable |

Estrategias: **lazy loading / cache-aside** y **write-through** (ver [Arquitectura en la nube](../../../cloud/arquitectura/arquitectura-cloud.md)). **ElastiCache Serverless** para no gestionar nodos.

!!! tip "En el examen"
    "Microsegundos en DynamoDB sin cambiar código" → **DAX**. "Acelerar consultas repetidas a RDS" → **ElastiCache** (requiere cambios en la app) o read replicas. "Leaderboard en tiempo real" → **ElastiCache (Valkey/Redis OSS) sorted sets**. "Escalar relacional con lecturas intensivas en todo el mundo" → **Aurora Global Database**.

## Redes de alto rendimiento

### Load balancers: ALB vs NLB vs GWLB

| Aspecto | Application Load Balancer | Network Load Balancer | Gateway Load Balancer |
| --- | --- | --- | --- |
| Capa OSI | **7** (HTTP, HTTPS, gRPC, WebSocket) | **4** (TCP, UDP, TLS) | **3** (IP, GENEVE) |
| Enrutamiento | Path, host, headers, query string, método | Puerto y protocolo | Hacia appliances de seguridad |
| IP | DNS (IPs cambiantes) | **IP estática por AZ** (o Elastic IP) | N/A |
| Rendimiento | Alto | **Millones de peticiones por segundo, latencia ultra baja** | Alto |
| Targets | Instancias, IPs, **Lambda**, contenedores | Instancias, IPs, ALB | Firewalls, IDS/IPS de terceros |
| Extras | WAF, autenticación Cognito/OIDC, sticky sessions | Preserva la IP de origen, base de **PrivateLink** | Inspección transparente |

Teoría L4 vs L7 en [Balanceo y alta disponibilidad](../../../networking/avanzado/balanceo-alta-disponibilidad.md).

### CloudFront vs Global Accelerator

| Aspecto | Amazon CloudFront | AWS Global Accelerator |
| --- | --- | --- |
| Qué es | **CDN** con caché en edge locations | Red global de AWS con **2 IPs anycast estáticas** |
| Protocolos | HTTP/HTTPS (y WebSocket) | **TCP y UDP** cualquiera |
| Caché | Sí | **No** |
| Failover | Origin failover | Entre endpoints regionales en segundos, sin caché DNS |
| Úsalo cuando | Web estática o dinámica, video, APIs | Juegos, VoIP, IoT, no HTTP; **IPs fijas** en allowlist; failover multi-región rápido |

**Origin Access Control (OAC)**: el bucket solo acepta peticiones de CloudFront (reemplaza a OAI). **Lambda@Edge** y **CloudFront Functions** para lógica en el borde.

### Conectividad entre VPC

| Opción | Transitivo | Cuándo |
| --- | --- | --- |
| **VPC peering** | **No** | Pocas VPC, sin CIDR solapados, sin costo por hora |
| **AWS Transit Gateway** | **Sí** (hub-and-spoke) | Muchas VPC, VPN y Direct Connect; peering entre regiones |
| **AWS PrivateLink** | N/A | Exponer un servicio concreto; CIDR solapados |
| **VPC sharing (AWS RAM)** | N/A | Varias cuentas en subnets de una VPC central |

### Conectividad híbrida: VPN vs Direct Connect

Qué es cada una en [Cloud Practitioner](../cloud-practitioner/dominio-3-tecnologia-servicios.md). Para decidir:

| Aspecto | AWS Site-to-Site VPN | AWS Direct Connect |
| --- | --- | --- |
| Puesta en marcha | Minutos u horas | **Semanas** (dedicated) o días (hosted vía partner) |
| Ancho de banda | Limitado por túnel (2 túneles por conexión); más con ECMP sobre Transit Gateway | Dedicated de 1, 10, 100 y 400 Gbps; hosted desde 50 Mbps |
| Latencia | Variable | **Consistente** |
| Cifrado | Sí | No por defecto (VPN sobre DX o MACsec) |
| Costo | Bajo | Puerto por hora + salida más barata |

- **Máxima resiliencia**: dos DX en **dos ubicaciones**; una VPN de **respaldo** es la opción económica.
- **Direct Connect Gateway**: una conexión DX hacia VPC de varias regiones (típico: DX → DX Gateway → Transit Gateway → VPC).
- Fundamentos (BGP) en [Redes de datacenter y redes híbridas](../../../networking/avanzado/redes-datacenter-hibridas.md).

## Ingesta y transformación de datos

### Streaming

| Servicio | Qué hace | Latencia |
| --- | --- | --- |
| **Kinesis Data Streams** | Flujo durable con shards (o on-demand); consumidores propios (Lambda, KCL, Flink) | **Real-time** (milisegundos a ~1 s) |
| **Amazon Data Firehose** | **Entrega** a S3, Redshift, OpenSearch, Splunk, HTTP o Iceberg; transforma con Lambda y **convierte a Parquet/ORC**; sin consumidores que gestionar | **Near real-time** (buffer) |

Además, en tiempo real: **Managed Service for Apache Flink** (analítica en streaming con ventanas y agregaciones), **Amazon MSK** (Kafka gestionado, también Serverless) y **Kinesis Video Streams** (video desde cámaras).

### Analítica y data lakes

Pipeline típico: Firehose (a Parquet) → S3 → Glue crawlers y Data Catalog (con permisos de Lake Formation) → Athena o Redshift Spectrum → Amazon Quick.

| Servicio | Para qué |
| --- | --- |
| **Athena** | SQL **serverless** sobre S3; pagas por datos escaneados (**Parquet** comprimido y **particiones**) |
| **AWS Glue** | ETL serverless, **Data Catalog** y crawlers; CSV → Parquet |
| **Lake Formation** | **Asegurar** un data lake: permisos por base, tabla, columna y fila |
| **Redshift** | Data warehouse; **Spectrum** consulta S3 sin cargarlo; Serverless |
| **EMR** | Spark/Hadoop para transformaciones grandes y personalizadas |
| **Amazon Quick** (antes QuickSight) | Dashboards y BI |
| **AppFlow** | Datos de SaaS (Salesforce, SAP, Slack) a S3 o Redshift sin código |

### Transferencia de datos híbrida y migración

| Servicio | Úsalo cuando |
| --- | --- |
| **AWS DataSync** | Copia **online** programada y verificada desde NFS, SMB, HDFS u object storage hacia S3, EFS o FSx |
| **Storage Gateway – S3 File Gateway** | Apps on-premises escriben en NFS/SMB y los archivos quedan como objetos en S3 (caché local) |
| **Storage Gateway – Volume Gateway** | Volúmenes iSCSI: *cached* (datos en S3) o *stored* (datos locales, snapshots a S3) |
| **Storage Gateway – Tape Gateway** | Reemplazar cintas físicas sin cambiar el software de backup |
| **AWS Transfer Family** | **SFTP, FTPS, FTP y AS2** gestionados sobre S3 o EFS |
| **AWS Snow Family** (Snowball Edge) | Decenas o cientos de TB con poca red o sin conectividad |
| **AWS DMS** | Bases de datos con replicación continua (CDC) y conversión de esquema para migraciones **heterogéneas** |
| **Application Migration Service (MGN)** | Rehost (*lift and shift*) de servidores a EC2 |

!!! warning "Snow Family: estado actual"
    En el examen, "cientos de TB con poco ancho de banda" suele ser **Snowball Edge**. En la vida real: Snowcone se discontinuó en noviembre de 2024 y, desde el **7 de noviembre de 2025**, Snowball Edge solo está disponible para clientes existentes. Para clientes nuevos: **DataSync**, **AWS Data Transfer Terminal**, partners u **Outposts**. Snowmobile ya no se ofrece. Ver el [anuncio](https://aws.amazon.com/blogs/storage/aws-snow-device-updates/).

!!! tip "En el examen"
    Calcula: 100 TB por un enlace de 100 Mbps tardan unos 3 meses; si el plazo es una semana, la red no alcanza → dispositivo físico. "Sincronizar un NAS con EFS cada noche" → **DataSync**. "Apps on-premises siguen usando un recurso compartido de archivos pero los datos deben quedar en S3" → **S3 File Gateway**. "Proveedores externos suben archivos por SFTP" → **Transfer Family**. Detalles de migración en [Migración a la nube](../../../cloud/arquitectura/migracion-cloud.md).

## Casos de uso

1. **Renderizado con cientos de instancias Linux que leen texturas de S3 en submilisegundos** → **FSx for Lustre** enlazado al bucket.
2. **Oracle en EC2 con 100,000 IOPS sostenidas** → EBS **io2 Block Express**.
3. **60 VPC en varias cuentas y dos datacenters** → **Transit Gateway** compartido con RAM + Direct Connect Gateway.
4. **Telemetría de 50,000 sensores para consultas SQL baratas** → Firehose a Parquet → S3 → Glue Data Catalog → **Athena**.
5. **Analistas solo ven columnas sin PII del data lake** → **Lake Formation** con permisos por columna.
6. **Rutas `/api` y `/imagenes` hacia servicios distintos** → **ALB** con reglas por path.

## Preguntas de práctica

**1.** Una aplicación HPC necesita la menor latencia de red posible entre 20 instancias que intercambian mensajes constantemente. ¿Qué configuración es la MÁS adecuada?

- A. Spread placement group en tres AZ
- B. Cluster placement group en una AZ con instancias compatibles con EFA
- C. Partition placement group
- D. Instancias T3 en un Auto Scaling group multi-AZ

??? success "Respuesta"
    **B.** Cluster coloca las instancias juntas en una AZ con red de alto rendimiento; EFA mejora el MPI. **A** maximiza la separación (y la latencia). **C** es para sistemas distribuidos con réplicas. **D** usa instancias burstable y reparte entre AZ.

**2.** Una empresa necesita un sistema de archivos compartido para servidores Windows, integrado con su Active Directory, con alta disponibilidad. ¿Qué servicio elegir?

- A. Amazon EFS
- B. Amazon FSx for Windows File Server en Multi-AZ
- C. Amazon S3 con S3 File Gateway
- D. EBS Multi-Attach

??? success "Respuesta"
    **B.** SMB nativo, integración con AD y despliegue Multi-AZ. **A** es NFS para Linux. **C** sirve para llevar archivos on-premises a S3, no como file server principal en AWS. **D** es block storage en una sola AZ.

**3.** Una aplicación TCP no HTTP en dos regiones debe tener IPs estáticas que los clientes pongan en su firewall y conmutar a la otra región en segundos si una falla. ¿Qué usar?

- A. CloudFront con dos orígenes
- B. Route 53 failover routing
- C. AWS Global Accelerator con endpoints en ambas regiones
- D. Un Application Load Balancer por región con Elastic IP

??? success "Respuesta"
    **C.** IPs anycast estáticas, cualquier TCP/UDP y failover rápido sin depender del TTL DNS. **A** es para HTTP. **B** depende de la caché DNS y no da IPs fijas. **D**: un ALB no admite Elastic IP.

**4.** Un equipo consulta con Athena logs en CSV en S3 y el costo y el tiempo de consulta crecen cada mes. ¿Qué DOS acciones mejoran ambos?

- A. Convertir los datos a Parquet comprimido
- B. Particionar los datos por fecha en S3
- C. Mover los datos a S3 Glacier Flexible Retrieval
- D. Aumentar la memoria de Athena
- E. Activar S3 Transfer Acceleration

??? success "Respuesta"
    **A y B.** Athena cobra por datos escaneados: un formato columnar comprimido y las particiones reducen lo que se lee. **C** impide consultar directamente. **D** no existe como opción. **E** acelera subidas, no consultas.

**5.** Una aplicación Lambda que procesa imágenes tarda demasiado y las métricas muestran uso de CPU al máximo. ¿Qué cambio es el más directo?

- A. Aumentar el timeout a 15 minutos
- B. Aumentar la memoria asignada a la función
- C. Activar reserved concurrency
- D. Mover la función a una VPC

??? success "Respuesta"
    **B.** En Lambda la CPU escala con la memoria. **A** permite que tarde más, no que vaya más rápido. **C** controla concurrencia, no velocidad. **D** no aporta rendimiento.

**6.** Una empresa debe migrar 500 TB desde un datacenter con un enlace de 1 Gbps ya usado al 80%, en menos de 3 semanas. Según las opciones que evalúa el examen, ¿qué es lo MÁS adecuado?

- A. AWS DataSync por el enlace existente
- B. AWS Snowball Edge (varios dispositivos)
- C. S3 Transfer Acceleration
- D. Site-to-Site VPN

??? success "Respuesta"
    **B.** Con unos 200 Mbps libres, 500 TB tardarían más de 6 meses por la red. **A**, **C** y **D** dependen de ese mismo enlace. Nota real: para clientes nuevos, Snowball Edge ya no se ofrece desde noviembre de 2025; la alternativa física es AWS Data Transfer Terminal o un partner.

## Para profundizar

- [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md): object, block, file y bases de datos.
- [Redes en la nube](../../../cloud/redes-y-datos/redes.md): load balancers, peering, VPN y CDN comparados.
- [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md), [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md) y [Serverless](../../../cloud/computo/serverless.md).
- [Arquitecturas de referencia](../../../cloud/arquitectura/arquitecturas-referencia.md#4-pipeline-de-datos): pipeline de datos.
- [Observabilidad](../../../monitoreo/fundamentos/observabilidad.md): medir latencia y saturación para escalar.
- [Lab 18: AWS: API serverless con Lambda, API Gateway y DynamoDB](../../../laboratorios/cloud/aws-serverless-api.md).

## Referencias

- [Exam guide SAA-C03: Domain 3](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03/solutions-architect-associate-03-domain3.html)
- [Amazon EBS volume types](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volume-types.html)
- [Choosing an Amazon FSx file system](https://aws.amazon.com/fsx/when-to-choose-fsx/)
- [S3 performance guidelines](https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance-guidelines.html)
- [AWS Direct Connect resiliency recommendations](https://aws.amazon.com/directconnect/resiliency-recommendation/)
- [AWS Snow device updates](https://aws.amazon.com/blogs/storage/aws-snow-device-updates/)
