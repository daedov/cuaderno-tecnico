---
tags:
  - negocio
  - metricas
  - dora
---

# Métricas, KPIs y OKRs

> La diferencia entre una métrica y un KPI, cómo se escriben OKRs (con un ejemplo de equipo de plataforma), DORA y SPACE en una línea, la North Star metric, métricas vanity vs accionables y cómo presentar métricas a negocio.

## ¿Qué es?

Medir sirve para **decidir**. Una organización mide muchas cosas, pero solo unas pocas le dicen si va bien o mal respecto a lo que quiere lograr. Esta nota ordena ese vocabulario para que puedas hablar de números con managers y negocio sin perderte.

## Métricas y KPIs

| | **Métrica** | **KPI** (*Key Performance Indicator*, indicador clave de desempeño) |
| --- | --- | --- |
| Qué es | Cualquier valor que se mide | Una métrica elegida porque refleja el avance hacia un objetivo importante |
| Cantidad | Cientos o miles | Pocos (3–7 por equipo o área) |
| Tiene objetivo | No necesariamente | Sí: un valor meta y un responsable |
| Ejemplo | Uso de CPU, número de pods, tickets abiertos | Disponibilidad mensual del checkout ≥ 99,9 %, costo de nube por cliente activo |

Todo KPI es una métrica, pero muy pocas métricas son KPIs.

### Tipos de indicadores

- **Leading indicators** (indicadores adelantados): anticipan un resultado y se pueden influir. Ejemplo: porcentaje de servicios con SLO definido, cobertura de alertas.
- **Lagging indicators** (indicadores rezagados): muestran el resultado cuando ya pasó. Ejemplo: horas de caída del trimestre, ingresos perdidos por incidentes.

Un buen tablero combina ambos: los rezagados dicen si llegaste; los adelantados, si vas a llegar.

### KPIs típicos de TI

| Área | KPI de ejemplo |
| --- | --- |
| Servicio | Cumplimiento de SLA, MTTR, incidentes SEV1 por mes ([Niveles de servicio](niveles-de-servicio.md)) |
| Entrega | Métricas DORA ([Cultura DevOps y métricas DORA](../devops/fundamentos/cultura-metricas-dora.md)) |
| Costos | Costo de nube por cliente o por transacción (*unit economics*), % del gasto con tags ([FinOps y costos](../cloud/fundamentos/finops-costos.md)) |
| Seguridad | Tiempo medio de remediación de vulnerabilidades críticas, % de cuentas con MFA ([Detección y respuesta](../devsecops/gobierno-y-respuesta/deteccion-respuesta.md)) |
| Soporte | Tiempo de primera respuesta, satisfacción del usuario |

## OKRs

Los **OKRs** (*Objectives and Key Results*, objetivos y resultados clave) son un método para fijar metas popularizado por Andy Grove en Intel y John Doerr en Google.

- **Objective** (objetivo): **qué** quieres lograr. Cualitativo, inspirador, con un plazo (normalmente un trimestre).
- **Key results** (resultados clave): **cómo sabrás** que lo lograste. 2 a 5 por objetivo, medibles, con valor inicial y meta.

!!! warning "Un key result no es una tarea"
    "Migrar el CI a GitHub Actions" es una **iniciativa** (algo que haces). Un key result es un **resultado** medible: "el tiempo medio del pipeline baja de 25 a 10 minutos". La migración puede ser una forma de lograrlo, o no.

### Ejemplo: equipo de plataforma

```text
Objetivo: Que los equipos de producto desplieguen solos, rápido y con seguridad

KR1: El lead time de cambios medio baja de 3 días a menos de 1 día.
KR2: El 80 % de los servicios despliega con el pipeline estándar (hoy, 35 %).
KR3: Los tickets "necesito un entorno" bajan de 40 a menos de 10 al mes.
KR4: La satisfacción con la plataforma en la encuesta interna pasa de 6,1 a 7,5 sobre 10.

Iniciativas (no son KRs):
- Plantilla de pipeline reutilizable con escaneos de seguridad incluidos.
- Entornos efímeros por pull request.
- Documentación de autoservicio en el portal interno.
```

Cómo se usa:

- **Revisión** a mitad y al final del trimestre. Una puntuación de 0 a 1 por KR es habitual; con OKRs ambiciosos, llegar a 0,6–0,7 se considera un buen resultado.
- **Committed vs aspirational**: algunos OKRs son compromisos (hay que cumplirlos al 100 %) y otros son apuestas ambiciosas. Hay que decir cuál es cuál.
- Los OKRs **no se usan para evaluar personas**: si penalizas no llegar, la gente propondrá metas fáciles.

## DORA y SPACE en una línea

| Marco | En una línea |
| --- | --- |
| **DORA** | Cinco métricas del **sistema de entrega**: frecuencia de despliegue, change lead time, change failure rate, failed deployment recovery time y deployment rework rate. Detalle en [Cultura DevOps y métricas DORA](../devops/fundamentos/cultura-metricas-dora.md). |
| **SPACE** | Marco de 2021 (Forsgren y otros) para la **productividad de quienes desarrollan**, en cinco dimensiones: **S**atisfaction and well-being, **P**erformance, **A**ctivity, **C**ommunication and collaboration, **E**fficiency and flow; propone combinar métricas de varias dimensiones y nunca usar solo una. |

