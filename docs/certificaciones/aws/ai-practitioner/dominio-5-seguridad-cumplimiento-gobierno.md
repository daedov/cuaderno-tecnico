---
tags:
  - aws
  - certificacion
  - aif-c01
  - ia
  - seguridad
  - cumplimiento
---

# Dominio 5: Security, Compliance, and Governance for AI Solutions (14%)

> Cómo se protege un sistema de IA en AWS (identidad, cifrado, red, guardrails, agentes), cómo se controlan las alucinaciones y la fuga de datos, y qué servicios y marcos ayudan a gobernarlo y cumplir normas.

!!! info "Qué evalúa este dominio"
    - **5.1 Asegurar sistemas de IA**: IAM (roles, políticas, permisos), cifrado, **Amazon Macie**, **AWS PrivateLink**, Shared Responsibility Model, **Bedrock AgentCore Identity**, **Policy in AgentCore**, **Bedrock Guardrails**; citación de fuentes y linaje de datos (**SageMaker Model Cards**); ingeniería de datos segura; consideraciones de seguridad y privacidad (prompt injection, fuga de datos, filtrado de salidas, registros de auditoría, toxicidad); detección de alucinaciones y *grounding*.
    - **5.2 Gobierno y cumplimiento**: **AWS Config**, **Amazon Inspector**, **AWS Artifact**, **AWS CloudTrail**, **AWS Trusted Advisor**; estrategias de gobierno de datos (ciclo de vida, logs, residencia, monitoreo, retención); procesos de gobierno (políticas, revisiones, **Generative AI Security Scoping Matrix**, estándares de transparencia, formación).

    Volver al [resumen del examen](resumen-examen.md).

Lo general de seguridad en AWS (IAM, cifrado, CloudTrail, Config, Artifact, Inspector, Macie) se explica en [Cloud Practitioner, Dominio 2](../cloud-practitioner/dominio-2-seguridad-cumplimiento.md). Aquí solo va lo específico de IA. Los controles equivalentes en Azure y Google Cloud están en [Seguridad de servicios de IA generativa](../../../cloud/seguridad/seguridad-servicios-ia.md).

## Responsabilidad compartida en IA

