# DevOps :gear:

**DevOps es cómo lo automatizas** (la automatización): cultura, control de versiones, CI/CD, Infrastructure as Code, contenedores y operación. Las prácticas son las mismas en cualquier nube; solo se indica el proveedor donde cambia la herramienta nativa.

Cada tema se ve también desde [Cloud](../cloud/index.md) (dónde corre) y [DevSecOps](../devsecops/index.md) (cómo se verifica que es seguro). Ver el [mapa de relaciones](../mapa-de-relaciones.md).

## Fundamentos

- [Cultura DevOps y métricas DORA](fundamentos/cultura-metricas-dora.md): CALMS, agile, DORA metrics
- [Linux, redes y scripting](fundamentos/linux-redes-scripting.md): Bash, Python, systemd, SSH, DNS, HTTP
- [Git y control de versiones](fundamentos/git-control-versiones.md): trunk-based vs GitFlow, pull requests, code review

## CI/CD

- [Integración continua (CI)](ci-cd/integracion-continua.md): build, tests, artifacts, registries
- [Despliegue continuo (CD)](ci-cd/despliegue-continuo.md): blue/green, canary, rolling, feature flags, GitOps

## Infrastructure as Code

- [Infrastructure as Code](iac/infraestructura-como-codigo.md): Terraform, Terragrunt, CloudFormation, Bicep, Pulumi
- [Infrastructure as Code con Terraform](iac/terraform-basico.md)
- [Terraform workspaces](iac/terraform-workspaces.md)
- [Configuration management con Ansible](iac/ansible.md)
- [Pruebas de infraestructura](iac/pruebas-infraestructura.md): Terratest, Molecule, entornos efímeros

## Contenedores

- [Docker](contenedores/docker.md): imágenes, multi-stage builds, Compose
- [Kubernetes](contenedores/kubernetes.md): pods, deployments, services, ingress, Helm, Kustomize

## Operación

- [Observabilidad](operacion/observabilidad.md): Prometheus, Grafana, Loki/ELK, OpenTelemetry, SLI/SLO
- [Cómo leer logs](operacion/leer-logs.md): anatomía de una línea, método, herramientas y ejercicios (formatos en [Recursos](../recursos/formatos-de-logs.md))
- [Troubleshooting](operacion/troubleshooting.md): método de diagnóstico y checklists por capa
- [Operación y fiabilidad (SRE)](operacion/operacion-sre.md): principios, política de error budget, severidades y ciclo de vida de un incidente, on-call, capacity planning
- [Postmortem](operacion/postmortem.md): cultura blameless, plantilla, timeline, seguimiento de acciones y ejemplo completo
- [Análisis de causa raíz (RCA)](operacion/analisis-causa-raiz.md): 5 porqués, Ishikawa, fault tree, queso suizo y sesgos
- [Runbooks y playbooks](operacion/runbooks-playbooks.md): estructura, plantilla, automatización y mantenimiento
- [Comunicación de incidentes](operacion/comunicacion-incidentes.md): roles del incidente, status page, cadencia y plantillas de mensajes
- [Prácticas de aprendizaje](operacion/practicas-aprendizaje.md): pre-mortem, game days, chaos engineering, Wheel of Misfortune, handoff de guardia, toil

!!! note "Añadir una nota"
    Crea un `.md` en la subcarpeta del bloque que corresponda dentro de `docs/devops/` y agrégalo a su archivo `.pages` para fijar su orden en el menú.
