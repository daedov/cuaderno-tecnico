---
tags:
  - carrera
  - certificaciones
  - devops
  - sre
  - seguridad
  - finops
---

# Roles profesionales en cloud, DevOps y seguridad

> Qué hace cada rol (Cloud Engineer, Platform Engineer, SRE, DevOps, DevSecOps y otros), en qué se diferencian los que se confunden, cómo crece la carrera y qué parte del cuaderno, de los laboratorios y de las certificaciones sirve para cada camino.

## ¿Por qué se confunden los nombres de los puestos?

Los títulos de puesto (*job titles*) no están estandarizados: la misma persona puede llamarse DevOps, Platform o Cloud Engineer según la empresa, y dos ofertas "DevOps Engineer" pueden pedir trabajos muy distintos. DevOps es una cultura que el mercado convirtió en puesto (ver [Cultura DevOps y métricas DORA](../devops/fundamentos/cultura-metricas-dora.md)), el tamaño de la empresa cambia el alcance (en una startup una persona lo hace todo) y las modas renombran trabajos existentes.

!!! tip "Lee las responsabilidades, no el título"
    En una oferta de trabajo (*job description*, JD), subraya los **verbos** ("diseñar", "operar", "automatizar", "auditar", "estar de guardia") y los **sistemas** (Kubernetes, Terraform, SIEM, firewalls). Te dicen el rol real mejor que el título.

Cada rol vive sobre todo en una o dos capas del cuaderno (ver el [mapa de relaciones](../mapa-de-relaciones.md)): Cloud (el control), DevOps (la automatización), DevSecOps (la verificación), con Negocio TI, Networking y Python alrededor.

## Fichas por rol

