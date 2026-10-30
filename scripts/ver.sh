#!/usr/bin/env bash
# Arranca el servidor local para ver el cuaderno en http://127.0.0.1:8000
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Linux/macOS usan .venv/bin; Windows (Git Bash) usa .venv/Scripts
# shellcheck disable=SC1091
if [ -f .venv/bin/activate ]; then
  source .venv/bin/activate
else
  source .venv/Scripts/activate
fi

export NO_MKDOCS_2_WARNING=1
exec mkdocs serve "$@"
