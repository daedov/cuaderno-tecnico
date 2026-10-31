---
tags:
  - seguridad
  - siem
  - incidentes
  - vulnerabilidades
  - observabilidad
  - aws
  - azure
  - gcp
---

# Detección y respuesta

> Cómo detectar actividad maliciosa (SIEM y fuentes de logs), gestionar vulnerabilidades con prioridades y SLA de remediación, y responder a incidentes con playbooks y forense básico en la nube.

## ¿Qué es?

Ningún control preventivo es perfecto: una credencial se filtra, aparece una CVE nueva o alguien abre un puerto a mano. Esta nota trata lo que pasa **después**:

| Bloque | Pregunta |
| --- | --- |
| **Detection** (detección) | ¿Cómo me entero de que algo va mal? |
| **Vulnerability management** (gestión de vulnerabilidades) | ¿Qué debilidades tengo y en qué orden las arreglo? |
| **Incident response** (respuesta a incidentes) | ¿Qué hago, paso a paso, cuando ocurre? |

Se apoya en la observabilidad (logs, métricas, alertas) de [Observabilidad](../../devops/operacion/observabilidad.md) y en la gestión de incidentes de [Operación y fiabilidad (SRE)](../../devops/operacion/operacion-sre.md), pero con foco en seguridad.

## Detección

### Fuentes de logs

