# Observabilidad y monitoreo :material-monitor-dashboard:

**Observabilidad y monitoreo es cómo sabes qué está pasando**: qué medir en cada capa, cómo centralizar y leer los logs, cómo convertir las señales en alertas que lleguen a la persona correcta y qué ofrece cada nube de serie. Es la base para operar con SLOs, diagnosticar incidentes y detectar ataques.

Lo que pasa después de la alerta (incidentes, runbooks, postmortems) está en [DevOps > Operación](../devops/operacion/operacion-sre.md); la detección de amenazas y el SIEM, en [DevSecOps](../devsecops/gobierno-y-respuesta/deteccion-respuesta.md). Ver también el [mapa de relaciones](../mapa-de-relaciones.md).

## Fundamentos

- [Observabilidad](fundamentos/observabilidad.md): metrics, logs y traces, Prometheus, Grafana, Loki/ELK, OpenTelemetry, SLI/SLO y error budget, RED/USE
- [Qué monitorear en cada capa](fundamentos/que-monitorear.md): caja negra y caja blanca, señales y PromQL por capa, monitoreo sintético, health checks, dashboards y monitorear el monitoreo

## Logging

- [Cómo leer logs](logging/leer-logs.md): anatomía de una línea, método, herramientas y ejercicios (formatos en [Recursos](../recursos/formatos-de-logs.md))
- [Pipeline de logs](logging/pipeline-de-logs.md): niveles por entorno, logs estructurados, agentes (Fluent Bit, Vector, Alloy, OTel Collector), redacción de datos sensibles, LogQL, métricas a partir de logs y retención

## Alertas

- [Alertas: diseño, Alertmanager y on-call](alertas/alertas.md): qué merece una alerta, severidades, reglas con runbook, burn rate, rutas, inhibición y silencios, escalado

## En la nube

- [Observabilidad nativa](nube/observabilidad-nativa.md): CloudWatch, Azure Monitor y Google Cloud Observability, retención y costos de logs, alarmas útiles
- [Seguridad de logging y detección](../cloud/seguridad/seguridad-logging-deteccion.md) (en Cloud): logs de auditoría obligatorios, integridad, cuenta central de logs y alertas mínimas de seguridad

!!! tip "Para practicar"
    El [Lab 11 (parte 1)](../laboratorios/devops/observabilidad-prometheus-grafana.md) monta métricas, un SLO y alertas con Prometheus y Alertmanager; la [parte 2](../laboratorios/devops/observabilidad-logs-grafana.md) añade Loki y dashboards en Grafana; el [Lab 03](../laboratorios/fundamentos/python-analizar-logs.md) analiza logs con Python y el [Lab 21](../laboratorios/operacion/game-day-incidente.md) sigue un incidente de la alerta al postmortem.

!!! note "Añadir una nota"
    Crea el `.md` en `fundamentos/`, `logging/`, `alertas/` o `nube/` y agrégalo a su `.pages` para fijar su orden en el menú.
