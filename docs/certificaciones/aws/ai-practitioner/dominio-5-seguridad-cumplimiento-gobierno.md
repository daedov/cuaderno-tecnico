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

## Responsabilidad compartida en IA

El [Shared Responsibility Model](../../../cloud/fundamentos/responsabilidad-compartida.md) también aplica a la IA: AWS protege la infraestructura y los servicios gestionados ("seguridad **de** la nube"); tú proteges lo que pones y configuras ("seguridad **en** la nube").

| Responsabilidad | AWS | Tú |
| --- | --- | --- |
| Infraestructura física, hipervisor, red global | Sí | — |
| Operar y parchear Bedrock y los servicios de IA gestionados | Sí | — |
| Quién puede invocar modelos y acceder a datos (IAM) | — | Sí |
| Cifrado y gestión de llaves propias (KMS) | Ofrece el servicio | Configurarlo |
| Datos de entrenamiento, documentos de RAG y su clasificación | — | Sí |
| Prompts, guardrails, validación de salidas | — | Sí |
| Instancias y contenedores que gestionas (EC2, endpoints de SageMaker AI) | Hardware | Sistema operativo, imágenes, dependencias |

Cuanto más gestionado es el servicio (Bedrock frente a un modelo propio en EC2), menos responsabilidad operativa tienes, pero **datos, identidades y configuración siempre son tuyos**.

## Servicios para asegurar sistemas de IA

| Servicio o función | Qué aporta a la seguridad de IA |
| --- | --- |
| **AWS IAM** | Roles con permisos mínimos para invocar modelos (`bedrock:InvokeModel` sobre modelos concretos), acceder a buckets de datos y gestionar endpoints. Roles de servicio para Knowledge Bases, agentes y trabajos de entrenamiento |
| **AWS KMS** | Cifrado en reposo con llaves gestionadas por el cliente (*customer managed keys*) para datos de entrenamiento, modelos personalizados, Knowledge Bases y logs |
| **TLS** | Cifrado en tránsito en todas las APIs de AWS |
| **Amazon Macie** | Descubre y clasifica **datos sensibles (PII) en S3** con ML, antes de usarlos para entrenar o para RAG |
| **AWS PrivateLink** (VPC interface endpoints) | Llamar a Bedrock o SageMaker AI **desde tu VPC sin pasar por internet** |
| **Amazon VPC** | Aislar trabajos de entrenamiento y endpoints en subredes privadas |
| **AWS Secrets Manager** | Guardar credenciales de bases vectoriales externas o APIs que usan los agentes |
| **Amazon Bedrock Guardrails** | Filtrar contenido dañino, ataques de prompt, PII y respuestas no fundamentadas |
| **Bedrock AgentCore Identity** | Identidad propia de cada agente y gestión de credenciales para que actúe en otros servicios **en nombre del usuario**, compatible con proveedores de identidad existentes (Cognito, Okta, Microsoft Entra ID…) |
| **Policy in AgentCore** | Reglas **deterministas** sobre qué herramientas puede usar un agente y con qué condiciones; se evalúan en AgentCore Gateway antes de ejecutar cada llamada (lenguaje compatible con Cedar) |
| **Amazon Inspector** | Escaneo de vulnerabilidades en instancias EC2, imágenes de contenedor y funciones Lambda que forman parte de la solución |

!!! tip "En el examen"
    - "Encontrar PII en los datos de entrenamiento en S3" → **Macie**.
    - "Acceder a Bedrock sin tráfico por internet" → **PrivateLink / VPC endpoint**.
    - "Controlar con llaves propias el cifrado" → **KMS** con *customer managed key*.
    - "Limitar qué herramientas puede ejecutar un agente" → **Policy in AgentCore** (y permisos mínimos de IAM).
    - **GuardDuty, Security Hub, WAF y Shield están fuera de alcance** de este examen; no suelen ser la respuesta.

Para el detalle de IAM, cifrado y secretos en AWS, ver [IAM: AWS, Azure y GCP](../../../cloud/identidad-y-seguridad/iam-comparativa.md) y [Seguridad base](../../../cloud/identidad-y-seguridad/seguridad-base.md).

## Origen de los datos y citación de fuentes

