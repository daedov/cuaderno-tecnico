---
tags:
  - aws
  - certificacion
  - clf-c02
  - finops
---

# Dominio 4: Billing, Pricing, and Support (12%)

> Cómo se paga AWS (modelos de compra de cómputo, almacenamiento y transferencia de datos), qué herramienta usar para presupuestar y analizar costos, y qué plan de soporte y recurso técnico elegir.

!!! info "Qué evalúa este dominio"
    Según la guía oficial de CLF-C02, tres *task statements*:

    - **4.1** Modelos de precios: On-Demand, Reserved Instances, Spot, Savings Plans, Dedicated Hosts, Dedicated Instances, Capacity Reservations; RI en AWS Organizations; transferencia de datos y almacenamiento.
    - **4.2** Facturación y costos: **AWS Budgets**, **Cost Explorer**, **Pricing Calculator**, consolidated billing, **cost allocation tags** y **Cost and Usage Report**.
    - **4.3** Recursos técnicos y AWS Support: documentación, re:Post, Prescriptive Guidance; **planes de AWS Support**; Trusted Advisor, Health; Trust and Safety; Partner Network y Marketplace; Professional Services.

    Pesa poco (unas 6 preguntas), pero son preguntas **fáciles de ganar** si memorizas las diferencias. Vuelve al [resumen del examen](resumen-examen.md).

## Modelos de compra de cómputo