El modelo general está en [Shared Responsibility Model (CLF)](../cloud-practitioner/dominio-2-seguridad-cumplimiento.md#shared-responsibility-model). En IA: AWS opera la infraestructura, Bedrock y los servicios de IA gestionados; **tú** respondes de quién invoca modelos y accede a datos (IAM), la configuración del cifrado (KMS), los datos de entrenamiento y de RAG, los prompts, los guardrails y la validación de salidas. En instancias o endpoints que gestionas (EC2, endpoints de SageMaker AI), además el sistema operativo, las imágenes y las dependencias.

Cuanto más gestionado es el servicio (Bedrock frente a un modelo propio en EC2), menos responsabilidad operativa tienes, pero **datos, identidades y configuración siempre son tuyos**.

## Servicios para asegurar sistemas de IA

Para qué sirve cada servicio de seguridad general: ver [Servicios que hay que distinguir (CLF)](../cloud-practitioner/dominio-2-seguridad-cumplimiento.md#servicios-que-hay-que-distinguir). Lo que aportan a un sistema de IA:

| Servicio o función | Qué aporta a la seguridad de IA |
| --- | --- |
| **AWS IAM** | Permisos mínimos para invocar modelos (`bedrock:InvokeModel` sobre modelos concretos), acceder a buckets de datos y gestionar endpoints. Roles de servicio para Knowledge Bases, agentes y entrenamiento |
| **AWS KMS** | *Customer managed keys* para datos de entrenamiento, modelos personalizados, Knowledge Bases y logs (TLS cifra en tránsito) |
| **Amazon Macie** | Descubre **PII en S3** antes de usar los datos para entrenar o para RAG |
| **AWS PrivateLink** (VPC interface endpoints) | Llamar a Bedrock o SageMaker AI **desde tu VPC sin pasar por internet**; entrenamiento y endpoints en subredes privadas de **Amazon VPC** |
| **AWS Secrets Manager** | Credenciales de bases vectoriales externas o APIs que usan los agentes |
| **Amazon Bedrock Guardrails** | Contenido dañino, ataques de prompt, PII y respuestas no fundamentadas (ver [Dominio 4](dominio-4-ia-responsable.md#amazon-bedrock-guardrails)) |
| **Bedrock AgentCore Identity** | Identidad propia de cada agente y gestión de credenciales para actuar **en nombre del usuario**, compatible con proveedores existentes (Cognito, Okta, Microsoft Entra ID…) |
| **Policy in AgentCore** | Reglas **deterministas** sobre qué herramientas puede usar un agente y con qué condiciones; se evalúan en AgentCore Gateway antes de cada llamada (lenguaje compatible con Cedar) |
| **Amazon Inspector** | Vulnerabilidades en EC2, imágenes de contenedor y Lambda de la solución |

!!! tip "En el examen"
    - "Encontrar PII en los datos de entrenamiento en S3" → **Macie**.
    - "Acceder a Bedrock sin tráfico por internet" → **PrivateLink / VPC endpoint**.
    - "Controlar con llaves propias el cifrado" → **KMS** con *customer managed key*.
    - "Limitar qué herramientas puede ejecutar un agente" → **Policy in AgentCore** (y permisos mínimos de IAM).
    - **GuardDuty, Security Hub, WAF y Shield están fuera de alcance** de este examen; no suelen ser la respuesta.

## Origen de los datos e ingeniería de datos segura

- **Source citation**: Bedrock Knowledge Bases devuelve **citas** con la referencia al chunk y al documento de origen.
- **Data lineage** (linaje): de dónde viene cada dato, qué transformaciones sufrió y qué modelos lo usaron ("¿con qué se entrenó este modelo?"). **Data cataloging**: **AWS Glue Data Catalog**, Amazon SageMaker Catalog. **SageMaker Model Cards** documentan datos, uso previsto y evaluación.

| Práctica | En qué consiste |
| --- | --- |
| **Assessing data quality** | Completitud, exactitud y consistencia antes de entrenar (Glue DataBrew, Data Wrangler) |
| **Privacy-enhancing technologies** (PETs) | **Anonymization**, **pseudonymization** (seudonimización), **masking**, **tokenization**, **differential privacy** (ruido estadístico para no identificar personas) |
| **Data access control** | Permisos mínimos; control fino por tabla, columna o fila con **AWS Lake Formation** |
| **Data integrity** | Versionado de S3, checksums, registro de cambios; protege contra *data poisoning* |

## Consideraciones de seguridad y privacidad

Los sistemas de GenAI heredan los riesgos de cualquier aplicación y suman los propios; la referencia es el **OWASP Top 10 for LLM Applications** (detalle y ejemplos en [Riesgos típicos](../../../cloud/seguridad/seguridad-servicios-ia.md#riesgos-tipicos)).

| Riesgo | Controles en AWS |
| --- | --- |
| **Prompt injection** (directa o indirecta) | Guardrails (filtro *prompt attack*), separar instrucciones de datos, permisos mínimos para herramientas, revisión humana de acciones sensibles |
| **Data leakage** (fuga de datos) | Filtros de información sensible, filtros de metadatos por documento en RAG, sin secretos en prompts, Macie en los datos de origen |
| **Output filtering and validation** | Tratar la salida como **entrada no confiable**: Guardrails sobre la salida, esquemas JSON, nunca ejecutar código o SQL generado sin control |
| **Toxicity** | Content filters de Guardrails, evaluación de toxicidad antes de elegir modelo |
| **Audit trail and logging** | **CloudTrail** (llamadas a la API de Bedrock), **model invocation logging** (prompts y respuestas a CloudWatch Logs o S3), trazas de AgentCore Observability |
| **Encryption** y **vulnerability management** | KMS y TLS; Amazon Inspector |

!!! warning "Los logs de prompts también son datos sensibles"
    Si activas el *model invocation logging*, los prompts y respuestas quedan guardados: pueden contener PII. Cifra esos logs con KMS, restringe quién puede leerlos y define su retención.

## Alucinaciones: detección y grounding

Una **hallucination** es una respuesta plausible pero falsa o no respaldada. No se elimina del todo, pero se reduce y se detecta:

- **RAG grounding** y **citas**: la respuesta se basa en documentos recuperados y el usuario puede verificar la fuente.
- **Contextual grounding check** y **Automated Reasoning checks** de Guardrails (ver [Dominio 4](dominio-4-ia-responsable.md#amazon-bedrock-guardrails)).
- **Output validation** contra sistemas de registro, esquemas y reglas de negocio; **confidence scoring** para responder, pedir aclaración o derivar a una persona.
- **Prompt engineering** ("si no está en el contexto, di que no lo sabes") y **temperatura baja** (ayuda, pero no basta).

## Servicios de gobierno y cumplimiento

| Servicio | Ejemplo en IA |
| --- | --- |
| **AWS CloudTrail** | Auditar quién creó un modelo personalizado o invocó un modelo |
| **AWS Config** | Detectar un endpoint de SageMaker AI sin cifrado o un bucket de datos público |
| **Amazon Inspector** | CVEs en contenedores de inferencia |
| **AWS Artifact** | Entregar al auditor el informe SOC 2 de AWS |
| **AWS Trusted Advisor** | Detectar permisos o recursos expuestos |
| **Amazon CloudWatch** | Invocaciones, latencia, errores y tokens de Bedrock |
| **AWS Well-Architected Tool** | Revisión de una app de GenAI (incluye lentes de ML y GenAI) |

!!! tip "En el examen: no confundas"
    **CloudTrail** = quién llamó a la API. **Config** = cómo está configurado el recurso y si cumple reglas. **Artifact** = descargar informes de cumplimiento **de AWS**. **Inspector** = vulnerabilidades. **Trusted Advisor** = recomendaciones generales.

## Gobierno de datos

**Data lifecycle** (S3 Lifecycle, S3 Glacier), **logging** (CloudTrail, model invocation logging, CloudWatch Logs), **residency** (elegir región; cuidado con *cross-Region inference*), **monitoring** (CloudWatch, Model Monitor, AgentCore Observability) y **retention** (políticas de retención de CloudWatch Logs y S3: requisito legal frente a costo y riesgo).

## Procesos y marcos de gobierno

- **Policies**: uso aceptable de IA, datos permitidos, modelos aprobados.
- **Review cadence** y **review strategies**: revisar modelos, prompts y guardrails periódicamente y ante cambios; revisiones técnicas, legales y éticas.
- **Transparency standards** (Model Cards, avisar de que es una IA) y **team training requirements**.
- **Marcos**: además de ISO 27001, SOC 2 y NIST CSF, existen **ISO/IEC 42001** (sistema de gestión de IA), el **NIST AI Risk Management Framework** y el **EU AI Act**.

### Generative AI Security Scoping Matrix

Marco de AWS que clasifica una solución de GenAI en **cinco alcances** según cuánto control tienes sobre el modelo y los datos. A más número, más responsabilidad de seguridad tuya.

| Alcance | Qué es | Ejemplo | Tu responsabilidad principal |
| --- | --- | --- | --- |
| **1. Consumer app** | Usar una app pública de GenAI | Un chatbot público de terceros | Política de uso: qué datos pueden introducir los empleados |
| **2. Enterprise app** | App empresarial de terceros con GenAI integrada | Un SaaS con funciones de IA, Amazon Quick | Contrato, términos de uso de datos, configuración de acceso |
| **3. Pre-trained models** | Tu app sobre un FM existente sin modificarlo | App propia sobre Bedrock con RAG | Seguridad de la app, prompts, datos de RAG, guardrails |
| **4. Fine-tuned models** | Ajustar un FM con tus datos | Modelo personalizado en Bedrock o SageMaker AI | Lo anterior + datos de entrenamiento y acceso al modelo resultante |
| **5. Self-trained models** | Entrenar un modelo desde cero | Modelo propio en SageMaker AI | Todo: datos, entrenamiento, modelo e infraestructura |

!!! tip "En el examen"
    "Construyen un chatbot con Bedrock y RAG sin modificar el modelo" → **alcance 3**. "Ajustan el modelo con datos propios" → **alcance 4**. "Los empleados usan una herramienta pública de IA" → **alcance 1**.

## Casos de uso

1. Saber si miles de documentos en S3 tienen datos personales antes de crear una Knowledge Base → **Amazon Macie**.
2. Tráfico hacia Bedrock que no debe salir a internet → **interface VPC endpoint (PrivateLink)**.
3. El auditor pide los informes SOC 2 e ISO 27001 de AWS → **AWS Artifact**.
4. Quién creó un trabajo de fine-tuning el viernes por la noche → **AWS CloudTrail**.
5. Detectar endpoints de SageMaker AI sin cifrado con KMS → reglas de **AWS Config**.
6. Un agente que consulta pedidos pero nunca emite reembolsos de más de 100 USD → **Policy in AgentCore** + permisos mínimos y aprobación humana para excepciones.
7. Un asistente de RAG que inventa condiciones contractuales → **contextual grounding check**, citas y validación de salidas.
8. Conservar un año los prompts y respuestas del chatbot → **model invocation logging** a S3 o CloudWatch Logs, con KMS y retención configurada.

## Preguntas de práctica

**1.** Una empresa quiere descubrir automáticamente información personal identificable en los buckets de S3 que usará para entrenar un modelo. ¿Qué servicio usa?

- A. Amazon Inspector
- B. Amazon Macie
- C. AWS Artifact
- D. AWS Trusted Advisor

??? success "Respuesta"
    **B.** Macie descubre y clasifica datos sensibles en S3. A busca vulnerabilidades. C entrega informes de cumplimiento de AWS. D da recomendaciones generales.

**2.** ¿Qué servicio registra las llamadas a la API de Amazon Bedrock para auditar quién hizo cada acción?

- A. AWS CloudTrail
- B. AWS Config
- C. Amazon Inspector
- D. Amazon Polly

??? success "Respuesta"
    **A.** CloudTrail registra la actividad de la API. B registra configuración de recursos. C escanea vulnerabilidades. D es texto a voz.

**3.** Una empresa construye una aplicación propia que usa un FM de Amazon Bedrock con RAG, sin modificar el modelo. Según la Generative AI Security Scoping Matrix, ¿en qué alcance está?

- A. Alcance 1: Consumer app
- B. Alcance 3: Pre-trained models
- C. Alcance 4: Fine-tuned models
- D. Alcance 5: Self-trained models

??? success "Respuesta"
    **B.** App propia sobre un FM sin modificarlo es el alcance 3. A es usar una app pública de terceros. C implica ajustar el modelo. D, entrenarlo desde cero.

**4.** (Elige dos) ¿Qué medidas reducen el riesgo de que una respuesta de GenAI incluya información no respaldada por las fuentes?

- A. Contextual grounding checks de Bedrock Guardrails
- B. Aumentar la temperatura
- C. RAG con citas a los documentos de origen
- D. Desactivar CloudTrail
- E. Usar un endpoint serverless

??? success "Respuesta"
    **A y C.** El grounding check y el RAG con citas atacan directamente las alucinaciones. B las aumenta. D y E no tienen relación.

**5.** Un equipo necesita que su aplicación en una subred privada llame a Amazon Bedrock sin pasar por internet. ¿Qué configura?

- A. Un NAT gateway
- B. Un interface VPC endpoint con AWS PrivateLink
- C. Una IP pública en cada instancia
- D. Amazon CloudFront

??? success "Respuesta"
    **B.** PrivateLink da conectividad privada a servicios de AWS. A y C salen a internet. D es una CDN.

**6.** ¿Qué afirmación sobre el Shared Responsibility Model en Amazon Bedrock es correcta?

- A. AWS es responsable de decidir qué usuarios de tu cuenta pueden invocar modelos
- B. El cliente es responsable de la seguridad física de los centros de datos
- C. El cliente es responsable de los permisos de IAM y de los datos que envía en los prompts
- D. AWS es responsable de configurar los guardrails de tu aplicación

??? success "Respuesta"
    **C.** Identidades, datos y configuración son del cliente. A y D son configuración del cliente. B es responsabilidad de AWS.

**7.** El área de cumplimiento quiere comprobar de forma continua que todos los buckets con datos de entrenamiento tienen cifrado y bloqueo de acceso público. ¿Qué servicio encaja mejor?

- A. AWS Config
- B. AWS Artifact
- C. Amazon Comprehend
- D. Amazon Lex

??? success "Respuesta"
    **A.** Config evalúa la configuración de recursos con reglas de forma continua. B da informes de AWS, no de tus recursos. C y D son servicios de IA.

## Para profundizar

| Tema | Nota del cuaderno |
| --- | --- |
| Seguridad general de AWS para el examen | [Cloud Practitioner, Dominio 2](../cloud-practitioner/dominio-2-seguridad-cumplimiento.md) |
| Controles de IA en AWS, Azure y GCP | [Seguridad de servicios de IA generativa](../../../cloud/seguridad/seguridad-servicios-ia.md) |
| Identidades, cifrado y logs de auditoría | [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md), [Seguridad de cifrado y secretos](../../../cloud/seguridad/seguridad-cifrado-secretos.md), [Seguridad de logging y detección](../../../cloud/seguridad/seguridad-logging-deteccion.md) |
| Conectividad privada | [Redes en la nube](../../../cloud/redes-y-datos/redes.md) |
| Marcos de cumplimiento y gobierno | [Cumplimiento y gobierno](../../../devsecops/gobierno-y-respuesta/cumplimiento.md), [Gobernanza en la nube](../../../cloud/operacion-y-gobierno/gobernanza.md) |
| Dominio anterior | [Dominio 4](dominio-4-ia-responsable.md) · [Resumen del examen](resumen-examen.md) |

## Referencias

- [Exam guide AIF-C01 – Domain 5](https://docs.aws.amazon.com/aws-certification/latest/ai-practitioner-01/ai-practitioner-01-domain5.html)
- [Seguridad en Amazon Bedrock](https://docs.aws.amazon.com/bedrock/latest/userguide/security.html)
- [Model invocation logging en Bedrock](https://docs.aws.amazon.com/bedrock/latest/userguide/model-invocation-logging.html)
- [Bedrock con interface VPC endpoints (PrivateLink)](https://docs.aws.amazon.com/bedrock/latest/userguide/vpc-interface-endpoints.html)
- [Generative AI Security Scoping Matrix](https://aws.amazon.com/ai/generative-ai/security/scoping-matrix/)
- [OWASP Top 10 for LLM Applications](https://genai.owasp.org/llm-top-10/)