- **Source citation** (citación de fuentes): que la respuesta indique de qué documento sale. Bedrock Knowledge Bases devuelve **citas** con la referencia al chunk y al documento de origen.
- **Data lineage** (linaje de datos): registrar de dónde viene cada dato, qué transformaciones sufrió y qué modelos lo usaron. Permite auditar y responder "¿con qué se entrenó este modelo?".
- **Data cataloging** (catalogación): inventario de datasets con su esquema, dueño y clasificación (**AWS Glue Data Catalog**, Amazon SageMaker Catalog).
- **SageMaker Model Cards**: documentan datos de entrenamiento, uso previsto y evaluación de cada modelo.

## Ingeniería de datos segura

| Práctica | En qué consiste |
| --- | --- |
| **Assessing data quality** (evaluar calidad) | Validar completitud, exactitud y consistencia antes de entrenar (AWS Glue DataBrew, Data Wrangler) |
| **Privacy-enhancing technologies** (tecnologías de mejora de la privacidad, PETs) | **Anonymization** (anonimización), **pseudonymization** (seudonimización), **masking** (enmascaramiento), **tokenization**, **differential privacy** (privacidad diferencial: añadir ruido estadístico para no identificar personas) |
| **Data access control** | Permisos mínimos; control fino por tabla, columna o fila con **AWS Lake Formation** |
| **Data integrity** (integridad) | Evitar modificaciones no autorizadas: versionado de S3, checksums, registro de cambios; protege contra *data poisoning* |

## Consideraciones de seguridad y privacidad

Los sistemas de GenAI heredan los riesgos de cualquier aplicación (seguridad de aplicación, gestión de vulnerabilidades, protección de infraestructura, detección de amenazas) y suman riesgos propios. La referencia del sector es el **OWASP Top 10 for LLM Applications**.

| Riesgo | Qué es | Controles en AWS |
| --- | --- | --- |
| **Prompt injection** (directa o indirecta) | Instrucciones maliciosas en la entrada del usuario o en documentos/webs que procesa el modelo | Guardrails (filtro *prompt attack*), separar instrucciones de datos, permisos mínimos para herramientas, revisión humana de acciones sensibles |
| **Data leakage** (fuga de datos) | El modelo revela datos de otros usuarios, del system prompt o de la base de conocimiento | Filtros de información sensible, control de acceso por documento (filtros de metadatos en RAG), no poner secretos en prompts, Macie en los datos de origen |
| **Output filtering and validation** | Tratar la salida del modelo como **entrada no confiable**: validar formato, rango y contenido antes de usarla o ejecutarla | Guardrails sobre la salida, validación en el código (esquemas JSON), nunca ejecutar código o SQL generado sin control |
| **Toxicity** (toxicidad) | Contenido ofensivo, de odio o violento | Content filters de Guardrails, evaluación de toxicidad antes de elegir el modelo |
| **Audit trail and logging** (registro de auditoría) | Saber quién invocó qué modelo, con qué prompt y qué respondió | **CloudTrail** (llamadas a la API de Bedrock), **model invocation logging** de Bedrock (prompts y respuestas a CloudWatch Logs o S3), trazas de AgentCore Observability |
| **Encryption at rest and in transit** | Datos y modelos cifrados | KMS y TLS |
| **Vulnerability management** | Dependencias y sistemas operativos con fallos conocidos | Amazon Inspector |

!!! warning "Los logs de prompts también son datos sensibles"
    Si activas el *model invocation logging*, los prompts y respuestas quedan guardados: pueden contener PII. Cifra esos logs con KMS, restringe quién puede leerlos y define su retención.

## Alucinaciones: detección y grounding

Una **hallucination** (alucinación) es una respuesta plausible pero falsa o no respaldada. No se elimina del todo, pero se reduce y se detecta:

| Técnica | Cómo ayuda |
| --- | --- |
| **RAG grounding** | La respuesta se basa en documentos recuperados, no solo en la memoria del modelo |
| **Contextual grounding check** (Guardrails) | Puntúa si la respuesta está respaldada por la fuente y es relevante para la pregunta; bloquea o marca las que no |
| **Automated Reasoning checks** (Guardrails) | Verifica la respuesta contra reglas lógicas formales (por ejemplo, una política de RR. HH.) |
| **Output validation** | Comprobar datos contra sistemas de registro (precio real en la base de datos), esquemas y reglas de negocio |
| **Confidence scoring** (puntuación de confianza) | Usar puntuaciones de relevancia o de grounding para decidir si responder, pedir aclaración o derivar a una persona |
| **Citas** | El usuario puede verificar la fuente |
| **Prompt engineering** | Pedir "responde solo con el contexto dado; si no está, di que no lo sabes" |
| **Temperatura baja** | Respuestas más conservadoras (ayuda, pero no basta) |

