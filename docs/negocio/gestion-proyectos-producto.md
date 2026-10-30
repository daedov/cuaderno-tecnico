---
tags:
  - negocio
  - agile
  - producto
---

# Proyectos y producto en TI

> Waterfall vs agile, Scrum y Kanban, la diferencia entre gestionar proyectos y gestionar productos, roadmaps, técnicas de priorización (MoSCoW, RICE, Cost of Delay), estimación y la deuda técnica como decisión de negocio.

## ¿Qué es?

Todo trabajo técnico compite por el mismo recurso escaso: el tiempo del equipo. Esta nota recoge cómo se organiza ese trabajo y cómo se decide qué va primero, en el vocabulario que usan managers, Product Owners y PMOs (*Project Management Office*, oficina de gestión de proyectos).

## Waterfall vs agile

| | **Waterfall** (cascada) | **Agile** (ágil) |
| --- | --- | --- |
| Idea | Planificar todo al inicio y ejecutar por fases | Entregar en ciclos cortos y ajustar con lo aprendido |
| Fases | Requisitos → diseño → construcción → pruebas → despliegue, una tras otra | Todas las fases en cada iteración |
| Cambios | Caros; pasan por control de cambios | Esperados y bienvenidos |
| Entrega de valor | Al final | Incremental, desde las primeras semanas |
| Riesgo | Se descubre tarde | Se descubre pronto |
| Encaja con | Alcance fijo y conocido, contratos cerrados, regulación estricta, obra física | Incertidumbre, producto digital, requisitos que cambian |

El **Manifiesto Ágil** (2001) resume la idea en cuatro valores: individuos e interacciones sobre procesos y herramientas; software funcionando sobre documentación extensiva; colaboración con el cliente sobre negociación contractual; respuesta ante el cambio sobre seguir un plan. "Sobre" no significa "en lugar de": lo de la derecha también tiene valor.

!!! note "Lo híbrido es lo normal"
    Muchas organizaciones fijan presupuesto y fecha a nivel de programa (estilo waterfall) y trabajan en sprints dentro de él. Una migración a la nube, por ejemplo, suele tener hitos fijos (fin del contrato del centro de datos) y ejecución iterativa por oleadas.

## Scrum y Kanban

