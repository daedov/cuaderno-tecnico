---
tags:
  - shell
  - bash
  - scripting
---


# Shell / Bash

## 1. Estructura básica de un script
| Elemento | Descripción |
|----------|-------------|
| `#!/usr/bin/env bash` | Shebang: intérprete que ejecuta el script |
| `# <comentario>` | Comentario de una línea |
| `chmod +x script.sh` | Dar permisos de ejecución |
| `./script.sh` | Ejecutar el script |
| `bash script.sh` | Ejecutar con un intérprete explícito |
| `set -euo pipefail` | Modo estricto: corta ante errores, variables sin definir y fallos en tuberías |
| `set -x` | Depuración: imprime cada comando antes de ejecutarlo |

## 2. Variables
| Elemento | Descripción |
|----------|-------------|
| `nombre="valor"` | Asignar variable (sin espacios alrededor del `=`) |
| `$nombre` / `${nombre}` | Expandir el valor de una variable |
| `readonly VAR=1` | Variable de solo lectura (constante) |
| `export VAR=1` | Exportar variable al entorno de subprocesos |
| `local var=1` | Variable local dentro de una función |
| `${var:-default}` | Usar `default` si la variable está vacía o sin definir |
| `${var:=default}` | Asignar `default` si está vacía o sin definir |
| `${var:?mensaje}` | Fallar con `mensaje` si la variable no está definida |
| `${#var}` | Longitud de la cadena |
| `${var:0:3}` | Subcadena (posición 0, longitud 3) |
| `${var/viejo/nuevo}` | Reemplazar primera coincidencia dentro de la cadena |
| `${var^^}` / `${var,,}` | Convertir a mayúsculas / minúsculas |

## 3. Parámetros y argumentos
| Elemento | Descripción |
|----------|-------------|
| `$0` | Nombre del script |
| `$1`, `$2`, ... | Argumentos posicionales |
| `$#` | Número de argumentos recibidos |
| `$@` | Todos los argumentos (como lista separada) |
| `"$*"` | Todos los argumentos como una sola cadena |
| `$?` | Código de salida del último comando |
| `$$` | PID del proceso actual |
| `shift` | Desplazar los argumentos posicionales |
| `getopts "a:b" opt` | Parsear opciones de línea de comandos |

## 4. Sustitución y expansión
| Elemento | Descripción |
|----------|-------------|
| `$(comando)` | Sustitución de comando (recomendada) |
| `` `comando` `` | Sustitución de comando (sintaxis antigua) |
| `$((2 + 3))` | Expansión aritmética |
| `{1..5}` | Expansión de rango (1 2 3 4 5) |
| `{a,b,c}` | Expansión de llaves (a b c) |
| `*.txt` | Comodín (glob) que expande nombres de archivo |
| `<(comando)` | Sustitución de proceso (usar salida como archivo) |

## 5. Comillas y escape
| Elemento | Descripción |
|----------|-------------|
| `"texto $var"` | Comillas dobles: permiten expansión de variables |
| `'texto $var'` | Comillas simples: literal, sin expansión |
| `\$` | Escapar un carácter especial |
| `$'\n'` | Cadena con secuencias de escape (salto de línea) |

## 6. Condicionales
| Elemento | Descripción |
|----------|-------------|
| `if [ cond ]; then ... fi` | Estructura condicional básica |
| `if [[ cond ]]; then ... fi` | Condicional extendido (recomendado en Bash) |
| `elif [[ cond ]]; then` | Condición alternativa |
| `else` | Bloque por defecto |
| `[ -f <archivo> ]` | Verdadero si el archivo existe |
| `[ -d <ruta> ]` | Verdadero si el directorio existe |
| `[ -z "$var" ]` | Verdadero si la cadena está vacía |
| `[ -n "$var" ]` | Verdadero si la cadena no está vacía |
| `[ "$a" = "$b" ]` | Comparación de cadenas |
| `[ "$a" -eq "$b" ]` | Comparación numérica (`-eq -ne -lt -le -gt -ge`) |
| `[[ "$a" =~ regex ]]` | Comparación con expresión regular |
| `case "$var" in patrón) ... ;; esac` | Selección múltiple según patrón |

## 7. Bucles
| Elemento | Descripción |
|----------|-------------|
| `for i in <lista>; do ... done` | Bucle sobre una lista |
| `for ((i=0; i<n; i++)); do ... done` | Bucle estilo C |
| `while [[ cond ]]; do ... done` | Bucle mientras se cumpla la condición |
| `until [[ cond ]]; do ... done` | Bucle hasta que se cumpla la condición |
| `break` | Salir del bucle |
| `continue` | Saltar a la siguiente iteración |
| `while read -r line; do ... done < archivo` | Leer un archivo línea por línea |

