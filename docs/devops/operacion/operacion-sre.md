---
tags:
  - sre
  - observabilidad
  - incidentes
---

# Operación y fiabilidad (SRE)

> Principios de *Site Reliability Engineering*, política de error budget, severidades y ciclo de vida de un incidente, guardias sostenibles y capacity planning, con el mapa de las notas que desarrollan cada práctica (postmortem, runbooks, comunicación, chaos engineering).

## ¿Qué es?

**SRE** (*Site Reliability Engineering*, ingeniería de fiabilidad de sitios) es la forma en que Google empezó a operar sus servicios en producción: tratar la operación como un problema de **ingeniería de software**. Ben Treynor Sloss, que lo creó, lo resume como "lo que pasa cuando le pides a un ingeniero de software que diseñe un equipo de operaciones".

DevOps describe una cultura y unas prácticas; SRE es una forma concreta de llevarlas a cabo, con métricas (SLOs), límites (error budget) y prácticas definidas. Google lo expresa como *"class SRE implements interface DevOps"*. Ver [Cultura DevOps y métricas DORA](../fundamentos/cultura-metricas-dora.md).

## Principios

Los principios del libro *Site Reliability Engineering* de Google (disponible gratis en su web):

- **Embracing risk** (aceptar el riesgo): el 100 % de fiabilidad no es un objetivo realista ni deseable. Cada "nueve" extra cuesta mucho más y el usuario no lo nota (su wifi o su móvil fallan más que tu servicio).
- **Service Level Objectives**: la fiabilidad se define con SLIs y SLOs medibles desde el punto de vista del usuario (ver [Observabilidad](observabilidad.md#sli-slo-sla-y-error-budget)).
- **Error budget** (presupuesto de errores): `100 % − SLO` es el margen que se puede "gastar" en cambios, experimentos y fallos. Equilibra velocidad y estabilidad con datos, no con opiniones.
- **Eliminating toil** (eliminar el trabajo repetitivo): **toil** es el trabajo manual y repetitivo que crece con el servicio sin aportar valor duradero (reiniciar un servicio a mano cada semana, crear usuarios uno a uno). Google propone que no supere el **50 %** del tiempo de un SRE. Definición completa y cómo medirlo y reducirlo en [Prácticas para aprender de incidentes](practicas-aprendizaje.md#medir-y-reducir-el-toil).
- **Automation** (automatización): lo que se hace más de dos veces se automatiza; la automatización es más rápida, consistente y no se cansa.
- **Simplicity** (simplicidad): los sistemas simples fallan menos y se arreglan antes.

### Política de error budget

Cómo se calcula el error budget y cómo alertar por *burn rate* está en [Observabilidad](observabilidad.md#sli-slo-sla-y-error-budget); el error budget como acuerdo de negocio, en [Niveles de servicio](../../negocio/niveles-de-servicio.md#error-budget-como-acuerdo-de-negocio). Aquí, qué se hace con él. La política se acuerda **antes** de necesitarla, entre producto y ingeniería:

| Situación | Qué se hace |
| --- | --- |
| Queda presupuesto | Se despliega con normalidad; se pueden asumir riesgos (migraciones, experimentos) |
| Presupuesto agotado | Se congelan los cambios no urgentes y el equipo trabaja en fiabilidad hasta recuperarlo |
| Un solo incidente se come más del 20 % del presupuesto | Postmortem obligatorio con acciones prioritarias |

## Incident management (gestión de incidentes)

Un **incident** (incidente) es un evento que degrada o interrumpe el servicio y requiere una respuesta coordinada.

### Severidades

Cada organización define las suyas; un esquema típico:

| Severidad | Criterio | Respuesta |
| --- | --- | --- |
| **SEV1** | Servicio caído o pérdida de datos para muchos usuarios | Todo el equipo de guardia, comunicación pública, 24/7 |
| **SEV2** | Degradación importante o función crítica caída para parte de los usuarios | Guardia inmediata, comunicación interna |
| **SEV3** | Impacto menor o con alternativa | En horario laboral |
| **SEV4** | Sin impacto visible para el usuario | Ticket |

!!! tip "Ante la duda, sube la severidad"
    Es más barato declarar un SEV2 que resulta ser SEV3 que tardar en movilizar gente en un SEV1 real.

### Roles

Todo incidente tiene un **Incident Commander** (IC, responsable del incidente) que coordina sin arreglar con sus manos, y según el tamaño, responsables técnicos, un communications lead y un scribe (escriba). La tabla de roles y qué hace cada uno está en [Comunicación durante incidentes](comunicacion-incidentes.md#roles).

### Ciclo de vida

```mermaid
flowchart LR
    A[Detección] --> B[Triage y declaración]
    B --> C[Respuesta]
    C --> D[Mitigación]
    D --> E[Resolución]
    E --> F[Postmortem]
    F -->|acciones| G[Mejoras en sistema, alertas y runbooks]
```

1. **Detección**: idealmente por una alerta sobre síntomas, no por un cliente.
2. **Triage** (clasificación): evaluar el impacto, asignar severidad, nombrar al IC y abrir un canal dedicado.
3. **Respuesta**: investigar con métricas, logs y trazas; comunicar el estado.
4. **Mitigación**: **parar el daño primero**, aunque no sepas la causa: *rollback*, desactivar un *feature flag*, desviar tráfico, escalar. Ver [Despliegue continuo](../ci-cd/despliegue-continuo.md).
5. **Resolución**: arreglar la causa y confirmar que el servicio está normal.
6. **Postmortem**: aprender del incidente.

!!! note "Mitigar antes que entender"
    El objetivo durante el incidente es reducir el impacto, no encontrar la causa raíz. La investigación profunda viene después, con calma, en el postmortem.

Las métricas típicas de esta fase son **MTTD** (*Mean Time To Detect*, tiempo medio hasta detectar) y **MTTR** (*Mean Time To Restore/Recover*, tiempo medio hasta restablecer); ver [Niveles de servicio](../../negocio/niveles-de-servicio.md#mtbf-mttr-mtta-y-mttd). El tiempo para restablecer el servicio también es una de las métricas DORA.

## On-call (guardias) sostenible

- **Rotaciones** con suficiente gente: el SRE Book sugiere un mínimo de 8 personas para una rotación en un solo lugar (o 6 por sitio en dos zonas horarias), para que nadie esté de guardia más de una semana de cada varias.
- **Follow-the-sun** (seguir al sol): equipos en distintas zonas horarias para que nadie haga guardia de noche.
- **Pocas alertas y buenas**: demasiadas páginas por turno generan **alert fatigue** (fatiga de alertas) y errores. Los umbrales de referencia y la revisión semanal de alertas están en [Prácticas para aprender de incidentes](practicas-aprendizaje.md#revision-semanal-de-operaciones-y-de-alertas).
- **Escalado claro**: primario, secundario y a quién llamar si no responden. Herramientas como PagerDuty u Opsgenie, o las de la propia plataforma de alertas, gestionan rotaciones y escalados.
- **Compensación y descanso** después de una noche con incidentes.
- **Traspaso de guardia** (*handoff*) al cambiar de turno; plantilla en [Prácticas para aprender de incidentes](practicas-aprendizaje.md#traspaso-de-guardia-on-call-handoff).

## Postmortems blameless

Después de cada incidente relevante se escribe un **blameless postmortem** (postmortem sin culpables): busca **qué falló en el sistema y en los procesos**, no a quién culpar, y termina en acciones con responsable y fecha. Cuándo es obligatorio, plantilla, ejemplo y seguimiento de acciones en [Postmortem](postmortem.md); las técnicas de análisis, en [Análisis de causa raíz](analisis-causa-raiz.md).

## Runbooks

Un **runbook** (manual de operación) describe paso a paso cómo diagnosticar y resolver un problema concreto; cada alerta debería enlazar al suyo, y el siguiente paso es automatizarlo para reducir el toil. Plantilla, ejemplo y automatización en [Runbooks y playbooks](runbooks-playbooks.md).

## Capacity planning (planificación de capacidad)

Asegurar que habrá recursos suficientes para la demanda futura sin pagar de más:

1. **Medir** el uso actual y su relación con la demanda (por ejemplo, CPU por cada 1000 peticiones por segundo).
2. **Pronosticar** el crecimiento orgánico y los eventos previsibles (campañas, temporadas, lanzamientos).
3. **Probar** con **load testing** (pruebas de carga) para saber dónde está el límite real.
4. **Dejar margen** (*headroom*) para picos y para perder una zona entera (N+1, N+2).
5. Revisar los **quotas** (cuotas) y límites del proveedor: muchos incidentes ocurren porque se alcanzó un límite de la cuenta, no del hardware.

El autoscaling ayuda, pero no sustituye la planificación: tiene límites, tarda en reaccionar y depende de que haya capacidad y cuota disponibles. Ver [Resiliencia](../../cloud/operacion-y-gobierno/resiliencia.md) y [FinOps y costos](../../cloud/fundamentos/finops-costos.md).

## Chaos engineering

**Chaos engineering** (ingeniería del caos) es provocar fallos a propósito y de forma controlada para comprobar que el sistema resiste como esperas. Método, herramientas y su relación con los game days en [Prácticas para aprender de incidentes](practicas-aprendizaje.md#chaos-engineering); aplicado a disaster recovery, en [Resiliencia](../../cloud/operacion-y-gobierno/resiliencia.md#probar-el-dr-game-days-y-chaos-engineering).

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Alta disponibilidad, disaster recovery, RTO/RPO y costos de la capacidad | [Resiliencia](../../cloud/operacion-y-gobierno/resiliencia.md), [FinOps y costos](../../cloud/fundamentos/finops-costos.md) |
| DevOps (la automatización) | SLOs y alertas que disparan los incidentes, rollbacks y métricas de entrega | [Observabilidad](observabilidad.md), [Cultura DevOps y métricas DORA](../fundamentos/cultura-metricas-dora.md), [Despliegue continuo](../ci-cd/despliegue-continuo.md), [Troubleshooting](troubleshooting.md), [Postmortem](postmortem.md), [Análisis de causa raíz](analisis-causa-raiz.md), [Runbooks y playbooks](runbooks-playbooks.md), [Comunicación de incidentes](comunicacion-incidentes.md), [Prácticas de aprendizaje](practicas-aprendizaje.md) |
| DevSecOps (la verificación) | Incidentes de seguridad: mismo ciclo de respuesta, con playbooks y SIEM | [Detección y respuesta](../../devsecops/gobierno-y-respuesta/deteccion-respuesta.md) |
| Negocio TI (el porqué) | SLAs, OLAs y créditos; incidentes, problemas y cambios en el lenguaje de ITIL | [Niveles de servicio](../../negocio/niveles-de-servicio.md), [Gestión de servicios (ITSM) e ITIL](../../negocio/gestion-servicios-itil.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 11: Observabilidad con Prometheus y Grafana](../../laboratorios/devops/observabilidad-prometheus-grafana.md), [Lab 21: Game day: incidente simulado, troubleshooting y postmortem](../../laboratorios/operacion/game-day-incidente.md) |

## Referencias

- [Google SRE Book](https://sre.google/sre-book/table-of-contents/)
- [Google SRE Workbook](https://sre.google/workbook/table-of-contents/)
- [SRE Book: Eliminating Toil](https://sre.google/sre-book/eliminating-toil/)
- [SRE Book: Being On-Call](https://sre.google/sre-book/being-on-call/)
- [SRE Book: Postmortem Culture](https://sre.google/sre-book/postmortem-culture/)
- [SRE Workbook: Incident Response](https://sre.google/workbook/incident-response/)
- [PagerDuty Incident Response](https://response.pagerduty.com/)
