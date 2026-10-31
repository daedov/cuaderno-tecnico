---
tags:
  - aws
  - certificacion
  - aif-c01
  - ia
  - machine-learning
---

# Dominio 1: Fundamentals of AI and ML (20%)

> Qué es la IA, cómo aprende un modelo, cuándo conviene (y cuándo no) usar ML, cómo es su ciclo de vida en AWS y cómo se mide si funciona.

!!! info "Qué evalúa este dominio"
    - **1.1 Conceptos y terminología**: IA, ML, deep learning, redes neuronales, visión por computadora, NLP, LLM, GenAI, agentic AI; tipos de inferencia (batch, real-time, asynchronous, serverless); tipos de datos; tipos de aprendizaje (supervisado, no supervisado, por refuerzo).
    - **1.2 Casos de uso prácticos**: dónde aporta valor la IA y dónde no; elegir regresión, clasificación o clustering; aplicaciones reales; capacidades de los servicios gestionados (SageMaker AI, Transcribe, Translate, Comprehend, Lex, Polly…); cuándo usar ML tradicional y cuándo un foundation model.
    - **1.3 Ciclo de vida de IA/ML**: componentes del pipeline, origen de los modelos, formas de usarlos en producción, servicios de AWS por etapa, MLOps, métricas técnicas y de negocio.

    Volver al [resumen del examen](resumen-examen.md).

## IA, ML, deep learning, GenAI y agentic AI

Son círculos concéntricos: cada uno es un subconjunto del anterior, salvo la IA agéntica, que es una forma de **usar** los modelos.

| Término | Qué es | Ejemplo |
| --- | --- | --- |
| **Artificial intelligence** (inteligencia artificial, IA) | Cualquier técnica que imita capacidades humanas; incluye reglas escritas a mano | Un sistema experto con reglas `if/else` |
| **Machine learning** (aprendizaje automático, ML) | El sistema **aprende patrones de los datos** en vez de seguir reglas programadas | Detectar fraude con transacciones históricas |
| **Deep learning** (aprendizaje profundo) | ML con **neural networks** (redes neuronales) de muchas capas; destaca con imágenes, audio y texto | Reconocer caras en fotos |
| **Generative AI** (IA generativa, GenAI) | Deep learning que **genera contenido nuevo** a partir de un prompt (ver [Dominio 2](dominio-2-fundamentos-ia-generativa.md)) | Redactar un correo o crear una imagen |
| **Agentic AI** (IA agéntica) | Un modelo **planifica pasos, llama herramientas y actúa** para cumplir un objetivo | Un agente que revisa un pedido, consulta el inventario y abre un ticket |

Vocabulario mínimo: **model** (modelo) es el resultado de entrenar un **algorithm** con datos; **training** ajusta sus parámetros; **inference** (inferencia) es usarlo con datos nuevos. **Computer vision** interpreta imágenes y video; **NLP** (*natural language processing*) entiende o genera lenguaje; un **LLM** (*large language model*) es un modelo de deep learning entrenado con enormes cantidades de texto. **Bias** (sesgo) y **fairness** (equidad) se ven en el [Dominio 4](dominio-4-ia-responsable.md).

## Tipos de datos

**Labeled data** (etiquetados: cada ejemplo trae la respuesta, como correos marcados "spam") frente a **unlabeled data** (solo entradas). **Structured / tabular** (filas y columnas con esquema fijo) frente a **unstructured** (texto libre, imágenes, audio, video). **Time-series** (series temporales): valores ordenados en el tiempo, como ventas diarias.

## Tipos de aprendizaje