La [nota de cultura DevOps](../devops/fundamentos/cultura-metricas-dora.md#devops-y-agile) presenta ambos marcos; aquí, lo que necesitas para trabajar con ellos.

=== "Scrum"

    Según la Scrum Guide 2020:

    - **Roles** (*accountabilities*): **Product Owner** (maximiza el valor y ordena el backlog), **Scrum Master** (ayuda al equipo a aplicar Scrum y quita impedimentos) y **Developers** (todas las personas que construyen el incremento, no solo quien programa).
    - **Eventos**: el **Sprint** (máximo un mes), **Sprint Planning**, **Daily Scrum** (15 minutos), **Sprint Review** y **Sprint Retrospective**.
    - **Artefactos**: **Product Backlog** (con su *Product Goal*), **Sprint Backlog** (con su *Sprint Goal*) e **Increment** (con la *Definition of Done*).

=== "Kanban"

    - Tablero visible con columnas que reflejan el flujo real (por hacer, en curso, en revisión, hecho).
    - **WIP limits** (límites de trabajo en curso) por columna: no empiezas algo nuevo hasta terminar.
    - Métricas de flujo: **lead time** (desde que se pide hasta que se entrega), **cycle time** (desde que se empieza hasta que se entrega), **throughput** (elementos terminados por semana).
    - Sin iteraciones fijas: encaja con equipos de plataforma, operación y soporte, donde el trabajo llega sin aviso.

## Proyecto vs producto

| | **Proyecto** | **Producto** |
| --- | --- | --- |
| Duración | Inicio y fin definidos | Continuo mientras aporte valor |
| Éxito | Entregar el alcance a tiempo y en presupuesto | Resultados: uso, ingresos, satisfacción |
| Equipo | Se forma y se disuelve | Estable, con responsabilidad de largo plazo |
| Financiamiento | Por proyecto | Por equipo o capacidad, de forma recurrente |
| Después del lanzamiento | Pasa a "mantenimiento" (a menudo, a otro equipo) | El mismo equipo lo opera y mejora ("*you build it, you run it*") |

Las organizaciones que adoptan DevOps tienden a pasar de proyectos a **productos**, también para lo interno: la plataforma de despliegue o la plataforma de datos se gestionan como productos con sus "clientes" internos, un roadmap y métricas de adopción.

## Roadmap

Un **roadmap** (hoja de ruta) comunica **hacia dónde** va un producto o una plataforma y **por qué**, no una lista de tareas con fechas exactas.

Un formato muy usado es **Now / Next / Later** (ahora / después / más adelante):

| Now (este trimestre) | Next (siguiente) | Later (exploración) |
| --- | --- | --- |
| Pipeline estándar con escaneo de seguridad | Entornos efímeros por pull request | Autoservicio de bases de datos |
| SLOs para los 5 servicios más críticos | Alertas por burn rate en todos los servicios | Chaos engineering en producción |

Cuanto más lejos, menos detalle y menos compromiso. Si te piden fechas para "Later", explica el nivel de incertidumbre.

## Priorización

### MoSCoW

Técnica creada en el marco DSDM (hoy mantenido por el Agile Business Consortium) que clasifica los requisitos de una entrega en cuatro grupos:

| Categoría | Significado |
| --- | --- |
| **Must have** | Imprescindible: sin esto la entrega no sirve o no es legal |
| **Should have** | Importante, pero hay alternativa temporal |
| **Could have** | Deseable si sobra tiempo |
| **Won't have (this time)** | Acordado que **no** entra ahora |

Simple y útil para negociar alcance con una fecha fija. Su riesgo: que todo acabe en "Must".

### RICE

Puntuación propuesta por Intercom para comparar iniciativas:

```text
RICE = (Reach × Impact × Confidence) / Effort
```

| Factor | Qué mide | Escala habitual |
| --- | --- | --- |
| **Reach** (alcance) | Cuántas personas o eventos afecta en un periodo | Número (por ejemplo, usuarios por trimestre) |
| **Impact** (impacto) | Cuánto mejora para cada uno | 3 = masivo, 2 = alto, 1 = medio, 0,5 = bajo, 0,25 = mínimo |
| **Confidence** (confianza) | Qué tan seguros estamos de las estimaciones | 100 %, 80 %, 50 % |
| **Effort** (esfuerzo) | Trabajo necesario | Personas-mes |

| Iniciativa | Reach | Impact | Confidence | Effort | RICE |
| --- | --- | --- | --- | --- | --- |
| Entornos efímeros por PR | 60 devs | 2 | 80 % | 3 | 60 × 2 × 0,8 / 3 = **32** |
| Portal de autoservicio | 60 devs | 1 | 50 % | 4 | 60 × 1 × 0,5 / 4 = **7,5** |
| Plantilla de pipeline | 60 devs | 1 | 100 % | 1 | 60 × 1 × 1 / 1 = **60** |

El resultado ordena la conversación, no la sustituye.

### Cost of Delay

El **Cost of Delay** (costo del retraso) responde: **¿cuánto perdemos por cada semana que esto no está?** Pone a todo en la misma unidad (dinero por tiempo), lo que permite comparar una funcionalidad nueva con pagar deuda técnica o con un requisito regulatorio.

Para ordenar se usa el **CD3** (*Cost of Delay Divided by Duration*): costo del retraso dividido por la duración del trabajo. Primero va lo que más valor "libera" por semana de trabajo. SAFe usa una variante llamada **WSJF** (*Weighted Shortest Job First*).

| Iniciativa | Costo del retraso por semana | Duración | CD3 |
| --- | --- | --- | --- |
| A: integración con un nuevo medio de pago | 10 000 | 5 semanas | 2 000 |
| B: corregir un cuello de botella del checkout | 6 000 | 1 semana | **6 000** |

B va primero aunque A "valga" más en total: se termina antes y empieza a generar valor de inmediato.

## Estimación

| Técnica | Cómo funciona | Para qué |
| --- | --- | --- |
| **Story points** (puntos de historia) | Tamaño relativo (complejidad, incertidumbre), a menudo con una serie tipo Fibonacci | Planificar sprints con la velocidad histórica del equipo |
| **T-shirt sizing** (tallas de camiseta) | XS, S, M, L, XL | Estimaciones rápidas de un roadmap |
| **Planning poker** | Cada persona estima en secreto y se discuten las diferencias | Detectar supuestos distintos |
| **Three-point estimate** (estimación de tres puntos) | Optimista (O), más probable (M), pesimista (P): `(O + 4M + P) / 6` | Comunicar un rango, no un número |
| **Forecasting con datos de flujo** | Usar el throughput histórico para estimar fechas con probabilidades | Equipos Kanban; reemplaza estimar cada tarea |

!!! tip "Comunica rangos y supuestos"
    "Entre 4 y 7 semanas, suponiendo que el equipo de redes abre los puertos la primera semana" es más honesto y más útil que "5 semanas". Al inicio de un proyecto la incertidumbre es mayor y se reduce a medida que avanza (el **cone of uncertainty**, cono de incertidumbre).

## Deuda técnica como decisión de negocio

La **deuda técnica** (*technical debt*), metáfora de Ward Cunningham, es el costo futuro de elegir hoy una solución más rápida en vez de una mejor. Como la deuda financiera, tiene **intereses**: cada cambio sobre ese código o esa infraestructura cuesta más.

Martin Fowler la clasifica en un cuadrante:

| | **Deliberada** | **Inadvertida** |
| --- | --- | --- |
| **Prudente** | "Lanzamos ya y lo refactorizamos el próximo trimestre" | "Ahora sabemos cómo deberíamos haberlo diseñado" |
| **Imprudente** | "No hay tiempo para diseño" | "¿Qué es una arquitectura en capas?" |

Cómo hablar de deuda técnica con negocio:

1. **No digas "código feo"**: habla de su **interés**. "Cada cambio en el módulo de facturación tarda 3 veces más y genera el 40 % de los incidentes."
2. **Ponle número**: horas perdidas por sprint, incidentes asociados, riesgo (versiones sin soporte, vulnerabilidades sin parche).
3. **Prioriza con el mismo método** que el resto del backlog (Cost of Delay, RICE), no en una lista aparte que nunca se mira.
4. **Reserva capacidad** de forma explícita (por ejemplo, un porcentaje de cada sprint) y acuérdalo con el Product Owner.
5. **Registra la deuda deliberada** cuando la tomas, con su motivo; así es una decisión, no un accidente.

!!! warning "Deuda en infraestructura y seguridad"
    También es deuda: un clúster de Kubernetes en una versión sin soporte, recursos creados a mano fuera de IaC, imágenes base sin actualizar, dependencias con vulnerabilidades conocidas. Suelen tener fecha de vencimiento (fin de soporte del proveedor) y un riesgo de seguridad medible ([Cadena de suministro](../devsecops/codigo-y-dependencias/cadena-suministro.md)).

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Negocio TI (el porqué) | Business case, OKRs y riesgo para decidir qué entra en el roadmap | [TI y negocio](ti-y-negocio.md), [Métricas, KPIs y OKRs](metricas-kpis-okrs.md), [Gobierno y riesgo de TI](gobierno-riesgo-ti.md) |
| Cloud (el control) | Migraciones y modernización como proyectos con oleadas e hitos | [Well-Architected Framework](../cloud/fundamentos/well-architected.md), [FinOps y costos](../cloud/fundamentos/finops-costos.md) |
| DevOps (la automatización) | Agile, Kanban y lotes pequeños; cómo se mide el flujo de entrega | [Cultura DevOps y métricas DORA](../devops/fundamentos/cultura-metricas-dora.md), [Git y control de versiones](../devops/fundamentos/git-control-versiones.md), [Despliegue continuo](../devops/ci-cd/despliegue-continuo.md) |
| DevSecOps (la verificación) | Deuda de seguridad: vulnerabilidades y dependencias sin actualizar | [Cadena de suministro](../devsecops/codigo-y-dependencias/cadena-suministro.md), [Fundamentos DevSecOps](../devsecops/fundamentos-devsecops.md) |

## Referencias

- [Manifiesto Ágil (español)](https://agilemanifesto.org/iso/es/manifesto.html)
- [The Scrum Guide 2020 (español)](https://scrumguides.org/docs/scrumguide/v2020/2020-Scrum-Guide-Spanish-European.pdf)
- [The Kanban Guide](https://kanbanguides.org/)
- [Intercom: RICE prioritization](https://www.intercom.com/blog/rice-simple-prioritization-for-product-managers/)
- [Black Swan Farming: Cost of Delay](https://blackswanfarming.com/cost-of-delay/)
- [Martin Fowler: Technical Debt Quadrant](https://martinfowler.com/bliki/TechnicalDebtQuadrant.html)