## 8. Funciones
| Elemento | Descripción |
|----------|-------------|
| `nombre() { ... }` | Definir una función |
| `function nombre { ... }` | Sintaxis alternativa de función |
| `nombre arg1 arg2` | Llamar a la función con argumentos |
| `local var` | Declarar variable local a la función |
| `return <n>` | Devolver un código de salida (0-255) |
| `echo "resultado"` | Devolver un valor por stdout (capturar con `$(...)`) |

## 9. Redirección y tuberías
| Elemento | Descripción |
|----------|-------------|
| `> archivo` | Redirigir stdout (sobrescribe) |
| `>> archivo` | Redirigir stdout (agrega) |
| `2> archivo` | Redirigir stderr |
| `2>&1` | Redirigir stderr al mismo destino que stdout |
| `&> archivo` | Redirigir stdout y stderr juntos |
| `< archivo` | Redirigir entrada estándar desde un archivo |
| `\| comando` | Encadenar la salida hacia otro comando |
| `\|\|` / `&&` | Ejecutar según fallo / éxito del comando previo |
| `cat <<EOF ... EOF` | Here-document (bloque de texto multilínea) |
| `read var <<< "texto"` | Here-string (pasar cadena como entrada) |

## 10. Arreglos
| Elemento | Descripción |
|----------|-------------|
| `arr=(a b c)` | Definir un arreglo |
| `${arr[0]}` | Acceder a un elemento |
| `${arr[@]}` | Todos los elementos |
| `${#arr[@]}` | Número de elementos |
| `arr+=(d)` | Agregar un elemento |
| `declare -A mapa` | Declarar un arreglo asociativo (diccionario) |
| `mapa[clave]="valor"` | Asignar en un arreglo asociativo |

## 11. Manejo de errores y trazas
| Elemento | Descripción |
|----------|-------------|
| `command \|\| { echo "error"; exit 1; }` | Manejar el fallo de un comando |
| `trap 'comando' EXIT` | Ejecutar algo al salir del script (limpieza) |
| `trap 'comando' ERR` | Ejecutar algo cuando un comando falla |
| `exit <n>` | Terminar el script con un código de salida |
| `${LINENO}` | Número de línea actual (útil en mensajes de error) |
| `>&2 echo "mensaje"` | Escribir un mensaje en stderr |

## 12. Ejemplo de referencia

Script robusto: modo estricto, argumento obligatorio, valor por defecto, logs a stderr, limpieza con `trap` y reintentos.

```bash title="backup.sh"
#!/usr/bin/env bash
# Comprime un directorio y lo copia a un bucket. Uso: ./backup.sh <directorio>
set -euo pipefail

readonly ORIGEN="${1:?Uso: $0 <directorio>}"
readonly DESTINO="${BACKUP_BUCKET:-s3://mi-bucket-backups}"
readonly ARCHIVO="/tmp/backup-$(date +%Y%m%d-%H%M%S).tar.gz"

log() {
  echo "[$(date +%H:%M:%S)] $*" >&2
}

limpiar() {
  rm -f "$ARCHIVO"
}
trap limpiar EXIT

if [[ ! -d "$ORIGEN" ]]; then
  log "ERROR: $ORIGEN no es un directorio"
  exit 1
fi

log "Comprimiendo $ORIGEN"
tar -czf "$ARCHIVO" -C "$ORIGEN" .

for intento in 1 2 3; do
  if aws s3 cp "$ARCHIVO" "$DESTINO/"; then
    log "Backup subido"
    exit 0
  fi
  log "Fallo en intento $intento, reintentando..."
  sleep 5
done

log "ERROR: no se pudo subir el backup"
exit 2
```

| Pieza | Para qué sirve |
| --- | --- |
| `set -e` | Termina el script si un comando falla (código distinto de 0) |
| `set -u` | Falla si usas una variable no definida (evita `rm -rf "$DIR/"` con `DIR` vacío) |
| `set -o pipefail` | Una tubería (`a \| b`) falla si falla cualquier comando, no solo el último |
| `"${1:?mensaje}"` / `"${VAR:-defecto}"` | Argumento obligatorio / valor por defecto |
| `trap limpiar EXIT` | Borra el temporal al salir, haya error o no |
| `log ... >&2` | Los mensajes van a *stderr*, así no ensucian la salida útil |
| `exit 1` / `exit 2` | Códigos distintos por tipo de fallo, para que el pipeline sepa qué pasó |

!!! tip "Siempre comillas en las variables"
    Escribe `"$VAR"`, no `$VAR`. Sin comillas, un valor con espacios se parte en varias palabras y un valor vacío desaparece. Usa **ShellCheck** (`shellcheck script.sh`) para detectar estos errores; se integra fácil en CI.
