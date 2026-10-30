---
tags:
  - aws
  - certificacion
  - aif-c01
  - ia
  - ia-responsable
---

# Dominio 4: Guidelines for Responsible AI (14%)

> Qué significa que un sistema de IA sea responsable (justo, seguro, veraz, transparente), de dónde vienen el sesgo y los riesgos legales, y qué herramientas de AWS ayudan a detectarlos, explicarlos y controlarlos.

!!! info "Qué evalúa este dominio"
    - **4.1 Desarrollo responsable**: características de la IA responsable (sesgo, equidad, inclusividad, robustez, seguridad, veracidad); herramientas como **Amazon Bedrock Guardrails**; selección responsable de modelos (sostenibilidad); riesgos legales de la GenAI; características de los datasets; efectos del sesgo y la varianza; herramientas para detectar y monitorear sesgo y veracidad.
    - **4.2 Transparencia y explicabilidad**: diferencia entre modelos explicables y no explicables; herramientas (**SageMaker Model Cards**, **SageMaker Clarify**, **Bedrock Evaluations**, modelos y datos abiertos, licencias); trade-offs entre seguridad y transparencia; diseño centrado en las personas.

    Volver al [resumen del examen](resumen-examen.md).

## ¿Qué es la IA responsable?

La **responsible AI** (IA responsable) es el conjunto de prácticas para que un sistema de IA sea útil **sin causar daño**: que trate a las personas de forma justa, que sea seguro, que diga la verdad, que se pueda explicar y que alguien responda por él. No es un paso al final: se aplica en todo el ciclo (datos, entrenamiento, evaluación, despliegue, monitoreo).

AWS describe la IA responsable en estas **dimensiones**:

| Dimensión | Qué significa | Ejemplo de fallo |
| --- | --- | --- |
| **Fairness** (equidad) | Resultados equitativos entre grupos de personas | Un modelo de crédito rechaza más a un grupo por su código postal |
| **Explainability** (explicabilidad) | Poder entender y explicar por qué el modelo produjo un resultado | Nadie sabe justificar un rechazo ante el regulador |
| **Privacy and security** (privacidad y seguridad) | Proteger los datos y el modelo | El chatbot revela datos de otro cliente |
| **Safety** (seguridad, de no causar daño) | Evitar contenido o acciones dañinas | El asistente da instrucciones peligrosas |
| **Controllability** (controlabilidad) | Poder supervisar y dirigir el comportamiento del sistema | Un agente ejecuta acciones sin posibilidad de detenerlo |
| **Veracity and robustness** (veracidad y robustez) | Resultados correctos y estables, incluso con entradas inesperadas o adversarias | Alucinaciones; un cambio mínimo en la entrada cambia la decisión |
| **Governance** (gobierno) | Procesos, roles y responsables definidos | Nadie aprobó poner el modelo en producción |
| **Transparency** (transparencia) | Comunicar qué hace el sistema, sus límites y que es una IA | El usuario no sabe que habla con un bot |

La guía añade **inclusivity** (inclusividad): que el sistema funcione para personas diversas (idiomas, acentos, capacidades).

## Sesgo y varianza

### De dónde viene el sesgo

El **bias** (sesgo) casi siempre entra por los **datos** o por cómo se define el problema:

| Tipo | Qué ocurre | Ejemplo |
| --- | --- | --- |
| **Sampling bias** (sesgo de muestreo) | Los datos no representan a toda la población | Reconocimiento de voz entrenado casi solo con un acento |
| **Historical bias** (sesgo histórico) | Los datos reflejan decisiones injustas del pasado | Historial de contrataciones que favorecía a un género |
| **Measurement / label bias** (de medición o etiquetado) | Las etiquetas son inconsistentes o subjetivas | Etiquetadores que califican distinto el mismo comentario |
| **Confirmation bias** (de confirmación) | Se buscan o seleccionan datos que confirman lo esperado | Elegir solo métricas que favorecen al modelo |
| **Automation bias** (de automatización) | Las personas confían en exceso en lo que dice el sistema | Aprobar sin revisar lo que propone la IA |

