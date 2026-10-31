---
tags:
  - aws
  - certificacion
  - clf-c02
  - arquitectura
  - finops
---

# Dominio 1: Cloud Concepts (24%)

> Por qué una organización se va a la nube: los beneficios de AWS, los seis pilares de Well-Architected, cómo se planifica una migración y cómo cambia la economía frente a un datacenter propio.

!!! info "Qué evalúa este dominio"
    Según la guía oficial de CLF-C02, cuatro *task statements* (enunciados de tarea):

    - **1.1** Beneficios de AWS Cloud: propuesta de valor, alcance global, high availability, elasticidad y agilidad.
    - **1.2** Pilares del **AWS Well-Architected Framework** y en qué se diferencian.
    - **1.3** Migración: **AWS Cloud Adoption Framework (AWS CAF)** y estrategias de migración.
    - **1.4** Economía de la nube: costos fijos vs variables, licencias (BYOL vs incluidas), rightsizing, automatización y economías de escala.

    Vuelve al [resumen del examen](resumen-examen.md) para ver el formato y el plan de estudio.

## Beneficios de la nube de AWS

**Cloud computing**: recursos de TI **on-demand** (bajo demanda) por internet con **pay-as-you-go pricing** (pago por uso). IaaS, PaaS y SaaS están en [Modelos de servicio y regiones](../../../cloud/fundamentos/modelos-de-servicio-y-regiones.md).

Las **seis ventajas** del whitepaper *Overview of Amazon Web Services* (el examen las parafrasea en inglés):

| Ventaja (nombre oficial) | Qué significa |
| --- | --- |
| **Trade fixed expense for variable expense** | Sin inversión por adelantado; pagas solo lo que consumes |
| **Benefit from massive economies of scale** | AWS compra a gran escala y traslada el ahorro en precios más bajos |
| **Stop guessing capacity** | Escalas según la demanda real, sin sobredimensionar "por si acaso" |
| **Increase speed and agility** | Recursos nuevos en minutos, no en semanas de compra |
| **Stop spending money running and maintaining data centers** | Inviertes en tu producto, no en energía, refrigeración y racks |
| **Go global in minutes** | Despliegas en otras regiones del mundo con pocos clics |

| Concepto | Definición | Servicio típico |
| --- | --- | --- |
| **High availability** (alta disponibilidad) | Sigue funcionando aunque falle un componente, gracias a redundancia | Varias **Availability Zones**, Elastic Load Balancing |
| **Elasticity** (elasticidad) | Crecer **y decrecer** automáticamente según la demanda | EC2 Auto Scaling, Lambda |
| **Scalability** (escalabilidad) | Capacidad de crecer para atender más carga | Cambiar el instance type, añadir instancias |
| **Agility** (agilidad) | Probar, lanzar y descartar rápido y barato | Entornos con CloudFormation |
| **Fault tolerance** (tolerancia a fallos) | Seguir **sin interrupción** ante un fallo (más exigente que HA) | Activo-activo multi-AZ |

!!! tip "En el examen"
    - "Pagar solo por lo que usas", "sin inversión inicial" → **trade fixed expense for variable expense**.
    - "Ajustarse automáticamente a la demanda, hacia arriba **y hacia abajo**" → **elasticity** (no "scalability").
    - "Llegar a usuarios de otro continente rápidamente" → **go global in minutes**.
    - "Precios más bajos porque AWS tiene millones de clientes" → **economies of scale**.

## Principios de diseño: AWS Well-Architected Framework

**Seis pilares**, explicados en [Well-Architected Framework](../../../cloud/fundamentos/well-architected.md). Para distinguirlos:

| Pilar | Palabra clave para reconocerlo |
| --- | --- |
| **Operational Excellence** | Operar, monitorear, mejorar procesos; IaC; cambios pequeños y reversibles |
| **Security** | Proteger datos y accesos; least privilege; trazabilidad; cifrado |
| **Reliability** | Recuperarse de fallos; escalar; probar recuperación |
| **Performance Efficiency** | Recurso adecuado; serverless; experimentar más; global en minutos |
| **Cost Optimization** | Pagar solo por lo que aporta valor; rightsizing |
| **Sustainability** | Reducir el impacto ambiental; maximizar la utilización |

!!! tip "En el examen"
    - *Fallos* y *recuperación* → Reliability; *elegir el recurso más adecuado* → Performance Efficiency.
    - "Operations as code", runbooks y postmortems → Operational Excellence; Multi-AZ y backups probados → Reliability.
    - Revisar una arquitectura contra los pilares → **AWS Well-Architected Tool** (gratuita).
    - Son **seis**: "Scalability pillar" o "Availability pillar" es una trampa.

