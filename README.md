# Cuaderno de Notas Técnicas

📖 **Sitio publicado:** <https://daedov.github.io/cuaderno-tecnico/>

Cuaderno personal de notas sobre **Cloud**, **DevOps** y **DevSecOps** —con bases de
**Networking**, **Servidores**, **Negocio** y **Python**—, más **laboratorios** prácticos y
guías de **certificaciones**. Escrito en Markdown y publicado con [MkDocs](https://www.mkdocs.org/) + [Material](https://squidfunk.github.io/mkdocs-material/).

## Requisitos

- Python 3.8+

## Instalación

```bash
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Uso

```bash
mkdocs serve      # servidor local con recarga en http://127.0.0.1:8000
mkdocs build      # genera el sitio estático en site/
```

## Estructura

```
docs/
├── index.md                  # portada
├── mapa-de-relaciones.md     # cómo se conectan Cloud, DevOps y DevSecOps
├── etiquetas.md              # índice de notas por etiqueta (plugin tags)
├── negocio/                  # TI y negocio: SLA/SLO, ITIL, KPIs, continuidad, riesgo
├── networking/               # basico/ · intermedio/ · avanzado/
├── servidores/               # linux/ · windows/ · ansible/
├── cloud/                    # fundamentos/ · computo/ · redes-y-datos/ · identidad-y-seguridad/
│                             # seguridad/ · operacion-y-gobierno/ · arquitectura/
├── devops/                   # fundamentos/ · ci-cd/ · contenedores/ · iac/ · operacion/
├── devsecops/                # escaneos/ · hardening/ · vulnerabilidades/ · codigo-y-dependencias/
│                             # identidades-y-pipeline/ · infraestructura-y-contenedores/
│                             # gobierno-y-respuesta/
├── python/                   # fundamentos/ · scripting/
├── laboratorios/             # prácticas guiadas: fundamentos, devops, devsecops, cloud, operacion
├── certificaciones/          # AWS, Azure, Google Cloud, HashiCorp y roles profesionales
├── recursos/                 # comandos/ · sintaxis/ · anatomia/ · puertos · docs oficiales
├── stylesheets/extra.css     # estilos propios
└── javascripts/copiar-comandos.js  # botón "copiar" en las tablas de Recursos > Comandos

scripts/
├── nueva-nota.sh             # crea una nota desde la plantilla
├── plantilla-nota.md         # plantilla base de una nota
├── ver.sh                    # mkdocs serve
└── compilar.sh               # mkdocs build

.github/workflows/
├── deploy.yml                # push a main -> build -> GitHub Pages
└── ci.yml                    # PR -> solo valida el build
```

El orden de cada sección en el menú se fija con su archivo `.pages` (plugin `awesome-pages`).

## Añadir una nota nueva

**Opción A — script:**

```bash
./scripts/nueva-nota.sh devops/contenedores "Mi nota sobre Kubernetes"
```

El primer argumento es la carpeta (que debe existir) dentro de `docs/` (sección o subsección).

La plantilla vive en `scripts/plantilla-nota.md`; editarla cambia todas las notas
futuras.

**Opción B — manual:** crea un archivo `.md` dentro de la carpeta del tema
(p. ej. `docs/cloud/computo/`, `docs/devsecops/escaneos/`). Gracias al plugin
`awesome-pages`, aparecerá automáticamente en el menú de navegación —
no hay que tocar `mkdocs.yml`.

## Añadir un tema nuevo

1. Crea una carpeta en `docs/`, p. ej. `docs/observabilidad/`.
2. Añade un `index.md` dentro.
3. (Opcional) Añade su nombre en `docs/.pages` para fijar el orden en el menú, y un
   `.pages` dentro de la carpeta para ordenar sus subsecciones.

## Publicación

Cada push a `main` dispara el workflow `deploy.yml`, que compila el sitio con
`mkdocs build --strict` y lo publica en GitHub Pages. El modo estricto convierte
cualquier enlace roto en un fallo del build, así que nunca se publica un sitio roto.

Los pull requests disparan `ci.yml`, que solo compila para validar el cambio.