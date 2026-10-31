---
tags:
  - seguridad
  - cumplimiento
  - cspm
  - aws
  - azure
  - gcp
---

# Cumplimiento y gobierno

> Qué son los marcos de cumplimiento (CIS Benchmarks, ISO/IEC 27001, SOC 2, NIST), cómo se verifican de forma continua con compliance as code y qué hace un CSPM en cada nube.

## ¿Qué es?

**Compliance** (cumplimiento) es demostrar que cumples un conjunto de requisitos: una norma (ISO/IEC 27001), un marco de referencia (NIST CSF), un contrato con un cliente o una ley (protección de datos). **Gobierno** (*governance*) es cómo la organización decide esas reglas, asigna responsables y comprueba que se siguen.

!!! warning "Compliance no es lo mismo que seguridad"
    - **Seguridad**: reducir el riesgo real de que algo malo pase.
    - **Compliance**: poder **demostrar** a un tercero (auditor, cliente, regulador) que aplicas ciertos controles.

    Se ayudan, pero no son iguales: puedes aprobar una auditoría con un control que en la práctica nadie mira ("revisión anual de accesos" hecha en una hoja de cálculo), y puedes ser muy seguro sin tener ningún certificado. El objetivo es que el cumplimiento salga **como consecuencia** de controles reales y automatizados.

Para entender quién es responsable de qué control en la nube, parte del [Shared Responsibility Model](../../cloud/fundamentos/responsabilidad-compartida.md): el proveedor tiene sus propias certificaciones, pero **no cubren tu configuración**.

## Marcos de referencia

### CIS Benchmarks

Los **CIS Benchmarks** (del *Center for Internet Security*) son guías de configuración segura, gratuitas en PDF, con recomendaciones concretas y comprobables ("asegúrate de que MFA está activado para el root user").

- **Cloud**: CIS Amazon Web Services Foundations, CIS Microsoft Azure Foundations, CIS Google Cloud Platform Foundation.
- **Sistemas operativos**: Ubuntu, Red Hat Enterprise Linux, Windows Server…
- **Kubernetes**: CIS Kubernetes Benchmark y versiones para EKS, AKS y GKE (ver [Seguridad de Kubernetes](../infraestructura-y-contenedores/seguridad-kubernetes.md)).

Cada recomendación tiene un **Level 1** (básico, poco impacto en el funcionamiento) o **Level 2** (más estricto, para entornos sensibles). Son el punto de partida más práctico: casi todos los CSPM y escáneres los implementan.

### ISO/IEC 27001

Norma internacional que define un **ISMS** (*Information Security Management System*, sistema de gestión de seguridad de la información): cómo identificar riesgos, elegir controles, medirlos y mejorarlos de forma continua. La versión actual es **ISO/IEC 27001:2022**, cuyo **Annex A** lista 93 controles en cuatro temas (organizacionales, de personas, físicos y tecnológicos).

- Se **certifica** con una auditoría de un organismo acreditado; el certificado dura tres años con auditorías de seguimiento.
- **ISO/IEC 27017** añade controles específicos para servicios cloud y **ISO/IEC 27018** para la protección de datos personales en nube pública.

### SOC 2

**SOC 2** (*System and Organization Controls 2*) es un **informe de auditoría** (*attestation*, atestación) del AICPA, emitido por una firma de auditoría externa. Es muy común en empresas SaaS que venden a clientes de Estados Unidos. No es una certificación: es un informe que el cliente lee.

Se basa en los **Trust Services Criteria**: **Security** (obligatorio), **Availability**, **Processing Integrity**, **Confidentiality** y **Privacy** (estos cuatro se eligen según el servicio).

| | Type I | Type II |
| --- | --- | --- |
| Qué evalúa | Que los controles están **bien diseñados** | Que los controles **funcionaron** de forma efectiva |
| Periodo | Una fecha concreta | Un periodo de observación (habitualmente entre 3 y 12 meses) |
| Valor para el cliente | Menor; se usa como primer paso | El que suelen pedir los clientes |

### NIST CSF 2.0 y NIST SP 800-53

El **NIST Cybersecurity Framework (CSF) 2.0** (2024) es un marco voluntario que organiza la ciberseguridad en seis funciones:

| Función | Pregunta |
| --- | --- |
| **Govern** (gobernar) | ¿Quién decide, con qué estrategia y políticas, y cómo se supervisa? (nueva en la 2.0) |
| **Identify** (identificar) | ¿Qué activos y riesgos tenemos? |
| **Protect** (proteger) | ¿Qué controles los protegen? |
| **Detect** (detectar) | ¿Cómo nos enteramos de un ataque? |
| **Respond** (responder) | ¿Qué hacemos durante un incidente? |
| **Recover** (recuperar) | ¿Cómo volvemos a la normalidad? |

