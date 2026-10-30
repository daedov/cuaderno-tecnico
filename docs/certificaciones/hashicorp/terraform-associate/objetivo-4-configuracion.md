---
tags:
  - terraform
  - certificacion
  - terraform-associate
  - iac
  - secretos
---

# Objetivo 4: Terraform configuration

> El lenguaje HCL para el examen: resources y data sources, referencias, variables y outputs, tipos complejos, expresiones y funciones, dependencias, custom conditions y manejo de datos sensibles con ephemeral values, write-only arguments y Vault.

!!! info "Qué evalúa este objetivo"
    Sub-objetivos oficiales de la versión 004 (es el objetivo más largo; 4f, 4g y 4h son **nuevos** respecto a la 003):

    - **4a** Use and differentiate resource and data blocks (usar y diferenciar bloques resource y data).
    - **4b** Refer to resource attributes and create cross-resource references (referenciar atributos y crear referencias entre recursos).
    - **4c** Use variables and outputs (usar variables y outputs).
    - **4d** Understand and use complex types (tipos complejos).
    - **4e** Write dynamic configuration using expressions and functions (configuración dinámica con expresiones y funciones).
    - **4f** Define resource dependencies in configuration (dependencias entre recursos).
    - **4g** Validate configuration using custom conditions (validar con condiciones personalizadas).
    - **4h** Understand best practices for managing sensitive data, including secrets management with Vault (datos sensibles y Vault).

    Vuelve al [resumen del examen](resumen-examen.md) para ver el formato y el plan de estudio.

Todos los ejemplos con `random`, `local` y `archive` se probaron con **Terraform 1.12.2**; los que usan AWS o Vault se marcan como ilustrativos.

## 4a. Resource vs data

| | `resource` | `data` (data source, fuente de datos) |
| --- | --- | --- |
| Qué hace | **Crea, actualiza y destruye** un objeto | **Solo lee** algo que ya existe (o que calcula el provider) |
| Ciclo de vida | Gestionado por Terraform | No gestionado: `destroy` no lo toca |
| Dirección | `TIPO.NOMBRE` (`aws_instance.web`) | `data.TIPO.NOMBRE` (`data.aws_ami.al2023`) |
| Ejemplo típico | Un bucket, una VM | La AMI más reciente, la VPC por defecto, un secreto, el ID de la cuenta |

```hcl
# Ilustrativo (AWS): leer la AMI más reciente y usarla en una VM
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t3.micro"
}
```

En el laboratorio, `data "archive_file"` empaqueta archivos en un `.zip`. Como depende de recursos que aún no existen, el plan lo lee **durante el apply** (salida real):

```console
  # data.archive_file.paquete will be read during apply
  # (config refers to values not yet known)
 <= data "archive_file" "paquete" {
```

## 4b. Referencias y direcciones

| Expresión | Qué devuelve |
| --- | --- |
| `random_pet.nombre.id` | Atributo de un recurso |
| `data.archive_file.paquete.output_size` | Atributo de un data source |
| `var.entorno` | Variable de entrada |
| `local.prefijo` | Valor local |
| `module.etiquetas.tags` | Output de un módulo hijo |
| `random_string.sufijo[0]` | Instancia de un recurso con `count` |
| `local_file.config["web"]` | Instancia de un recurso con `for_each` |
| `path.module`, `path.root`, `path.cwd` | Rutas del módulo, del módulo raíz y del directorio actual |
| `terraform.workspace` | Nombre del CLI workspace activo |
| `self` | El propio recurso (solo en `postcondition`, provisioners y `connection`) |
| `each.key`, `each.value`, `count.index` | Dentro de recursos con `for_each` o `count` |

