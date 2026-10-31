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

La **responsible AI** (IA responsable) son las prácticas para que un sistema de IA sea útil **sin causar daño**, aplicadas en todo el ciclo (datos, entrenamiento, evaluación, despliegue, monitoreo). Dimensiones según AWS:

| Dimensión | Qué significa | Ejemplo de fallo |
| --- | --- | --- |
| **Fairness** (equidad) | Resultados equitativos entre grupos | Un modelo de crédito rechaza más a un grupo por su código postal |
| **Explainability** (explicabilidad) | Entender y explicar por qué produjo un resultado | Nadie sabe justificar un rechazo ante el regulador |
| **Privacy and security** | Proteger los datos y el modelo | El chatbot revela datos de otro cliente |
| **Safety** (no causar daño) | Evitar contenido o acciones dañinas | El asistente da instrucciones peligrosas |
| **Controllability** | Supervisar y dirigir el comportamiento | Un agente actúa sin posibilidad de detenerlo |
| **Veracity and robustness** | Resultados correctos y estables, incluso con entradas adversarias | Alucinaciones; un cambio mínimo en la entrada cambia la decisión |
| **Governance** | Procesos, roles y responsables definidos | Nadie aprobó poner el modelo en producción |
| **Transparency** | Comunicar qué hace, sus límites y que es una IA | El usuario no sabe que habla con un bot |

La guía añade **inclusivity** (inclusividad): que funcione para personas diversas (idiomas, acentos, capacidades).

## Sesgo y varianza

El **bias** (sesgo) casi siempre entra por los **datos** o por cómo se define el problema:

| Tipo | Qué ocurre | Ejemplo |
| --- | --- | --- |
| **Sampling bias** (de muestreo) | Los datos no representan a toda la población | Voz entrenada casi solo con un acento |
| **Historical bias** (histórico) | Los datos reflejan decisiones injustas del pasado | Contrataciones que favorecían a un género |
| **Measurement / label bias** | Etiquetas inconsistentes o subjetivas | Etiquetadores que califican distinto el mismo comentario |
| **Confirmation bias** | Se eligen datos que confirman lo esperado | Solo métricas que favorecen al modelo |
| **Automation bias** | Las personas confían en exceso en el sistema | Aprobar sin revisar lo que propone la IA |