Las herramientas son ejemplos habituales, no una lista obligatoria. Cada ficha enlaza las guías de certificación del cuaderno; el orden completo para cada rol vive en [Rutas sugeridas por rol](otras-certificaciones.md#rutas-sugeridas-por-rol).

### Cloud Engineer

- **Qué hace:** construye y opera la infraestructura en uno o varios proveedores cloud de forma segura, repetible y con costos razonables.
- **Día a día:** redes, cómputo, almacenamiento e IAM; IaC; monitoreo y backups; incidentes de infraestructura, parches y cambios.
- **Herramientas:** consola y CLI del proveedor, Terraform, Git, CloudWatch / Azure Monitor / Cloud Monitoring, Ansible.
- **Notas:** [IAM](../cloud/fundamentos/iam-comparativa.md), [Redes en la nube](../cloud/redes-y-datos/redes.md), [Máquinas virtuales](../cloud/computo/maquinas-virtuales.md), [Terraform](../devops/iac/terraform-basico.md), [Observabilidad nativa](../monitoreo/nube/observabilidad-nativa.md).
- **Certificaciones:** [Cloud Practitioner](aws/cloud-practitioner/resumen-examen.md) como base y luego [Solutions Architect – Associate](aws/solutions-architect-associate/resumen-examen.md), [AZ-104](azure/azure-administrator/resumen-examen.md) o [Associate Cloud Engineer](google-cloud/associate-cloud-engineer/resumen-examen.md), más [Terraform Associate](hashicorp/terraform-associate/resumen-examen.md) ([ruta sugerida](otras-certificaciones.md#rutas-sugeridas-por-rol)).

### Cloud Architect / Solutions Architect

- **Qué hace:** decide **cómo** se construye una solución para que cumpla requisitos de negocio, seguridad, fiabilidad y costo, y documenta esas decisiones.
- **Día a día:** levantar requisitos funcionales y no funcionales, diseñar, escribir **ADR** (*Architecture Decision Records*, registros de decisiones), revisar diseños de otros, estimar costos, guiar migraciones. Negocia *trade-offs* (compromisos entre opciones) con negocio.
- **Herramientas:** diagramas (modelo C4, draw.io), calculadoras de precios, Well-Architected, plantillas de ADR.
- **Notas:** [Fundamentos de arquitectura de software](../cloud/arquitectura/fundamentos-arquitectura-software.md), [Arquitectura en la nube](../cloud/arquitectura/arquitectura-cloud.md), [Arquitecturas de referencia](../cloud/arquitectura/arquitecturas-referencia.md), [Well-Architected](../cloud/fundamentos/well-architected.md), [TI y negocio](../negocio/ti-y-negocio.md).
- **Certificaciones:** [Solutions Architect – Associate](aws/solutions-architect-associate/resumen-examen.md) y después el nivel profesional o experto de tu proveedor ([ruta sugerida](otras-certificaciones.md#rutas-sugeridas-por-rol)).

!!! note "Solutions Architect en un proveedor o partner"
    En AWS, Microsoft, Google o sus partners suele ser un rol **de cara al cliente** (preventa, *pre-sales*): diseña propuestas y demos más que operar sistemas.

### DevOps Engineer

- **Qué hace:** acorta el camino entre un cambio en el código y producción, de forma automática, segura y repetible.
- **Día a día:** pipelines de **CI/CD** (integración y entrega continuas), contenerizar aplicaciones, entornos con IaC, estrategias de despliegue, apoyo a desarrollo en build y despliegue. Se mide con las métricas **DORA**.
- **Herramientas:** GitHub Actions, GitLab CI, Jenkins, Azure Pipelines, Docker, Helm, Argo CD, Terraform.
- **Notas:** [Integración continua](../devops/ci-cd/integracion-continua.md), [Despliegue continuo](../devops/ci-cd/despliegue-continuo.md), [Docker](../devops/contenedores/docker.md), [Kubernetes](../devops/contenedores/kubernetes.md), [Infrastructure as Code](../devops/iac/infraestructura-como-codigo.md).
- **Certificaciones:** [Terraform Associate](hashicorp/terraform-associate/resumen-examen.md), luego Kubernetes y la profesional de DevOps de tu nube ([ruta sugerida](otras-certificaciones.md#rutas-sugeridas-por-rol)).

### Platform Engineer

- **Qué hace:** construye una **plataforma interna de desarrollo** (*Internal Developer Platform*, IDP) tratada como producto, para que los equipos se sirvan solos (*self-service*) por **caminos dorados** (*golden paths*) seguros y estándar.
- **Día a día:** plantillas de servicios, módulos de IaC reutilizables, clústeres Kubernetes compartidos, portal de desarrolladores, pipelines estándar, políticas por defecto. Mentalidad de producto: usuarios internos, *roadmap*, adopción.
- **Herramientas:** Kubernetes, Backstage, Crossplane, Argo CD/Flux, Terraform, Helm, OPA/Kyverno.
- **Notas:** [Kubernetes](../devops/contenedores/kubernetes.md), [Infrastructure as Code](../devops/iac/infraestructura-como-codigo.md), [Pruebas de infraestructura](../devops/iac/pruebas-infraestructura.md), [Gobernanza](../cloud/operacion-y-gobierno/gobernanza.md), [Seguridad de IaC](../devsecops/infraestructura-y-contenedores/seguridad-iac.md).
- **Certificaciones:** [Terraform Associate](hashicorp/terraform-associate/resumen-examen.md) y la ruta Kubernetes de la CNCF ([ruta sugerida](otras-certificaciones.md#rutas-sugeridas-por-rol)).

### Site Reliability Engineer (SRE)

- **Qué hace:** mantiene los servicios **fiables** aplicando ingeniería de software a operaciones: SLO, presupuestos de error (*error budget*), automatización y aprendizaje de incidentes.
- **Día a día:** SLI/SLO con producto, alertas por síntomas, guardias (*on-call*), gestión de incidentes, *postmortems* sin culpables (*blameless*), planificación de capacidad, reducir **toil** (trabajo manual repetitivo).
- **Herramientas:** Prometheus, Grafana, OpenTelemetry, PagerDuty/Opsgenie, runbooks, chaos engineering.
- **Notas:** [Operación y fiabilidad (SRE)](../devops/operacion/operacion-sre.md), [Observabilidad](../monitoreo/fundamentos/observabilidad.md), [Postmortem](../devops/operacion/postmortem.md), [Runbooks y playbooks](../devops/operacion/runbooks-playbooks.md), [Niveles de servicio](../negocio/niveles-de-servicio.md), [Resiliencia](../cloud/operacion-y-gobierno/resiliencia.md).
- **Certificaciones:** pesa más la experiencia que las certificaciones ([ruta sugerida](otras-certificaciones.md#rutas-sugeridas-por-rol)).

### DevSecOps Engineer / Application Security Engineer

- **Qué hace:** hace que la seguridad sea parte del ciclo de desarrollo (*shift-left*), con controles automáticos en el pipeline y apoyo a los equipos para corregir.
- **Día a día:** SAST, SCA, secret scanning y escaneo de imágenes e IaC en CI; triage de hallazgos; *threat modeling* (modelado de amenazas); revisión de código; cadena de suministro (SBOM, firma); formación a desarrolladores.
- **Herramientas:** Semgrep, CodeQL, SonarQube, Trivy, Dependabot, Snyk, gitleaks, OWASP ZAP, cosign.
- **Notas:** [Fundamentos DevSecOps](../devsecops/fundamentos-devsecops.md), [Seguridad del código](../devsecops/codigo-y-dependencias/seguridad-codigo.md), [Software supply chain](../devsecops/codigo-y-dependencias/cadena-suministro.md), [Escaneo en el pipeline](../devsecops/escaneos/escaneo-en-pipeline.md), [Seguridad del pipeline](../devsecops/identidades-y-pipeline/seguridad-pipeline.md).
- **Certificaciones:** Security+ y la ruta de seguridad de Kubernetes ([ruta sugerida](otras-certificaciones.md#rutas-sugeridas-por-rol)).

### Cloud Security Engineer

- **Qué hace:** protege la **plataforma cloud** en sí: identidades, configuración, redes, datos y detección de amenazas en cuentas, suscripciones y proyectos.
- **Día a día:** IAM y guardrails (SCP, Azure Policy, Organization Policy), **CSPM** (gestión de la postura de seguridad cloud), cifrado y KMS, logs de auditoría, detección y respuesta, cumplimiento (CIS, ISO 27001, SOC 2).
- **Herramientas:** Security Hub, Defender for Cloud, Security Command Center, GuardDuty, Microsoft Sentinel, Prowler, Checkov.
- **Notas:** [Fundamentos de seguridad cloud](../cloud/seguridad/fundamentos-seguridad-cloud.md), [IAM](../cloud/fundamentos/iam-comparativa.md), [CSPM](../devsecops/escaneos/cspm.md), [Cumplimiento](../devsecops/gobierno-y-respuesta/cumplimiento.md), [Detección y respuesta](../devsecops/gobierno-y-respuesta/deteccion-respuesta.md), [Responsabilidad compartida](../cloud/fundamentos/responsabilidad-compartida.md).
- **Certificaciones:** [Solutions Architect – Associate](aws/solutions-architect-associate/resumen-examen.md) o [AZ-104](azure/azure-administrator/resumen-examen.md) como base y luego la de seguridad de tu nube ([ruta sugerida](otras-certificaciones.md#rutas-sugeridas-por-rol)). SC-500 reemplaza a AZ-500 (retirada en agosto de 2026).

### Infrastructure Engineer / SysAdmin moderno

- **Qué hace:** mantiene servidores, sistemas operativos, almacenamiento y virtualización (on-premise, híbridos o en la nube) funcionando, cada vez más **con código** en vez de a mano.
- **Día a día:** Linux/Windows, parches, backups, virtualización, directorio (Active Directory / Entra ID), automatizar configuración, soporte de tercer nivel.
- **Herramientas:** Ansible, PowerShell, VMware o Hyper-V, herramientas de backup, Zabbix o Prometheus.
- **Notas:** [Linux, redes y scripting](../devops/fundamentos/linux-redes-scripting.md), [Ansible](../devops/iac/ansible.md), [Troubleshooting](../devops/operacion/troubleshooting.md), [Python: sistema y procesos](../python/scripting/sistema-procesos.md).
- **Certificaciones:** [AZ-104](azure/azure-administrator/resumen-examen.md) y certificaciones de Linux ([ruta sugerida](otras-certificaciones.md#rutas-sugeridas-por-rol)).

### Network Engineer y Cloud Network Engineer

- **Qué hace:** diseña y opera la conectividad: LAN/WAN, firewalls, VPN y, en cloud, VPC/VNet, conectividad híbrida, DNS y balanceo entre nubes y datacenter.
- **Día a día:** direccionamiento IP, routing (BGP, OSPF), firewalls, VPN, balanceadores; en cloud, hub-and-spoke, Transit Gateway / Virtual WAN / Network Connectivity Center, Direct Connect / ExpressRoute / Cloud Interconnect, DNS híbrido.
- **Herramientas:** equipos de Cisco, Juniper, Palo Alto o Fortinet, Wireshark, tcpdump, Terraform, diagnóstico de red de cada nube.
- **Notas:** toda la sección Networking, desde [Fundamentos de redes](../networking/basico/fundamentos-redes.md) hasta [Redes de datacenter e híbridas](../networking/avanzado/redes-datacenter-hibridas.md); [Redes en la nube](../cloud/redes-y-datos/redes.md); [Troubleshooting de red](../networking/avanzado/troubleshooting-red.md).
- **Certificaciones:** [AZ-104](azure/azure-administrator/resumen-examen.md) (área de redes) y luego la de redes de tu nube ([ruta sugerida](otras-certificaciones.md#rutas-sugeridas-por-rol)).

### FinOps Practitioner / Analyst

- **Qué hace:** hace que la organización saque el máximo valor de cada unidad de dinero gastada en la nube, conectando ingeniería, finanzas y negocio (una de las *personas* de la FinOps Foundation).
- **Día a día:** asignar costos (*tagging*, *showback*, *chargeback*), presupuestos y pronósticos, anomalías, *rightsizing* y compromisos de uso, informes para dirección, costos de IA y SaaS.
- **Herramientas:** AWS Cost Explorer y CUR, Microsoft Cost Management, Cloud Billing, FOCUS (especificación abierta de datos de facturación), SQL y BI.
- **Notas:** [FinOps y costos](../cloud/fundamentos/finops-costos.md), [TI y negocio](../negocio/ti-y-negocio.md), [Métricas, KPIs y OKRs](../negocio/metricas-kpis-okrs.md), [Gobernanza](../cloud/operacion-y-gobierno/gobernanza.md).
- **Certificaciones:** [Cloud Practitioner](aws/cloud-practitioner/resumen-examen.md) (facturación y precios) y FinOps Certified Practitioner ([ruta sugerida](otras-certificaciones.md#rutas-sugeridas-por-rol)).

### MLOps / AI Platform Engineer

- **Qué hace:** lleva modelos de *machine learning* (aprendizaje automático) e IA generativa a producción de forma repetible: pipelines de entrenamiento, despliegue, monitoreo y gobierno.
- **Día a día:** entrenamiento continuo, registro de modelos (*model registry*), despliegue e inferencia, monitoreo de deriva (*drift*), infraestructura con GPU, plataformas para aplicaciones con LLM, costos de IA. Según Google, la madurez va de **0** (manual) a **1** (pipeline de ML automatizado) y **2** (CI/CD del propio pipeline).
- **Herramientas:** Amazon SageMaker AI / Amazon Bedrock, Azure Machine Learning / Microsoft Foundry, Vertex AI, MLflow, Kubeflow.
- **Notas:** [Kubernetes](../devops/contenedores/kubernetes.md), [Integración continua](../devops/ci-cd/integracion-continua.md), [Observabilidad](../monitoreo/fundamentos/observabilidad.md), [Python](../python/index.md).
- **Certificaciones:** [AI Practitioner](aws/ai-practitioner/resumen-examen.md) como base ([ruta sugerida](otras-certificaciones.md#rutas-sugeridas-por-rol)).

### Release / Build Engineer

- **Qué hace:** hace que el software se compile, empaquete, versione y publique de forma confiable. Frecuente en software de producto, videojuegos, móviles o embebidos.
- **Día a día:** sistemas de build, versionado semántico, ramas de release, artefactos y registries, notas de versión, coordinación de lanzamientos.
- **Herramientas:** Gradle, Maven, Bazel, CMake, Artifactory/Nexus, CI/CD.
- **Notas:** [Git y control de versiones](../devops/fundamentos/git-control-versiones.md), [Integración continua](../devops/ci-cd/integracion-continua.md), [Software supply chain](../devsecops/codigo-y-dependencias/cadena-suministro.md).

### Support / Cloud Operations

- **Qué hace:** atiende incidencias y solicitudes, vigila alertas y resuelve o escala siguiendo runbooks. Es una de las **puertas de entrada** más comunes: ves muchos sistemas y aprendes troubleshooting real.
- **Día a día:** tickets de primer y segundo nivel, alertas, runbooks, escalamiento, documentar soluciones. Variantes: **NOC** (*Network Operations Center*) vigila redes y servicios; **SOC** (*Security Operations Center*) vigila alertas de seguridad y es la entrada típica a Cloud Security.
- **Notas:** [Troubleshooting](../devops/operacion/troubleshooting.md), [Leer logs](../monitoreo/logging/leer-logs.md), [Runbooks y playbooks](../devops/operacion/runbooks-playbooks.md), [Gestión de servicios e ITIL 4](../negocio/gestion-servicios-itil.md).
- **Certificaciones:** [Ruta sugerida](otras-certificaciones.md#rutas-sugeridas-por-rol).

## Tablas comparativas

### Matriz rol por responsabilidad

**P** = principal, **C** = compartida, **·** = poca o ninguna. Es una tendencia general: en cada empresa cambia.

| Rol | Diseño | Construir infra | CI/CD | Plataforma interna | Fiabilidad / on-call | Seguridad | Costos | Redes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cloud Engineer | C | P | C | C | C | C | C | C |
| Cloud Architect | P | · | · | C | C | C | P | C |
| DevOps Engineer | C | C | P | C | C | C | · | · |
| Platform Engineer | C | P | C | P | C | C | C | · |
| SRE | C | C | C | C | P | C | C | C |
| DevSecOps / AppSec | · | · | C | C | · | P | · | · |
| Cloud Security Engineer | C | C | · | C | C | P | · | C |
| Infrastructure Engineer | · | P | · | · | C | C | · | C |
| Network / Cloud Network Engineer | C | C | · | · | C | C | · | P |
| FinOps Practitioner | C | · | · | · | · | · | P | · |
| MLOps Engineer | C | C | P | C | C | · | C | · |
| Release / Build Engineer | · | · | P | C | · | C | · | · |
| Support / Cloud Operations | · | · | · | · | P | · | · | C |

### Pares que se confunden

| Par | En qué se parecen | Diferencia clave |
| --- | --- | --- |
| **DevOps vs SRE** | Automatizan, usan CI/CD, IaC y observabilidad | DevOps se centra en el **flujo de entrega** (llevar cambios a producción rápido); SRE en la **fiabilidad en producción** (SLO, error budget, incidentes, guardias). Google describe SRE como una forma concreta de implementar DevOps |
| **DevOps vs Platform Engineer** | Mismas herramientas (Kubernetes, Terraform, pipelines) | DevOps suele resolver la entrega **de uno o varios equipos**; Platform Engineer construye un **producto interno reutilizable** para toda la organización, con usuarios, roadmap y métricas de adopción |
| **Cloud Engineer vs Cloud Architect** | Conocen a fondo los servicios cloud | El Engineer **construye y opera**; el Architect **decide y documenta** el diseño, con más peso en requisitos de negocio, costos y trade-offs, y menos manos en la consola |
| **DevSecOps vs Cloud Security Engineer** | Los dos automatizan seguridad | DevSecOps protege el **software y su ciclo de vida** (código, dependencias, pipeline, imágenes); Cloud Security protege la **plataforma** (IAM, configuración de cuentas, red, detección) |
| **SRE vs Platform Engineer** | Trabajan sobre infraestructura compartida y a veces están en el mismo equipo | SRE mide y defiende la **fiabilidad de los servicios**; Platform Engineer mide la **productividad de los desarrolladores**. La plataforma suele tener sus propios SLO, que puede cuidar SRE |

### Seniority: qué cambia en cada nivel

Cambia el **alcance**, la **autonomía** y el **impacto**: **junior**, tareas definidas con guía; **semi-senior** (*mid-level*), componentes completos y guardias sin supervisión; **senior**, sistemas y decisiones del equipo, revisa y mentoriza; **staff/principal**, estrategia técnica entre equipos. Desde senior, escribir (ADR, postmortems) y hablar de riesgo en términos de negocio pesa tanto como la herramienta (ver [Negocio TI](../negocio/index.md)).

## Rutas de entrada y crecimiento

Desde la entrada se suele crecer hacia SRE, Platform o Cloud Architect. Qué estudiar del cuaderno en cada camino:

| Si vienes de… | Apunta a… | Empieza por estas secciones | Laboratorios clave |
| --- | --- | --- | --- |
| Soporte o SysAdmin | Cloud Engineer | Networking básico, [Linux, redes y scripting](../devops/fundamentos/linux-redes-scripting.md), Cloud (fundamentos, IAM, redes, cómputo) | 00–03, 08–09, 17, 19 |
| Cloud Engineer | DevOps, Platform o SRE | DevOps completo, [Observabilidad](../monitoreo/fundamentos/observabilidad.md), [Operación SRE](../devops/operacion/operacion-sre.md) | 04–11, 21 |
| Desarrollo de software | DevOps o Platform | [Git](../devops/fundamentos/git-control-versiones.md), CI/CD, contenedores, IaC; luego Cloud | 04–08, 18, 20 |
| Seguridad o SOC | DevSecOps o Cloud Security | DevSecOps completo, [Fundamentos de seguridad cloud](../cloud/seguridad/fundamentos-seguridad-cloud.md), [IAM](../cloud/fundamentos/iam-comparativa.md) | 12–16 |
| Redes o NOC | Cloud Network Engineer | Networking intermedio y avanzado, [Redes en la nube](../cloud/redes-y-datos/redes.md) | 01–02, 17, 19 |
| Cualquier rol técnico con experiencia | Cloud Architect | [Arquitectura](../cloud/arquitectura/fundamentos-arquitectura-software.md), [Well-Architected](../cloud/fundamentos/well-architected.md), Negocio TI | 17–20 (como diseño completo) |

Los números corresponden a los [laboratorios](../laboratorios/index.md). Las certificaciones de cada camino están en [Rutas sugeridas por rol](otras-certificaciones.md#rutas-sugeridas-por-rol).

### Portafolio recomendado por rol

Un repositorio público con README claro (problema, diagrama, cómo ejecutarlo, cómo limpiarlo) vale más que una lista de herramientas en el CV. Antes de publicar, pasa un detector de secretos por el historial (ver [Secret scanning](../devsecops/escaneos/secret-scanning.md)) y no subas state de Terraform, `.env` ni IDs de cuenta.

| Rol objetivo | Qué mostrar (laboratorios) |
| --- | --- |
| Cloud Engineer | VPC con EC2 privada en Terraform ([17](../laboratorios/cloud/aws-vpc-ec2.md)), lo mismo en Azure ([19](../laboratorios/cloud/azure-vnet-vm.md)), backend remoto ([09](../laboratorios/devops/terraform-aws-backend-remoto.md)) |
| DevOps Engineer | Contenedor multi-stage ([05](../laboratorios/devops/docker-multistage-compose.md)) con CI ([07](../laboratorios/devops/github-actions-ci.md)) y despliegue en Kubernetes ([06](../laboratorios/devops/kubernetes-local-kind.md)) |
| Platform Engineer | Módulos de Terraform con tests ([08](../laboratorios/devops/terraform-local-workspaces.md)), plantilla de servicio con pipeline y políticas ([07](../laboratorios/devops/github-actions-ci.md), [14](../laboratorios/devsecops/seguridad-kubernetes.md)) |
| SRE | SLO y alertas de error budget con Prometheus y Grafana ([11](../laboratorios/devops/observabilidad-prometheus-grafana.md)), postmortem del game day ([21](../laboratorios/operacion/game-day-incidente.md)) |
| DevSecOps / AppSec | Pipeline con escaneos y gating ([12](../laboratorios/devsecops/escaneos-en-pipeline.md)), OIDC sin llaves ([13](../laboratorios/devsecops/oidc-github-aws.md)), DAST con ZAP ([15](../laboratorios/devsecops/dast-zap-juice-shop.md)) |
| Cloud Security | Prowler y remediación como código ([16](../laboratorios/devsecops/cspm-prowler.md)), OIDC ([13](../laboratorios/devsecops/oidc-github-aws.md)), hardening de Kubernetes ([14](../laboratorios/devsecops/seguridad-kubernetes.md)) |
| Network / Cloud Network | Plan de direccionamiento ([02](../laboratorios/fundamentos/subnetting-plan-ips.md)), diagnóstico documentado ([01](../laboratorios/fundamentos/linux-red-diagnostico.md)), VPC y VNet como IaC ([17](../laboratorios/cloud/aws-vpc-ec2.md), [19](../laboratorios/cloud/azure-vnet-vm.md)) |
| FinOps | Presupuestos y alertas ([00, parte 2](../laboratorios/fundamentos/preparar-cuentas-cloud.md)) y un análisis de costos de los labs con etiquetas |
| MLOps | Modelo pequeño servido en serverless ([18](../laboratorios/cloud/aws-serverless-api.md)) o Cloud Run ([20](../laboratorios/cloud/gcp-cloud-run.md)), con CI y monitoreo |

## Contexto de mercado

Tendencias, no predicciones (contrasta con ofertas de tu país): la CNCF y DORA destacan la **ingeniería de plataformas**; DORA 2025 ve la IA como **amplificador** de una buena plataforma; el State of FinOps 2026 prioriza los **costos de IA**; y SLSA, SBOM y firma de artefactos aparecen cada vez más en ofertas. Sobre **salarios** no hay cifras a propósito: usa encuestas con metodología (Stack Overflow Developer Survey, encuestas locales) y rangos publicados, comparando el mismo nivel y alcance.

## Referencias

- [CNCF Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/)
- [Google SRE book: Introduction](https://sre.google/sre-book/introduction/)
- [DORA Research (informes anuales)](https://dora.dev/research/)
- [FinOps Framework: Personas](https://www.finops.org/framework/personas/)
- [Google Cloud: MLOps, continuous delivery and automation pipelines in machine learning](https://docs.cloud.google.com/architecture/mlops-continuous-delivery-and-automation-pipelines-in-machine-learning)
- [Stack Overflow Developer Survey 2025: Work (incluye salarios)](https://survey.stackoverflow.co/2025/work)