**NIST SP 800-53** (Rev. 5) es un catálogo detallado de controles de seguridad y privacidad, obligatorio para sistemas federales de Estados Unidos y base de FedRAMP.

### Comparativa

| Marco | Tipo | Quién lo pide | ¿Se certifica? | Punto fuerte |
| --- | --- | --- | --- | --- |
| CIS Benchmarks | Guía técnica de configuración | Equipos técnicos, auditores | No (hay CIS *hardened images*) | Concreto y automatizable |
| ISO/IEC 27001 | Norma de sistema de gestión | Clientes y socios en todo el mundo | Sí | Reconocimiento internacional, enfoque en riesgo |
| SOC 2 | Informe de auditoría | Clientes de SaaS, sobre todo de EE. UU. | No, es un informe (Type I/II) | Demuestra que los controles funcionan en el tiempo |
| NIST CSF 2.0 | Marco voluntario | Organizaciones que estructuran su programa | No | Lenguaje común para dirección y equipos |
| NIST SP 800-53 | Catálogo de controles | Gobierno de EE. UU., FedRAMP | Vía FedRAMP / ATO | Muy detallado |

!!! tip "Los marcos se solapan"
    Un mismo control (MFA, cifrado, logs de auditoría) aparece en todos. Los CSPM y herramientas como Prowler mapean cada comprobación a varios marcos a la vez, así que un solo hallazgo corregido avanza en todos.

## Auditoría continua y compliance as code

La auditoría tradicional es una foto una vez al año. **Continuous compliance** (cumplimiento continuo) comprueba los controles todo el tiempo y genera evidencia automáticamente.

**Compliance as code** es escribir los controles como código versionado y ejecutable:

| Dónde | Cómo | Ejemplos |
| --- | --- | --- |
| Antes de desplegar | Escaneo de IaC y policy as code en el pipeline | Checkov, Trivy, Conftest ([Seguridad de IaC](../infraestructura-y-contenedores/seguridad-iac.md)) |
| En la nube | Guardrails que impiden configuraciones no permitidas | SCP, Azure Policy, Organization Policy ([Gobernanza](../../cloud/operacion-y-gobierno/gobernanza.md)) |
| Recursos ya desplegados | Evaluación periódica contra benchmarks | CSPM, AWS Config rules, Prowler |
| Servidores | Hardening y comprobación del sistema operativo | Ansible con roles CIS ([Ansible](../../devops/iac/ansible.md)), OpenSCAP, Chef InSpec |
| Evidencia | Registro de quién cambió qué y cuándo | CloudTrail, Activity Log, Cloud Audit Logs ([Seguridad de logging y detección](../../cloud/seguridad/seguridad-logging-deteccion.md)) |

## CSPM

Un **CSPM** (*Cloud Security Posture Management*, gestión de la postura de seguridad en la nube) revisa continuamente la configuración de tus cuentas cloud, la compara con benchmarks y marcos (CIS, NIST, ISO, PCI DSS) y muestra los hallazgos priorizados con su corrección.

!!! tip "Escaneo en detalle"
    Cómo ejecutar Prowler y Steampipe/Powerpipe, los servicios nativos, la cuenta de seguridad centralizada y la remediación de hallazgos con IaC están en [CSPM](../escaneos/cspm.md).

### CSPM nativos

| | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Servicio | **AWS Security Hub CSPM** (antes "Security Hub") + **AWS Config** | **Microsoft Defender for Cloud** | **Security Command Center** |
| Estándares | AWS Foundational Security Best Practices, CIS AWS Foundations, NIST SP 800-53, PCI DSS | Microsoft cloud security benchmark por defecto; se añaden CIS, ISO 27001, SOC 2, NIST… | CIS, NIST, ISO 27001, PCI DSS (según el *tier*) |
| Vista de cumplimiento | Puntuación por estándar en Security Hub CSPM; **conformance packs** de AWS Config | **Regulatory compliance dashboard** | Compliance en Security Command Center |
| Evidencia para auditorías | AWS Audit Manager | Exportación de informes de Defender for Cloud | Informes de SCC |
| Niveles | Pago por uso (revisa la página de precios) | Foundational CSPM (gratis) y Defender CSPM (de pago) | Standard, Premium y Enterprise |

!!! info "Security Hub cambió de nombre en 2025"
    En 2025 AWS lanzó un **nuevo AWS Security Hub** que correlaciona hallazgos de GuardDuty, Inspector y otros servicios para priorizar riesgos, y renombró el servicio original de comprobaciones contra estándares como **AWS Security Hub CSPM**. En documentación anterior verás solo "Security Hub".

