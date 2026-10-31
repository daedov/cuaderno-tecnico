---
tags:
  - aws
  - certificacion
  - clf-c02
  - seguridad
  - iam
  - cumplimiento
---

# Dominio 2: Security and Compliance (30%)

> Quién protege qué en AWS, dónde se encuentran los informes de cumplimiento y los logs, cómo se gestionan las identidades (y el usuario root) y qué servicio de seguridad usar en cada caso.

!!! info "Qué evalúa este dominio"
    Según la guía oficial de CLF-C02, cuatro *task statements*:

    - **2.1** **AWS shared responsibility model**: qué hace AWS, qué hace el cliente y cómo cambia según el servicio (EC2, RDS, Lambda).
    - **2.2** Seguridad, gobierno y cumplimiento: **AWS Artifact**, cifrado en tránsito y en reposo, servicios de protección (Inspector, Security Hub, GuardDuty, Shield) y de gobierno (CloudWatch, CloudTrail, Config, access reports).
    - **2.3** Gestión de accesos: **IAM**, **root user**, **least privilege**, **IAM Identity Center**, access keys, almacenamiento de credenciales, MFA, roles entre cuentas y federación.
    - **2.4** Componentes y recursos de seguridad: WAF, Firewall Manager, Shield, GuardDuty, **AWS Marketplace**, fuentes de información y **Trusted Advisor**.

    Es el **segundo dominio con más peso**. Vuelve al [resumen del examen](resumen-examen.md) para el plan de estudio.

## Shared Responsibility Model

AWS es responsable de la **security OF the cloud** (datacenters, hardware, red global, hipervisor). Tú, de la **security IN the cloud** (tus datos, identidades y configuración). La explicación completa por capas está en [Shared Responsibility Model](../../../cloud/fundamentos/responsabilidad-compartida.md). La guía pide comparar EC2, RDS y Lambda: cuanto más **managed** es el servicio, menos te toca.

| Tarea | Amazon EC2 (IaaS) | Amazon RDS (gestionado) | AWS Lambda (serverless) |
| --- | --- | --- | --- |
| Seguridad física, hardware, hipervisor | AWS | AWS | AWS |
| Parches del sistema operativo | **Cliente** | AWS | AWS |
| Parches del motor de base de datos o del runtime | **Cliente** (lo que instales) | AWS (en la ventana de mantenimiento que eliges) | AWS |
| Security groups / acceso de red | **Cliente** | **Cliente** | **Cliente** (si la conectas a una VPC) |
| Código, datos, cifrado e IAM | **Cliente** | **Cliente** | **Cliente** |

**Controles compartidos** (cada parte en su capa): **patch management**, **configuration management** y **awareness and training**. **Controles heredados** (*inherited controls*): los físicos y ambientales, que el cliente hereda de AWS.

!!! tip "En el examen"
    - "Parchear el SO de una instancia EC2" → **cliente**. "Parchear el SO de RDS" → **AWS**.
    - "Proteger el hardware o destruir discos al final de su vida útil" → **AWS**.
    - **IAM** y los **datos** son siempre del cliente, en cualquier modelo.
    - "Responsabilidad compartida" en una opción suele referirse a parches, configuración o formación.

## Seguridad, gobierno y cumplimiento

- **AWS Artifact**: portal **self-service** y gratuito para descargar los **informes de auditoría** de AWS (SOC 1/2/3, ISO 27001, PCI DSS…) en **Artifact Reports** y aceptar acuerdos como el **BAA** (HIPAA) en **Artifact Agreements**.
- **AWS Compliance Programs** lista los programas por país e industria (HIPAA, GDPR, PCI DSS, FedRAMP). Comprueba en **Services in Scope** que el servicio que usas está **en alcance**: que AWS esté certificado **no** hace que tu aplicación cumpla (ver [Cumplimiento y gobierno](../../../devsecops/gobierno-y-respuesta/cumplimiento.md)).

| Cifrado | Qué protege | Servicios |
| --- | --- | --- |
| **In transit** (en tránsito) | Datos que viajan por la red | TLS/HTTPS, **AWS Certificate Manager (ACM)**, VPN |
| **At rest** (en reposo) | Datos guardados | **AWS KMS**: AWS gestiona el hardware y tú controlas el uso de las claves |
| Hardware dedicado | Claves en un **HSM** de un solo cliente | **AWS CloudHSM**: gestionas tú las claves |

