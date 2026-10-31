---
tags:
  - arquitectura
  - aws
  - azure
  - gcp
---

# Well-Architected Framework

> Qué es el AWS Well-Architected Framework, sus seis pilares (*pillars*) y cómo se comparan los marcos equivalentes de Azure y Google Cloud.

## ¿Qué es?

Un **Well-Architected Framework** (marco de buena arquitectura) es un conjunto de **best practices** (buenas prácticas), **design principles** (principios de diseño) y preguntas de revisión que publica un proveedor cloud para evaluar si una arquitectura está bien construida.

No es un servicio ni una norma obligatoria: es una **guía** para responder preguntas como:

- ¿Qué pasa si se cae una **Availability Zone** (zona de disponibilidad)?
- ¿Quién tiene acceso a estos datos y cómo lo sé?
- ¿Estoy pagando por recursos que no uso?
- ¿Puedo desplegar un cambio sin miedo a romper producción?

La unidad de análisis es el **workload** (carga de trabajo): el conjunto de recursos y código que entrega valor de negocio (por ejemplo, una tienda online con su frontend, API, base de datos y colas).

!!! note "Well-Architected Framework no es lo mismo que Cloud Adoption Framework"
    Los tres proveedores tienen también un **Cloud Adoption Framework (CAF)** (marco de adopción de la nube). El CAF trata la *estrategia de adopción* de la nube en la organización (personas, *governance* o gobierno, migración). El Well-Architected Framework trata la *calidad técnica* de cada workload.

## AWS Well-Architected Framework

AWS lo publicó en 2015 y es el marco de referencia que luego adoptaron (con variaciones) Azure y Google Cloud. Hoy tiene **seis pilares**.

### Los seis pilares

| Pilar | Pregunta que responde | Ejemplos de prácticas |
| --- | --- | --- |
| **Operational Excellence** (excelencia operativa) | ¿Cómo opero y mejoro el sistema día a día? | Infrastructure as Code (IaC), cambios pequeños y reversibles, *runbooks*, *postmortems* |
| **Security** (seguridad) | ¿Cómo protejo datos, sistemas y accesos? | *Least privilege* (mínimo privilegio) en IAM, cifrado *in transit* y *at rest* (en tránsito y en reposo), trazabilidad con CloudTrail |
| **Reliability** (fiabilidad) | ¿Se recupera solo ante fallos? | Multi-AZ, *backups* probados, *auto scaling* (escalado automático), *retries* con *exponential backoff* (reintentos con espera creciente) |
| **Performance Efficiency** (eficiencia del rendimiento) | ¿Uso los recursos adecuados para la carga? | Elegir el *instance type* correcto, *serverless*, caché, CDN |
| **Cost Optimization** (optimización de costos) | ¿Pago solo por lo que aporta valor? | *Tagging* (etiquetado), *rightsizing* (ajustar el tamaño), Savings Plans, apagar entornos de dev fuera de horario |
| **Sustainability** (sostenibilidad) | ¿Minimizo el impacto ambiental? | Maximizar el uso de los recursos, regiones con menor huella de carbono, instancias Graviton |

!!! info "Sustainability es el pilar más nuevo"
    AWS agregó el pilar de **Sustainability** en diciembre de 2021. Antes el marco tenía cinco pilares, por eso aún se ven muchos materiales que hablan de "los cinco pilares".

### Design principles generales

Los principios de diseño generales del marco, con su nombre oficial:

- **Stop guessing your capacity needs** (deja de adivinar la capacidad): escala según la demanda real en vez de sobredimensionar "por si acaso".
- **Test systems at production scale** (prueba a escala de producción): crea un entorno igual al de producción cuando lo necesites y bórralo al terminar.
- **Automate with architecture experimentation in mind** (automatiza para poder experimentar): que probar cambios sea fácil y repetible (IaC, ver [Terraform](../../devops/iac/terraform-basico.md)).
- **Consider evolutionary architectures** (arquitecturas que evolucionan): las decisiones no son para siempre.
- **Drive architectures using data** (decide con datos): mide antes de cambiar.
- **Improve through game days** (mejora con simulacros): provoca fallos a propósito para comprobar que el sistema se recupera.

### Herramientas

- **AWS Well-Architected Tool**: servicio gratuito en la consola. Haces la *review* (revisión) respondiendo preguntas por pilar, obtienes una lista de **high risk issues** y **medium risk issues** (riesgos altos y medios) y un **improvement plan** (plan de mejora).
- **Lenses** (lentes): preguntas adicionales para tipos de workload concretos, por ejemplo *Serverless*, *SaaS*, *Machine Learning*, *Generative AI* o *Data Analytics*.
- **AWS Trusted Advisor**: revisa la cuenta automáticamente y da recomendaciones de costos, seguridad, *fault tolerance* (tolerancia a fallos), rendimiento y *service quotas* (límites de servicio).

!!! tip "Revisión periódica, no una sola vez"
    Lo recomendado es revisar cada workload importante **antes de salir a producción** y después de forma periódica o tras cambios grandes. Los riesgos encontrados se tratan como **deuda técnica** (*technical debt*) a priorizar.

## Azure Well-Architected Framework

Microsoft sigue la misma idea con **cinco pilares**:

- **Reliability** (fiabilidad)
- **Security** (seguridad)
- **Cost Optimization** (optimización de costos)
- **Operational Excellence** (excelencia operativa)
- **Performance Efficiency** (eficiencia del rendimiento)

Lo que lo diferencia:

- **No tiene pilar de Sustainability**: trata la sostenibilidad como guía aparte para workloads, no como pilar.
- **Pone mucho énfasis en los *trade-offs*** (compromisos entre pilares). Por ejemplo, más redundancia mejora la Reliability pero sube el costo; la documentación muestra explícitamente estos conflictos.
- Además de los pilares, publica **workload guidance** (guías por tipo de workload: IA, SaaS, *mission-critical*…) y **service guides** (cómo aplicar cada pilar a App Service, AKS, Azure SQL…).