## Servicios de gobierno y cumplimiento

| Servicio | Qué hace | Ejemplo en IA |
| --- | --- | --- |
| **AWS CloudTrail** | Registra **quién hizo qué llamada a la API**, cuándo y desde dónde | Auditar quién creó un modelo personalizado o invocó un modelo |
| **AWS Config** | Registra la **configuración** de los recursos y evalúa reglas de cumplimiento | Detectar un endpoint de SageMaker AI sin cifrado o un bucket de datos público |
| **Amazon Inspector** | Escaneo continuo de **vulnerabilidades** | CVEs en contenedores de inferencia |
| **AWS Artifact** | Portal de **informes de cumplimiento de AWS** (SOC, ISO, PCI) y acuerdos | Entregar al auditor el informe SOC 2 de AWS |
| **AWS Trusted Advisor** | Recomendaciones de buenas prácticas (costo, seguridad, rendimiento, límites) | Detectar permisos o recursos expuestos |
| **Amazon CloudWatch** | Métricas, logs y alarmas | Invocaciones, latencia, errores y tokens de Bedrock |
| **AWS Well-Architected Tool** | Revisar una carga contra el marco Well-Architected (incluye lentes de ML y GenAI) | Revisión de arquitectura de una app de GenAI |

!!! tip "En el examen: no confundas"
    **CloudTrail** = quién llamó a la API. **Config** = cómo está configurado el recurso y si cumple reglas. **Artifact** = descargar informes de cumplimiento **de AWS**. **Inspector** = vulnerabilidades. **Trusted Advisor** = recomendaciones generales.

Para el detalle de auditoría continua y CSPM, ver [Cumplimiento y gobierno](../../../devsecops/gobierno-y-respuesta/cumplimiento.md) y [Gobernanza en la nube](../../../cloud/operacion-y-gobierno/gobernanza.md).

## Gobierno de datos

| Estrategia | Qué decide | En AWS |
| --- | --- | --- |
| **Data lifecycle** (ciclo de vida) | Desde la creación hasta el borrado: clasificar, usar, archivar, eliminar | S3 Lifecycle, S3 Glacier |
| **Logging** | Qué se registra (acceso, invocaciones, cambios) | CloudTrail, model invocation logging, CloudWatch Logs |
| **Residency** (residencia) | En qué país o región pueden estar y procesarse los datos | Elegir región; cuidado con *cross-Region inference* |
| **Monitoring** y **observation** | Vigilar uso, calidad, drift y abusos | CloudWatch, Model Monitor, AgentCore Observability |
| **Retention** (retención) | Cuánto tiempo se guardan datos y logs (requisito legal vs costo y riesgo) | Políticas de retención de CloudWatch Logs y S3 |

## Procesos y marcos de gobierno

- **Policies** (políticas): uso aceptable de IA, qué datos pueden usarse, qué modelos están aprobados.
- **Review cadence** (frecuencia de revisión) y **review strategies**: revisar modelos, prompts y guardrails periódicamente y ante cambios (nuevo modelo, nueva fuente de datos); revisiones técnicas, legales y éticas.
- **Transparency standards**: documentar con Model Cards, avisar a los usuarios de que interactúan con una IA.
- **Team training requirements** (formación): que quien construye y usa IA conozca sus riesgos y las políticas.
- **Marcos de referencia**: además de los de seguridad generales (ISO 27001, SOC 2, NIST CSF), existen marcos de IA como **ISO/IEC 42001** (sistema de gestión de IA), el **NIST AI Risk Management Framework** y regulaciones como el **EU AI Act**.

### Generative AI Security Scoping Matrix

Marco de AWS que clasifica una solución de GenAI en **cinco alcances** según cuánto control tienes sobre el modelo y los datos. A más número, más responsabilidad de seguridad tuya.

| Alcance | Qué es | Ejemplo | Tu responsabilidad principal |
| --- | --- | --- | --- |
| **1. Consumer app** | Usar una app pública de GenAI | Un chatbot público de terceros | Política de uso: qué datos pueden introducir los empleados |
| **2. Enterprise app** | App empresarial de terceros con GenAI integrada | Un SaaS con funciones de IA, Amazon Quick | Contrato, términos de uso de datos, configuración de acceso |
| **3. Pre-trained models** | Construir tu app sobre un FM existente sin modificarlo | App propia sobre Bedrock con RAG | Seguridad de la app, prompts, datos de RAG, guardrails |
| **4. Fine-tuned models** | Ajustar un FM con tus datos | Modelo personalizado en Bedrock o SageMaker AI | Lo anterior + datos de entrenamiento y acceso al modelo resultante |
| **5. Self-trained models** | Entrenar un modelo desde cero | Modelo propio en SageMaker AI | Todo: datos, entrenamiento, modelo e infraestructura |