Detalle de KMS, envelope encryption y rotación en [Seguridad de cifrado y secretos](../../../cloud/seguridad/seguridad-cifrado-secretos.md#envelope-encryption-y-modelos-de-clave).

| Servicio | Responde a… | Ejemplo |
| --- | --- | --- |
| **AWS CloudTrail** | ¿**Quién** hizo **qué** llamada a la API, cuándo y desde dónde? | "¿Quién borró este bucket?" |
| **AWS Config** | ¿**Cómo estaba configurado** un recurso y cumple las reglas? | "¿Hay buckets S3 públicos?" |
| **Amazon CloudWatch** | ¿**Cómo funciona** (métricas, logs, alarmas)? | "Alarma si la CPU supera 80%" |
| **Access reports** (IAM access advisor, credential report, IAM Access Analyzer) | ¿Qué permisos se usan y qué se comparte fuera? | "Access keys de más de 90 días" |

!!! tip "En el examen"
    - "**Auditar** llamadas a la API", "quién lanzó la instancia" → **CloudTrail**.
    - "**Historial de configuración**", "cumplimiento de reglas de configuración" → **Config**.
    - "Métricas de rendimiento y alarmas" → **CloudWatch**.
    - "Descargar el informe SOC 2 o PCI de AWS" → **AWS Artifact** (no Trusted Advisor ni Security Hub).

## Gestión de identidades y accesos

**AWS IAM** controla **quién** puede hacer **qué** sobre **qué recursos**. Usuarios, grupos, roles, políticas JSON y su evaluación están en [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md#aws-iam). Lo mínimo para el examen:

| Pieza | Qué es | Buena práctica |
| --- | --- | --- |
| **IAM user** | Credenciales a largo plazo (contraseña, access keys) | Úsalos lo menos posible; para personas, IAM Identity Center |
| **IAM group** | Usuarios que comparten políticas | Permisos al grupo, no usuario por usuario |
| **IAM role** | Sin credenciales permanentes: entrega credenciales **temporales** | Servicios (EC2, Lambda), **cross-account** y federación |
| **IAM policy** | JSON con `Effect`, `Action`, `Resource` | **AWS managed** para empezar; **customer managed** para ajustar al **least privilege** |

- **MFA**: actívalo **siempre** en el root y en usuarios con consola. **Password policy** para IAM users.
- **Access keys**: para CLI, SDK y API. Nunca en el código; mejor roles con credenciales temporales.
- **AWS IAM Identity Center** (antes AWS SSO): inicio de sesión único para **varias cuentas** y aplicaciones, con un **IdP** externo (Entra ID, Okta, Google Workspace) o usuarios propios.
- **Federation**: identidades de otro sistema (SAML 2.0, OIDC). Para usuarios de **apps móviles o web**, **Amazon Cognito**.
- **Credenciales de aplicaciones**: **Secrets Manager** (rotación automática integrada, de pago por secreto) vs **Systems Manager Parameter Store** (configuración y secretos simples, tier estándar sin costo, sin rotación nativa).

### El usuario root

Se crea con la cuenta (correo del registro) y tiene **acceso total**, que no se puede limitar con políticas IAM dentro de la cuenta. Protégelo: **MFA**, **sin access keys**, contraseña fuerte con correo de grupo, **no usarlo a diario** (crea identidades administrativas en IAM Identity Center) y, en Organizations, **centralized root access** para quitar las credenciales root de las cuentas miembro.

Tareas que **solo** puede hacer el root (las más preguntadas):

- Cambiar correo, contraseña o access keys del root; **cerrar la cuenta**.
- **Cambiar o cancelar el plan de AWS Support**.
- Restaurar permisos de IAM cuando el único administrador se bloqueó.
- Registrarse como vendedor en el **Reserved Instance Marketplace**.
- Configurar **MFA Delete** en S3 y editar una bucket policy que deniega el acceso a todos.

!!! tip "En el examen"
    - "Mejor práctica **inmediata** al crear una cuenta" → **MFA en el root** y no usarlo para tareas diarias.
    - "Aplicación en EC2 que lee S3" → **IAM role** (instance profile), **nunca** access keys en la instancia.
    - "Varias cuentas, un solo inicio de sesión" → **IAM Identity Center**. "Usuarios de una app móvil" → **Cognito**.
    - "Rotar automáticamente la contraseña de la base de datos" → **Secrets Manager**.
    - Los permisos de IAM son **globales** (no por región).

## Servicios y recursos de seguridad

### Servicios que hay que distinguir

| Servicio | Qué hace | Frase que lo delata |
| --- | --- | --- |
| **Amazon GuardDuty** | **Threat detection** (detección de amenazas) con ML sobre CloudTrail, VPC Flow Logs, DNS logs y más | "Actividad maliciosa o anómala", "instancia minando criptomonedas" |
| **Amazon Inspector** | **Vulnerability scanning** automático de EC2, imágenes en ECR y Lambda | "CVE", "vulnerabilidades de software", "exposición de red no intencionada" |
| **Amazon Macie** | Descubre **datos sensibles** (PII) en S3 con ML | "Datos personales o de tarjetas en buckets" |
| **Amazon Detective** | **Investigar** la causa raíz de un hallazgo | "Analizar e investigar" hallazgos de GuardDuty |
| **AWS Security Hub** | Vista **central** de hallazgos y postura contra estándares (CIS, AWS Foundational Security Best Practices) | "Panel único", "postura en varias cuentas" |
| **AWS Shield** | **DDoS**. **Standard**: gratis y automático. **Advanced**: de pago, con Shield Response Team y protección de costos | "DDoS" |
| **AWS WAF** | Firewall de aplicaciones web (capa 7) delante de CloudFront, ALB o API Gateway | "Inyección SQL", "XSS", "bloquear IPs o países", "rate limiting" |
| **AWS Firewall Manager** | Gestiona **centralmente** WAF, Shield Advanced y security groups en Organizations | "Mismas reglas de firewall en todas las cuentas" |
| **AWS Trusted Advisor** | Recomendaciones de costo, rendimiento, **seguridad**, tolerancia a fallos, service limits y excelencia operativa | "Puertos abiertos sin restricción", "MFA en root sin activar" |

!!! info "Cambio reciente en AWS Security Hub"
    En 2025 el Security Hub original pasó a llamarse **AWS Security Hub CSPM** y salió un **nuevo AWS Security Hub** que correlaciona señales. La guía sigue diciendo "AWS Security Hub": quédate con **vista central de la postura y los hallazgos**. Más en [Seguridad de logging y detección](../../../cloud/seguridad/seguridad-logging-deteccion.md#deteccion).

Recursos: **AWS Marketplace** (software de seguridad de terceros pagado en tu factura de AWS), **AWS Security Center** y **Security Blog**, **AWS Knowledge Center** (hoy en **AWS re:Post**) y **AWS Security Bulletins**.

!!! tip "En el examen"
    - **GuardDuty vs Inspector**: GuardDuty mira **comportamiento** (amenazas en curso); Inspector mira **software vulnerable** (CVE).
    - **WAF vs Shield**: WAF filtra peticiones HTTP maliciosas (capa 7); Shield protege contra DDoS. "SQL injection" → WAF.
    - **Shield Standard** es gratuito y ya está activo; "equipo de respuesta DDoS 24/7" o "protección de costos durante un ataque" → **Shield Advanced**.
    - "Comprar una solución de seguridad de un proveedor externo" → **AWS Marketplace**.

## Casos de uso

1. Un auditor pide el informe PCI DSS de AWS → **AWS Artifact**.
2. Saber quién borró una tabla de DynamoDB → **CloudTrail**.
3. Alertas si una instancia habla con IPs de botnets → **GuardDuty**.
4. Localizar datos de pacientes guardados por error en S3 → **Macie**.
5. Inyección SQL en una web detrás de CloudFront → **AWS WAF** con reglas gestionadas.
6. 40 cuentas y login con el usuario corporativo de Entra ID → **IAM Identity Center** federado.
7. Lambda que necesita la contraseña de RDS rotada cada 30 días → **Secrets Manager** + execution role.
8. Un panel con hallazgos de GuardDuty, Inspector y Macie de todas las cuentas → **Security Hub** con administrador delegado.
9. Detectar el puerto 22 abierto a internet sin instalar nada → **Trusted Advisor** o una regla de **Config**.

## Preguntas de práctica

**1.** Según el AWS shared responsibility model, ¿cuál de estas tareas es responsabilidad del cliente cuando usa Amazon EC2?

- A. Mantener la seguridad física de los datacenters
- B. Parchear el sistema operativo invitado
- C. Reemplazar discos defectuosos del host
- D. Actualizar el hipervisor

??? success "Respuesta"
    **B.** En EC2 (IaaS) el sistema operativo es tuyo. A, C y D son infraestructura física y de virtualización: responsabilidad de AWS.

**2.** ¿Qué servicio permite descargar los informes SOC de AWS para entregarlos a un auditor?

- A. AWS Trusted Advisor
- B. AWS Security Hub
- C. AWS Artifact
- D. Amazon Inspector

??? success "Respuesta"
    **C.** Artifact es el portal de informes y acuerdos de cumplimiento. A da recomendaciones; B centraliza hallazgos de tus cuentas; D busca vulnerabilidades en tus recursos.

**3.** ¿Cuáles DOS acciones son buenas prácticas para proteger el usuario root? (Elige dos.)

- A. Activar MFA
- B. Crear access keys para el root y guardarlas en un lugar seguro
- C. Usar el root para las tareas administrativas diarias
- D. Crear identidades administrativas separadas para el trabajo diario
- E. Compartir la contraseña del root con el equipo de operaciones

??? success "Respuesta"
    **A y D.** B va contra la recomendación de no tener access keys del root. C y E aumentan el riesgo y eliminan la trazabilidad individual.

**4.** Una aplicación en EC2 necesita escribir objetos en un bucket S3. ¿Cuál es la forma MÁS segura de darle permisos?

- A. Guardar access keys de un IAM user en un archivo de la instancia
- B. Asignar un IAM role a la instancia con una política que solo permita escribir en ese bucket
- C. Hacer público el bucket
- D. Usar las credenciales del root user

??? success "Respuesta"
    **B.** El rol entrega credenciales temporales y la política aplica least privilege. A expone credenciales de larga duración; C abre los datos a cualquiera; D es la peor práctica posible.

**5.** ¿Qué servicio analiza de forma continua las instancias EC2 y las imágenes de contenedor en Amazon ECR en busca de vulnerabilidades de software conocidas?

- A. Amazon GuardDuty
- B. Amazon Inspector
- C. Amazon Macie
- D. AWS Shield

??? success "Respuesta"
    **B.** Inspector escanea CVE en EC2, ECR y Lambda. A detecta amenazas por comportamiento; C busca datos sensibles en S3; D protege contra DDoS.

**6.** ¿Qué servicio registra el historial de cambios de configuración de los recursos y evalúa si cumplen reglas definidas?

- A. AWS CloudTrail
- B. AWS Config
- C. Amazon CloudWatch
- D. AWS Artifact

??? success "Respuesta"
    **B.** Config guarda el estado de configuración en el tiempo y lo evalúa con Config rules. A registra llamadas a la API (quién hizo qué); C métricas, logs y alarmas; D informes de cumplimiento de AWS.

**7.** Una empresa quiere protección DDoS avanzada con acceso 24/7 a un equipo especializado de AWS durante los ataques. ¿Qué debe usar?

- A. AWS Shield Standard
- B. AWS Shield Advanced
- C. AWS WAF
- D. Amazon GuardDuty

??? success "Respuesta"
    **B.** Shield Advanced incluye el Shield Response Team y protección de costos. A es gratuito y automático, pero sin equipo dedicado; C filtra peticiones web pero no es un servicio DDoS completo; D detecta amenazas, no mitiga DDoS.

## Para profundizar

- [Shared Responsibility Model](../../../cloud/fundamentos/responsabilidad-compartida.md): tabla por capas y diferencias entre proveedores.
- [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md): usuarios, roles, políticas y buenas prácticas.
- [Fundamentos de seguridad cloud](../../../cloud/seguridad/fundamentos-seguridad-cloud.md): cifrado, KMS, secretos, WAF, detección de amenazas y logs de auditoría.
- [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md): multi-cuenta, SCPs y cuentas centrales de logs y seguridad.
- [Cumplimiento y gobierno](../../../devsecops/gobierno-y-respuesta/cumplimiento.md): ISO 27001, SOC 2, CIS y CSPM.
- [Detección y respuesta](../../../devsecops/gobierno-y-respuesta/deteccion-respuesta.md): qué hacer con los hallazgos.

## Referencias

- [Exam guide CLF-C02: Domain 2](https://docs.aws.amazon.com/aws-certification/latest/cloud-practitioner-02/cloud-practitioner-02-domain2.html)
- [Shared Responsibility Model (AWS)](https://aws.amazon.com/compliance/shared-responsibility-model/)
- [AWS Artifact](https://docs.aws.amazon.com/artifact/latest/ug/what-is-aws-artifact.html)
- [Tasks that require root user credentials](https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-tasks.html)
- [Security best practices in IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Compliance Programs](https://aws.amazon.com/compliance/programs/)
