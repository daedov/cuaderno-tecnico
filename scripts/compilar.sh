#!/usr/bin/env bash
# Genera el sitio estático en site/
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
exec mkdocs build "$@"