!!! tip "En el examen"
    "Construyen un chatbot con Bedrock y RAG sin modificar el modelo" → **alcance 3**. "Ajustan el modelo con datos propios" → **alcance 4**. "Los empleados usan una herramienta pública de IA" → **alcance 1**.

## Casos de uso

1. **Antes de crear una Knowledge Base con miles de documentos en S3, la empresa necesita saber si contienen datos personales.** → **Amazon Macie**.
2. **Una entidad financiera exige que el tráfico hacia Bedrock no salga a internet.** → **Interface VPC endpoint (AWS PrivateLink)** para Bedrock.
3. **El auditor pide los informes SOC 2 e ISO 27001 de AWS.** → **AWS Artifact**.
4. **Seguridad quiere saber quién creó un trabajo de fine-tuning el viernes por la noche.** → **AWS CloudTrail**.
5. **Hay que detectar automáticamente endpoints de SageMaker AI sin cifrado con KMS.** → Reglas de **AWS Config**.
6. **Un agente de soporte debe poder consultar pedidos pero nunca emitir reembolsos de más de 100 USD.** → **Policy in AgentCore** (más permisos mínimos en IAM y aprobación humana para excepciones).
7. **Un asistente de RAG a veces inventa condiciones contractuales.** → **Contextual grounding check** de Guardrails, citas y validación de salidas.
8. **Compliance necesita conservar registro de los prompts y respuestas del chatbot durante un año.** → **Model invocation logging** de Bedrock a S3 o CloudWatch Logs, cifrado con KMS y con retención configurada.

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
| Responsabilidad compartida | [Shared Responsibility Model](../../../cloud/fundamentos/responsabilidad-compartida.md) |
| Identidades, roles y permisos mínimos | [IAM: AWS, Azure y GCP](../../../cloud/identidad-y-seguridad/iam-comparativa.md), [Secretos e identidades](../../../devsecops/identidades-y-pipeline/secretos-identidades.md) |
| Cifrado, KMS, logs de auditoría y registro de configuración | [Seguridad base](../../../cloud/identidad-y-seguridad/seguridad-base.md) |
| Conectividad privada | [Redes en la nube](../../../cloud/redes-y-datos/redes.md) |
| Logs, métricas y alarmas | [Observabilidad nativa](../../../cloud/operacion-y-gobierno/observabilidad-nativa.md) |
| Marcos de cumplimiento y CSPM | [Cumplimiento y gobierno](../../../devsecops/gobierno-y-respuesta/cumplimiento.md), [CSPM](../../../devsecops/escaneos/cspm.md) |
| Gobierno, riesgo y proveedores | [Gobierno y riesgo de TI](../../../negocio/gobierno-riesgo-ti.md), [Gobernanza en la nube](../../../cloud/operacion-y-gobierno/gobernanza.md) |
| OWASP y threat modeling | [Fundamentos DevSecOps](../../../devsecops/fundamentos-devsecops.md) |
| Dominio anterior | [Dominio 4](dominio-4-ia-responsable.md) · [Resumen del examen](resumen-examen.md) |

## Referencias

- [Exam guide AIF-C01 – Domain 5](https://docs.aws.amazon.com/aws-certification/latest/ai-practitioner-01/ai-practitioner-01-domain5.html)
- [Seguridad en Amazon Bedrock](https://docs.aws.amazon.com/bedrock/latest/userguide/security.html)
- [Model invocation logging en Bedrock](https://docs.aws.amazon.com/bedrock/latest/userguide/model-invocation-logging.html)
- [Bedrock con interface VPC endpoints (PrivateLink)](https://docs.aws.amazon.com/bedrock/latest/userguide/vpc-interface-endpoints.html)
- [Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/what-is-bedrock-agentcore.html)
- [Generative AI Security Scoping Matrix](https://aws.amazon.com/ai/generative-ai/security/scoping-matrix/)
- [Amazon Macie](https://docs.aws.amazon.com/macie/latest/user/what-is-macie.html)
- [AWS Artifact](https://docs.aws.amazon.com/artifact/latest/ug/what-is-aws-artifact.html)
- [OWASP Top 10 for LLM Applications](https://genai.owasp.org/llm-top-10/)
