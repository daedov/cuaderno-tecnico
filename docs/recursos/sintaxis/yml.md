---
tags:
  - yaml
  - yml
  - configuracion
---

# YAML / YML

> YAML (acrónimo recursivo de "YAML Ain't Markup Language") es un formato de serialización de datos diseñado para ser legible por humanos. En la práctica, es la forma en que escribes archivos de configuración de manera clara y ordenada.

!!! note "¿Dónde se usa YAML?"

    Kubernetes, Ansible, GitHub Actions, Azure DevOps, GitLab CI/CD, ArgoCD, AWS CloudFormation, entre otros.

**Sus ideas clave:**

- La estructura se define por indentación con espacios (nunca tabs), en vez de llaves o etiquetas como JSON o XML.
- Representa dos cosas básicas: mapas (pares clave: valor) y listas (elementos con -), que puedes anidar.
- No lleva sintaxis "ruidosa", así que es fácil de leer y editar a mano.


!!! danger "La importancia de la indentación"
    El detalle que más problemas causa es que la indentación es significativa, un espacio de más o un tab mal puesto rompe el archivo. Por eso conviene validar con [yamllint](https://yamllint.readthedocs.io/en/stable/index.html).

## Ejemplo en Docker Compose
```yaml
---
services:
  web:
    image: nginx:latest
    ports:
      - "80:80" 
    environment:
      - ENV=produccion
    depends_on:
      - db
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: "${DB_PASS}"
```

## 1. Fundamentos
| Elemento | Descripción |
|----------|-------------|
| `clave: valor` | Par clave-valor (par de un mapa) |
| Indentación con espacios | La estructura se define con espacios, **nunca tabulaciones** |
| 2 espacios por nivel | Convención de indentación recomendada |
| `# comentario` | Comentario de una línea |
| `---` | Inicio de un documento YAML |
| `...` | Fin de un documento YAML |
| `clave:` (sin valor) | Declara un mapa/objeto anidado debajo |

## 2. Tipos de datos escalares
| Elemento | Descripción |
|----------|-------------|
| `nombre: texto` | Cadena sin comillas |
| `nombre: "texto"` | Cadena con comillas dobles (permite escapes) |
| `nombre: 'texto'` | Cadena con comillas simples (literal) |
| `edad: 42` | Número entero |
| `precio: 3.14` | Número decimal |
| `activo: true` | Booleano (`true`/`false`, también `yes`/`no`) |
| `valor: null` | Valor nulo (también `~`) |
| `fecha: 2026-07-12` | Fecha en formato ISO 8601 |

## 3. Listas (secuencias)
| Elemento | Descripción |
|----------|-------------|
| `- item` | Elemento de una lista (formato en bloque) |
| `frutas:` / `  - manzana` | Lista anidada bajo una clave |
| `frutas: [manzana, pera]` | Lista en formato en línea (flow) |
| `- clave: valor` | Lista de mapas (objetos) |
| lista vacía `[]` | Representa una lista sin elementos |

## 4. Mapas (diccionarios)
| Elemento | Descripción |
|----------|-------------|
| `persona:` / `  nombre: Ana` | Mapa anidado en bloque |
| `persona: {nombre: Ana, edad: 30}` | Mapa en formato en línea (flow) |
| mapa vacío `{}` | Representa un mapa sin claves |
| Anidamiento por indentación | Los niveles se anidan aumentando la sangría |

## 5. Cadenas multilínea
| Elemento | Descripción |
|----------|-------------|
| `texto: \|` | Bloque literal: conserva los saltos de línea |
| `texto: >` | Bloque plegado: convierte saltos de línea en espacios |
| `texto: \|-` | Literal recortando el salto de línea final |
| `texto: \|+` | Literal conservando los saltos de línea finales |
| `texto: >-` | Plegado recortando el salto de línea final |

## 6. Anclas y reutilización
| Elemento | Descripción |
|----------|-------------|
| `&ancla` | Definir un ancla (marca un nodo reutilizable) |
| `*ancla` | Referencia al valor de un ancla |
| `<<: *ancla` | Fusionar (merge) las claves de un mapa anclado |
| `defaults: &defaults` | Patrón común para definir valores por defecto reutilizables |

## 7. Tipos explícitos y especiales
| Elemento | Descripción |
|----------|-------------|
| `!!str 123` | Forzar el tipo cadena |
| `!!int "42"` | Forzar el tipo entero |
| `!!float`, `!!bool`, `!!null` | Etiquetas de tipo explícitas |
| `!Ref`, `!Sub` | Tags personalizados (ej. AWS CloudFormation) |
| `? clave compleja` / `: valor` | Clave explícita (para claves multilínea o compuestas) |

## 8. Múltiples documentos y buenas prácticas
| Elemento | Descripción |
|----------|-------------|
| `---` entre bloques | Separa varios documentos en un mismo archivo |
| Usar espacios, no tabs | Las tabulaciones causan errores de parseo |
| Comillas en valores ambiguos | Encomillar `"yes"`, `"true"`, `"3.0"` para evitar conversión automática |
| Encomillar valores con `:` o `#` | Evita que se interpreten como estructura o comentario |
| `yamllint <archivo>` | Validar sintaxis y estilo del YAML |


