# Certificaciones :material-certificate:

Guías de estudio para certificaciones técnicas: qué evalúa cada examen, explicaciones técnicas de los temas, casos de uso y preguntas de práctica originales. Cada guía enlaza a las notas del cuaderno donde el tema se explica a fondo, así que estudiar para una certificación también sirve para repasar el resto del cuaderno.

!!! warning "Revisa siempre la guía oficial"
    Los proveedores actualizan sus exámenes (código, dominios, pesos, servicios en alcance y precio). Antes de agendar el examen, compara estas notas con la *exam guide* oficial vigente.

## Antes de elegir

- [Roles profesionales](roles-profesionales.md): qué hace cada puesto (Cloud Engineer, DevOps, SRE, Platform, seguridad…) y qué certificaciones encajan con cada uno.
- [Otras certificaciones que conviene conocer](otras-certificaciones.md): mapa de Kubernetes, AWS, Azure, Google Cloud, HashiCorp, seguridad, redes y gestión, con rutas sugeridas por rol y certificaciones retiradas.

## AWS

Ruta sugerida: empieza por Cloud Practitioner, que da la base de AWS; sigue con AI Practitioner si te interesa la IA, y después Solutions Architect – Associate.

| Certificación | Nivel | Para quién |
| --- | --- | --- |
| [Cloud Practitioner](aws/cloud-practitioner/resumen-examen.md) | Foundational | Cualquier persona que empieza en AWS, técnica o de negocio |
| [AI Practitioner](aws/ai-practitioner/resumen-examen.md) | Foundational | Quien usa o propone soluciones de IA y IA generativa en AWS |
| [Solutions Architect – Associate](aws/solutions-architect-associate/resumen-examen.md) | Associate | Quien diseña arquitecturas en AWS |

## Google Cloud

| Certificación | Nivel | Para quién |
| --- | --- | --- |
| [Associate Cloud Engineer](google-cloud/associate-cloud-engineer/resumen-examen.md) | Associate | Quien despliega, opera y administra proyectos y recursos en Google Cloud |

## Azure

| Certificación | Nivel | Para quién |
| --- | --- | --- |
| [Azure Administrator Associate (AZ-104)](azure/azure-administrator/resumen-examen.md) | Associate | Quien administra identidades, redes, cómputo, almacenamiento y monitoreo en Azure |

!!! tip "Associate Cloud Engineer y AZ-104 son equivalentes"
    Las dos evalúan el día a día de administrar una nube (identidades, redes, cómputo, almacenamiento, monitoreo), cada una en su proveedor. Para comparar los conceptos entre AWS, Azure y Google Cloud, usa las notas de [Cloud](../cloud/index.md).

## HashiCorp

| Certificación | Nivel | Para quién |
| --- | --- | --- |
| [Terraform Associate](hashicorp/terraform-associate/resumen-examen.md) | Associate | Quien escribe y opera infraestructura como código con Terraform, en cualquier nube |

!!! note "Añadir una certificación"
    Crea una carpeta por proveedor (por ejemplo `kubernetes/` o `linux-foundation/`) y dentro una subcarpeta por certificación, con un `resumen-examen.md` y una nota por dominio. Agrégala a los `.pages` para fijar el orden en el menú.