## Migración: AWS Cloud Adoption Framework y estrategias

El **AWS CAF** guía la transformación de una **organización** (no de un workload: eso es Well-Architected). Seis **perspectivas**:

- **De negocio**: **Business** (que la inversión acelere resultados; CEO, CFO), **People** (cultura, habilidades, gestión del cambio; RR. HH.), **Governance** (riesgos, programas, gestión financiera; CIO, PMO).
- **Técnicas**: **Platform** (plataforma escalable e híbrida; CTO), **Security** (confidencialidad, integridad, disponibilidad; CISO), **Operations** (entregar al nivel acordado).
- *Business outcomes*: **reduced business risk**, **improved ESG performance**, **increased revenue**, **increased operational efficiency**. Fases: **Envision, Align, Launch, Scale**.

Las **7 R** están explicadas en [Migración a la nube](../../../cloud/arquitectura/migracion-cloud.md#las-7-r). Para reconocerlas:

| Estrategia | Frase que la delata |
| --- | --- |
| **Rehost** ("lift and shift") | "Mover tal cual, sin cambios, lo más rápido posible" |
| **Replatform** ("lift, tinker and shift") | "Pequeños ajustes, p. ej. pasar la BD a Amazon RDS" |
| **Refactor / re-architect** | "Rediseñar para cloud-native, serverless o microservicios" |
| **Repurchase** ("drop and shop") | "Cambiar a un producto SaaS" |
| **Relocate** | "Mover VMware a nivel de hipervisor (VMware Cloud on AWS)" |
| **Retain** / **Retire** | "Dejarlo on-premises por ahora" / "Apagarlo porque ya no se usa" |

Herramientas: **Application Discovery Service** (descubre servidores y dependencias), **Migration Evaluator** (business case), **Migration Hub** (seguimiento), **Application Migration Service** (rehost a EC2), **DMS** (migra y **replica** bases de datos con mínima inactividad) y **SCT** (convierte el esquema entre motores).

!!! tip "En el examen"
    - "Migrar la base de datos **sin parar la aplicación**" → **AWS DMS**. Si además cambia el motor → **DMS + SCT**.
    - "Alinear personas, procesos y tecnología" → **AWS CAF**. "Capacitar al equipo y gestionar el cambio" → perspectiva **People**.
    - La familia **AWS Snow** aparece en materiales antiguos, pero no está en la lista de alcance vigente y AWS limitó su disponibilidad: no la priorices.

## Economía de la nube

CapEx vs OpEx y TCO están en [TI y negocio](../../../negocio/ti-y-negocio.md); la optimización, en [FinOps y costos](../../../cloud/fundamentos/finops-costos.md).

- **CapEx → OpEx**: on-premises compras por adelantado un costo **fijo** dimensionado para el pico; en AWS pagas un costo **variable** por uso.
- **TCO** on-premises: además del servidor, espacio, energía, refrigeración, red, seguridad física, licencias, renovación del hardware y **personal**. La nube reduce esos costos **indirectos**.
- **Rightsizing**: **AWS Compute Optimizer** y recomendaciones de **Cost Explorer**. **Automatización**: IaC para crear, destruir y apagar entornos fuera de horario.
- **Licencias**: **license included** (el precio por hora de EC2 o RDS ya incluye Windows, SQL Server…) o **BYOL** (*Bring Your Own License*: usas las tuyas y pagas solo la infraestructura; a veces exige **Dedicated Hosts**). **AWS License Manager** controla su uso.

!!! tip "En el examen"
    - "Costo que **no** se elimina al migrar": datos, aplicaciones y gestión de accesos siguen siendo tuyos. Desaparece lo físico.
    - "Reducir costos de licencias de Windows/SQL que ya tienes" → **BYOL** (posiblemente con **Dedicated Hosts**).
    - "Identificar instancias sobredimensionadas" → **AWS Compute Optimizer**.

## Casos de uso

1. Picos en fechas de oferta y servidores al 10% el resto del año → **EC2 Auto Scaling** con load balancer.
2. Banco que prepara gente, procesos y gobierno antes de migrar → **AWS CAF** (People y Governance).
3. ERP que solo hay que mover a EC2 sin cambios → **Rehost** con **Application Migration Service**.
4. Oracle a Aurora PostgreSQL con mínima interrupción → **SCT** + **DMS**.
5. Justificar la migración con números → **Migration Evaluator**.
6. Licencias de SQL Server con Software Assurance → **BYOL** con **License Manager**.

## Preguntas de práctica

**1.** Una empresa quiere dejar de comprar servidores para picos que solo ocurren dos veces al año. ¿Qué ventaja de la nube describe mejor su objetivo?

- A. Go global in minutes
- B. Stop guessing capacity
- C. Benefit from massive economies of scale
- D. Stop spending money running and maintaining data centers

??? success "Respuesta"
    **B.** El problema es dimensionar para el pico. A habla de alcance geográfico; C de precios más bajos por volumen de AWS; D de dejar de operar instalaciones físicas, no de capacidad.

**2.** ¿Qué pilar del AWS Well-Architected Framework se centra en la capacidad de un workload para recuperarse de fallos de infraestructura?

- A. Operational Excellence
- B. Performance Efficiency
- C. Reliability
- D. Security

??? success "Respuesta"
    **C.** Reliability trata la recuperación ante fallos y la gestión de cambios en la demanda. A trata operar y mejorar procesos; B elegir los recursos adecuados; D proteger datos y accesos.

**3.** ¿Qué perspectiva del AWS CAF se ocupa de la cultura organizativa, la formación y la gestión del cambio?

- A. Business
- B. People
- C. Platform
- D. Operations

??? success "Respuesta"
    **B.** People cubre cultura, talento y gestión del cambio. Business cubre estrategia y resultados; Platform la plataforma técnica; Operations la entrega del servicio al nivel acordado.

**4.** Una empresa migra su aplicación a EC2 y, al mismo tiempo, mueve su base de datos MySQL autogestionada a Amazon RDS for MySQL sin cambiar el código. ¿Qué estrategia aplica a la base de datos?

- A. Rehost
- B. Replatform
- C. Refactor
- D. Retain

??? success "Respuesta"
    **B.** Pasar a un servicio gestionado sin rediseñar es replatform. Rehost sería instalar MySQL en EC2 tal cual; Refactor implicaría rediseñar la aplicación; Retain sería dejarla on-premises.

**5.** ¿Cuáles DOS son beneficios económicos de mover cargas a AWS? (Elige dos.)

- A. Cambiar gastos variables por gastos de capital
- B. Reducir costos de energía y refrigeración del datacenter
- C. Eliminar la responsabilidad del cliente sobre los datos
- D. Pagar solo por los recursos que se consumen
- E. Obtener licencias de software gratis para todas las aplicaciones

??? success "Respuesta"
    **B y D.** A está al revés (se cambia CapEx por gasto variable). C es falso por el Shared Responsibility Model: los datos siguen siendo tuyos. E es falso: las licencias se pagan (incluidas en el precio o BYOL).

**6.** Una empresa necesita migrar una base de datos Oracle on-premises a Amazon Aurora PostgreSQL. ¿Qué combinación de servicios es la adecuada?

- A. AWS Application Migration Service y AWS Backup
- B. AWS Schema Conversion Tool y AWS Database Migration Service
- C. AWS Migration Hub y Amazon RDS Proxy
- D. AWS DataSync y AWS Storage Gateway

??? success "Respuesta"
    **B.** SCT convierte el esquema entre motores distintos y DMS mueve y replica los datos. A sirve para rehost de servidores y backups; C sigue el progreso, pero no convierte; D mueve archivos, no bases de datos.

## Para profundizar

- [Well-Architected Framework](../../../cloud/fundamentos/well-architected.md): pilares, design principles y Well-Architected Tool.
- [Migración a la nube](../../../cloud/arquitectura/migracion-cloud.md): las 7 R, fases y herramientas.
- [FinOps y costos](../../../cloud/fundamentos/finops-costos.md) y [TI y negocio](../../../negocio/ti-y-negocio.md): cobro, optimización, CapEx/OpEx y TCO.
- [Resiliencia](../../../cloud/operacion-y-gobierno/resiliencia.md): high availability y disaster recovery.

## Referencias

- [Exam guide CLF-C02: Domain 1](https://docs.aws.amazon.com/aws-certification/latest/cloud-practitioner-02/cloud-practitioner-02-domain1.html)
- [Six advantages of cloud computing](https://docs.aws.amazon.com/whitepapers/latest/aws-overview/six-advantages-of-cloud-computing.html)
- [AWS Cloud Adoption Framework](https://aws.amazon.com/cloud-adoption-framework/)
- [Migration strategies (AWS Prescriptive Guidance)](https://docs.aws.amazon.com/prescriptive-guidance/latest/large-migration-guide/migration-strategies.html)