Cómo cobra la nube y cómo optimizar: [FinOps y costos](../../../cloud/fundamentos/finops-costos.md) y [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md#modelos-de-pago). Lo que el examen pide distinguir:

| Opción | Cómo funciona | Descuento aproximado frente a On-Demand | Cuándo usarla |
| --- | --- | --- | --- |
| **On-Demand Instances** | Pagas por segundo u hora, sin compromiso | — | Cargas cortas, impredecibles, pruebas |
| **Savings Plans** | Te comprometes a gastar **X USD/hora** durante **1 o 3 años** | Hasta ~72% | Uso estable con flexibilidad de familia, región o servicio |
| **Reserved Instances (RI)** | Te comprometes a una **configuración** de instancia durante **1 o 3 años** | Hasta ~72% | Uso estable y predecible (p. ej. una base de datos 24/7) |
| **Spot Instances** | Capacidad sobrante; AWS puede recuperarla con **2 minutos de aviso** | Hasta ~90% | Cargas **tolerantes a interrupciones**: batch, análisis, CI, renderizado |
| **Dedicated Hosts** | Un **servidor físico entero** para ti, con visibilidad de sockets y núcleos | — (más caro) | **BYOL** con licencias por socket/núcleo, cumplimiento |
| **Dedicated Instances** | Hardware **no compartido** con otros clientes, sin control del host | — (más caro) | Aislamiento sin control del servidor |
| **On-Demand Capacity Reservations** | Reservas **capacidad** en una AZ, sin plazo; pagas On-Demand la uses o no | Ninguno por sí solas (se combinan con Savings Plans o RI regionales) | Garantizar capacidad para un evento o DR |

Los porcentajes cambian con el tiempo: tómalos como orientación.

- **Savings Plans**: **Compute Savings Plans** (los más flexibles: cualquier familia, tamaño, región y SO de EC2, más **Fargate** y **Lambda**); **EC2 Instance Savings Plans** (más descuento, atados a una familia en una región); también para **SageMaker AI**.
- **RI**: **Standard** (más descuento, sin cambiar de familia; se venden en el **Reserved Instance Marketplace**) vs **Convertible** (menos descuento, puedes cambiar familia, SO o tenancy). **Regional** aplica el descuento en cualquier AZ sin reservar capacidad; **zonal** reserva capacidad en una AZ. Pago **All Upfront** (más descuento), **Partial Upfront** o **No Upfront**.
- **En AWS Organizations**, con consolidated billing el descuento de una RI o Savings Plan **se comparte** con las demás cuentas si la compradora no lo usa; la **management account** puede desactivarlo.

!!! tip "En el examen"
    - "Trabajo que **puede interrumpirse** y debe ser lo más barato" → **Spot**. Si "no puede interrumpirse", Spot es la trampa.
    - "Carga **estable 24/7** durante 3 años" → **RI** o **Savings Plans** (si piden flexibilidad o Lambda/Fargate, Savings Plans).
    - "Corto plazo, impredecible, sin compromiso" → **On-Demand**.
    - "Licencias por socket o núcleo" o "servidor físico dedicado" → **Dedicated Hosts**.
    - "Asegurar capacidad en una AZ para un evento, sin compromiso de 1 año" → **Capacity Reservations**.

## Precios de almacenamiento y transferencia de datos

En **S3** pagas por **GB almacenado al mes** (según la [storage class](dominio-3-tecnologia-servicios.md#amazon-s3-storage-classes)), por **peticiones**, por **recuperación** en IA y Glacier, y por la **salida** de datos. En **EBS** pagas los **GB aprovisionados** (aunque no los llenes) y, en algunos tipos, IOPS y throughput.

| Tráfico | ¿Se cobra? |
| --- | --- |
| **Entrada** desde internet (*data transfer in*) | Generalmente **gratis** |
| **Salida** a internet (*data transfer out*) | **Sí**, por GB, escalonado |
| Entre **regiones** / entre **AZ** de la misma región | **Sí** (entre AZ, en cada dirección) |
| Dentro de la **misma AZ** con IP privada | Generalmente **gratis** |
| De un origen en AWS hacia **CloudFront** | Gratis; pagas la salida de CloudFront al usuario |

!!! tip "En el examen"
    - "¿Qué tráfico **no** suele cobrarse?" → la **entrada** desde internet.
    - En EBS pagas lo **aprovisionado**; en S3, lo **almacenado**. Para reducir la salida a usuarios globales, **CloudFront**.

## Facturación, presupuestos y gestión de costos

| Herramienta | Pregunta que responde |
| --- | --- |
| **AWS Pricing Calculator** | "¿Cuánto me costará?" (**antes** de desplegar) |
| **AWS Budgets** | "Avísame si me paso" (costo, uso, cobertura de RI/Savings Plans; **alertas** y **acciones**) |
| **AWS Cost Explorer** | "¿En qué gasté y cuánto gastaré?" (histórico, filtros, **pronóstico**, recomendaciones de RI, Savings Plans y rightsizing) |
| **AWS Cost and Usage Report (CUR)** | "Necesito **todo el detalle**" (línea por línea en S3; hoy con **Data Exports**, CUR 2.0) |
| **Billing and Cost Management console** | "¿Cuál es mi factura?" (pagos, Free Tier, cost allocation tags) |
| **AWS Cost Anomaly Detection** | "Avísame de un pico raro de gasto" (ML) |

- **Consolidated billing** de **AWS Organizations** (sin costo; ver [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md)): **una sola factura** pagada por la management account, **descuentos por volumen agregados**, reparto de RI y Savings Plans y costo **por cuenta** para showback y chargeback.
- **Cost allocation tags**: **AWS-generated** (p. ej. `aws:createdBy`) o **user-defined** (`Proyecto=tienda`). Hay que **activarlas** en Billing para verlas en Cost Explorer y CUR; solo cuentan desde la activación. Detalle en [FinOps y costos](../../../cloud/fundamentos/finops-costos.md#asignar-costos-tags-y-labels).
- **AWS Free Tier**: en **julio de 2025** AWS cambió el modelo para cuentas nuevas (plan gratuito con **créditos** los primeros meses o plan de pago, más ofertas **always free**). Revisa la página oficial y configura **Budgets** desde el primer día.

!!! tip "En el examen"
    - "Estimar **antes**" → **Pricing Calculator**. "Analizar lo **ya** gastado y pronosticar" → **Cost Explorer**. "**Alertar** al superar un umbral" → **Budgets**. "Máximo **detalle**" → **CUR**.
    - "Una factura para muchas cuentas y descuentos por volumen" → **consolidated billing**.
    - "Costos por proyecto o departamento" → **cost allocation tags** (activadas).

## AWS Support y recursos técnicos

### Planes de AWS Support

AWS **reestructuró sus planes** a finales de 2025 y la guía vigente de CLF-C02 ya usa los nombres nuevos:

| Plan | Para quién | Primera respuesta para un sistema de producción caído | Lo que lo distingue |
| --- | --- | --- | --- |
| **Basic Support** | Todos los clientes, **gratis** | Sin casos técnicos (solo cuenta y facturación) | Customer service 24/7, documentación, re:Post, **Trusted Advisor core checks**, AWS Health Dashboard |
| **AWS Business Support+** | Mínimo recomendado para **producción** | < 30 minutos | Soporte técnico 24/7 con asistencia de IA, **todos** los checks de Trusted Advisor, AWS Health API |
| **AWS Enterprise Support** | Cargas **críticas para el negocio** | < 15 minutos | **TAM** (*Technical Account Manager*) designado, Trusted Advisor Priority, revisiones operativas y de arquitectura |
| **AWS Unified Operations** | Cargas **de misión crítica** | < 5 minutos | Equipo ampliado (TAM, ingenieros especialistas, gestión de incidentes), máxima rapidez |

!!! warning "Planes antiguos que aún verás en cursos y simulacros"
    **Developer**, **Business** (sin "+") y **Enterprise On-Ramp** dejaron de venderse a clientes nuevos en **diciembre de 2025**. Según las FAQ de AWS Support, Developer y Business se **discontinúan el 1 de enero de 2027** y Enterprise On-Ramp tiene soporte hasta el **31 de diciembre de 2026**. Si una pregunta los menciona, razona por **nivel de servicio** (más caro = respuesta más rápida + TAM). Precios: Business Support+ desde 29 USD/mes por cuenta y Enterprise Support desde 5.000 USD/mes, creciendo con el gasto.

### Trusted Advisor, Health y otros recursos

- **AWS Trusted Advisor**: recomendaciones en **cost optimization, performance, security, fault tolerance, service limits** y **operational excellence**. Basic solo da los **core checks**; los planes de pago, todos.
- **AWS Health Dashboard**: estado público de los servicios (**Service health**) y eventos que **afectan a tus recursos** (**Your account health**). **AWS Health API**: acceso programático (plan de pago).
- **AWS Trust and Safety team**: se le **reporta abuso** desde IPs de AWS (spam, escaneo de puertos, DoS, malware) con el formulario de abuso.
- **Documentación y ayuda**: AWS Documentation, Whitepapers & Guides, **Prescriptive Guidance** (patrones probados de migración y modernización), **re:Post** (comunidad que sustituye a los foros) con el **Knowledge Center**, AWS Blogs y **Support Center** (casos de soporte).
- **AWS Partner Network (APN)**: **ISV** (software que corre en AWS) y **system integrators** o consultoras. **AWS Marketplace**: software de terceros pagado **en la factura de AWS**, con ofertas privadas y **entitlements**. **Professional Services**: consultores de AWS. **Solutions architects**: asesoría de diseño vía tu equipo de cuenta.

!!! tip "En el examen"
    - "**TAM** designado" → **Enterprise Support** o superior. "< 5 minutos" → **Unified Operations**.
    - "Todos los checks de Trusted Advisor al menor costo" → **Business Support+**. "Gratis" → **Basic** (sin casos técnicos).
    - "Una IP de AWS envía spam" → **Trust and Safety**.
    - "Software de terceros en la factura de AWS" → **Marketplace**. "Consultora para migrar" → **Partner Network**.
    - "Guías paso a paso para migrar" → **Prescriptive Guidance**. "Evento de AWS que afecta a **mis** recursos" → **Health Dashboard**.

## Casos de uso

1. Renderizado que puede repetirse si se interrumpe → **Spot**.
2. Base de datos en EC2 24/7 durante 3 años → **RI** o **EC2 Instance Savings Plans**.
3. EC2, Fargate y Lambda con cambios de familia frecuentes → **Compute Savings Plans**.
4. Licencias de Windows Server por núcleo físico → **Dedicated Hosts** (BYOL).
5. Correo cuando el gasto mensual previsto supere 1.000 USD → **Budgets** con alerta sobre el pronóstico.
6. Holding con 12 cuentas, una factura y descuentos por volumen → **consolidated billing**.
7. Fintech que necesita TAM y respuesta en < 15 minutos → **Enterprise Support**.

## Preguntas de práctica

**1.** Una empresa ejecuta trabajos de análisis nocturnos que pueden reiniciarse sin problema si se interrumpen. ¿Qué opción de compra es la MÁS rentable?

- A. On-Demand Instances
- B. Dedicated Hosts
- C. Spot Instances
- D. On-Demand Capacity Reservations

??? success "Respuesta"
    **C.** Spot ofrece el mayor descuento para cargas tolerantes a interrupciones. A es más caro; B es la opción más cara; D garantiza capacidad pero se cobra a tarifa On-Demand.

**2.** ¿Qué herramienta se usa para estimar el costo de una arquitectura ANTES de desplegarla?

- A. AWS Cost Explorer
- B. AWS Pricing Calculator
- C. AWS Budgets
- D. AWS Cost and Usage Report

??? success "Respuesta"
    **B.** Pricing Calculator estima costos de algo que aún no existe. A analiza gasto real; C alerta sobre umbrales; D da el detalle del uso ya facturado.

**3.** ¿Cuáles DOS son beneficios del consolidated billing de AWS Organizations? (Elige dos.)

- A. Una sola factura para varias cuentas
- B. Soporte técnico gratuito para todas las cuentas
- C. Agregación del uso para obtener descuentos por volumen
- D. Cifrado automático de todos los recursos
- E. Eliminación de los costos de transferencia de datos

??? success "Respuesta"
    **A y C.** B es falso (el soporte se contrata por plan); D y E no tienen relación con la facturación consolidada.

**4.** ¿Qué tipo de transferencia de datos generalmente NO tiene costo?

- A. Datos de salida de AWS a internet
- B. Datos entre dos regiones de AWS
- C. Datos de entrada desde internet a AWS
- D. Datos entre dos Availability Zones

??? success "Respuesta"
    **C.** La entrada desde internet suele ser gratuita. A, B y D se cobran por GB.

**5.** Una empresa necesita un Technical Account Manager designado para sus cargas críticas. ¿Cuál es el plan de AWS Support de MENOR costo que lo incluye?

- A. Basic Support
- B. AWS Business Support+
- C. AWS Enterprise Support
- D. AWS Unified Operations

??? success "Respuesta"
    **C.** Enterprise Support incluye TAM designado. A y B no lo incluyen; D también lo incluye, pero es más caro.

**6.** ¿Qué servicio da recomendaciones para reducir costos, mejorar la seguridad y evitar alcanzar los service quotas?

- A. AWS Trusted Advisor
- B. AWS Health Dashboard
- C. AWS Artifact
- D. AWS Pricing Calculator

??? success "Respuesta"
    **A.** Trusted Advisor revisa la cuenta en esas categorías. B informa de eventos de AWS que afectan a tus recursos; C da informes de cumplimiento; D estima costos.

**7.** Una empresa detecta que una dirección IP de AWS está lanzando ataques contra su servidor. ¿A quién debe reportarlo?

- A. AWS Professional Services
- B. AWS Trust and Safety team
- C. AWS Partner Network
- D. AWS Support Center de su propia cuenta con Basic Support

??? success "Respuesta"
    **B.** Trust and Safety gestiona los reportes de abuso de recursos de AWS. A es consultoría; C es la red de socios; D: con Basic no hay casos técnicos y además el abuso se reporta por el canal específico.

## Para profundizar

- [FinOps y costos](../../../cloud/fundamentos/finops-costos.md): modelos de cobro, herramientas nativas, tags y optimización.
- [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md): opciones de compra comparadas entre proveedores.
- [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md): AWS Organizations, multi-cuenta y tagging.
- [Niveles de servicio](../../../negocio/niveles-de-servicio.md): SLA de los proveedores y créditos.

## Referencias

- [Exam guide CLF-C02: Domain 4](https://docs.aws.amazon.com/aws-certification/latest/cloud-practitioner-02/cloud-practitioner-02-domain4.html)
- [How AWS Pricing Works (whitepaper)](https://docs.aws.amazon.com/whitepapers/latest/how-aws-pricing-works/welcome.html)
- [Savings Plans](https://docs.aws.amazon.com/savingsplans/latest/userguide/what-is-savings-plans.html)
- [Consolidated billing for AWS Organizations](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/consolidated-billing.html)
- [Compare AWS Support Plans](https://aws.amazon.com/premiumsupport/plans/)
- [AWS Support FAQs](https://aws.amazon.com/premiumsupport/faqs/)