Activa el CSPM en **todas** las cuentas y regiones desde la cuenta de administración delegada (*delegated administrator*), para tener una vista central.

### Herramientas open source

| Herramienta | Nubes | Notas |
| --- | --- | --- |
| **Prowler** | AWS, Azure, Google Cloud, Kubernetes, Microsoft 365 y otros | Cientos de comprobaciones mapeadas a CIS, NIST, ISO 27001, SOC 2, PCI DSS…; CLI e interfaz web; muy activo |
| **ScoutSuite** (NCC Group) | AWS, Azure, Google Cloud y otras | Genera un informe HTML para revisión manual. Su última release es de 2024 y el desarrollo está casi parado; revisa su estado antes de adoptarlo |

```bash
# Prowler: ver qué marcos soporta y ejecutar uno
prowler aws --list-compliance
prowler aws --compliance <marco_de_la_lista>

# Prowler en Azure y Google Cloud
prowler azure --az-cli-auth
prowler gcp --project-ids mi-proyecto
```

### CNAPP

Un **CNAPP** (*Cloud-Native Application Protection Platform*) une en una plataforma CSPM, protección de cargas de trabajo (*CWPP*), gestión de permisos (*CIEM*) y escaneo de IaC e imágenes, para relacionar hallazgos ("esta VM expuesta a internet tiene una CVE crítica y un rol con permisos de administrador").

## Cómo empezar

1. Elige **un benchmark base** (CIS Foundations de tu nube) aunque no busques una certificación.
2. Activa el **CSPM nativo** en todas las cuentas y los **logs de auditoría** centralizados.
3. Corrige primero lo crítico (root sin MFA, buckets públicos, puertos de administración abiertos).
4. Evita que vuelva a aparecer: lleva cada corrección a **IaC** y a **guardrails**.
5. Si un cliente pide ISO 27001 o SOC 2, ya tendrás buena parte de la evidencia técnica.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Logs de auditoría, AWS Config, guardrails y estructura de cuentas que el cumplimiento revisa | [Seguridad de logging y detección](../../cloud/seguridad/seguridad-logging-deteccion.md), [Gobernanza](../../cloud/operacion-y-gobierno/gobernanza.md), [Shared Responsibility Model](../../cloud/fundamentos/responsabilidad-compartida.md) |
| DevOps (la automatización) | Hardening de servidores y configuración reproducible | [Ansible](../../devops/iac/ansible.md), [Infrastructure as Code](../../devops/iac/infraestructura-como-codigo.md) |
| DevSecOps (la verificación) | Controles preventivos en el pipeline y respuesta cuando algo falla | [Seguridad de IaC](../infraestructura-y-contenedores/seguridad-iac.md), [CSPM](../escaneos/cspm.md), [Detección y respuesta](deteccion-respuesta.md), [Fundamentos DevSecOps](../fundamentos-devsecops.md) |
| Negocio TI (el porqué) | Gobierno de TI, registro de riesgos, apetito de riesgo y gestión de proveedores | [Gobierno y riesgo de TI](../../negocio/gobierno-riesgo-ti.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 10: Configurar servidores con Ansible](../../laboratorios/devops/ansible-configuracion.md), [Lab 14: Endurecer un clúster: Pod Security, NetworkPolicy y Kyverno](../../laboratorios/devsecops/seguridad-kubernetes.md), [Lab 16: Auditar tu cuenta cloud con Prowler (CSPM)](../../laboratorios/devsecops/cspm-prowler.md), [Lab 22: Endurecer un servidor Linux con Ansible y medirlo con Lynis y OpenSCAP](../../laboratorios/devsecops/hardening-linux-ansible.md) |

## Referencias

- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
- [ISO/IEC 27001](https://www.iso.org/standard/27001)
- [AICPA: SOC 2](https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2)
- [NIST Cybersecurity Framework 2.0](https://www.nist.gov/cyberframework)
- [NIST SP 800-53 Rev. 5](https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final)
- [AWS Security Hub CSPM](https://docs.aws.amazon.com/securityhub/latest/userguide/what-is-securityhub.html)
- [AWS Config conformance packs](https://docs.aws.amazon.com/es_es/config/latest/developerguide/conformance-packs.html)
- [Microsoft Defender for Cloud: regulatory compliance](https://learn.microsoft.com/es-es/azure/defender-for-cloud/regulatory-compliance-dashboard)
- [Security Command Center](https://cloud.google.com/security-command-center/docs/security-command-center-overview)
- [Prowler](https://docs.prowler.com/)
- [ScoutSuite](https://github.com/nccgroup/ScoutSuite)