Sin logs no hay detección ni investigación. Qué logs de cada nube activar (CloudTrail, Activity Log y logs de Microsoft Entra ID, Cloud Audit Logs, flow logs), cómo hacerlos inmutables en una cuenta o proyecto de logs separado y qué servicios de **threat detection** (detección de amenazas) nativos encender (Amazon GuardDuty, Microsoft Defender for Cloud, Security Command Center) está en [Seguridad de logging y detección](../../cloud/seguridad/seguridad-logging-deteccion.md). Los audit logs del API server de Kubernetes se activan en el servicio gestionado (ver [Seguridad de contenedores y Kubernetes gestionado](../../cloud/seguridad/seguridad-contenedores-kubernetes.md#controles-por-proveedor)).

Para el SIEM, a esas fuentes de la nube se suman los logs de aplicación, WAF, DNS y load balancers, los de los hosts y los hallazgos de los servicios de detección. Lo primero que intenta un atacante es borrar su rastro, así que el SIEM debe leer de la copia central, no de cada cuenta.

### SIEM

Un **SIEM** (*Security Information and Event Management*, gestión de eventos e información de seguridad):

1. **Recoge** logs de muchas fuentes (nube, identidad, endpoints, red, aplicaciones).
2. **Normaliza** los datos a un formato común.
3. **Correlaciona** eventos con reglas de detección ("login desde un país nuevo + creación de access key + desactivación de CloudTrail en 10 minutos").
4. **Alerta** y da contexto para investigar (*threat hunting*, búsqueda proactiva de amenazas).
5. **Conserva** los datos para auditorías y forense.

| Opción | Tipo | Notas |
| --- | --- | --- |
| **Microsoft Sentinel** | SIEM cloud de Microsoft | Integración nativa con Entra ID, Defender y Azure. Se está trasladando al **portal de Microsoft Defender**; Microsoft anunció el fin del soporte en el portal de Azure para el 31 de marzo de 2027 |
| **Google Security Operations** (antes Chronicle) | SIEM cloud de Google | Ingesta a gran escala, búsqueda rápida sobre mucho histórico |
| **Splunk Enterprise Security** | SIEM comercial | Muy extendido en grandes empresas |
| **Elastic Security** | SIEM sobre Elasticsearch | Versión gratuita con funciones básicas; reglas de detección abiertas |
| **Wazuh** | Open source | SIEM y XDR con agentes en hosts; buena opción para aprender |
| **Amazon Security Lake** | *Data lake* de seguridad (no es un SIEM) | Centraliza logs de AWS y de terceros en S3 en formato **OCSF** (*Open Cybersecurity Schema Framework*) para que los consuma el SIEM que elijas |

**SOAR** (*Security Orchestration, Automation and Response*): automatiza la respuesta a alertas con flujos (*playbooks* ejecutables): enriquecer la alerta, abrir un ticket, desactivar una credencial. Microsoft Sentinel y Google Security Operations lo incluyen.

!!! tip "Detection as code"
    Igual que la infraestructura, las reglas de detección se pueden versionar y probar en Git (por ejemplo, en formato **Sigma**, convertible a la sintaxis de cada SIEM). Así se revisan por PR y no se pierden.

## Vulnerability management

La **gestión de vulnerabilidades** es un ciclo continuo, no un escaneo puntual:

```mermaid
flowchart LR
    A[Descubrir<br/>inventario + escaneos] --> B[Priorizar<br/>CVSS + EPSS + KEV + contexto]
    B --> C[Remediar<br/>parche, cambio de config, mitigación]
    C --> D[Verificar<br/>re-escaneo]
    D --> A
```

- **Descubrir**: inventario de activos y escaneo de imágenes, dependencias, VMs e IaC (Trivy, Amazon Inspector, Defender for Cloud, Artifact Analysis; ver [Container scanning](../escaneos/container-scanning.md)).
- **Priorizar**: no todo lo "crítico" es urgente.
- **Remediar**: actualizar, reconstruir la imagen, cambiar la configuración o aplicar una mitigación temporal (regla de WAF, cerrar un puerto).
- **Verificar**: el re-escaneo confirma que desapareció.

!!! tip "CVE en detalle"
    Qué es un CVE, quién lo asigna y cómo leer NVD, CWE, CVSS, EPSS, KEV, GHSA y OSV está en [Fundamentos de CVE](../vulnerabilidades/fundamentos-cve.md). El análisis paso a paso de un CVE concreto (¿nos afecta?, ¿qué tan urgente es?), con consultas a las APIs de NVD y OSV, está en [Cómo investigar un CVE](../vulnerabilidades/investigar-un-cve.md). Y los CVE históricos más importantes, agrupados por tipo de componente, en el catálogo: [Aplicaciones y librerías](../vulnerabilidades/cve-aplicaciones-librerias.md), [Supply chain y CI/CD](../vulnerabilidades/cve-supply-chain-cicd.md), [Contenedores y Kubernetes](../vulnerabilidades/cve-contenedores-kubernetes.md), [Linux y sistemas](../vulnerabilidades/cve-linux-sistemas.md), [Windows y Active Directory](../vulnerabilidades/cve-windows-active-directory.md), [Perímetro y VPN](../vulnerabilidades/cve-perimetro-vpn.md) y [Protocolos y hardware](../vulnerabilidades/cve-protocolos-hardware.md).

### Priorizar con CVSS, EPSS y KEV

| Señal | Qué dice | Quién la publica |
| --- | --- | --- |
| **CVSS** (*Common Vulnerability Scoring System*) | **Gravedad** teórica de 0 a 10 (versión actual: 4.0) | FIRST; el NVD y los fabricantes publican las puntuaciones |
| **EPSS** (*Exploit Prediction Scoring System*) | **Probabilidad** de que se explote en los próximos 30 días | FIRST |
| **CISA KEV** (*Known Exploited Vulnerabilities*) | Lista de CVEs que **ya se están explotando** | CISA (EE. UU.) |
| Contexto propio | ¿Está expuesto a internet? ¿Tiene datos sensibles? ¿Hay un control que lo mitiga? | Tu equipo |

Una CVE con CVSS 9.8 en una librería que no se carga nunca puede esperar; una CVSS 7.5 que está en KEV y en un servicio expuesto a internet, no.

### SLA de remediación

Un **SLA de remediación** (*remediation SLA*) fija en cuánto tiempo se corrige cada vulnerabilidad según su severidad. Los valores siguientes son **un ejemplo habitual**; cada organización define los suyos según su riesgo, normativa y contratos:

| Severidad | Plazo de ejemplo | Ejemplos |
| --- | --- | --- |
| Crítica, o en CISA KEV con exposición a internet | 24 horas a 7 días | RCE explotable en un servicio público |
| Alta | 30 días | Escalada de privilegios con exploit público |
| Media | 90 días | Vulnerabilidad que requiere acceso previo |
| Baja | 180 días o en el ciclo normal de mantenimiento | Información expuesta de bajo impacto |

Mide el cumplimiento con métricas como **MTTR** (*mean time to remediate*, tiempo medio de remediación) y el porcentaje de vulnerabilidades fuera de SLA.

### Excepciones y riesgo aceptado

A veces no se puede corregir a tiempo (no hay parche, el cambio rompe un sistema heredado). Entonces se registra una **excepción** (*risk acceptance*, aceptación del riesgo) con:

- Justificación y **controles compensatorios** (WAF, aislamiento de red, monitoreo extra).
- **Responsable** con autoridad para aceptar el riesgo (no quien lo reporta).
- **Fecha de caducidad**: la excepción se revisa; no es permanente.

En las herramientas se refleja como supresión documentada (por ejemplo, un `.trivyignore` con comentario y fecha). La gestión de riesgo está en [Fundamentos DevSecOps](../fundamentos-devsecops.md).

## Respuesta a incidentes

### El ciclo de NIST

La guía de referencia es **NIST SP 800-61**. La **Revisión 3** (abril de 2025) sustituye a la Rev. 2 y cambia el enfoque: en lugar de un ciclo propio, integra la respuesta a incidentes en las seis funciones del **NIST CSF 2.0** (ver [Cumplimiento](cumplimiento.md)) y deja los detalles técnicos cambiantes en recursos complementarios.

| Rev. 2 (2012), ciclo clásico | Rev. 3 (2025), funciones del CSF 2.0 |
| --- | --- |
| Preparation | **Govern**, **Identify**, **Protect**: preparación continua |
| Detection & Analysis | **Detect** |
| Containment, Eradication & Recovery | **Respond** y **Recover** |
| Post-Incident Activity | **Identify** (mejora): las lecciones aprendidas alimentan todas las funciones |

El ciclo de la Rev. 2 sigue siendo útil para pensar en las fases de un incidente concreto, y muchas organizaciones lo siguen usando.

### Playbooks

Un **playbook** (o *runbook* de seguridad) es una guía paso a paso para un tipo de incidente concreto. Se escribe **antes**, se prueba en simulacros (*tabletop exercises*) y se versiona como cualquier documento técnico.

#### Ejemplo: access key de AWS filtrada en GitHub

!!! info "Cómo suele empezar"
    GitHub tiene un programa de **secret scanning** con proveedores: si se publica una access key de AWS en un repositorio público, AWS recibe el aviso, adjunta a ese usuario una managed policy de cuarentena (`AWSCompromisedKeyQuarantine`, con sufijo de versión) y abre un caso de soporte. La cuarentena **limita** algunas acciones, pero no sustituye tu respuesta.

1. **Contener: desactivar la key** (no borrarla aún, para poder investigar):

    ```bash
    aws iam update-access-key --user-name ci-legacy \
      --access-key-id AKIAXXXXXXXXXXXXXXXX --status Inactive
    ```

2. **Revocar sesiones temporales** que se hayan obtenido con esa key: desactivarla no invalida los tokens de STS ya emitidos. Adjunta al usuario una policy que deniegue todo para tokens emitidos antes de ahora:

    ```json
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Deny",
        "Action": "*",
        "Resource": "*",
        "Condition": { "DateLessThan": { "aws:TokenIssueTime": "2026-10-24T12:00:00Z" } }
      }]
    }
    ```

3. **Investigar en CloudTrail** qué se hizo con la key, en **todas las regiones**:

    ```bash
    aws cloudtrail lookup-events \
      --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=AKIAXXXXXXXXXXXXXXXX \
      --max-results 50
    ```

    Busca: usuarios, roles o keys nuevos (persistencia), instancias EC2 en regiones que no usas (minería de criptomonedas), cambios en CloudTrail o GuardDuty, acceso a S3 o Secrets Manager.

4. **Erradicar**: elimina lo que creó el atacante y **borra** la key comprometida.
5. **Recuperar**: sustituye la key por OIDC o un rol (ver [Secretos e identidades](../identidades-y-pipeline/secretos-identidades.md)); si no es posible, crea una nueva y guárdala en un gestor de secretos.
6. **Limpiar el repositorio** (reescribir el historial) **después** de rotar: la key ya debe considerarse pública.
7. **Lecciones aprendidas**: postmortem sin culpables (*blameless*), y acciones como pre-commit hooks con gitleaks, secret scanning con *push protection* y eliminar IAM users con keys. Ver [Operación y fiabilidad (SRE)](../../devops/operacion/operacion-sre.md).

### Forense básico en la nube

Ante una VM comprometida, el instinto es apagarla o borrarla. **No lo hagas**: pierdes la evidencia. Primero **aísla y preserva**:

1. **Etiqueta** el recurso (`Incidente=IR-2026-001`) y activa la protección contra borrado.
2. **Sácala del escalado automático** y del load balancer para que no la reemplacen ni reciba tráfico.
3. **Snapshot** de los discos (y, si tienes las herramientas, captura de memoria antes de apagar).
4. **Aísla la red** con un security group / NSG / regla de firewall que no permita tráfico, salvo el acceso de los investigadores.
5. **Revoca las credenciales** que la VM tenía (rol, managed identity, service account) si pudieron robarse.
6. Analiza las copias en una cuenta o proyecto **forense** separado, no en la máquina original.

| Paso | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Snapshot de disco | `aws ec2 create-snapshot` (EBS) | Snapshot de managed disk (`az snapshot create`) | `gcloud compute snapshots create` |
| Aislar la red | Security group de aislamiento (y NACL si hace falta) | NSG sin reglas de entrada/salida | Firewall rule de *deny* con *network tag* o regla de alta prioridad |
| Hallazgos de partida | GuardDuty, Detective | Defender for Cloud, Sentinel | Security Command Center |

!!! warning "Conexiones ya abiertas"
    En AWS, cambiar el security group no corta las conexiones que ya estaban **rastreadas** (*tracked connections*). La guía de respuesta a incidentes de AWS explica cómo cortarlas; revísala antes de un incidente real, no durante.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Qué logs de auditoría activar y proteger, y servicios de detección nativos (GuardDuty, Defender, SCC) | [Seguridad de logging y detección](../../cloud/seguridad/seguridad-logging-deteccion.md), [Observabilidad nativa](../../cloud/operacion-y-gobierno/observabilidad-nativa.md) |
| DevOps (la automatización) | Centralizar logs y alertas; gestión de incidentes, on-call y postmortems | [Observabilidad](../../devops/operacion/observabilidad.md), [Operación y fiabilidad (SRE)](../../devops/operacion/operacion-sre.md), [Postmortem](../../devops/operacion/postmortem.md), [Comunicación de incidentes](../../devops/operacion/comunicacion-incidentes.md), [Runbooks y playbooks](../../devops/operacion/runbooks-playbooks.md), [Cómo leer logs](../../devops/operacion/leer-logs.md) |
| DevSecOps (la verificación) | De dónde salen las vulnerabilidades y los controles que evitan repetir el incidente | [Seguridad de contenedores](../infraestructura-y-contenedores/seguridad-contenedores.md), [Secretos e identidades](../identidades-y-pipeline/secretos-identidades.md), [Cumplimiento y gobierno](cumplimiento.md), [Fundamentos de CVE](../vulnerabilidades/fundamentos-cve.md), [Cómo investigar un CVE](../vulnerabilidades/investigar-un-cve.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 03: Script en Python para analizar logs](../../laboratorios/fundamentos/python-analizar-logs.md), [Lab 11: Observabilidad con Prometheus y Grafana](../../laboratorios/devops/observabilidad-prometheus-grafana.md), [Lab 12: Escaneos de seguridad en el pipeline](../../laboratorios/devsecops/escaneos-en-pipeline.md), [Lab 15: DAST con OWASP ZAP sobre OWASP Juice Shop](../../laboratorios/devsecops/dast-zap-juice-shop.md), [Lab 16: Auditar tu cuenta cloud con Prowler (CSPM)](../../laboratorios/devsecops/cspm-prowler.md), [Lab 21: Game day: incidente simulado, troubleshooting y postmortem](../../laboratorios/operacion/game-day-incidente.md) |

## Referencias

- [NIST SP 800-61 Rev. 3](https://csrc.nist.gov/pubs/sp/800/61/r3/final)
- [CVSS v4.0 (FIRST)](https://www.first.org/cvss/)
- [EPSS (FIRST)](https://www.first.org/epss/)
- [CISA Known Exploited Vulnerabilities Catalog](https://www.cisa.gov/known-exploited-vulnerabilities-catalog)
- [AWS Security Incident Response Guide](https://docs.aws.amazon.com/whitepapers/latest/aws-security-incident-response-guide/aws-security-incident-response-guide.html)
- [AWS: qué hacer si una access key se expone](https://repost.aws/knowledge-center/potential-account-compromise)
- [Amazon Security Lake](https://docs.aws.amazon.com/es_es/security-lake/latest/userguide/what-is-security-lake.html)
- [Microsoft Sentinel](https://learn.microsoft.com/es-es/azure/sentinel/overview)
- [Google Security Operations](https://cloud.google.com/chronicle/docs/secops/secops-overview)
- [Wazuh](https://documentation.wazuh.com/)
- [Sigma rules](https://sigmahq.io/)
- [GitHub secret scanning partner program](https://docs.github.com/es/code-security/secret-scanning/secret-scanning-partnership-program/secret-scanning-partner-program)
