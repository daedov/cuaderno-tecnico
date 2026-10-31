---
tags:
  - terraform
  - certificacion
  - terraform-associate
  - iac
---

# Objetivos 1 y 2: Infrastructure as Code (IaC) with Terraform y Terraform fundamentals

> Qué es IaC y por qué conviene, cómo trabaja Terraform con varias nubes y servicios, cómo se instalan y versionan los providers y para qué sirve el state.

!!! info "Qué evalúan estos objetivos"
    Sub-objetivos oficiales de la versión 004:

    - **1a** Explain what IaC is (explicar qué es IaC).
    - **1b** Describe the advantages of IaC patterns (ventajas de los patrones de IaC).
    - **1c** Explain how Terraform manages multi-cloud, hybrid cloud, and service-agnostic workflows (multi-cloud, nube híbrida y flujos agnósticos al servicio).
    - **2a** Install and version Terraform providers (instalar y versionar providers).
    - **2b** Describe how Terraform uses providers (cómo usa Terraform los providers).
    - **2c** Write Terraform configuration using multiple providers (configuración con varios providers).
    - **2d** Explain how Terraform uses and manages state (cómo usa y gestiona Terraform el state).

    Vuelve al [resumen del examen](resumen-examen.md) para ver el formato y el plan de estudio.

## 1a. Qué es Infrastructure as Code

Definición, declarativo vs imperativo, idempotencia e IaC vs configuration management están en [Infrastructure as Code: panorama y herramientas](../../../devops/iac/infraestructura-como-codigo.md). Lo que el examen pregunta de Terraform:

| Característica | Qué significa | Contraste |
| --- | --- | --- |
| **Declarative** (declarativo) | Describes el **estado final**; Terraform calcula los pasos | Imperativo: un script Bash que ejecuta comandos en orden |
| **Idempotent** (idempotente) | Aplicar dos veces el mismo código no cambia nada la segunda vez | Un script que ejecuta "crear VM" dos veces crea dos VMs |
| Basado en **HCL** (*HashiCorp Configuration Language*) | También admite JSON (`.tf.json`) | YAML/JSON de otras herramientas |
| Con **state** | Guarda qué objetos reales corresponden a cada bloque del código | CloudFormation/Bicep guardan el estado en el propio servicio |
| **Immutable infrastructure** (infraestructura inmutable) | Ante ciertos cambios, reemplaza el recurso en vez de modificarlo | *Configuration management* (Ansible, Chef) que modifica servidores existentes |

!!! note "Terraform no es configuration management"
    Terraform **aprovisiona**. Lo de dentro del servidor es trabajo de [Ansible](../../../devops/iac/ansible.md), Packer o `user_data`/cloud-init. Los *provisioners* (`local-exec`, `remote-exec`) existen, pero HashiCorp los considera **último recurso**.

## 1b. Ventajas de los patrones de IaC

Reproducibilidad (adiós a los *snowflake servers*), versionado en Git, revisión con `plan` y *pull requests*, automatización en CI/CD, reutilización con **modules**, documentación viva, velocidad (`count = 50`) y seguridad verificable con [IaC scanning](../../../devsecops/escaneos/iac-scanning.md).

!!! tip "En el examen"
    Las ventajas típicas son **versionado, reutilización, automatización, consistencia y revisión del plan**. Una opción como "IaC elimina la necesidad de entender la nube" o "IaC hace imposible el drift" es falsa: alguien puede seguir cambiando recursos a mano.

## 1c. Multi-cloud, hybrid cloud y flujos agnósticos al servicio

Terraform usa **el mismo lenguaje y el mismo workflow** para cualquier plataforma con **provider**: nubes públicas, on-premises (vSphere, OpenStack) y SaaS (GitHub, Datadog, Cloudflare).

| Concepto | Qué significa con Terraform |
| --- | --- |
| **Multi-cloud** | Una configuración crea recursos en varias nubes a la vez, con dependencias entre ellos (DNS en Cloudflare que apunta a un load balancer de Azure) |
| **Hybrid cloud** (nube híbrida) | El mismo flujo gestiona on-premises y nube |
| **Service-agnostic workflow** | Write → Plan → Apply es igual para cualquier provider: el equipo aprende **un** flujo |