Al referenciar un atributo de otro recurso creas una **implicit dependency** (dependencia implícita): Terraform crea primero el referenciado. Ver [4f](#4f-dependencias-entre-recursos).

## 4c. Variables y outputs

### Input variables

```hcl title="variables.tf"
variable "entorno" {
  description = "Nombre del entorno"
  type        = string
  default     = "dev"
  nullable    = false

  validation {
    condition     = contains(["dev", "staging", "prod"], var.entorno)
    error_message = "El entorno debe ser dev, staging o prod."
  }
}

variable "token_api" {
  type      = string
  sensitive = true # se oculta en la salida, pero se guarda en el state
}
```

Argumentos del bloque `variable`: `type`, `default`, `description`, `validation`, `sensitive`, `nullable`, `ephemeral`. Una variable **sin `default`** es obligatoria: Terraform la pide de forma interactiva o falla con `-input=false`.

**Precedencia** (de menor a mayor; la última gana). Probado en el laboratorio con la misma variable definida en cada sitio:

| Orden | Fuente | Resultado real de `entorno` |
| --- | --- | --- |
| 1 | `default` del bloque | `"default-del-bloque"` |
| 2 | Variable de entorno `TF_VAR_entorno` | `"desde-env"` |
| 3 | `terraform.tfvars` (y `terraform.tfvars.json`) | `"desde-tfvars"` |
| 4 | `*.auto.tfvars` (en orden alfabético) | `"desde-auto"` |
| 5 | `-var` y `-var-file` en la línea de comandos (en el orden en que aparecen) | `"desde-cli"` |

!!! tip "En el examen"
    La pregunta típica: "se define en `terraform.tfvars` y en `TF_VAR_`, ¿cuál gana?" → **`terraform.tfvars`**. La línea de comandos siempre gana. HCP Terraform tiene sus propias variables de workspace y variable sets ([objetivo 8](objetivo-8-hcp-terraform.md)).

### Outputs y locals

```hcl title="outputs.tf"
output "nombre" {
  description = "Nombre generado"
  value       = random_pet.proyecto.id
}

output "token" {
  value     = var.token_api
  sensitive = true # obligatorio si el valor deriva de algo sensible
}
```

Si un output usa un valor sensible sin `sensitive = true`, Terraform falla (salida real): `Error: Output refers to sensitive values`. Los outputs sirven para mostrar datos tras el apply, para exponer valores de un **módulo hijo** al padre y para que otra configuración los lea con `terraform_remote_state`.

```console
$ terraform output
token = <sensitive>
$ terraform output token
"no-uses-esto-en-prod"
```

Ojo: pedir un output sensible **por nombre** (o con `-json`/`-raw`) **sí** muestra el valor.

Los **locals** (valores locales) son nombres para expresiones que se repiten dentro del módulo; no se pueden pasar desde fuera:

```hcl
locals {
  prefijo  = "lab-${var.entorno}"
  publicos = [for nombre, s in var.servicios : nombre if s.publico]
}
```

## 4d. Tipos complejos

| Tipo | Tipo primitivo/colección | Ejemplo | Detalle |
| --- | --- | --- | --- |
| `string`, `number`, `bool` | Primitivos | `"dev"`, `3`, `true` | Se convierten automáticamente cuando es posible (`"3"` ↔ `3`) |
| `list(T)` | Colección | `["a", "b"]` | Ordenada, mismo tipo, índice desde 0 |
| `set(T)` | Colección | `toset(["b", "a"])` | Sin orden ni duplicados (`toset(["b","a","b"])` → `["a","b"]`) |
| `map(T)` | Colección | `{ dev = 1, prod = 3 }` | Claves string, valores del mismo tipo |
| `object({...})` | Estructural | `{ puerto = 443, publico = true }` | Atributos con nombre y tipos distintos |
| `tuple([...])` | Estructural | `["a", 1, true]` | Posiciones fijas con tipos distintos |
| `any` | Comodín | | Terraform infiere el tipo |

```hcl title="variables.tf (probado)"
variable "servicios" {
  type = map(object({
    puerto  = number
    publico = optional(bool, false) # atributo opcional con valor por defecto
  }))
  default = {
    web = { puerto = 443, publico = true }
    api = { puerto = 8080 }
  }
}
```

`optional(tipo, default)` permite omitir atributos de un `object`. En el ejemplo, `api` queda con `publico = false`.

## 4e. Expresiones y funciones

### Expresiones

| Expresión | Ejemplo | Resultado real en `terraform console` |
| --- | --- | --- |
| **Conditional** (condicional) | `var.entorno == "prod" ? 3 : 1` | `1` |
| **For** a lista | `[for k, s in var.servicios : "${k}:${s.puerto}"]` | `["api:8080", "web:443"]` |
| **For** a mapa con filtro | `{ for k, s in var.servicios : k => s.puerto if !s.publico }` | `{ "api" = 8080 }` |
| **Splat** (`[*]`) | `var.subredes[*].cidr` | `["10.0.1.0/24", "10.0.2.0/24"]` |
| **String template** (plantilla) | `"lab-${var.entorno}"` | `"lab-dev"` |
| **Heredoc** | `<<-EOT ... EOT` | Texto multilínea (el `-` quita la indentación) |

### Meta-argumentos `count` y `for_each`

```hcl title="main.tf (probado)"
resource "random_string" "sufijo" {
  count   = 2 # crea random_string.sufijo[0] y [1]
  length  = 6
  special = false
  upper   = false
}

resource "local_file" "config" {
  for_each = var.servicios # crea local_file.config["api"] y ["web"]

  filename = "${path.module}/salida/${each.key}.conf"
  content  = <<-EOT
    nombre=${random_pet.proyecto.id}-${each.key}
    puerto=${each.value.puerto}
    publico=${each.value.publico}
  EOT
}
```

| | `count` | `for_each` |
| --- | --- | --- |
| Acepta | Un número | Un `map` o un `set` de strings |
| Dirección | `recurso[0]` | `recurso["clave"]` |
| Si quitas un elemento del medio | Los índices se desplazan y Terraform **recrea** los siguientes | Solo se destruye ese elemento |
| Úsalo para | N copias idénticas, o crear/no crear (`count = var.activar ? 1 : 0`) | Instancias distintas identificadas por nombre |

No se pueden usar `count` y `for_each` a la vez en el mismo bloque, y sus valores deben conocerse **en el plan** (no pueden depender de atributos que solo existen tras el apply).

### Dynamic blocks

Un bloque `dynamic` genera **bloques anidados** repetidos a partir de una colección. Probado con `archive_file`, que acepta varios bloques `source`:

```hcl title="main.tf (probado)"
data "archive_file" "paquete" {
  type        = "zip"
  output_path = "${path.module}/salida/paquete.zip"

  dynamic "source" {
    for_each = local_file.config
    content {
      content  = source.value.content          # el iterador se llama como el bloque
      filename = basename(source.value.filename)
    }
  }
}
```

Úsalos con moderación: hacen el código más difícil de leer. El caso clásico en la nube son las reglas `ingress` de un security group.

### Funciones built-in

Terraform **no** permite funciones definidas por el usuario (solo las integradas y las que aporten los providers). Se prueban en `terraform console`. Resultados reales:

| Función | Ejemplo | Resultado |
| --- | --- | --- |
| `upper`, `lower` | `upper(var.entorno)` | `"DEV"` |
| `join`, `split` | `join("-", ["lab", "dev"])` | `"lab-dev"` |
| `replace`, `substr`, `format` | `format("%s-%03d", "vm", 7)` | `"vm-007"` |
| `length` | `length("hola")` | `4` |
| `merge` | `merge({ a = 1 }, { b = 2, a = 9 })` | `{ a = 9, b = 2 }` (gana el último) |
| `lookup` | `lookup({ dev = 1, prod = 3 }, "qa", 1)` | `1` (valor por defecto) |
| `element` | `element(["a", "b", "c"], 4)` | `"b"` (da la vuelta) |
| `flatten` | `flatten([[1, 2], [3]])` | `[1, 2, 3]` |
| `toset`, `tolist`, `tomap` | `toset(["b", "a", "b"])` | `["a", "b"]` |
| `coalesce` | `coalesce("", "x")` | `"x"` (primer valor no vacío) |
| `try`, `can` | `try(var.servicios.db.puerto, 5432)` | `5432` |
| `cidrsubnet` | `cidrsubnet("10.0.0.0/16", 8, 2)` | `"10.0.2.0/24"` |
| `file`, `templatefile` | `file("noexiste.txt")` | Error: el archivo debe existir **antes** del plan |
| `jsonencode`, `yamlencode` | `jsonencode({ a = 1 })` | `"{\"a\":1}"` |

## 4f. Dependencias entre recursos

Terraform construye un grafo a partir de las **referencias**. Si no hay referencia pero sí una dependencia real (por ejemplo, una política IAM que debe existir antes de que una aplicación arranque), se usa `depends_on`.

```hcl title="main.tf (probado)"
resource "local_file" "marca" {
  filename = "${path.module}/marca.txt"
  content  = "creado"

  depends_on = [random_pet.base] # dependencia explícita: no hay referencia

  lifecycle {
    create_before_destroy = true
  }
}
```

| Tipo | Cómo se declara | Cuándo |
| --- | --- | --- |
| **Implicit** (implícita) | Referenciando un atributo: `ami = data.aws_ami.al2023.id` | Siempre que puedas: es la forma preferida |
| **Explicit** (explícita) | `depends_on = [recurso.nombre]` | Solo si la dependencia no se ve en los argumentos. Hace los planes más conservadores (más valores "known after apply") |

### Reglas de `lifecycle`

| Regla | Efecto | Probado |
| --- | --- | --- |
| `create_before_destroy = true` | En un reemplazo, **crea el nuevo antes** de destruir el viejo. El plan muestra `+/-` en vez de `-/+` | Sí: `+/- resource "random_pet" "servidor"` |
| `prevent_destroy = true` | Cualquier plan que destruya el recurso **falla** | Sí: `Error: Instance cannot be destroyed` |
| `ignore_changes = [atributo]` | Ignora cambios en esos atributos (por ejemplo, tags que cambia otro sistema) | Sí: cambiar `length` no generó cambios |
| `replace_triggered_by = [ref]` | Reemplaza el recurso cuando cambia otro | Sí: `will be replaced due to changes in replace_triggered_by` |
| `precondition` / `postcondition` | Custom conditions ([4g](#4g-custom-conditions)) | Sí |

!!! warning "create_before_destroy y nombres únicos"
    Si el recurso tiene un nombre que debe ser único (un bucket, un DNS), el nuevo choca con el viejo mientras ambos existen. Usa nombres generados (`name_prefix` o un sufijo aleatorio).

!!! tip "En el examen"
    - "Terraform crea los recursos en el orden en que aparecen en el archivo": **falso**. El orden lo da el grafo; lo independiente se crea **en paralelo** (10 operaciones por defecto).
    - `depends_on` acepta referencias a recursos o módulos completos, **no** a atributos sueltos y no admite expresiones calculadas.
    - `create_before_destroy` se propaga a las dependencias del recurso.

## 4g. Custom conditions

Cuatro mecanismos para validar, que se diferencian por **cuándo** se evalúan y **qué pasa si fallan**:

| Mecanismo | Dónde | Cuándo se evalúa | Si falla |
| --- | --- | --- | --- |
| **`validation`** en `variable` | Bloque `variable` | Al recibir el valor | **Error**: bloquea el plan |
| **`precondition`** | `lifecycle` de un resource/data, o en un `output` | Antes de crear/leer ese objeto | **Error** |
| **`postcondition`** | `lifecycle` de un resource/data | Después de crear/leer (puede usar `self`) | **Error** (el objeto ya puede existir) |
| **`check`** block | Bloque de nivel superior | Al final de plan y apply | Solo **warning** (aviso): no bloquea |

```hcl title="main.tf (probado)"
resource "random_pet" "proyecto" {
  prefix = local.prefijo
  length = 2

  lifecycle {
    precondition {
      condition     = length(var.servicios) > 0
      error_message = "Define al menos un servicio."
    }
    postcondition {
      condition     = startswith(self.id, local.prefijo)
      error_message = "El nombre generado no empieza por el prefijo."
    }
  }
}

check "paquete_no_vacio" {
  assert {
    condition     = data.archive_file.paquete.output_size > 0
    error_message = "El zip generado está vacío."
  }
}
```

Salidas reales:

```console
$ terraform plan -var entorno=pruebas
Error: Invalid value for variable
  on variables.tf line 1:
   1: variable "entorno" {
    │ var.entorno is "pruebas"
El entorno debe ser dev, staging o prod.

$ terraform plan          # con la condición del check forzada a fallar
Warning: Check block assertion failed
  on main.tf line 61, in check "paquete_no_vacio":
    │ data.archive_file.paquete.output_size is 364
El zip generado está vacío.
```

Desde Terraform 1.9, una `validation` puede referirse a **otras variables** (probado: `condition = var.max_nodos >= var.min_nodos`). Un bloque `check` puede tener su propio **scoped data source** (un `data` dentro del `check`), útil para comprobar, por ejemplo, que un endpoint responde con un 200 tras el despliegue. HCP Terraform evalúa los `check` periódicamente con **continuous validation** ([objetivo 8](objetivo-8-hcp-terraform.md#8b-colaboracion-y-gobierno)).

!!! tip "En el examen"
    "Quiero avisar sin bloquear el despliegue" → `check`. "Quiero rechazar un valor de entrada" → `validation`. "Quiero garantizar algo de un recurso antes/después de crearlo" → `precondition`/`postcondition`. Las pruebas automatizadas con `terraform test` son otro tema (ver [Pruebas de infraestructura](../../../devops/iac/pruebas-infraestructura.md#terraform-test)).

## 4h. Datos sensibles y Vault

### Lo que hace y no hace `sensitive`

| Medida | Oculta en la CLI | Fuera del state y del plan |
| --- | --- | --- |
| `sensitive = true` en variable u output | Sí | **No**: queda en texto plano en el state |
| `nonsensitive(valor)` | Lo **vuelve a mostrar** (probado: `nonsensitive(var.token_api)` → `"no-uses-esto-en-prod"`) | No |
| **Ephemeral** (Terraform 1.10+) | Sí | **Sí** |
| **Write-only arguments** (Terraform 1.11+) | Sí | **Sí** |

Prueba real: un `resource "random_password"` normal guardó su `result` en `terraform.tfstate`; el equivalente `ephemeral "random_password"` y una variable `ephemeral = true` **no aparecen** en el state.

### Ephemeral values (valores efímeros)

```hcl title="main.tf (probado)"
variable "clave_db" {
  type      = string
  sensitive = true
  ephemeral = true # existe solo durante la ejecución
}

ephemeral "random_password" "db" { # ephemeral resource: se abre y se cierra en cada run
  length  = 20
  special = false
}
```

Reglas que el examen puede preguntar (probadas):

- Un valor efímero solo puede usarse en sitios que también son efímeros: otras variables/outputs `ephemeral`, `locals`, bloques `provider`, provisioners y **write-only arguments**. Asignarlo a un argumento normal o a un output normal da `Error: Ephemeral value not allowed`.
- Los outputs `ephemeral = true` solo se permiten en **módulos hijo**: en el módulo raíz da `Error: Ephemeral outputs are not allowed in context of a root module`.
- En la salida verás `ephemeral.random_password.db: Opening...` y `Closing...`: no se "crea" nada.

### Write-only arguments (argumentos de solo escritura)

Algunos recursos ofrecen argumentos que terminan en `_wo`: Terraform los envía al provider pero **nunca los guarda** en el plan ni en el state. Como Terraform no recuerda el valor, se acompaña de un argumento de versión que incrementas cuando quieres rotar el secreto.

```hcl
# Ilustrativo (AWS provider reciente): contraseña de RDS que nunca llega al state
ephemeral "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_instance" "app" {
  # ... resto de argumentos ...
  username            = "app"
  password_wo         = ephemeral.random_password.db.result
  password_wo_version = 1 # súbelo a 2 para rotar la contraseña
}
```

### Vault

**HashiCorp Vault** es el gestor de secretos de HashiCorp (ver [Secretos e identidades](../../../devsecops/identidades-y-pipeline/secretos-identidades.md#hashicorp-vault)). Con el **Vault provider**, Terraform lee secretos en vez de tenerlos en `.tfvars`:

```hcl
# Ilustrativo: leer un secreto KV v2 de Vault como valor efímero
ephemeral "vault_kv_secret_v2" "db" {
  mount = "secret"
  name  = "app/db"
}

resource "aws_db_instance" "app" {
  # ...
  password_wo         = tostring(ephemeral.vault_kv_secret_v2.db.data.password)
  password_wo_version = 1
}
```

!!! warning "data source de Vault = secreto en el state"
    Con un `data "vault_kv_secret_v2"` clásico, el secreto leído **se guarda en el state**. Por eso la recomendación actual es usar el **ephemeral resource** y write-only arguments cuando el recurso destino los soporte. Revisa en la documentación del provider qué versiones los incluyen.

Buenas prácticas de datos sensibles que resume el objetivo:

- No escribir secretos en `.tf` ni en `.tfvars` versionados; usar variables de entorno, Vault o el gestor de secretos de la nube.
- Marcar variables y outputs con `sensitive = true`.
- Tratar el **state** y los **planes guardados** como secretos: backend cifrado, acceso mínimo, nunca en Git.
- Preferir ephemeral y write-only para que el secreto no llegue al state.
- En HCP Terraform, marcar variables como **sensitive** (no se pueden volver a leer desde la UI ni la API) y usar **dynamic provider credentials** en vez de llaves estáticas ([objetivo 8](objetivo-8-hcp-terraform.md)).

## Casos de uso

1. **Crear un bucket por cada equipo de una lista que cambia a menudo.** `for_each` con un `set` o `map`: quitar un equipo solo destruye su bucket (con `count` se desplazarían los índices).
2. **Crear un recurso solo en producción.** `count = var.entorno == "prod" ? 1 : 0`.
3. **Usar siempre la imagen más reciente del sistema operativo.** Un `data` source que la busca y una referencia a su `id`.
4. **Un certificado debe reemplazarse sin cortar el servicio.** `lifecycle { create_before_destroy = true }`.
5. **Proteger la base de datos de producción de un `destroy` accidental.** `prevent_destroy = true` (y, en la nube, la protección contra borrado del propio servicio).
6. **Avisar si el endpoint no responde tras el despliegue, sin bloquear el pipeline.** Bloque `check` con un data source `http` dentro.
7. **Rechazar tamaños de instancia no aprobados.** `validation` en la variable con `contains([...], var.tipo)`.
8. **La contraseña de la base de datos no debe quedar en el state.** `ephemeral` + write-only argument (`password_wo`), leyendo el valor desde Vault con un ephemeral resource.

## Preguntas de práctica

**1.** ¿Cuál es la diferencia principal entre un bloque `resource` y uno `data`?

- A. `data` crea recursos más rápido.
- B. `resource` gestiona el ciclo de vida del objeto; `data` solo lee información.
- C. `data` solo funciona con HCP Terraform.
- D. `resource` no puede referenciar a un `data`.

??? success "Respuesta"
    **B.** A y C son falsas. D es falsa: lo habitual es que un `resource` use atributos de un `data` (por ejemplo, el ID de una AMI).

**2.** Una variable `region` se define con `default = "us-east-1"`, en `terraform.tfvars` con `"eu-west-1"` y con `TF_VAR_region=sa-east-1`. Ejecutas `terraform plan` sin más opciones. ¿Qué valor se usa?

- A. `us-east-1`
- B. `eu-west-1`
- C. `sa-east-1`
- D. Terraform pide el valor de forma interactiva.

??? success "Respuesta"
    **B.** `terraform.tfvars` tiene más precedencia que las variables de entorno `TF_VAR_`, y estas más que el `default`. Solo `*.auto.tfvars` y la línea de comandos estarían por encima.

**3.** Tienes `count = length(var.nombres)` con `["a", "b", "c"]` y quitas `"a"` de la lista. ¿Qué propondrá el plan?

- A. Destruir solo la instancia de `"a"`.
- B. Cambiar o reemplazar las instancias `[0]` y `[1]` y destruir `[2]`.
- C. Ningún cambio.
- D. Un error de validación.

??? success "Respuesta"
    **B.** Con `count` las instancias se identifican por índice: `"b"` pasa a `[0]` y `"c"` a `[1]`, y `[2]` sobra. Con `for_each = toset(var.nombres)` solo se destruiría `"a"` (A).

**4.** Quieres que un despliegue continúe aunque una comprobación de salud falle, pero que quede un aviso visible. ¿Qué usas?

- A. `validation` en una variable.
- B. `precondition` en el recurso.
- C. Un bloque `check`.
- D. `prevent_destroy`.

??? success "Respuesta"
    **C.** Los `check` generan warnings, no errores. A y B bloquean la ejecución. D no valida nada.

**5.** ¿Qué hace `lifecycle { create_before_destroy = true }`?

- A. Impide destruir el recurso.
- B. En un reemplazo, crea el objeto nuevo antes de destruir el anterior.
- C. Crea el recurso antes que todos los demás.
- D. Ignora cambios en los atributos.

??? success "Respuesta"
    **B.** A es `prevent_destroy`; C no existe (el orden lo da el grafo); D es `ignore_changes`.

**6.** ¿Cuáles de estas medidas evitan que un secreto se guarde en el state? (Elige DOS.)

- A. `sensitive = true` en la variable.
- B. Declarar la variable con `ephemeral = true` y usarla en un write-only argument.
- C. Leer el secreto con un `data` source de Vault.
- D. Generarlo con un `ephemeral` resource y pasarlo a un argumento `_wo`.

??? success "Respuesta"
    **B y D.** A solo lo oculta en la salida. C lo guarda en el state (por eso se prefiere el ephemeral resource de Vault).

**7.** ¿Cuándo es necesario `depends_on`?

- A. Siempre que un recurso use un atributo de otro.
- B. Cuando existe una dependencia real que Terraform no puede deducir de las referencias.
- C. Para que los recursos se creen en el orden del archivo.
- D. Para que un data source se lea antes del plan.

??? success "Respuesta"
    **B.** A ya genera una dependencia implícita; añadir `depends_on` es redundante. C no es como funciona Terraform. D no es su propósito.

**8.** Verdadero o falso: en Terraform puedes definir funciones propias con un bloque `function`.

??? success "Respuesta"
    **Falso.** Solo existen las funciones integradas y, desde Terraform 1.8, funciones que aporten los providers (`provider::nombre::funcion`). Para lógica reutilizable se usan `locals` y módulos.

## Para profundizar

- [Infrastructure as Code con Terraform](../../../devops/iac/terraform-basico.md#dar-valor-a-las-variables): variables, precedencia y ejemplo completo con AWS.
- [Terraform workspaces](../../../devops/iac/terraform-workspaces.md#usar-el-workspace-en-el-codigo): `terraform.workspace` en mapas de `locals` y `precondition` para bloquear `default`.
- [Pruebas de infraestructura](../../../devops/iac/pruebas-infraestructura.md): `terraform test` y `mock_provider`.
- [Secretos e identidades](../../../devsecops/identidades-y-pipeline/secretos-identidades.md) y [Seguridad de IaC](../../../devsecops/infraestructura-y-contenedores/seguridad-iac.md): Vault, rotación, escaneo de configuración.
- Siguiente: [Objetivo 5: Terraform modules](objetivo-5-modulos.md).

## Referencias

- [Resources](https://developer.hashicorp.com/terraform/language/resources) y [Data sources](https://developer.hashicorp.com/terraform/language/data-sources)
- [References to named values](https://developer.hashicorp.com/terraform/language/expressions/references)
- [Input variables](https://developer.hashicorp.com/terraform/language/values/variables) y [Output values](https://developer.hashicorp.com/terraform/language/values/outputs)
- [Type constraints](https://developer.hashicorp.com/terraform/language/expressions/type-constraints)
- [Expressions](https://developer.hashicorp.com/terraform/language/expressions) y [Built-in functions](https://developer.hashicorp.com/terraform/language/functions)
- [The lifecycle meta-argument](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [Custom conditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions) y [Checks](https://developer.hashicorp.com/terraform/language/checks)
- [Manage sensitive data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)
- [Ephemeral values](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/ephemeral) y [Write-only arguments](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/write-only)
- [Vault provider](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)