Herramientas:

- **Azure Well-Architected Review**: cuestionario de autoevaluación dentro de *Microsoft Assessments*.
- **Azure Advisor**: recomendaciones automáticas agrupadas por pilar y un **Advisor Score** (puntuación) para seguir el progreso.

## Google Cloud Well-Architected Framework

Antes se llamaba *Google Cloud Architecture Framework*; hoy usa el mismo nombre que los demás. Tiene **seis pilares**:

1. **Operational excellence** (excelencia operativa)
2. **Security, privacy, and compliance** (seguridad, privacidad y cumplimiento normativo)
3. **Reliability** (fiabilidad)
4. **Cost optimization** (optimización de costos)
5. **Performance optimization** (optimización del rendimiento)
6. **Sustainability** (sostenibilidad)

Lo que lo diferencia:

- El pilar de seguridad incluye explícitamente **privacy** y **compliance** (privacidad y cumplimiento normativo).
- El pilar de Sustainability considera **energía, carbono y también uso de agua**, e incluye guía para diseñar sistemas de IA sostenibles.
- Ofrece **cross-pillar perspectives** (perspectivas transversales), por ejemplo para *AI and ML* o para servicios financieros, que aplican todos los pilares a un contexto concreto.
- Encaja con su idea de **Shared Fate** (destino compartido, ver [Shared Responsibility Model](responsabilidad-compartida.md)): Google intenta dar configuraciones seguras por defecto y guías listas para usar.

Herramientas:

- **Active Assist / Recommender**: recomendaciones automáticas de costos, seguridad, rendimiento y sostenibilidad (por ejemplo, detectar VMs inactivas, *idle VMs*).
- **Google Cloud Architecture Center**: *reference architectures* (arquitecturas de referencia) y guías alineadas con el marco.

## Comparación de pilares

| Tema | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Operación | Operational Excellence | Operational Excellence | Operational excellence |
| Seguridad | Security | Security | Security, privacy, and compliance |
| Resiliencia | Reliability | Reliability | Reliability |
| Rendimiento | Performance Efficiency | Performance Efficiency | Performance optimization |
| Costos | Cost Optimization | Cost Optimization | Cost optimization |
| Medio ambiente | Sustainability | Guía aparte (no es pilar) | Sustainability |
| Autoevaluación | Well-Architected Tool | Well-Architected Review | Guías + Architecture Center |
| Recomendaciones automáticas | Trusted Advisor | Azure Advisor | Active Assist / Recommender |
| Extensiones por tipo de workload | Lenses | Workload guidance + service guides | Cross-pillar perspectives |

!!! note "Mismo fondo, distinto envoltorio"
    Los nombres cambian un poco, pero las preguntas de fondo son las mismas en las tres nubes. Si entiendes bien los pilares de un proveedor, puedes aplicar esa forma de pensar en cualquier otro.

## Conclusión práctica

- Usa los pilares como **checklist** (lista de verificación) al diseñar o revisar una arquitectura.
- No existe la arquitectura perfecta en todos los pilares: cada decisión es un **trade-off** (costo vs. Reliability, rendimiento vs. Sustainability). Lo importante es que sea **consciente y documentado**.
- **Security** y **Reliability** suelen ser los pilares que menos conviene sacrificar.
- Automatizar con IaC y pipelines CI/CD ayuda a cumplir varios pilares a la vez: Operational Excellence, Security y Reliability.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Reliability (zonas, DR), Cost Optimization (FinOps), Security (seguridad base) y gobierno de varios workloads | [Modelos de servicio y regiones](modelos-de-servicio-y-regiones.md), [Resiliencia](../operacion-y-gobierno/resiliencia.md), [FinOps y costos](finops-costos.md), [Fundamentos de seguridad cloud](../seguridad/fundamentos-seguridad-cloud.md), [Gobernanza](../operacion-y-gobierno/gobernanza.md), [Arquitectura en la nube](../arquitectura/arquitectura-cloud.md), [Arquitecturas de referencia](../arquitectura/arquitecturas-referencia.md) |
| DevOps (la automatización) | Operational Excellence: IaC, CI/CD, observabilidad, postmortems | [Infrastructure as Code](../../devops/iac/infraestructura-como-codigo.md), [Despliegue continuo](../../devops/ci-cd/despliegue-continuo.md), [Observabilidad](../../devops/operacion/observabilidad.md), [Operación y fiabilidad (SRE)](../../devops/operacion/operacion-sre.md) |
| DevSecOps (la verificación) | Pilar de Security verificado de forma continua: threat modeling, cumplimiento, detección | [Fundamentos DevSecOps](../../devsecops/fundamentos-devsecops.md), [Cumplimiento y gobierno](../../devsecops/gobierno-y-respuesta/cumplimiento.md), [Detección y respuesta](../../devsecops/gobierno-y-respuesta/deteccion-respuesta.md) |

## Referencias

- [AWS Well-Architected Framework](https://docs.aws.amazon.com/es_es/wellarchitected/latest/framework/welcome.html)
- [AWS Well-Architected Tool](https://aws.amazon.com/es/well-architected-tool/)
- [AWS Well-Architected Lenses](https://aws.amazon.com/es/architecture/well-architected/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/es-es/azure/well-architected/)
- [Azure Advisor](https://learn.microsoft.com/es-es/azure/advisor/advisor-overview)
- [Google Cloud Well-Architected Framework](https://cloud.google.com/architecture/framework)
- [Pilar de Sustainability de Google Cloud](https://cloud.google.com/architecture/framework/sustainability)