## North Star metric

La **North Star metric** (métrica estrella del norte) es **una** métrica que resume el valor que el producto entrega a sus clientes y que, si sube, el negocio crece a largo plazo.

| Producto | North Star posible |
| --- | --- |
| Plataforma de streaming | Horas de contenido vistas por semana |
| Marketplace | Transacciones completadas |
| Plataforma interna de desarrollo | Despliegues a producción hechos con autoservicio |
| SaaS B2B | Cuentas que usan la funcionalidad clave cada semana |

No reemplaza a los KPIs: los ordena. Cada equipo puede preguntarse "¿qué de lo que hago mueve la North Star?".

## Métricas vanity vs accionables

| | **Vanity metrics** (métricas de vanidad) | **Actionable metrics** (métricas accionables) |
| --- | --- | --- |
| Qué son | Números que se ven bien pero no ayudan a decidir | Números que cambian una decisión si suben o bajan |
| Suelen ser | Totales acumulados que solo crecen | Tasas, proporciones, comparaciones por cohorte o periodo |
| Ejemplos en TI | Número total de despliegues desde siempre, líneas de código, número de alertas configuradas, tickets cerrados | Change failure rate del mes, % de alertas que requirieron acción, tiempo de resolución por severidad |

Una pregunta rápida para distinguirlas: **"si este número cambia, ¿qué haría distinto?"**. Si la respuesta es "nada", es vanidad.

!!! danger "Ley de Goodhart"
    "Cuando una medida se convierte en objetivo, deja de ser una buena medida." Si premias tickets cerrados, se cierran tickets sin resolver; si premias despliegues, aparecen despliegues vacíos. Combina métricas que se equilibren entre sí (velocidad con estabilidad, costo con disponibilidad).

## Cómo presentar métricas a negocio

1. **Empieza por la conclusión**: "Cumplimos el SLA de pagos los tres meses; el costo por transacción bajó un 12 %." Después los datos.
2. **Traduce a dinero, riesgo o clientes**: "4 horas de caída" se entiende mejor como "unas 13 000 en ventas perdidas y 1 200 clientes afectados".
3. **Muestra tendencia y meta**: un valor aislado no dice nada. Usa una línea con los últimos 6–12 meses y la meta marcada.
4. **Pocos números**: 3 a 5 KPIs en una página. El detalle técnico, en un anexo o en el dashboard del equipo.
5. **Explica los saltos**: si un indicador empeoró, di por qué y qué vas a hacer.
6. **Mismo formato cada vez**: misma estructura cada mes para que se pueda comparar sin esfuerzo.
7. **Sé honesta con la calidad del dato**: si una métrica se mide de forma aproximada, dilo.

```text
Informe mensual de plataforma (ejemplo de estructura)

1. Resumen en 3 líneas
2. Servicio: cumplimiento de SLO/SLA y error budget restante (semáforo)
3. Entrega: métricas DORA, tendencia de 6 meses
4. Costos: gasto vs presupuesto, costo por unidad de negocio
5. Riesgos y decisiones que necesitamos
```

!!! tip "Semáforo con criterio"
    Un semáforo (verde, amarillo, rojo) es útil para dirección, pero define los umbrales antes y por escrito; si no, todo termina en amarillo.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Negocio TI (el porqué) | De dónde salen los objetivos y cómo se miden servicios y proyectos | [TI y negocio](ti-y-negocio.md), [Niveles de servicio](niveles-de-servicio.md), [Proyectos y producto en TI](gestion-proyectos-producto.md) |
| Cloud (el control) | Métricas de costo por unidad y datos de uso de la nube | [FinOps y costos](../cloud/fundamentos/finops-costos.md), [Observabilidad nativa](../monitoreo/nube/observabilidad-nativa.md) |
| DevOps (la automatización) | Métricas DORA, SLIs y los datos del pipeline | [Cultura DevOps y métricas DORA](../devops/fundamentos/cultura-metricas-dora.md), [Observabilidad](../monitoreo/fundamentos/observabilidad.md) |
| DevSecOps (la verificación) | KPIs de seguridad: remediación de vulnerabilidades, cumplimiento de controles | [Detección y respuesta](../devsecops/gobierno-y-respuesta/deteccion-respuesta.md), [Cumplimiento y gobierno](../devsecops/gobierno-y-respuesta/cumplimiento.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 11: Observabilidad con Prometheus y Grafana](../laboratorios/devops/observabilidad-prometheus-grafana.md) |

## Referencias

- [DORA: métricas de entrega de software](https://dora.dev/guides/dora-metrics/)
- [The SPACE of Developer Productivity (ACM Queue)](https://queue.acm.org/detail.cfm?id=3454124)
- [What Matters: OKRs](https://www.whatmatters.com/faqs/okr-meaning-definition-example)
- [Google re:Work: establece metas con OKRs](https://rework.withgoogle.com/es/guides/set-goals-with-okrs/)
- [Atlassian: KPIs vs OKRs](https://www.atlassian.com/es/agile/agile-at-scale/okr)