**Efectos**: un modelo puede tener buena accuracy global y fallar mucho más en un subgrupo (por eso se hace **subgroup analysis**); el **overfitting** (alta varianza) memoriza también los patrones sesgados, y el **underfitting** (alto sesgo estadístico) falla para todos, a menudo más para los grupos minoritarios. Ver [overfitting y underfitting en el Dominio 1](dominio-1-fundamentos-ia-ml.md#overfitting-y-underfitting).

**Un buen dataset** es **inclusivo y diverso** (representa todos los grupos y situaciones reales), viene de **curated data sources** (origen conocido, limpio y con permisos) y está **balanceado** (o se compensa el desbalanceo).

## Herramientas para detectar y controlar

### Amazon Bedrock Guardrails

Aplica **salvaguardas configurables** a las entradas y respuestas, de forma consistente entre modelos. Se usa al invocar un modelo de Bedrock (indicando ID y versión del guardrail) o de forma independiente con la API **`ApplyGuardrail`**, incluso para modelos fuera de Bedrock. Puedes definir el **mensaje** que ve el usuario cuando se bloquea algo.

| Filtro | Qué hace | Ejemplo |
| --- | --- | --- |
| **Content filters** | Contenido dañino por categorías (Hate, Insults, Sexual, Violence, Misconduct, Prompt Attack) con intensidad configurable, en texto e imágenes | Bloquear insultos en un chat |
| **Denied topics** | Bloquea temas que defines en lenguaje natural | Un banco que no da consejos de inversión |
| **Word filters** | Palabras o frases exactas (incluye lista de groserías) | Nombres de la competencia |
| **Sensitive information filters** | Detecta y **bloquea o enmascara PII** (y regex propios) | Ocultar números de tarjeta |
| **Contextual grounding checks** | Respuestas no fundamentadas en la fuente o irrelevantes | Bloquear alucinaciones en un RAG |
| **Automated Reasoning checks** | Valida la respuesta contra reglas lógicas formales | Verificar que cumple la política de reembolsos |

### Amazon SageMaker Clarify

- **Pre-training bias**: métricas sobre los datos antes de entrenar (*class imbalance*, diferencia en proporciones de etiquetas positivas).
- **Post-training bias**: métricas sobre las predicciones por grupo.
- **Explainability**: importancia de cada *feature* con valores **SHAP**, global y por predicción.
- **Evaluación de FMs**: exactitud, toxicidad, robustez, estereotipos.

Con **SageMaker Model Monitor** vigila en producción el **bias drift** y el **feature attribution drift**. Otras prácticas: revisar **label quality** (consistencia entre etiquetadores, con **SageMaker Ground Truth**), **human audits** y revisión humana de predicciones de baja confianza con **Amazon Augmented AI (A2I)**, **subgroup analysis** y **Bedrock Evaluations** (robustez, toxicidad y exactitud antes de elegir modelo).

!!! tip "En el examen"
    - "Bloquear temas", "filtrar contenido dañino", "enmascarar PII en prompts y respuestas" → **Bedrock Guardrails**.
    - "Detectar sesgo en datos o modelo", "explicar qué variables influyeron" → **SageMaker Clarify**.
    - "Sesgo que aparece con el tiempo en producción" → **SageMaker Model Monitor** (con Clarify).
    - "Revisión humana de predicciones dudosas" → **Amazon A2I**.

## Selección responsable de un modelo

- **Sustainability** (sostenibilidad): el modelo más pequeño que cumpla, reutilizar FMs en vez de entrenar desde cero, distillation, inferencia batch y hardware eficiente (Trainium, Inferentia, Graviton). Ver el pilar de sostenibilidad en [Well-Architected](../../../cloud/fundamentos/well-architected.md).
- **Licencias** y origen de los datos de entrenamiento.
- **AWS AI Service Cards**: documentos de AWS con usos previstos, limitaciones y prácticas de diseño responsable de sus servicios y modelos (por ejemplo, Amazon Nova).

## Riesgos legales de la IA generativa

| Riesgo | Qué puede pasar | Mitigación |
| --- | --- | --- |
| **Intellectual property infringement** | El contenido reproduce material protegido | Revisar licencias, filtros, revisión humana; algunos proveedores ofrecen indemnización (revisa condiciones) |
| **Biased model outputs** | Discriminación, sanciones | Evaluar por subgrupos, Clarify, Guardrails |
| **Loss of customer trust** | Daño reputacional | Guardrails, transparencia, canales de reporte |
| **End user risk** | Consejos dañinos (médicos, financieros) | Temas denegados, avisos, derivar a una persona |
| **Hallucinations** | Información falsa con consecuencias legales | RAG, grounding checks, citas, revisión humana |

Gestión de estos riesgos: [Gobierno y riesgo de TI](../../../negocio/gobierno-riesgo-ti.md).

## Transparencia y explicabilidad

| | Transparentes / interpretables | Opacos (*black box*) |
| --- | --- | --- |
| Ejemplos | Regresión lineal y logística, árboles pequeños | Redes neuronales profundas, LLMs, *ensembles* grandes |
| Cómo se explican | Se leen directamente (coeficientes, reglas) | Técnicas *post hoc*: SHAP, PDP, contrafactuales |
| Rendimiento | Menor en problemas complejos | Mayor |
| Uso típico | Decisiones reguladas | Visión, lenguaje, generación |

**Interpretability** es entender el **mecanismo interno**; **explainability** es explicar **un resultado** en términos que una persona entienda, aunque el modelo sea opaco.

**Herramientas**: **SageMaker Model Cards** (uso previsto, datos, métricas, riesgos y consideraciones éticas; para auditoría y gobierno), **SageMaker Clarify** (SHAP e informes de sesgo), **Bedrock Evaluations** (resultados comparables) y **modelos, datos y licencias abiertos** (permiten inspeccionar pesos y licencia).

**Trade-offs**: un modelo más interpretable puede rendir menos (*interpretability* vs *performance*); publicar todos los detalles (datos, pesos, filtros) aumenta la transparencia pero puede facilitar ataques o *jailbreaks*. Se busca un equilibrio documentado según el riesgo del caso.

**Human-centered design** (diseño centrado en las personas): avisar de que interviene una IA y explicar en lenguaje claro (*AI decision transparency*), **user-feedback mechanisms** (pulgar arriba/abajo, reportar, apelar), supervisión humana en decisiones de alto impacto y explicaciones adaptadas a la audiencia.

## Casos de uso

1. Chatbot de banco que no debe recomendar inversiones ni mostrar números de cuenta → **Guardrails**: *denied topic* + filtro de información sensible.
2. Modelo de selección de CVs que parece favorecer a un grupo → **SageMaker Clarify** (sesgo pre y post entrenamiento, subgrupos).
3. Regulador que pide documentación de cada modelo → **SageMaker Model Cards**.
4. Explicar a cada cliente por qué subió su prima → **SHAP** (Clarify) o un modelo interpretable.
5. Modelo de crédito que rechaza más a un grupo seis meses después → **Model Monitor** con *bias drift* y reentrenar.
6. Elegir un FM minimizando la huella de carbono → modelo más pequeño, distillation, hardware eficiente.
7. Asistente de RAG que da información que no está en los documentos → **contextual grounding check**.
8. Reconocimiento de voz que falla con ciertos acentos → **dataset no inclusivo**: ampliar diversidad y evaluar por subgrupo.

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
| Guardrails y filtros en AWS, Azure y GCP | [Seguridad de servicios de IA generativa](../../../cloud/seguridad/seguridad-servicios-ia.md) |
| Dominio anterior y siguiente | [Dominio 3](dominio-3-aplicaciones-modelos-fundacionales.md) · [Dominio 5](dominio-5-seguridad-cumplimiento-gobierno.md) |

## Referencias

- [Exam guide AIF-C01 – Domain 4](https://docs.aws.amazon.com/aws-certification/latest/ai-practitioner-01/ai-practitioner-01-domain4.html)
- [IA responsable en AWS](https://aws.amazon.com/ai/responsible-ai/)
- [Amazon Bedrock Guardrails](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html)
- [Amazon SageMaker Clarify](https://docs.aws.amazon.com/sagemaker/latest/dg/clarify-configure-processing-jobs.html)
- [Amazon SageMaker Model Cards](https://docs.aws.amazon.com/sagemaker/latest/dg/model-cards.html)
- [AWS AI Service Cards](https://aws.amazon.com/ai/responsible-ai/resources/)