!!! warning "Agnóstico al flujo, no al recurso"
    El código **no es portable** entre nubes: un `aws_instance` no se convierte en `azurerm_linux_virtual_machine` cambiando el provider. Lo común es el lenguaje, el workflow, el state y los módulos.

## 2a. Instalar y versionar providers

Un **provider** se declara en `required_providers` del bloque `terraform`; `terraform init` lo descarga del **Terraform Registry** a `.terraform/providers/`. El bloque comentado línea por línea está en [Anatomía: versions.tf](../../../recursos/anatomia/terraform.md#versionstf-comentado-linea-por-linea).

- **Source address**: `[hostname/]namespace/type`. Sin hostname se asume `registry.terraform.io` (`hashicorp/random` = `registry.terraform.io/hashicorp/random`).
- `required_version` restringe la versión de la **CLI**; `version` dentro de `required_providers` restringe el **provider**.

| Operador | Significado | Ejemplo |
| --- | --- | --- |
| `=` (o sin operador) | Exactamente esa versión | `= 3.7.2` |
| `!=` | Excluye una versión | `!= 3.7.0` |
| `>`, `>=`, `<`, `<=` | Comparaciones | `>= 3.0, < 4.0` |
| `~>` | **Pessimistic constraint** (restricción pesimista): solo deja subir el **último** número indicado | `~> 3.7` permite 3.8, 3.9 pero no 4.0; `~> 3.7.0` permite 3.7.x pero no 3.8 |

### Dependency lock file

`.terraform.lock.hcl` guarda la versión exacta elegida de cada provider y sus **hashes**, y **se sube a Git** (detalle en [Anatomía: .terraform.lock.hcl](../../../recursos/anatomia/terraform.md#terraformlockhcl)). Si cambias la restricción a algo incompatible con lo bloqueado, `plan` falla con `Inconsistent dependency lock file` hasta que ejecutes `terraform init -upgrade`.

!!! tip "En el examen"
    - El lock file bloquea **providers**, **no módulos** (las versiones de módulos se fijan con `version` en el bloque `module`).
    - `terraform init` respeta el lock file; **`terraform init -upgrade`** busca la versión más nueva que cumpla las restricciones y reescribe el lock.
    - `terraform providers lock -platform=linux_amd64 -platform=windows_amd64` añade hashes de otras plataformas (útil si desarrollas en Windows y el pipeline corre en Linux).

## 2b. Cómo usa Terraform los providers

Terraform **core** (el binario `terraform`) no sabe nada de AWS ni de GitHub: lee la configuración, construye el **grafo de dependencias**, compara con el state y pide a cada **provider plugin** (binario aparte, comunicado por RPC) que lea, cree, actualice o borre objetos con la API del servicio.

| Concepto | Detalle |
| --- | --- |
| **Terraform Registry** | Repositorio público de providers y módulos (`registry.terraform.io`) |
| **Tiers** (niveles) de providers | **Official** (HashiCorp, namespace `hashicorp`), **Partner** (la empresa del servicio, verificada), **Community** (la comunidad) |
| Cada provider aporta | *Resource types*, *data sources*, *ephemeral resources* y a veces funciones propias (`provider::nombre::funcion`) |
| Configuración | Bloque `provider "nombre" { ... }`; credenciales por variables de entorno o identidad, nunca en el código |
| Dónde se guardan | `.terraform/providers/`; `TF_PLUGIN_CACHE_DIR` comparte una caché entre proyectos |

`terraform providers` muestra los providers que piden la configuración (con sus restricciones, también los de módulos) y el state. `terraform_remote_state` y `terraform_data` vienen del provider **built-in** `terraform.io/builtin/terraform`, que no se declara ni se descarga.

## 2c. Configuración con varios providers

Varios providers distintos van cada uno en `required_providers`; varias configuraciones del **mismo** provider se distinguen con `alias`:

```hcl
provider "aws" {
  region = "us-east-1" # configuración por defecto (sin alias)
}

provider "aws" {
  alias  = "europa"
  region = "eu-west-1"
}

resource "aws_s3_bucket" "replica" {
  provider = aws.europa # <PROVIDER>.<ALIAS>, sin comillas
  bucket   = "ejemplo-replica-123"
}
```

!!! tip "En el examen"
    - Un recurso **sin** `provider` usa la configuración **por defecto** (la que no tiene alias) del provider que indica su prefijo (`aws_` → `aws`).
    - Para pasar un provider con alias a un **módulo** se usa `providers = { aws = aws.europa }` en el bloque `module` (ver [objetivo 5](objetivo-5-modulos.md)).
    - Un mismo `apply` puede tocar AWS, Azure y GitHub: eso es multi-cloud con un solo workflow.

## 2d. Cómo usa y gestiona Terraform el state

El **state** es un archivo JSON (por defecto `terraform.tfstate`) que **asocia cada recurso del código con un objeto real** (por ID) y guarda sus atributos.

| Para qué sirve | Explicación |
| --- | --- |
| **Mapping to the real world** | Sabe qué objeto real es cada recurso. Sin state no sabría qué objetos son suyos |
| **Metadata** | Guarda dependencias para destruir en orden aunque ya hayas borrado el código |
| **Performance** | Cachea atributos; en infraestructuras grandes se puede saltar el refresh con `-refresh=false` |
| **Syncing** | Con un **remote backend**, todo el equipo trabaja contra el mismo state |

- Antes de planificar, Terraform hace un **refresh** de los objetos reales y compara **configuración vs state actualizado**.
- En el JSON, `serial` aumenta con cada escritura y `lineage` identifica ese state (evita mezclar states de proyectos distintos). El backend local deja una copia `terraform.tfstate.backup`.

!!! danger "El state contiene secretos en texto plano"
    Contraseñas generadas, claves privadas o el valor de una variable `sensitive` **se guardan sin cifrar en el state**. `sensitive = true` solo oculta el valor en la CLI. Protege el backend, no subas el state a Git y usa *ephemeral values* o *write-only arguments* cuando puedas (ver [objetivo 4](objetivo-4-configuracion.md#4h-datos-sensibles-y-vault)).

!!! tip "En el examen"
    - "Terraform **requiere** el state para funcionar": verdadero. No es opcional.
    - Editar el JSON del state a mano: no. Usa `terraform state ...`, `moved`, `removed` o `import`.
    - El state local es el **default**: si no configuras backend, se usa `local`. Backends, locking y drift: [Objetivos 6 y 7](objetivo-6-7-estado-y-mantenimiento.md).

## Casos de uso

1. **Cada entorno se crea a mano y ninguno es igual** → IaC con un módulo común.
2. **AWS para cómputo, Cloudflare para DNS y GitHub para repos** → una configuración con tres providers y un solo workflow.
3. **El pipeline instala otra versión de provider que las laptops** → `.terraform.lock.hcl` en Git y `terraform providers lock -platform=...`.
4. **El mismo bucket en dos regiones** → dos bloques `provider "aws"`, uno con `alias`, y `provider = aws.<alias>`.
5. **Alguien cambió el tamaño de una VM en la consola** → el refresh lo detecta y el `plan` propone volver al código (drift, objetivo 6).
6. **Guardar el state en el repositorio "para no perderlo"** → no: tiene secretos. Remote backend con cifrado, versionado y locking.
7. **Subir el provider de AWS a la última menor** → `~> 6.0` y `terraform init -upgrade`; revisa el plan.

## Preguntas de práctica

**1.** ¿Qué describe mejor que Terraform sea declarativo?

- A. Ejecuta los comandos en el orden en que aparecen en los archivos.
- B. Describes el estado final deseado y Terraform calcula las acciones necesarias.
- C. Solo funciona con un proveedor de nube por configuración.
- D. Necesita un script de rollback para cada cambio.

??? success "Respuesta"
    **B.** A describe un enfoque imperativo (y además Terraform no depende del orden de los bloques). C es falso: admite varios providers. D no tiene relación con ser declarativo.

**2.** Tu configuración tiene `version = "~> 2.5"` para un provider. ¿Cuál de estas versiones **no** se puede instalar?

- A. 2.5.0
- B. 2.9.1
- C. 2.10.0
- D. 3.0.0

??? success "Respuesta"
    **D.** `~> 2.5` permite cualquier 2.x a partir de 2.5 (A, B y C), pero no sube la versión mayor. Para limitar a 2.5.x habría que escribir `~> 2.5.0`.

**3.** ¿Qué afirmaciones sobre `.terraform.lock.hcl` son correctas? (Elige DOS.)

- A. Se debe incluir en el control de versiones.
- B. Fija las versiones de los módulos del Registry.
- C. `terraform init -upgrade` puede actualizarlo.
- D. Contiene una copia del state.

??? success "Respuesta"
    **A y C.** B es falso: el lock file solo cubre providers. D es falso: no contiene state.

**4.** Necesitas crear recursos de AWS en dos regiones en la misma configuración. ¿Qué usas?

- A. Dos CLI workspaces.
- B. Dos bloques `provider "aws"`, uno con `alias`, y el argumento `provider` en los recursos.
- C. Dos archivos `.terraform.lock.hcl`.
- D. Un bloque `backend` por región.

??? success "Respuesta"
    **B.** Es el patrón de configuraciones múltiples de un provider. A crea states separados, no dos regiones en una configuración. C y D no tienen relación con regiones.

**5.** Verdadero o falso: marcar una variable con `sensitive = true` impide que su valor se guarde en el state.

??? success "Respuesta"
    **Falso.** `sensitive` solo la oculta en la salida de `plan`, `apply` y `output`. El valor queda en el state en texto plano. Para que no se guarde existen los valores `ephemeral` (Terraform 1.10+).

**6.** ¿Cuál **no** es una función del state de Terraform?

- A. Asociar los recursos de la configuración con objetos reales.
- B. Guardar dependencias para destruir en orden.
- C. Almacenar las credenciales del provider para la siguiente ejecución.
- D. Mejorar el rendimiento cacheando atributos.

??? success "Respuesta"
    **C.** El state no está pensado para guardar credenciales del provider (aunque puede contener otros secretos que generan los recursos). A, B y D son propósitos documentados del state.

**7.** ¿Quién mantiene un provider de tier **Partner** en el Terraform Registry?

- A. HashiCorp.
- B. La empresa propietaria del servicio, verificada por HashiCorp.
- C. Cualquier persona de la comunidad, sin verificación.
- D. La Linux Foundation.

??? success "Respuesta"
    **B.** Official los mantiene HashiCorp (A); Community, la comunidad (C). D no aplica (la Linux Foundation aloja OpenTofu, otro proyecto).

## Para profundizar

- [Infrastructure as Code: panorama y herramientas](../../../devops/iac/infraestructura-como-codigo.md): declarativo vs imperativo, IaC vs configuration management, comparativa de herramientas.
- [Infrastructure as Code con Terraform](../../../devops/iac/terraform-basico.md): conceptos clave, estructura de archivos, qué subir a Git.
- [Anatomía de los archivos de Terraform](../../../recursos/anatomia/terraform.md): bloque `terraform`, providers con alias y lock file comentados.
- [IaC scanning](../../../devsecops/escaneos/iac-scanning.md): verificar el código antes de aplicarlo.
- Siguiente: [Objetivo 3: Core Terraform workflow](objetivo-3-flujo-de-trabajo.md).

## Referencias

- [What is Terraform?](https://developer.hashicorp.com/terraform/intro)
- [Provider requirements](https://developer.hashicorp.com/terraform/language/providers/requirements)
- [Version constraints](https://developer.hashicorp.com/terraform/language/expressions/version-constraints)
- [Dependency lock file](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
- [Purpose of Terraform state](https://developer.hashicorp.com/terraform/language/state/purpose)
- [Exam Content List - Terraform Associate 004](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004)