| Tipo | Datos | Tareas |
| --- | --- | --- |
| **Supervised learning** (supervisado) | Etiquetados: pares entrada → respuesta | **Classification** (clasificación): predice una **categoría**, binaria o multiclase (regresión logística, árboles, XGBoost). **Regression** (regresión): predice un **valor numérico** continuo (regresión lineal) |
| **Unsupervised learning** (no supervisado) | Sin etiquetas: busca estructura | **Clustering** (agrupamiento, p. ej. k-means), **anomaly detection** (detección de anomalías), **dimensionality reduction** (p. ej. PCA) |
| **Reinforcement learning** (por refuerzo, RL) | Un **agent** actúa en un **environment** y recibe **rewards** (recompensas) | Aprende por prueba y error la **policy** que maximiza la recompensa: robótica, juegos, rutas y **RLHF** para alinear LLMs (ver [Dominio 3](dominio-3-aplicaciones-modelos-fundacionales.md#entrenamiento-y-fine-tuning-de-fms)) |

Variantes que aparecen en material de estudio: **semi-supervised** (pocos datos etiquetados y muchos sin etiquetar) y **self-supervised** (el modelo crea sus propias etiquetas, por ejemplo prediciendo la siguiente palabra; así se hace el *pre-training* de los LLMs).

!!! tip "En el examen"
    - "Predecir si…", "¿es A o B?" → **classification**. "¿Cuánto…?", "¿qué valor…?" → **regression**. "Agrupar sin categorías previas" → **clustering**.
    - "Aprende por prueba y error con recompensas" → **reinforcement learning**.
    - Si el enunciado dice que no hay etiquetas, descarta supervisado.

## Tipos de inferencia

| Tipo | Cómo funciona | Cuándo usarla | En SageMaker AI |
| --- | --- | --- | --- |
| **Real-time** (en tiempo real) | Endpoint siempre encendido; respuesta en milisegundos | Tráfico constante y baja latencia | Real-time endpoints |
| **Serverless** | Escala a cero entre peticiones; puede haber **cold start** (arranque en frío) | Tráfico intermitente; pagas solo por uso | Serverless Inference |
| **Asynchronous** (asíncrona) | La petición se encola y el resultado se deja en S3 | Payloads grandes o procesamiento de minutos | Asynchronous Inference |
| **Batch** (por lotes) | Procesa un dataset completo, sin endpoint persistente | Predicciones periódicas sobre muchos registros | Batch Transform |

!!! tip "En el examen"
    "Sin necesidad de respuesta inmediata, millones de registros cada noche" → **batch**. "Tráfico esporádico, minimizar costo" → **serverless**. "Archivos grandes, procesamiento de varios minutos" → **asynchronous**. "Latencia baja y constante" → **real-time**.

## Overfitting y underfitting

| | Entrenamiento | Datos nuevos | Se asocia a | Cómo se corrige |
| --- | --- | --- | --- | --- |
| **Overfitting** (sobreajuste) | Muy bien (memoriza, incluido el ruido) | Mal | **Alta varianza** | Más datos y más variados, *regularization*, *early stopping*, modelo más simple, *cross-validation* |
| **Underfitting** (subajuste) | Mal | Mal | **Alto sesgo** (estadístico) | Modelo más complejo, mejores *features*, entrenar más |

El equilibrio es el *bias-variance tradeoff*. Por eso los datos se dividen en **training set** (entrenar), **validation set** (ajustar hiperparámetros) y **test set** (medir al final con datos nunca vistos).

## Cuándo usar IA y cuándo no

La IA aporta valor cuando ayuda a **decidir mejor**, a **escalar** lo que no escala con personas o a **automatizar** tareas repetitivas con datos abundantes. No es adecuada cuando se necesita un **resultado exacto y determinista** (una fórmula conocida: usa reglas), cuando el **costo** supera el beneficio, cuando no hay datos suficientes o de calidad, o cuando la regulación exige una explicación que el modelo no puede dar.

Técnica según el caso: abandono sí/no → classification; precio de un inmueble → regression; segmentar sin grupos previos → clustering; fraude raro → classification (con etiquetas) o anomaly detection (sin ellas); demanda futura → regression sobre series temporales (*forecasting*); recomendar productos → recommendation systems; resumir o responder preguntas → GenAI.

### ML tradicional vs foundation models

| Criterio | ML tradicional (modelo propio) | Foundation model (GenAI) |
| --- | --- | --- |
| Tarea | Específica y bien definida (puntuar riesgo de crédito) | Abierta, con lenguaje o contenido |
| Datos | Datos etiquetados del problema | Pocos o ningún ejemplo (*zero/few-shot*) |
| **Explicabilidad** | Alta en modelos simples (árboles, regresión) | Baja |
| **Regulación** | Preferible cuando hay que justificar decisiones | Riesgo mayor en decisiones reguladas |
| Costo, latencia, determinismo | Barato, rápido, misma entrada → misma salida | Más caro por token, más latencia, no determinista |

!!! tip "En el examen"
    Si el escenario menciona **explicabilidad obligatoria**, **regulador** o **decisiones sobre personas** (crédito, contratación), la respuesta suele ser un modelo tradicional e interpretable, no un LLM.

## Servicios de IA gestionados de AWS

Los **AI services** (servicios de IA preentrenados) se consumen por API sin saber ML: son la respuesta cuando la pregunta dice *no ML expertise* o *least operational overhead*.

| Servicio | Qué hace | Caso típico |
| --- | --- | --- |
| **Amazon Comprehend** | NLP: sentimiento, entidades, frases clave, idioma, clasificación, detección de PII | Sentimiento de reseñas |
| **Amazon Translate** | Traducción automática neuronal | Traducir un catálogo |
| **Amazon Transcribe** | *Speech-to-text* (voz a texto), hablantes y redacción de PII | Transcribir llamadas |
| **Amazon Polly** | *Text-to-speech* (texto a voz) | Leer artículos en voz alta |
| **Amazon Lex** | Chatbots y bots de voz con intents y slots | Bot que agenda citas |
| **Amazon Rekognition** | Visión: objetos, caras, texto en imagen, moderación, video | Moderar imágenes subidas |
| **Amazon Textract** | Texto, formularios y tablas de documentos escaneados (más que OCR) | Digitalizar facturas |
| **Amazon Personalize** | Recomendaciones personalizadas en tiempo real | "Productos que te pueden gustar" |
| **Amazon SageMaker AI** | Construir, entrenar y desplegar tus propios modelos | Modelo de riesgo propio |

!!! tip "En el examen: no confundas"
    - **Textract** extrae texto de documentos; **Comprehend** analiza el significado. Flujo típico: Textract → Comprehend.
    - **Transcribe** (voz → texto) vs **Polly** (texto → voz). Truco: *Polly* habla como un loro.
    - **Lex** construye la conversación; Transcribe/Polly solo convierten audio.
    - **Rekognition** es para imágenes y video; si es un documento con campos, es **Textract**.

## Ciclo de vida de ML

Objetivo de negocio → **data collection** → **EDA** (*exploratory data analysis*) → **pre-processing** (limpiar, imputar, normalizar, dividir) → **feature engineering** → **training** → **hyperparameter tuning** (configuración que no se aprende de los datos) → **evaluation** → **deployment** → **monitoring**. En monitoreo se vigila el **data drift** (los datos de producción cambian respecto del entrenamiento) y el **model / concept drift** (cambia la relación entre entradas y resultado); cuando el modelo se degrada, se **reentrena**.

| Etapa | Servicio o función |
| --- | --- |
| Datos: almacenar, catalogar, preparar | S3, AWS Glue (ETL y Data Catalog), Lake Formation, **SageMaker Data Wrangler** (en Canvas), Glue DataBrew |
| Etiquetar / guardar features | **SageMaker Ground Truth** / **SageMaker Feature Store** |
| Entrenar y ajustar | SageMaker AI Training, Automatic Model Tuning; ML sin código con **SageMaker Canvas** |
| Modelos preentrenados | **SageMaker JumpStart**, Amazon Bedrock |
| Orquestar y versionar | **SageMaker Pipelines**, **SageMaker Model Registry** |
| Monitorear | **SageMaker Model Monitor** (calidad de datos y modelo, drift de sesgo y explicabilidad) |
| Sesgo, explicabilidad y gobierno | **SageMaker Clarify**, **SageMaker Model Cards**, Model Dashboard, Role Manager |

**Origen y consumo de modelos**: modelos abiertos (Llama, Mistral…) en JumpStart o Bedrock, propietarios por API en Bedrock, o propios entrenados en SageMaker AI (máximo control y costo). Por API gestionada (Bedrock) solo gestionas las llamadas; autoalojado (endpoint de SageMaker AI, EC2/EKS) gestionas instancias, escalado y endpoint.

## MLOps

**MLOps** aplica DevOps al ML para que entrenar y desplegar sea **repetible, automatizado y auditable**: *experimentation* (registrar datos, parámetros y métricas de cada prueba), *repeatable processes* (pipelines como código), *scalable systems*, *managing technical debt*, *production readiness* (pruebas, aprobación, rollback), *model monitoring* y *model re-training*. Es el mismo CI/CD de software con el modelo y los datos como artefactos adicionales (ver [Integración continua](../../../devops/ci-cd/integracion-continua.md)).

## Métricas de evaluación

| | Predicho: fraude | Predicho: no fraude |
| --- | --- | --- |
| **Real: fraude** | TP (*true positive*) | FN (*false negative*) |
| **Real: no fraude** | FP (*false positive*) | TN (*true negative*) |

| Métrica | Fórmula | Úsala cuando… |
| --- | --- | --- |
| **Accuracy** (exactitud) | (TP + TN) / total | Las clases están balanceadas |
| **Precision** (precisión) | TP / (TP + FP) | Un falso positivo es caro (bloquear a un cliente legítimo, spam) |
| **Recall** (sensibilidad) | TP / (TP + FN) | Un falso negativo es caro (fraude no detectado, diagnóstico médico) |
| **F1 score** | 2 × (P × R) / (P + R) | Clases desbalanceadas y ambos errores importan |
| **AUC-ROC** | Área bajo la curva ROC (0,5 = azar; 1 = perfecto) | Comparar clasificadores en todos los umbrales |

!!! example "Ejemplo resuelto"
    1000 transacciones, 10 son fraude. El modelo marca 15 como fraude, de las cuales 8 lo son: TP = 8, FP = 7, FN = 2, TN = 983. Accuracy = **99,1%** (un modelo que diga siempre "no fraude" tendría 99%), precision = **53%**, recall = **80%**, F1 ≈ **0,64**. Con clases desbalanceadas, la accuracy engaña.

Para **regresión**: **MAE** (error absoluto medio), **RMSE** (castiga más los errores grandes) y **R²** (variación explicada). Métricas de **negocio**: *cost per user*, *development costs*, *customer feedback* y **ROI**; un modelo con mejor F1 que cuesta el triple puede no compensar. Las métricas de modelos generativos (ROUGE, BLEU…) están en el [Dominio 3](dominio-3-aplicaciones-modelos-fundacionales.md#evaluar-un-fm).

!!! tip "En el examen"
    "Es crítico no dejar pasar ningún caso positivo" → **recall**. "Es crítico no molestar con falsas alarmas" → **precision**. "Dataset desbalanceado" → no elijas accuracy.

## Casos de uso

1. Extraer datos de miles de formularios escaneados → **Amazon Textract**.
2. Transcribir llamadas y saber si el cliente terminó molesto → **Transcribe** + **Comprehend**.
3. Recomendaciones sin equipo de data science → **Amazon Personalize**.
4. Créditos con regulador que exige justificar cada rechazo → modelo interpretable en **SageMaker AI** + **Clarify**, no un LLM.
5. Detectar imágenes inapropiadas antes de publicarlas → **Amazon Rekognition**.
6. Puntuar a todos los clientes una vez por semana → inferencia **batch** (Batch Transform).
7. Modelo de demanda que falla tras cambiar los hábitos de compra → **drift**: **Model Monitor** y reentrenar.
8. Bot que reserva citas por teléfono → **Amazon Lex** + **Amazon Polly**.

## Preguntas de práctica

**1.** Una empresa quiere agrupar a sus clientes en segmentos según su comportamiento de compra. No tiene categorías definidas de antemano. ¿Qué tipo de aprendizaje debe usar?

- A. Supervised learning con classification
- B. Unsupervised learning con clustering
- C. Reinforcement learning
- D. Supervised learning con regression

??? success "Respuesta"
    **B.** Sin etiquetas previas y con el objetivo de agrupar, es clustering (no supervisado). A y D requieren datos etiquetados. C aprende con recompensas por acciones, no agrupa datos.

**2.** Un hospital entrena un modelo para detectar una enfermedad grave. Lo peor que puede pasar es que un paciente enfermo sea clasificado como sano. ¿Qué métrica debe priorizar?

- A. Accuracy
- B. Precision
- C. Recall
- D. RMSE

??? success "Respuesta"
    **C.** Recall mide cuántos positivos reales se detectan; minimiza falsos negativos. A engaña si la enfermedad es rara. B prioriza evitar falsos positivos. D es una métrica de regresión.

**3.** Un equipo necesita predicciones sobre archivos de 500 MB que tardan varios minutos en procesarse. No necesitan respuesta inmediata, pero sí procesar cada petición a medida que llega. ¿Qué opción de inferencia de SageMaker AI es la más adecuada?

- A. Real-time inference
- B. Serverless inference
- C. Asynchronous inference
- D. Ninguna: debe usar EC2

??? success "Respuesta"
    **C.** Asynchronous inference encola peticiones con payloads grandes y tiempos largos y deja el resultado en S3. A está pensada para baja latencia y payloads pequeños. B tiene límites de tamaño y duración y sufre cold starts. D añade gestión innecesaria.

**4.** ¿Qué servicio permite a una persona sin conocimientos de ML convertir texto de un sitio web en audio con voz natural?

- A. Amazon Transcribe
- B. Amazon Polly
- C. Amazon Lex
- D. Amazon Comprehend

??? success "Respuesta"
    **B.** Polly es text-to-speech. A es lo contrario (voz a texto). C crea bots conversacionales. D analiza texto.

**5.** Un modelo obtiene 99% de exactitud en entrenamiento y 70% con datos nuevos. ¿Qué está ocurriendo?

- A. Underfitting
- B. Overfitting
- C. Data drift
- D. El modelo está bien ajustado

??? success "Respuesta"
    **B.** Gran diferencia entre entrenamiento y datos nuevos indica que memorizó el entrenamiento. A daría malos resultados en ambos. C ocurre en producción con el tiempo, no inmediatamente. D no explica la caída.

**6.** (Elige dos) ¿Qué situaciones indican que una solución de ML **no** es adecuada?

- A. El resultado debe calcularse exactamente con una fórmula legal conocida
- B. Hay millones de transacciones históricas etiquetadas
- C. El costo de desarrollo supera claramente el beneficio esperado
- D. Se quiere escalar una tarea de clasificación repetitiva
- E. Los patrones cambian y las reglas manuales no dan abasto

??? success "Respuesta"
    **A y C.** Si existe una regla exacta, una predicción no aporta; y si el costo supera el beneficio, no compensa. B, D y E son señales a favor de usar ML.

**7.** Una empresa quiere desplegar un modelo de código abierto preentrenado con pocos clics, controlando la instancia en la que corre. ¿Qué opción encaja mejor?

- A. Amazon SageMaker JumpStart
- B. Amazon Comprehend
- C. Amazon Personalize
- D. AWS Glue DataBrew

??? success "Respuesta"
    **A.** JumpStart ofrece modelos preentrenados (incluidos abiertos) que se despliegan en endpoints de SageMaker AI que tú eliges. B y C son servicios cerrados para tareas específicas. D prepara datos.

## Para profundizar

| Tema | Nota del cuaderno |
| --- | --- |
| Cómputo donde corren los modelos | [Máquinas virtuales](../../../cloud/computo/maquinas-virtuales.md), [Serverless](../../../cloud/computo/serverless.md), [Contenedores gestionados](../../../cloud/computo/contenedores-gestionados.md) |
| Almacenamiento de datos de entrenamiento | [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md) |
| MLOps como CI/CD | [Integración continua](../../../devops/ci-cd/integracion-continua.md), [Despliegue continuo](../../../devops/ci-cd/despliegue-continuo.md) |
| Monitoreo y drift | [Observabilidad](../../../devops/operacion/observabilidad.md) |
| Métricas de negocio y ROI | [Métricas, KPIs y OKRs](../../../negocio/metricas-kpis-okrs.md) |
| Siguiente dominio | [Dominio 2: Fundamentals of GenAI](dominio-2-fundamentos-ia-generativa.md) |

## Referencias

- [Exam guide AIF-C01 – Domain 1](https://docs.aws.amazon.com/aws-certification/latest/ai-practitioner-01/ai-practitioner-01-domain1.html)
- [Qué es Amazon SageMaker AI](https://docs.aws.amazon.com/sagemaker/latest/dg/whatis.html)
- [Opciones de despliegue para inferencia en SageMaker AI](https://docs.aws.amazon.com/sagemaker/latest/dg/deploy-model.html)
- [Amazon SageMaker Model Monitor](https://docs.aws.amazon.com/sagemaker/latest/dg/model-monitor.html)
- [Servicios de IA de AWS](https://aws.amazon.com/ai/services/)
- [Machine Learning Lens – AWS Well-Architected](https://docs.aws.amazon.com/wellarchitected/latest/machine-learning-lens/machine-learning-lens.html)
