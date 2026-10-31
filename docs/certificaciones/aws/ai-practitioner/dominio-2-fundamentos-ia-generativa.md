---
tags:
  - aws
  - certificacion
  - aif-c01
  - ia
  - ia-generativa
---

# Dominio 2: Fundamentals of GenAI (24%)

> Cómo funcionan por dentro los modelos generativos (tokens, embeddings, transformers), cuánto cuestan, qué es un agente, qué pueden y qué no pueden hacer, y qué servicios de AWS se usan para construir con ellos.

!!! info "Qué evalúa este dominio"
    - **2.1 Conceptos básicos de GenAI**: tokens, chunking, embeddings, vectores, prompt engineering, LLMs basados en transformers, foundation models, modelos multimodales y de difusión; casos de uso; ciclo de vida de un FM; precio por token; *context engineering*; conceptos de IA agéntica (multiagente, MCP, memoria, herramientas, orquestación).
    - **2.2 Capacidades y límites**: ventajas, desventajas (alucinaciones, no determinismo, interpretabilidad), criterios para elegir un modelo, métricas de valor de negocio.
    - **2.3 Infraestructura y servicios de AWS**: Bedrock, SageMaker AI, JumpStart, Amazon Quick, Kiro, Strands Agents, Bedrock AgentCore; ventajas y *trade-offs* de costo.

    Volver al [resumen del examen](resumen-examen.md).

Este dominio es el "dueño" de los conceptos de GenAI y de Amazon Bedrock. Cómo se aplican (RAG, prompt engineering, fine-tuning, evaluación) está en el [Dominio 3](dominio-3-aplicaciones-modelos-fundacionales.md).

## Conceptos base de la IA generativa

| Concepto | Qué es | Por qué importa |
| --- | --- | --- |
| **Foundation model** (modelo fundacional, FM) | Modelo muy grande entrenado con datos masivos que sirve de **base para muchas tareas** sin reentrenarlo. Un **LLM** es un FM de lenguaje; un **multi-modal model** acepta o genera texto, imagen, audio o video | Una sola API resume, traduce, clasifica, responde y programa |
| **Token** | Unidad mínima que procesa el modelo: palabra, parte de palabra o signo. En inglés, 1 token ≈ 4 caracteres o ¾ de palabra; en español algo más de tokens por palabra. Cada modelo tiene su *tokenizer* | Define el **costo** (entrada y salida), la **context window** (máximo de tokens a la vez: prompt + historial + documentos + respuesta) y la **latencia** |
| **Embedding** | Representación de un texto o imagen como **vector** de cientos o miles de números que captura su **significado**: "auto" y "vehículo" quedan cerca | La cercanía se mide con **cosine similarity** (similitud coseno) o distancia euclidiana; una **vector database** busca los más parecidos (**semantic search**). Es la base de RAG |
| **Chunking** (fragmentación) | Dividir documentos largos en trozos antes de generar embeddings: tamaño fijo con *overlap*, por estructura, jerárquico o semántico | Chunks grandes diluyen el significado y gastan contexto; pequeños pierden contexto |
| **Transformer** | Arquitectura (2017) base de los LLMs. Su clave es la **self-attention** (autoatención): pondera qué otros tokens son relevantes, aunque estén lejos, y procesa en paralelo | Un LLM **predice el siguiente token** una y otra vez |
| **Diffusion model** (difusión) | Genera imágenes partiendo de **ruido aleatorio** y eliminándolo paso a paso guiado por el prompt. Otras arquitecturas: **GANs** (generador contra discriminador) y **VAEs** | Técnica habitual para texto → imagen o video |

**Casos de uso**: generación de imagen, video y audio; *summarization*; asistentes; traducción; *code generation*; atención al cliente; búsqueda conversacional; recomendaciones; extracción de datos de documentos; datos sintéticos.

**Ciclo de vida de un FM**: selección de datos → selección de modelo → *pre-training* → *fine-tuning* → evaluación → despliegue → feedback (y vuelta a ajustar). En la práctica casi ninguna empresa hace pre-training: elige un FM (Bedrock o JumpStart), lo adapta con prompts, RAG o fine-tuning, lo evalúa y lo despliega.

## Precio por token

