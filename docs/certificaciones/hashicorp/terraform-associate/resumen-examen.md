---
tags:
  - terraform
  - certificacion
  - terraform-associate
  - iac
---

# HashiCorp Certified: Terraform Associate (004): resumen del examen

> Qué evalúa la certificación de entrada de Terraform, cómo es el formato, qué cambió de la versión 003 a la 004, un plan de estudio de 5 semanas y un laboratorio práctico con la CLI `terraform` que no necesita cuenta de nube.

## ¿Qué es?

**HashiCorp Certified: Terraform Associate** es el primer nivel (**Associate**) de las certificaciones de Terraform. Demuestra que conoces los conceptos de **Infrastructure as Code** (IaC, infraestructura como código), que usas la CLI de **Terraform Community Edition** (la edición gratuita) en el día a día y que entiendes qué añade **HCP Terraform** (antes *Terraform Cloud*) para trabajar en equipo.

El examen es **agnóstico al proveedor**: los tutoriales oficiales usan AWS, Azure, Google Cloud o Docker, pero **no se pregunta nada específico de una nube**.

!!! info "Versión vigente: 004 (desde el 8 de enero de 2026)"
    La **004** sustituyó a la **003** (último día para agendar la 003: 5 de enero de 2026; para presentarla: 7 de enero de 2026). Evalúa **Terraform 1.12**. Si ya tienes la 003, tu credencial sigue válida hasta su vencimiento; para renovar tienes que presentar la 004 (ver [Renovación](#renovacion)).

Lo genérico de cualquier examen (gestión del tiempo, online proctored, dumps, palabras clave comunes) está en [Cómo preparar un examen de certificación](../../como-preparar-un-examen.md).

## Formato del examen

| Aspecto | Detalle |
| --- | --- |
| Versión | **004** (Terraform Associate 004) |
| Versión de Terraform evaluada | **Terraform 1.12** |
| Tipos de pregunta | **True or false** (verdadero o falso), **multiple choice** (opción múltiple, 1 correcta) y **multiple answer** (respuesta múltiple, varias correctas) |
| Duración | **1 hora** |
| Número de preguntas | HashiCorp **no lo publica** (la comunidad reporta alrededor de 55–60; tómalo como orientativo) |
| Puntaje de aprobación | No publicado; el resultado es aprobado/no aprobado |
| Modalidad | **Online proctored**, a través de la plataforma de HashiCorp Certifications |
| Idioma | **Inglés** |
| Costo | **70.50 USD** más impuestos locales. **No incluye** reintento gratuito |
| Validez | **2 años** |

!!! warning "Datos que cambian"
    Precio, plataforma y número de preguntas pueden cambiar: revisa la [página oficial del examen](https://developer.hashicorp.com/certifications/terraform-associate) antes de agendar. HashiCorp **no publica pesos por objetivo**: estudia todos con la misma atención.

### Renovación

| Si tienes… | Opciones para renovar |
| --- | --- |
| Terraform Associate **004** vigente | Aprobar **Terraform Infrastructure Engineer Professional**, aprobar **Terraform Authoring and Operations Advanced** (versión AWS o Azure), o volver a presentar la 004 desde **6 meses antes** del vencimiento (extiende la misma credencial) |
| Terraform Associate **002 o 003** vigente | Las dos certificaciones superiores, o presentar la 004 desde 6 meses antes del vencimiento: en este caso recibes una **credencial nueva y separada** (la antigua no se extiende) |
| Cualquier versión **vencida** | Presentar la versión vigente del examen en cualquier momento |

## Objetivo profesional

Según HashiCorp, es para un **Cloud Engineer** con fundamentos de Terraform, capaz de distinguir las funciones de Terraform Enterprise de las de Community Edition; practicar los objetivos en un entorno personal puede bastar. Encaja con [Cloud Engineer](../../roles-profesionales.md#cloud-engineer), [DevOps Engineer](../../roles-profesionales.md#devops-engineer) y [Platform Engineer](../../roles-profesionales.md#platform-engineer). Después: **Terraform Infrastructure Engineer Professional** (opción múltiple, 90 minutos, Terraform 1.15) o **Terraform Authoring and Operations Advanced** (examen de laboratorio, AWS o Azure, Terraform 1.6), que además renuevan la Associate; o una Associate de nube ([SAA](../../aws/solutions-architect-associate/resumen-examen.md), [ACE](../../google-cloud/associate-cloud-engineer/resumen-examen.md), [AZ-104](../../azure/azure-administrator/resumen-examen.md)). Más rutas en [Otras certificaciones](../../otras-certificaciones.md).

## Qué cambió de la 003 a la 004

La 003 tenía **9 objetivos**; la 004 los reorganiza en **8** y añade **cuatro temas nuevos**:

| Tema nuevo en 004 | Qué tienes que saber | Nota |
| --- | --- | --- |
| **4f** `depends_on` y `create_before_destroy` | Dependencias implícitas vs explícitas; crear el reemplazo antes de destruir el original | [Objetivo 4](objetivo-4-configuracion.md#4f-dependencias-entre-recursos) |
| **4g** *Custom conditions* | `validation`, `precondition`/`postcondition` y bloques `check` | [Objetivo 4](objetivo-4-configuracion.md#4g-custom-conditions) |
| **4h** *Ephemeral values* y *write-only arguments* | Valores que **no se guardan** en el plan ni en el state (1.10 y 1.11) y secretos con Vault | [Objetivo 4](objetivo-4-configuracion.md#4h-datos-sensibles-y-vault) |
| **8c** Workspaces y **projects** en HCP Terraform | Projects, variable sets, run triggers | [Objetivo 8](objetivo-8-hcp-terraform.md#8c-organizar-workspaces-y-projects) |

Además entra **más HCP Terraform** (Explorer, change requests, health, dynamic credentials) y funciones recientes como los bloques `removed` (1.7).

!!! tip "Si estudias con material de la 003"
    Casi todo sigue sirviendo, pero te faltarán los temas de arriba. Cuidado con material que dice **Terraform Cloud** (ahora **HCP Terraform**) o que recomienda `terraform taint` (ahora `terraform apply -replace`).

## Objetivos del examen

| Objetivo oficial | Sub-objetivos | Nota |
| --- | --- | --- |
| **1. Infrastructure as Code (IaC) with Terraform** | 1a–1c: qué es IaC, ventajas, multi-cloud, hybrid cloud y flujos agnósticos al servicio | [Objetivos 1 y 2](objetivo-1-2-iac-y-fundamentos.md) |
| **2. Terraform fundamentals** | 2a–2d: instalar y versionar providers, cómo usa Terraform los providers, varios providers, state | [Objetivos 1 y 2](objetivo-1-2-iac-y-fundamentos.md) |
| **3. Core Terraform workflow** | 3a–3g: workflow, `init`, `validate`, `plan`, `apply`, `destroy`, `fmt` | [Objetivo 3](objetivo-3-flujo-de-trabajo.md) |
| **4. Terraform configuration** | 4a–4h: resources y data, referencias, variables y outputs, tipos complejos, expresiones y funciones, dependencias, custom conditions, datos sensibles y Vault | [Objetivo 4](objetivo-4-configuracion.md) |
| **5. Terraform modules** | 5a–5d: fuentes de módulos, alcance de variables, usar módulos, versiones | [Objetivo 5](objetivo-5-modulos.md) |
| **6. Terraform state management** | 6a–6d: backend local, locking, backend remoto, drift y state | [Objetivos 6 y 7](objetivo-6-7-estado-y-mantenimiento.md) |
| **7. Maintain infrastructure with Terraform** | 7a–7c: importar infraestructura, inspeccionar el state con la CLI, logging detallado | [Objetivos 6 y 7](objetivo-6-7-estado-y-mantenimiento.md) |
| **8. HCP Terraform** | 8a–8d: crear infraestructura, colaboración y gobierno, workspaces y projects, integración con la CLI | [Objetivo 8](objetivo-8-hcp-terraform.md) |

## Plan de estudio de 5 semanas

Pensado para 5–7 horas por semana. Si ya usas Terraform en el trabajo, compáctalo en 2 semanas y céntrate en los temas nuevos y en HCP Terraform.

| Semana | Tema | Qué hacer |
| --- | --- | --- |
| 1 | Objetivos 1, 2 y 3 | Notas [1 y 2](objetivo-1-2-iac-y-fundamentos.md) y [3](objetivo-3-flujo-de-trabajo.md), el [laboratorio práctico](#laboratorio-practico) y [Infrastructure as Code con Terraform](../../../devops/iac/terraform-basico.md) |
| 2 | Objetivo 4 | Nota del [objetivo 4](objetivo-4-configuracion.md); practica cada expresión en `terraform console`. Escribe una `validation`, un `precondition` y un `check` |
| 3 | Objetivos 5, 6 y 7 | [Módulos](objetivo-5-modulos.md) y [state y mantenimiento](objetivo-6-7-estado-y-mantenimiento.md). Practica `moved`, `removed`, `import` y `terraform state` |
| 4 | Objetivo 8 | Organización gratuita en HCP Terraform, `terraform login`, bloque `cloud` y un workspace con VCS. Nota del [objetivo 8](objetivo-8-hcp-terraform.md) |
| 5 | Repaso | *Sample questions* oficiales, preguntas de práctica de cada nota y los "En el examen" |

!!! tip "Cuándo agendar"
    Cuando puedas explicar sin mirar **qué hace cada comando** del laboratorio, **qué guarda el state** y **qué diferencia hay entre un CLI workspace y un workspace de HCP Terraform**.

## Recursos oficiales gratuitos

| Recurso | Para qué sirve |
| --- | --- |
| **Learning Path - Terraform Associate 004** | Ruta de estudio oficial ordenada por complejidad |
| **Exam Content List - Terraform Associate 004** | Cada sub-objetivo enlazado a su documentación y tutorial: la fuente de verdad |
| **Sample Questions - Terraform Associate 004** | Ejemplos del formato de preguntas |
| **Get Started collections** (AWS, Azure, Google Cloud, Docker) | Crear, cambiar y destruir tu primera infraestructura. La de **Docker** no necesita cuenta de nube |
| **HCP Terraform Get Started** | Tutoriales del objetivo 8 con una organización gratuita |

## Laboratorio práctico

Un recorrido por el workflow completo **sin cuenta de nube**, con los providers `random` y `local`. Se probó con **Terraform 1.12.2** en Windows; las salidas son reales (recortadas). Para un recorrido más largo (variables, `for_each`, módulos, `moved`, workspaces) sigue el [Lab 08](../../../laboratorios/devops/terraform-local-workspaces.md).

!!! danger "Costos y limpieza"
    Este laboratorio **no tiene costo**. Si lo adaptas a una nube, usa una cuenta solo para practicar, con alerta de presupuesto, y termina **siempre** con `terraform destroy`. Lo creado fuera de Terraform o sacado del state con `terraform state rm` **no** se destruye y sigue cobrando.

1. **Escribe la configuración** en una carpeta vacía:

    ```hcl title="main.tf"
    terraform {
      required_version = ">= 1.12"
      required_providers {
        random = { source = "hashicorp/random", version = "~> 3.7" }
        local  = { source = "hashicorp/local", version = "~> 2.5" }
      }
    }

    variable "entorno" {
      type    = string
      default = "dev"
    }

    resource "random_pet" "nombre" {
      prefix = var.entorno
    }

    resource "local_file" "saludo" {
      filename = "${path.module}/salida/saludo.txt"
      content  = "Hola desde ${random_pet.nombre.id}\n"
    }

    output "nombre" {
      value = random_pet.nombre.id
    }
    ```

2. **Workflow completo** (objetivos 2, 3, 4 y 7):

    ```console
    $ terraform init && terraform fmt -check && terraform validate
    Success! The configuration is valid.
    $ terraform plan -out=lab.tfplan
    Plan: 2 to add, 0 to change, 0 to destroy.
    $ terraform apply lab.tfplan
    nombre = "dev-better-aardvark"
    $ terraform state list
    local_file.saludo
    random_pet.nombre
    $ echo 'upper(random_pet.nombre.id)' | terraform console
    "DEV-BETTER-AARDVARK"
    ```

3. **Reemplazo forzado y drift** (objetivo 6): `-replace` recrea un recurso y lo que depende de él; si borras el archivo a mano, `-refresh-only` lo detecta.

    ```console
    $ terraform plan -replace=random_pet.nombre
    Plan: 2 to add, 0 to change, 2 to destroy.
    $ rm salida/saludo.txt
    $ terraform plan -refresh-only
      # local_file.saludo has been deleted
    $ terraform destroy -auto-approve
    Destroy complete! Resources: 1 destroyed.
    ```

    Destruyó **1** recurso, no 2, porque el refresh detectó que el archivo ya no existía. Borra después `.terraform/`, el state y el plan guardado.

### Comandos que debes dominar

La lista básica está en la [Guía de comandos de Terraform](../../../recursos/comandos/terraform.md). Para el examen, además de esos, domina las opciones y comandos que salen en las notas de cada objetivo: `init -upgrade/-migrate-state/-reconfigure`, `fmt -check/-recursive`, `plan -refresh-only/-replace/-detailed-exitcode`, `apply -refresh-only`, `state mv/rm/pull/push`, `console`, `graph`, `providers`, `login`/`logout` y `force-unlock`.

## Trampas propias de Terraform

- **Community Edition, HCP Terraform o Terraform Enterprise**: Sentinel/OPA, variable sets, private registry, run triggers, health assessments y projects son de HCP Terraform/Enterprise, no de la CLI sola.
- En **true/false**, busca la palabra absoluta ("always", "never", "only") que vuelve falsa la frase. Las preguntas de código piden fijarse en detalles (una coma, un `count` frente a un `for_each`).

| Si la pregunta dice… | Piensa en… |
| --- | --- |
| "Recrear un recurso dañado" | `terraform apply -replace=...` (no `taint`, que está deprecated) |
| "Renombrar un recurso sin destruirlo" | Bloque `moved` (o `terraform state mv`) |
| "Dejar de gestionar un recurso sin borrarlo" | Bloque `removed` con `destroy = false` (o `terraform state rm`) |
| "Actualizar el state con la realidad sin cambiar infraestructura" | `terraform apply -refresh-only` |
| "Versión exacta de providers para todo el equipo" | `.terraform.lock.hcl` en Git |
| "Secretos en el state" | Siempre en texto plano: protege el backend; usa ephemeral/write-only si puedes |
| "Separar dev y prod con credenciales distintas" | No uses CLI workspaces: directorios o workspaces de HCP Terraform |

## Para profundizar

- Terraform en el cuaderno: [Infrastructure as Code con Terraform](../../../devops/iac/terraform-basico.md), [Terraform workspaces](../../../devops/iac/terraform-workspaces.md), [Infrastructure as Code: panorama y herramientas](../../../devops/iac/infraestructura-como-codigo.md)
- [Anatomía de los archivos de Terraform](../../../recursos/anatomia/terraform.md): cada bloque comentado línea por línea
- [Pruebas de infraestructura](../../../devops/iac/pruebas-infraestructura.md) (`terraform test`)
- Seguridad: [Seguridad de IaC](../../../devsecops/infraestructura-y-contenedores/seguridad-iac.md) (Sentinel, OPA, drift), [Secretos e identidades](../../../devsecops/identidades-y-pipeline/secretos-identidades.md) (Vault)

!!! example "Practica en el laboratorio"
    - [Lab 08: Terraform sin nube: providers locales y workspaces](../../../laboratorios/devops/terraform-local-workspaces.md)
    - [Lab 09: Terraform en AWS con remote state en S3](../../../laboratorios/devops/terraform-aws-backend-remoto.md)

## Referencias

- [Terraform Associate (004): página oficial del examen](https://developer.hashicorp.com/certifications/terraform-associate)
- [HashiCorp Certifications: Infrastructure Automation](https://developer.hashicorp.com/certifications/infrastructure-automation)
- [Exam Content List - Terraform Associate 004](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004)
- [Learning Path - Terraform Associate 004](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-study-004)
- [Sample Questions - Terraform Associate 004](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-questions-004)
- [HCP Terraform: planes y precios](https://www.hashicorp.com/pricing)