### Efectos del sesgo y la varianza

- **Efecto en grupos demográficos**: un modelo puede tener buena accuracy global y fallar mucho más en un subgrupo. Por eso se hace **subgroup analysis** (análisis por subgrupos).
- **Inaccuracy**: decisiones erróneas que afectan a personas y al negocio.
- **Overfitting** (alta varianza): el modelo memoriza patrones del entrenamiento, incluidos los sesgados, y generaliza mal.
- **Underfitting** (alto sesgo estadístico): el modelo es demasiado simple y falla para todos, a menudo más para los grupos minoritarios.

Ver [overfitting y underfitting en el Dominio 1](dominio-1-fundamentos-ia-ml.md#overfitting-y-underfitting).

### Características de un buen dataset

- **Inclusivity** y **diversity**: representa a todos los grupos y situaciones del uso real.
- **Curated data sources** (fuentes curadas): origen conocido, limpio y con permisos de uso.
- **Balanced datasets** (balanceados): proporciones razonables entre clases y grupos, o técnicas para compensar el desbalanceo.

## Herramientas para detectar y controlar

### Amazon Bedrock Guardrails

Aplica **salvaguardas configurables** a las entradas del usuario y a las respuestas del modelo, de forma consistente entre modelos. Se puede usar al invocar un modelo de Bedrock (indicando el ID y la versión del guardrail) o de forma independiente con la API **`ApplyGuardrail`**, incluso para modelos fuera de Bedrock.

| Filtro | Qué hace | Ejemplo |
| --- | --- | --- |
| **Content filters** | Detecta contenido dañino por categorías (Hate, Insults, Sexual, Violence, Misconduct, Prompt Attack) con intensidad configurable, en texto e imágenes | Bloquear insultos en un chat |
| **Denied topics** (temas denegados) | Bloquea temas que defines en lenguaje natural | Un banco que no quiere dar consejos de inversión |
| **Word filters** | Bloquea palabras o frases exactas (incluye lista de groserías) | Nombres de la competencia |
| **Sensitive information filters** | Detecta y **bloquea o enmascara PII** (y patrones propios con regex) | Ocultar números de tarjeta en transcripciones |
| **Contextual grounding checks** | Detecta respuestas no fundamentadas en la fuente o irrelevantes para la pregunta | Bloquear alucinaciones en un RAG |
| **Automated Reasoning checks** | Valida la respuesta contra reglas lógicas formales y señala errores o supuestos | Verificar que una respuesta cumple la política de reembolsos |

Además puedes definir el **mensaje** que ve el usuario cuando se bloquea algo.

### Amazon SageMaker Clarify

Ayuda a **detectar sesgo** y a **explicar predicciones** en modelos de ML:

- **Pre-training bias**: métricas sobre los datos antes de entrenar (por ejemplo, *class imbalance*, desbalanceo entre grupos; diferencia en proporciones de etiquetas positivas).
- **Post-training bias**: métricas sobre las predicciones del modelo por grupo.
- **Explainability**: atribución de importancia de cada *feature* con valores **SHAP** (por qué el modelo decidió esto), a nivel global y por predicción.
- **Evaluación de FMs**: también puede evaluar modelos generativos (exactitud, toxicidad, robustez, estereotipos).

Combinado con **SageMaker Model Monitor**, vigila en producción el **bias drift** (deriva del sesgo) y el **feature attribution drift** (cambios en qué variables pesan).

### Otras prácticas y herramientas

- **Analizar la calidad de las etiquetas** (*label quality*): revisar consistencia entre etiquetadores, por ejemplo con **SageMaker Ground Truth**.
- **Human audits** (auditorías humanas) y **revisión humana** de predicciones de baja confianza con **Amazon Augmented AI (A2I)**.
- **Subgroup analysis**: métricas separadas por grupo.
- **Amazon Bedrock Evaluations**: evaluar modelos en robustez, toxicidad y exactitud antes de elegir uno.

!!! tip "En el examen"
    - "Bloquear temas", "filtrar contenido dañino", "enmascarar PII en prompts y respuestas" → **Bedrock Guardrails**.
    - "Detectar sesgo en datos o modelo", "explicar qué variables influyeron" → **SageMaker Clarify**.
    - "Sesgo que aparece con el tiempo en producción" → **SageMaker Model Monitor** (con Clarify).
    - "Revisión humana de predicciones dudosas" → **Amazon A2I**.

## Selección responsable de un modelo

Además de calidad y costo, la guía pide considerar:

- **Environmental considerations / sustainability** (sostenibilidad): entrenar y servir modelos grandes consume mucha energía. Elige el modelo más pequeño que cumpla, reutiliza FMs en vez de entrenar desde cero, usa distillation, inferencia batch cuando sea posible y hardware eficiente (AWS Trainium e Inferentia, instancias Graviton para tareas no aceleradas). Ver el pilar de sostenibilidad en [Well-Architected](../../../cloud/fundamentos/well-architected.md).
- **Licencias** y origen de los datos de entrenamiento del modelo.
- **AWS AI Service Cards**: documentos de AWS que explican usos previstos, limitaciones y prácticas de diseño responsable de sus servicios y modelos (por ejemplo, Amazon Nova).

## Riesgos legales de la IA generativa

| Riesgo | Qué puede pasar | Mitigación |
| --- | --- | --- |
| **Intellectual property infringement** (infracción de propiedad intelectual) | El contenido generado reproduce material protegido; reclamaciones de autores | Revisar licencias del modelo y de los datos, filtros, revisión humana; algunos proveedores ofrecen indemnización (revisa condiciones) |
| **Biased model outputs** (resultados sesgados) | Discriminación, sanciones regulatorias | Evaluar por subgrupos, Clarify, Guardrails |
| **Loss of customer trust** (pérdida de confianza) | Daño reputacional por respuestas ofensivas o erróneas | Guardrails, transparencia, canales de reporte |
| **End user risk** (riesgo para el usuario final) | Consejos dañinos (médicos, financieros) | Temas denegados, avisos, derivar a una persona |
| **Hallucinations** | Información falsa con consecuencias legales o contractuales | RAG, grounding checks, citas, revisión humana |

Ver cómo se registran y gestionan estos riesgos en [Gobierno y riesgo de TI](../../../negocio/gobierno-riesgo-ti.md).

## Transparencia y explicabilidad

### Modelos transparentes vs opacos

| | Transparentes / interpretables | Opacos (*black box*) |
| --- | --- | --- |
| Ejemplos | Regresión lineal y logística, árboles de decisión pequeños | Redes neuronales profundas, LLMs, *ensembles* grandes |
| Cómo se explican | Se lee directamente (coeficientes, reglas) | Con técnicas *post hoc*: SHAP, PDP (*partial dependence plots*), ejemplos contrafactuales |
| Rendimiento | Suelen rendir menos en problemas complejos | Suelen rendir más |
| Uso típico | Decisiones reguladas | Visión, lenguaje, generación |

- **Interpretability** (interpretabilidad): entender el **mecanismo interno** del modelo.
- **Explainability** (explicabilidad): poder explicar **un resultado** en términos que una persona entienda, aunque el modelo sea opaco.

### Herramientas para la transparencia

- **Amazon SageMaker Model Cards**: documento estandarizado de cada modelo: uso previsto, datos de entrenamiento, métricas de evaluación, riesgos y consideraciones éticas. Sirve para auditoría y gobierno.
- **SageMaker Clarify**: explicaciones con SHAP e informes de sesgo.
- **Amazon Bedrock Evaluations**: resultados de evaluación comparables entre modelos.
- **Open source models, data y licensing**: los modelos abiertos permiten inspeccionar pesos, a veces datos y la licencia; aumentan la transparencia frente a modelos cerrados.

### Trade-offs entre seguridad y transparencia

- Un modelo **más interpretable** puede rendir menos; uno **más potente** suele ser menos explicable. Hay que medir ambos (*interpretability* vs *performance*) y decidir según el riesgo del caso.
- Publicar **todos** los detalles de un modelo (datos, pesos, filtros) aumenta la transparencia pero puede facilitar ataques o *jailbreaks*; ocultarlo todo reduce la confianza. Se busca un equilibrio documentado.

### Diseño centrado en las personas

El **human-centered design** (diseño centrado en las personas) para IA explicable incluye:

- **AI decision transparency**: avisar de que interviene una IA y explicar en lenguaje claro por qué decidió algo.
- **User-feedback mechanisms** (mecanismos de retroalimentación): pulgar arriba/abajo, reportar errores, apelar una decisión.
- Supervisión humana en decisiones de alto impacto (*human-in-the-loop*).
- Explicaciones adaptadas a la audiencia: no es lo mismo un científico de datos que un cliente.

## Casos de uso

1. **Un banco usa un chatbot de GenAI y no quiere que hable de recomendaciones de inversión ni que muestre números de cuenta.** → **Bedrock Guardrails** con un *denied topic* y un filtro de información sensible.
2. **Una empresa de RR. HH. sospecha que su modelo de selección de CVs favorece a un grupo.** → **SageMaker Clarify** para métricas de sesgo pre y post entrenamiento y análisis por subgrupos.
3. **Un regulador pide documentación de cada modelo en producción: uso previsto, datos y métricas.** → **SageMaker Model Cards**.
4. **Una aseguradora debe explicar a cada cliente por qué su prima subió.** → Explicaciones por predicción con **SHAP** (Clarify) o un modelo interpretable.
5. **Un modelo de crédito empezó a rechazar más a un grupo seis meses después del despliegue.** → **Model Monitor** con *bias drift* de Clarify, y reentrenar con datos revisados.
6. **Un equipo debe elegir un FM y quiere minimizar su huella de carbono.** → El modelo más pequeño que cumpla, distillation e inferencia en hardware eficiente.
7. **Un asistente de RAG a veces da información que no está en los documentos.** → **Contextual grounding check** de Guardrails.
8. **Una app de reconocimiento de voz falla más con ciertos acentos.** → Problema de **dataset no inclusivo**: ampliar datos con diversidad de hablantes y evaluar por subgrupo.

## Preguntas de práctica

**1.** Una empresa quiere evitar que su asistente de GenAI responda preguntas sobre política, sin importar qué modelo use. ¿Qué función lo resuelve con menos esfuerzo?

- A. Denied topics de Amazon Bedrock Guardrails
- B. Bajar la temperatura
- C. Fine-tuning del modelo con ejemplos de rechazo
- D. Amazon Macie

??? success "Respuesta"
    **A.** Los temas denegados bloquean temas definidos en lenguaje natural, en entradas y salidas, para cualquier modelo. B no impide temas. C es caro y menos fiable. D busca datos sensibles en S3.

**2.** ¿Qué servicio ayuda a medir el sesgo en un dataset **antes** de entrenar un modelo?

- A. Amazon SageMaker Clarify
- B. Amazon Rekognition
- C. AWS CloudTrail
- D. Amazon Polly

??? success "Respuesta"
    **A.** Clarify calcula métricas de sesgo pre-training. B es visión. C registra llamadas a APIs. D es texto a voz.

**3.** Un modelo de aprobación de préstamos tiene 95% de accuracy global, pero 70% para solicitantes de una región. ¿Qué práctica habría detectado el problema?

- A. Aumentar el tamaño del endpoint
- B. Análisis por subgrupos
- C. Subir la temperatura
- D. Cambiar a inferencia batch

??? success "Respuesta"
    **B.** Medir por subgrupo revela diferencias que la métrica global oculta. A, C y D no tienen relación con la equidad.

**4.** ¿Qué documento de SageMaker AI registra el uso previsto, los datos de entrenamiento y las métricas de un modelo para auditoría?

- A. SageMaker Model Cards
- B. SageMaker Feature Store
- C. SageMaker Data Wrangler
- D. SageMaker JumpStart

??? success "Respuesta"
    **A.** Model Cards es documentación de gobierno del modelo. B guarda features. C prepara datos. D ofrece modelos preentrenados.

**5.** (Elige dos) ¿Qué son riesgos legales propios de la IA generativa?

- A. Reclamaciones por infracción de propiedad intelectual en contenido generado
- B. Cold start de un endpoint serverless
- C. Alucinaciones que inducen a error a un cliente
- D. Uso de instancias Graviton
- E. Baja latencia

??? success "Respuesta"
    **A y C.** IP y alucinaciones con consecuencias son riesgos legales. B y E son de rendimiento. D es una elección de hardware.

**6.** Una organización necesita que un modelo sea fácilmente interpretable por un regulador, aunque pierda algo de rendimiento. ¿Qué modelo encaja mejor?

- A. Una red neuronal profunda de 50 capas
- B. Un árbol de decisión de poca profundidad
- C. Un LLM de propósito general
- D. Un modelo de difusión

??? success "Respuesta"
    **B.** Un árbol pequeño se explica leyendo sus reglas. A y C son opacos. D genera imágenes.

**7.** ¿Qué práctica de diseño centrado en las personas mejora la transparencia de un sistema de IA?

- A. Ocultar que las respuestas las genera una IA
- B. Ofrecer al usuario un mecanismo para reportar respuestas incorrectas y saber que habla con una IA
- C. Eliminar la revisión humana para ganar velocidad
- D. Usar siempre el modelo más grande disponible

??? success "Respuesta"
    **B.** Transparencia y retroalimentación son principios del diseño centrado en las personas. A y C los contradicen. D no tiene relación.

## Para profundizar

| Tema | Nota del cuaderno |
| --- | --- |
| Sostenibilidad y pilares de diseño | [Well-Architected Framework](../../../cloud/fundamentos/well-architected.md) |
| Gestión de riesgo, proveedores y licencias | [Gobierno y riesgo de TI](../../../negocio/gobierno-riesgo-ti.md) |
| Marcos de cumplimiento | [Cumplimiento y gobierno](../../../devsecops/gobierno-y-respuesta/cumplimiento.md) |
| Riesgo y threat modeling | [Fundamentos DevSecOps](../../../devsecops/fundamentos-devsecops.md) |
| Dominio anterior y siguiente | [Dominio 3](dominio-3-aplicaciones-modelos-fundacionales.md) · [Dominio 5](dominio-5-seguridad-cumplimiento-gobierno.md) |

## Referencias

- [Exam guide AIF-C01 – Domain 4](https://docs.aws.amazon.com/aws-certification/latest/ai-practitioner-01/ai-practitioner-01-domain4.html)
- [IA responsable en AWS](https://aws.amazon.com/ai/responsible-ai/)
- [Amazon Bedrock Guardrails](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html)
- [Amazon SageMaker Clarify](https://docs.aws.amazon.com/sagemaker/latest/dg/clarify-configure-processing-jobs.html)
- [Amazon SageMaker Model Cards](https://docs.aws.amazon.com/sagemaker/latest/dg/model-cards.html)
- [AWS AI Service Cards](https://aws.amazon.com/ai/responsible-ai/resources/)
- [Amazon Augmented AI (A2I)](https://docs.aws.amazon.com/sagemaker/latest/dg/a2i-use-augmented-ai-a2i-human-review-loops.html)
