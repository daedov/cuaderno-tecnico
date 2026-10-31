---
tags:
  - recursos
  - terraform
  - iac
---

# HCL (Terraform)

> Las piezas del lenguaje de Terraform: bloques, argumentos, expresiones y referencias. Para ver cada archivo de un proyecto real comentado línea por línea, consulta [Anatomía de los archivos de Terraform](../anatomia/terraform.md).

## Bloques, argumentos y atributos

**HCL** (*HashiCorp Configuration Language*, lenguaje de configuración de HashiCorp) tiene muy pocas piezas. Todo archivo `.tf` es una lista de **blocks** (bloques) que contienen **arguments** (argumentos) y otros bloques:

```hcl title="sintaxis.tf"
# Comentario de una línea (el estilo recomendado)
// También comentario de una línea
/* Comentario
   de varias líneas */

resource "aws_s3_bucket" "logs" { # tipo de bloque + 2 etiquetas (labels) + { cuerpo }
  bucket = "logs-${var.entorno}"  # argumento: nombre = expresión (con interpolación)
  tags = {                        # argumento cuyo valor es un mapa (lleva =)
    Equipo = "plataforma"
  }

  lifecycle { # bloque anidado: SIN = delante de la llave
    prevent_destroy = true
  }
}

output "logs_arn" {              # bloque con 1 etiqueta
  value = aws_s3_bucket.logs.arn # referencia: <tipo>.<nombre>.<atributo>
}
```

| Elemento | Qué es | Ejemplo |
| --- | --- | --- |
| **Block** (bloque) | Contenedor con un tipo, 0 o más etiquetas y un cuerpo entre `{ }` | `resource "aws_instance" "api" { … }` |
| **Block type** (tipo de bloque) | La palabra inicial: define qué es | `terraform`, `provider`, `variable`, `locals`, `data`, `resource`, `module`, `output` |
| **Labels** (etiquetas) | Textos entre comillas tras el tipo; cuántas lleva depende del tipo | `resource` lleva 2 (tipo y nombre local), `variable` 1, `locals` 0 |
| **Argument** (argumento) | `nombre = expresión`: un valor que tú asignas | `instance_type = "t3.micro"` |
| **Attribute** (atributo) | Un valor que el recurso **expone** para leerlo (los argumentos también se pueden leer); algunos solo se conocen tras el `apply` | `aws_instance.api.id`, `.arn`, `.public_ip` |
| **Nested block** (bloque anidado) | Bloque dentro de otro, sin `=`; puede repetirse si el esquema lo permite | `filter { … }`, `lifecycle { … }` |
| **Expression** (expresión) | Lo que va a la derecha del `=` | `"texto"`, `3`, `true`, `null`, `[…]`, `{…}`, `var.x`, `cond ? a : b` |
| **Identifier** (identificador) | Nombres de bloques, argumentos y etiquetas: letras, números, `_` y `-`; no empiezan por número | `token_alertas`, `bucket-logs` |

## Expresiones y referencias

| Expresión | Ejemplo | Resultado |
| --- | --- | --- |
| String y **interpolation** (interpolación) | `"lab-api-${var.entorno}"` | `"lab-api-dev"` |
| Número, booleano, nulo | `8000`, `true`, `null` | `null` = "como si no pusieras el argumento" |
| Lista / tupla | `["a", "b"]` | Se accede con `[0]` |
| Mapa / objeto | `{ Equipo = "plataforma" }` | Se accede con `["Equipo"]` o `.Equipo` |
| Operadores | `==`, `!=`, `>`, `&&`, `\|\|`, `!`, `+`, `%` | `var.entorno == "prod"` |
| **Conditional** (condicional) | `local.es_prod ? 365 : 30` | Si es prod, 365; si no, 30 |
| **For expression** (expresión for) | `[for ip in local.ips : "http://${ip}"]` | Transforma una lista o mapa |
| **Splat** | `aws_instance.api[*].public_ip` | Lista con el atributo de cada copia |
| **Function call** (función) | `merge(a, b)`, `cidrsubnet(cidr, 8, 1)`, `toset(lista)` | Solo funciones integradas; no puedes crear las tuyas |
| **Heredoc** | `<<-EOT … EOT` | String de varias líneas (`<<-` quita la indentación) |

Las **references** (referencias) son la forma de usar un valor de otro bloque. Cada vez que un bloque referencia a otro, Terraform anota una **dependencia implícita** y los crea en el orden correcto:

| Referencia | Apunta a |
| --- | --- |
| `var.<nombre>` | Una variable de entrada |
| `local.<nombre>` | Un valor de `locals` (ojo: el bloque es `locals`, la referencia `local`) |
| `<tipo>.<nombre>.<atributo>` | Un atributo de un recurso: `aws_security_group.api.id` |
| `<tipo>.<nombre>[0]` / `["clave"]` | Una copia concreta de un recurso con `count` / `for_each` |
| `data.<tipo>.<nombre>.<atributo>` | Un atributo de un data source: `data.aws_ami.al2023.id` |
| `module.<nombre>.<output>` | Un output de un módulo hijo: `module.vpc.vpc_id` |
| `count.index`, `each.key`, `each.value` | La copia actual dentro de un recurso con `count` / `for_each` |
| `path.module`, `path.root` | Carpeta del módulo actual / del root module |
| `terraform.workspace` | Nombre del workspace actual |

!!! example "Practica en el laboratorio"
    - [Lab 08: Terraform sin nube: providers locales y workspaces](../../laboratorios/devops/terraform-local-workspaces.md)
    - [Lab 09: Terraform en AWS con remote state en S3](../../laboratorios/devops/terraform-aws-backend-remoto.md)