En Bedrock *on-demand* pagas **input tokens** y **output tokens**; los de salida suelen costar varias veces más. Un prompt con muchos documentos encarece **cada** llamada; limitar `maxTokens` y pedir respuestas concisas reduce costo y latencia; un modelo más grande cuesta más y responde más lento.

| Modalidad de Bedrock | Cómo se cobra | Cuándo conviene |
| --- | --- | --- |
| **On-demand** | Por token, sin compromiso | Uso variable, pruebas, la mayoría de aplicaciones |
| **Batch inference** | Por token, con descuento frente a on-demand | Grandes volúmenes sin necesidad de respuesta inmediata |
| **Provisioned Throughput** | Por hora de capacidad reservada (con o sin compromiso de plazo) | Tráfico alto y estable, rendimiento garantizado; algunos modelos personalizados lo requieren |
| **Prompt caching** | Los tokens leídos de caché son más baratos | Prompts con un prefijo largo que se repite |
| **Service tiers** (priority, standard, flex) | Más caro por prioridad, más barato si toleras latencia | Ajustar costo/latencia por petición |

**Cross-Region inference** usa *inference profiles* para repartir peticiones entre regiones y aumentar el *throughput*; ojo con la residencia de datos. Los precios varían por modelo y región: consulta la página de precios de Bedrock antes de estimar.

## Context engineering

El **context engineering** (ingeniería de contexto) diseña **todo lo que entra en la ventana de contexto**: *system prompt*, historial, documentos recuperados, resultados de herramientas, memoria y ejemplos. Es la evolución del *prompt engineering* para agentes. Buenas prácticas: incluir solo lo relevante (más contexto cuesta más y no siempre es mejor), ordenar y etiquetar secciones, resumir el historial largo y poner al principio lo que no cambia para aprovechar el *prompt caching*.

## IA agéntica

Un **AI agent** (agente de IA) es un sistema en el que un FM **razona sobre un objetivo, decide una acción, usa herramientas, observa el resultado y repite** hasta terminar.

| Concepto | Qué es |
| --- | --- |
| **Tool usage** (uso de herramientas) | El modelo pide ejecutar funciones (APIs, consultas, código) y recibe el resultado; también *function calling* |
| **Memory management** | **Short-term**: contexto de la sesión. **Long-term**: preferencias y hechos que persisten entre sesiones |
| **Workflow orchestration** | Coordinar pasos, reintentos, ramas y aprobaciones humanas (*human-in-the-loop*) |
| **Model Context Protocol (MCP)** | Protocolo abierto (creado por Anthropic) que estandariza cómo un agente se conecta a herramientas y datos. Un **MCP server** expone herramientas que cualquier cliente compatible usa sin integración a medida |
| **Multi-agent systems** | Varios agentes especializados colaboran. Patrones: **supervisor / orchestrator-workers**, **sequential / pipeline**, **peer-to-peer / swarm** y **graph / workflow** |

**A2A** (*Agent2Agent*) es el protocolo abierto para comunicación entre agentes. Regla: MCP conecta **agente ↔ herramientas**; A2A conecta **agente ↔ agente**.

!!! tip "En el examen"
    - "Conectar un agente a sistemas externos de forma estandarizada" → **MCP**.
    - "Recordar preferencias del usuario entre sesiones" → **long-term memory**.
    - Un agente **actúa** (ejecuta acciones); un chatbot con RAG solo **responde**.

## Ventajas y desventajas de la GenAI

| Ventajas | Desventajas |
| --- | --- |
| **Adaptability**: un solo modelo sirve para muchas tareas | **Hallucinations** (alucinaciones): respuestas falsas dichas con seguridad |
| **Responsiveness**: respuestas en segundos | **Nondeterminism**: la misma pregunta puede dar respuestas distintas |
| Conversación en lenguaje natural | **Interpretability** baja: difícil explicar por qué respondió algo |
| Generación de contenido nuevo | **Inaccuracy**: errores en cálculos o datos concretos |
| Poca o ninguna necesidad de datos etiquetados | **Knowledge cutoff**: no sabe lo ocurrido después de su entrenamiento |
| Rapidez para prototipar | Costo por token y latencia; riesgos de seguridad (prompt injection) y legales |

## Cómo elegir un modelo y medir su valor

