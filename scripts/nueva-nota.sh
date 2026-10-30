#!/usr/bin/env bash
# Crea una nota nueva a partir de la plantilla.
# Uso: ./scripts/nueva-nota.sh <seccion> "Título de la nota"
#   seccion: carpeta dentro de docs/, p. ej. devops o devops/contenedores
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$#" -lt 2 ]; then
  echo "Uso: $0 <seccion> \"Título de la nota\""
  echo "Sección: carpeta dentro de docs/, p. ej. devops o devops/contenedores"
  exit 1
fi

SECCION="$1"
TITULO="$2"
DIR="$ROOT/docs/$SECCION"

if [ ! -d "$DIR" ]; then
  echo "Error: la sección '$SECCION' no existe en docs/."
  echo "Secciones disponibles:"
  find "$ROOT/docs" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
  exit 1
fi

# slug: minúsculas, espacios -> guiones, sin acentos ni símbolos
SLUG="$(echo "$TITULO" \
  | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null || echo "$TITULO")"
SLUG="$(echo "$SLUG" | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')"

ARCHIVO="$DIR/$SLUG.md"

if [ -e "$ARCHIVO" ]; then
  echo "Error: ya existe $ARCHIVO"
  exit 1
fi

PLANTILLA="$ROOT/scripts/plantilla-nota.md"

if [ ! -f "$PLANTILLA" ]; then
  echo "Error: no se encontró la plantilla en $PLANTILLA"
  exit 1
fi

# La etiqueta es la última carpeta (devops/contenedores -> contenedores),
# igual que en las notas existentes.
ETIQUETA="$(basename "$SECCION")"

# Escapa los caracteres especiales de sed (\ / &) en lo que se sustituye
escapar() { printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'; }

sed -e "s/{{SECCION}}/$(escapar "$ETIQUETA")/g" \
    -e "s/{{TITULO}}/$(escapar "$TITULO")/g" "$PLANTILLA" > "$ARCHIVO"

echo "Nota creada: $ARCHIVO"
