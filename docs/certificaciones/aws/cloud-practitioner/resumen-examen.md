---
tags:
  - aws
  - certificacion
  - clf-c02
---

# AWS Certified Cloud Practitioner (CLF-C02): resumen del examen

> Qué evalúa el examen de entrada de AWS, cómo es el formato, cuánto pesa cada dominio y un plan de estudio de 5 semanas para alguien que empieza en cloud.

## ¿Qué es?

**AWS Certified Cloud Practitioner** es la certificación **Foundational** (nivel fundamental) de AWS. Demuestra que entiendes **qué es la nube de AWS, para qué sirve cada servicio principal, cómo se reparte la seguridad, cómo se cobra y dónde pedir ayuda**. No pide programar, diseñar arquitecturas ni resolver incidentes: pide **reconocer** el servicio o concepto correcto para cada situación.

El código vigente es **CLF-C02** (sustituyó a CLF-C01 en septiembre de 2023). A la fecha de esta nota (octubre de 2026) no hay una versión nueva anunciada en la guía oficial. Lo genérico de cualquier examen (tiempo, descarte, palabras clave comunes, online proctored) está en [Cómo preparar un examen](../../como-preparar-un-examen.md).

## Objetivo profesional

- **Para quién**: hasta **6 meses de exposición** a AWS; quien empieza en cloud o trabaja **con** equipos cloud (ventas, compras, proyectos, finanzas). Deja fuera programar, diseñar arquitectura, troubleshooting, implementación y pruebas de carga.
- **Roles**: primer paso hacia [Cloud Engineer](../../roles-profesionales.md#cloud-engineer), [Support / Cloud Operations](../../roles-profesionales.md#support-cloud-operations) y [FinOps Practitioner](../../roles-profesionales.md#finops-practitioner-analyst).
- **Qué sigue**: [Solutions Architect – Associate](../solutions-architect-associate/resumen-examen.md) (lo más habitual), [AI Practitioner](../ai-practitioner/resumen-examen.md) si te interesa la IA generativa, u [otras de AWS](../../otras-certificaciones.md#aws-el-resto-del-catalogo).

## Formato del examen

| Aspecto | Detalle |
| --- | --- |
| Código | **CLF-C02** |
| Preguntas | **65**: 50 puntúan y **15 son unscored** (sin puntaje, de prueba para futuras versiones; no sabes cuáles son) |
| Tipos de pregunta | **Multiple choice** (opción múltiple: 1 correcta de 4) y **multiple response** (respuesta múltiple: 2 o más correctas de 5 o más) |
| Duración | **90 minutos** (~80 segundos por pregunta) |
| Puntaje | Escala de 100 a 1000; **aprobado con 700** |
| Modelo de puntaje | **Compensatory** (compensatorio): no necesitas aprobar cada dominio, solo el total |
| Costo | **100 USD** (más impuestos o tipo de cambio según el país) |
| Modalidad | Centro de pruebas **Pearson VUE** u **online proctored** (en línea con supervisor) |
| Idiomas | Inglés, español (Latinoamérica), español (España), portugués (Brasil), francés, alemán, italiano, japonés, coreano, árabe, chino simplificado y tradicional |
| Validez | **3 años** |

!!! warning "Datos que cambian"
    La página oficial indica que las versiones en **italiano y alemán se retiran después del 31 de diciembre de 2026**. Revisa la página del examen antes de agendar.

!!! tip "Si el inglés no es tu idioma nativo"
    Si lo presentas en inglés, AWS ofrece la acomodación **ESL +30** (30 minutos extra) que se solicita **antes** de agendar desde tu cuenta de AWS Certification.

## Dominios y peso

| Dominio | Peso | Qué cubre | Nota |
| --- | --- | --- | --- |
| 1. Cloud Concepts | **24%** (~12 preguntas) | Beneficios de la nube, Well-Architected, CAF y migración, economía de la nube | [Dominio 1](dominio-1-conceptos-cloud.md) |
| 2. Security and Compliance | **30%** (~15) | Shared Responsibility Model, cumplimiento, IAM y usuario root, servicios de seguridad | [Dominio 2](dominio-2-seguridad-cumplimiento.md) |
| 3. Cloud Technology and Services | **34%** (~17) | Formas de desplegar, infraestructura global, cómputo, bases de datos, redes, almacenamiento, IA/analítica y otros servicios | [Dominio 3](dominio-3-tecnologia-servicios.md) |
| 4. Billing, Pricing, and Support | **12%** (~6) | Modelos de compra, herramientas de costos, Organizations, planes de soporte y recursos | [Dominio 4](dominio-4-facturacion-precios-soporte.md) |

El número de preguntas es aproximado (sobre las 50 que puntúan). Los dominios 2 y 3 suman casi dos tercios del examen.

## Servicios que más salen

La lista completa está en [In-Scope AWS Services](https://docs.aws.amazon.com/aws-certification/latest/cloud-practitioner-02/clf-02-in-scope-services.html) y [Out-of-Scope AWS Services](https://docs.aws.amazon.com/aws-certification/latest/cloud-practitioner-02/clf-02-out-of-scope-services.html).

| Categoría | Servicios en alcance que más salen |
| --- | --- |
| Compute y contenedores | EC2, Elastic Beanstalk, Lightsail, ECS, EKS, Fargate, Lambda |
| Storage | S3, S3 Glacier, EBS, EFS, Storage Gateway |
| Database | RDS, Aurora, DynamoDB, ElastiCache |
| Networking | VPC, Route 53, CloudFront, Direct Connect, Site-to-Site VPN |
| Security | IAM, IAM Identity Center, Artifact, GuardDuty, Inspector, Shield, WAF |
| Management y costos | CloudWatch, CloudTrail, Config, Organizations, Trusted Advisor, Budgets, Cost Explorer |

**Fuera de alcance** (ejemplos): Amazon MSK, AWS CodeDeploy, AWS CloudShell, AWS Network Firewall, AWS Wavelength, Amazon FSx for Lustre, Amazon Personalize. Si una opción nombra un servicio fuera de alcance, casi nunca es la correcta.

## Palabras clave propias de CLF

| Palabra clave | Qué suele indicar |
| --- | --- |
| **MOST cost-effective** / **LEAST expensive** | Spot, Savings Plans, S3 Glacier, serverless, apagar recursos |
| **LEAST operational overhead** | RDS frente a base de datos en EC2, Lambda/Fargate frente a EC2 |
| **Compliance reports** (SOC, ISO, PCI) | AWS Artifact |
| **Recommendations** sobre costo, seguridad, límites | AWS Trusted Advisor |
| **Forecast** / alertas de gasto | AWS Budgets (alertas) y Cost Explorer (análisis y pronóstico) |

## Plan de estudio de 5 semanas

Pensado para 5–7 horas por semana. Si ya trabajas con AWS, compáctalo en 2–3 semanas.

| Semana | Tema | Qué hacer |
| --- | --- | --- |
| 1 | Dominio 1 + base del cuaderno | Lee [Dominio 1](dominio-1-conceptos-cloud.md), [modelos de servicio y regiones](../../../cloud/fundamentos/modelos-de-servicio-y-regiones.md) y [Well-Architected](../../../cloud/fundamentos/well-architected.md). Crea una cuenta de AWS y configura **MFA en el root** y una alerta de AWS Budgets el primer día |
| 2 | Dominio 2 | Lee [Dominio 2](dominio-2-seguridad-cumplimiento.md), [responsabilidad compartida](../../../cloud/fundamentos/responsabilidad-compartida.md) e [IAM](../../../cloud/fundamentos/iam-comparativa.md). Práctica: crear un usuario en IAM Identity Center, revisar AWS Artifact |
| 3 | Dominio 3 (cómputo, redes, almacenamiento, bases de datos) | Lee la primera mitad del [Dominio 3](dominio-3-tecnologia-servicios.md). Práctica: lanzar y terminar una EC2 pequeña, crear un bucket S3 con lifecycle policy |
| 4 | Dominio 3 (IA, analítica, integración, otros) + Dominio 4 | Termina el Dominio 3 y lee [Dominio 4](dominio-4-facturacion-precios-soporte.md). Práctica: estimar un costo en AWS Pricing Calculator y explorar Cost Explorer |
| 5 | Repaso y simulacros | Official Practice Question Set, repaso de los "En el examen" de cada nota, preguntas de práctica de las notas. Repite los temas donde falles más |

## Recursos oficiales gratuitos

| Recurso | Para qué sirve |
| --- | --- |
| **Exam guide** (guía del examen) | La fuente de verdad: dominios, task statements y servicios en alcance |
| **AWS Skill Builder** | Gratis: *AWS Cloud Practitioner Essentials*, *Exam Prep Standard Course: CLF-C02* y el **Official Practice Question Set** (20 preguntas) |
| **Official Practice Exam** | Simulacro completo del mismo formato (en la suscripción de Skill Builder; revisa disponibilidad) |
| **AWS Cloud Quest: Cloud Practitioner** | Juego de rol con laboratorios reales; la parte de Cloud Practitioner es gratuita |
| **Whitepapers** | *Overview of Amazon Web Services*, *AWS Well-Architected Framework*, *How AWS Pricing Works* |
| **AWS Free Tier** | Probar servicios con costo bajo o cero (las condiciones cambiaron en 2025: revisa la página vigente) |

## Para profundizar

- Base conceptual: [Modelos de servicio y regiones](../../../cloud/fundamentos/modelos-de-servicio-y-regiones.md), [Shared Responsibility Model](../../../cloud/fundamentos/responsabilidad-compartida.md), [Well-Architected Framework](../../../cloud/fundamentos/well-architected.md), [FinOps y costos](../../../cloud/fundamentos/finops-costos.md)
- Servicios: [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md), [Redes](../../../cloud/redes-y-datos/redes.md), [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md)
- Seguridad y gobierno: [IAM](../../../cloud/fundamentos/iam-comparativa.md), [Fundamentos de seguridad cloud](../../../cloud/seguridad/fundamentos-seguridad-cloud.md), [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md)
- Negocio: [TI y negocio](../../../negocio/ti-y-negocio.md) (CapEx vs OpEx, TCO)
- Método de estudio y día del examen: [Cómo preparar un examen](../../como-preparar-un-examen.md)

## Referencias

- [AWS Certified Cloud Practitioner (página oficial)](https://aws.amazon.com/certification/certified-cloud-practitioner/)
- [Exam guide CLF-C02](https://docs.aws.amazon.com/aws-certification/latest/cloud-practitioner-02/cloud-practitioner-02.html)
- [In-Scope AWS Services (CLF-C02)](https://docs.aws.amazon.com/aws-certification/latest/cloud-practitioner-02/clf-02-in-scope-services.html)
- [AWS Skill Builder](https://skillbuilder.aws/)
- [AWS Certification: políticas del examen](https://aws.amazon.com/certification/policies/)
- [Overview of Amazon Web Services (whitepaper)](https://docs.aws.amazon.com/whitepapers/latest/aws-overview/introduction.html)