Factores: **modality** (texto, imagen, embeddings, multimodal), **performance** en tu tarea (evalúalo, ver [Dominio 3](dominio-3-aplicaciones-modelos-fundacionales.md#evaluar-un-fm)), **capabilities** (idiomas, herramientas, razonamiento, longitud de contexto), **constraints** (región, tamaño de entrada y salida), **compliance** (residencia, licencia), **cost**, **latency** y **model size**: un modelo pequeño puede bastar para clasificar; uno grande para razonar.

Métricas de valor de negocio: **ROI**, **efficiency** (tiempo ahorrado), **conversion rate**, **ARPU** (*average revenue per user*), **CLV** (*customer lifetime value*), **accuracy** de las respuestas y **cross-domain performance**. Ver [Métricas, KPIs y OKRs](../../../negocio/metricas-kpis-okrs.md).

## Servicios de AWS para construir con GenAI

### Amazon Bedrock

Servicio **serverless y totalmente gestionado** que da acceso por una API unificada a FMs de Amazon (**Amazon Nova**, Titan) y de terceros (Anthropic, Meta, Mistral, Cohere y otros), sin gestionar infraestructura.

| Función de Bedrock | Para qué | Detalle en |
| --- | --- | --- |
| **Playgrounds** | Probar modelos y prompts en la consola | — |
| **Knowledge Bases** | RAG gestionado | [Dominio 3](dominio-3-aplicaciones-modelos-fundacionales.md#amazon-bedrock-knowledge-bases) |
| **Agents** | Agentes gestionados con *action groups* y Knowledge Bases | [Dominio 3](dominio-3-aplicaciones-modelos-fundacionales.md#agentes-de-ia-y-sus-aplicaciones-de-negocio) |
| **Guardrails** | Filtros de seguridad y privacidad | [Dominio 4](dominio-4-ia-responsable.md#amazon-bedrock-guardrails) |
| **Prompt Management** y **Flows** | Versionar prompts y orquestar flujos de GenAI | [Dominio 3](dominio-3-aplicaciones-modelos-fundacionales.md#amazon-bedrock-prompt-management) |
| **Evaluations** | Evaluación automática, humana o con *LLM-as-a-judge* | [Dominio 3](dominio-3-aplicaciones-modelos-fundacionales.md#evaluar-un-fm) |
| **Model customization** | Fine-tuning supervisado, *reinforcement fine-tuning*, distillation | [Dominio 3](dominio-3-aplicaciones-modelos-fundacionales.md#personalizar-un-fm-costos-y-trade-offs) |
| **Marketplace** e importación de modelos | Usar más modelos o traer los tuyos | — |

!!! note "Tus datos en Bedrock"
    AWS indica que Bedrock no usa tus prompts ni respuestas para entrenar los modelos base ni los comparte con los proveedores de modelos. Es un argumento habitual en preguntas de privacidad.

**Amazon Bedrock AgentCore** es la plataforma para **desplegar y operar agentes en producción** con cualquier framework (Strands Agents, LangGraph, CrewAI…) y cualquier modelo. Servicios modulares: **Runtime** (serverless con aislamiento por sesión), **Memory**, **Gateway** (convierte APIs y Lambdas en herramientas MCP), **Identity**, **Policy** (reglas deterministas sobre qué herramientas usa un agente), **Code Interpreter**, **Browser**, **Observability** y **Evaluations**, entre otros.

### Otros servicios: ¿cuál elijo?

| Necesidad | Servicio | Qué es |
| --- | --- | --- |
| Usar FMs por API sin gestionar infraestructura | **Amazon Bedrock** | Ver arriba |
| Entrenar o desplegar modelos con control total de instancias | **Amazon SageMaker AI** | Entrenar, ajustar y desplegar modelos propios o abiertos en la infraestructura que elijas |
| Desplegar un modelo abierto preentrenado con pocos clics | **SageMaker JumpStart** | Hub de modelos preentrenados y soluciones |
| Asistente para empleados sobre documentos y datos de la empresa | **Amazon Quick** | Agentes para empleados: chat sobre datos (Quick Index), investigación con citas (Quick Research), automatización (Quick Flows, Quick Automate) y BI (Quick Sight). Evolución de **Amazon Q Business** |
| Asistente de programación agéntico | **Kiro** | IDE y CLI para *spec-driven development* (requisitos → diseño → tareas), con *hooks* y MCP. Sucesor de los plugins de IDE de Q Developer |
| Ayuda con tu cuenta de AWS en la consola | **Amazon Q Developer** (consola) | Preguntas, errores y costos de tu cuenta |
| Construir un agente con código propio | **Strands Agents** (u otro framework) | SDK abierto de AWS: defines modelo, prompt y herramientas y el modelo decide el plan |
| Operar agentes en producción con identidad, memoria y políticas | **Amazon Bedrock AgentCore** | Ver arriba |
| Modernizar y migrar aplicaciones (.NET, mainframe, VMware) | **AWS Transform** | Servicio agéntico de modernización |
| Una tarea concreta de IA (traducir, transcribir, OCR) | Servicio de IA preentrenado | Ver [Dominio 1](dominio-1-fundamentos-ia-ml.md#servicios-de-ia-gestionados-de-aws) |

**Amazon Nova** es la familia de FMs de Amazon (texto, multimodal, imagen, video, voz) en Bedrock; **AWS Trainium** e **Inferentia** son chips propios para entrenamiento e inferencia, además de GPUs en EC2.

!!! warning "Cambios recientes en Amazon Q"
    En material antiguo verás "Amazon Q Business" y "Q Developer en el IDE" como respuestas correctas; con la guía 1.1 piensa en **Amazon Quick** y **Kiro** (fechas en el [resumen del examen](resumen-examen.md#servicios-que-mas-salen)).

Ventajas de construir GenAI en AWS: **accessibility** y **lower barrier to entry**, **speed to market**, **cost-effectiveness** (pago por uso, sin GPUs ociosas) y seguridad y cumplimiento (ver [Dominio 5](dominio-5-seguridad-cumplimiento-gobierno.md)).

### Trade-offs de costo

| Decisión | Gana | Pierde |
| --- | --- | --- |
| Modelo grande vs pequeño | Calidad y razonamiento | Costo por token y latencia |
| On-demand vs Provisioned Throughput | Flexibilidad, sin compromiso | Rendimiento garantizado a gran escala |
| Una región vs cross-Region inference | Residencia de datos simple | Throughput y disponibilidad |
| Modelo base vs modelo personalizado | Sin costo de entrenamiento ni hosting | Calidad en tu dominio específico |
| Redundancia multi-región | Disponibilidad | Costo y complejidad |

## Casos de uso

1. Probar FMs de varios proveedores sin aprovisionar servidores → **Amazon Bedrock**.
2. Empleados que preguntan en lenguaje natural sobre políticas en SharePoint y S3 → **Amazon Quick** (Quick Index).
3. Un *system prompt* de 5000 tokens repetido en cada llamada → **prompt caching**.
4. Un agente que consulta CRM, ERP y una base interna sin integraciones a medida por framework → **MCP servers** (por ejemplo con **AgentCore Gateway**).
5. Entrenar un modelo propio con algoritmo propio y elegir la GPU → **Amazon SageMaker AI**.
6. Clasificar 10 millones de reseñas una vez al mes con un LLM → **batch inference** de Bedrock.
7. Un buscador no encuentra "vehículo" cuando el documento dice "auto" → búsqueda semántica con **embeddings**.
8. Modernizar aplicaciones .NET antiguas con IA → **AWS Transform**.

## Preguntas de práctica

**1.** ¿Qué describe mejor un embedding?

- A. Un fragmento de un documento largo
- B. Una representación numérica que captura el significado de un texto
- C. La unidad mínima de texto que procesa un LLM
- D. Un parámetro que controla la creatividad del modelo

??? success "Respuesta"
    **B.** Un embedding es un vector que representa significado. A es un chunk. C es un token. D es la temperatura.

**2.** Una empresa nota que su factura de Bedrock creció porque cada petición incluye largos documentos de contexto. ¿Qué acción reduce el costo **sin cambiar de modelo**?

- A. Aumentar `maxTokens`
- B. Enviar solo los fragmentos relevantes y reutilizar el prefijo fijo con prompt caching
- C. Cambiar de on-demand a Provisioned Throughput sin analizar el tráfico
- D. Subir la temperatura

??? success "Respuesta"
    **B.** Menos tokens de entrada y caché del prefijo repetido reducen costo. A puede aumentar tokens de salida. C solo compensa con tráfico alto y estable. D no afecta al costo.

**3.** ¿Qué tipo de modelo genera imágenes eliminando ruido paso a paso?

- A. Transformer de solo texto
- B. Diffusion model
- C. Modelo de regresión
- D. Embedding model

??? success "Respuesta"
    **B.** Es la definición de difusión. A genera texto. C predice números. D produce vectores, no imágenes.

**4.** Un asistente de soporte da respuestas distintas a la misma pregunta y a veces inventa números de política. ¿Qué desventajas de la GenAI muestra? (Elige dos)

- A. Nondeterminism
- B. Hallucinations
- C. Underfitting
- D. Data drift
- E. Cold start

??? success "Respuesta"
    **A y B.** Respuestas distintas = no determinismo; datos inventados = alucinaciones. C es un problema de entrenamiento de ML tradicional. D es cambio en datos de producción. E es latencia de arranque.

**5.** ¿Qué protocolo abierto estandariza cómo un agente se conecta a herramientas y fuentes de datos externas?

- A. A2A
- B. MCP
- C. OAuth
- D. HTTP/3

??? success "Respuesta"
    **B.** MCP conecta agentes con herramientas. A2A conecta agentes entre sí. C es autorización. D es transporte web.

**6.** Un equipo quiere un servicio para ejecutar sus agentes (construidos con LangGraph) en producción con aislamiento por sesión, memoria gestionada y control de identidad, sin gestionar servidores. ¿Qué elige?

- A. Amazon Bedrock AgentCore
- B. Amazon Comprehend
- C. Amazon EC2 con Auto Scaling
- D. Amazon Lex

??? success "Respuesta"
    **A.** AgentCore es framework-agnóstico y ofrece Runtime, Memory e Identity gestionados. B es NLP. C exige gestionar todo. D crea bots conversacionales, no ejecuta agentes de otros frameworks.

**7.** Una empresa que hoy usa los plugins de IDE de Amazon Q Developer pregunta qué herramienta recomienda AWS de cara al futuro para desarrollo asistido por agentes. ¿Cuál?

- A. Amazon Quick
- B. Kiro
- C. Amazon SageMaker Canvas
- D. AWS Transform

??? success "Respuesta"
    **B.** AWS recomienda Kiro como sucesor de los plugins de IDE de Q Developer. A es para trabajo de negocio. C es ML sin código. D moderniza aplicaciones, no es un IDE.

**8.** ¿Qué factor es **más** relevante al elegir un FM para un chatbot de voz en tiempo real?

- A. Latency
- B. Capacidad de generar video
- C. Tamaño del dataset de pre-training
- D. Licencia de los datos de entrenamiento de un modelo de imagen

??? success "Respuesta"
    **A.** En voz en tiempo real, la latencia domina la experiencia. B y D no aplican al caso. C no se elige al consumir un FM.

## Para profundizar

| Tema | Nota del cuaderno |
| --- | --- |
| Serverless y pago por uso | [Serverless](../../../cloud/computo/serverless.md), [FinOps y costos](../../../cloud/fundamentos/finops-costos.md) |
| Bases de datos donde viven los vectores | [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md) |
| Agentes e integración por APIs | [Integración y APIs](../../../cloud/arquitectura/integracion-apis.md) |
| Llamar APIs desde Python | [APIs y HTTP](../../../python/scripting/apis-http.md), [Automatización cloud con SDKs](../../../python/scripting/automatizacion-cloud.md) |
| Dominio anterior y siguiente | [Dominio 1](dominio-1-fundamentos-ia-ml.md) · [Dominio 3](dominio-3-aplicaciones-modelos-fundacionales.md) |

## Referencias

- [Exam guide AIF-C01 – Domain 2](https://docs.aws.amazon.com/aws-certification/latest/ai-practitioner-01/ai-practitioner-01-domain2.html)
- [Qué es Amazon Bedrock](https://docs.aws.amazon.com/es_es/bedrock/latest/userguide/what-is-bedrock.html)
- [Precios de Amazon Bedrock](https://aws.amazon.com/bedrock/pricing/)
- [Qué es Amazon Bedrock AgentCore](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/what-is-bedrock-agentcore.html)
- [Qué es Amazon Quick](https://docs.aws.amazon.com/quicksuite/latest/userguide/what-is.html)
- [Model Context Protocol](https://modelcontextprotocol.io/)
