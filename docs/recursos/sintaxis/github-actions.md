---
tags:
  - github-actions
  - ci-cd
---


# GitHub Actions
| Elemento | Descripción |
|----------|-------------|
| `on: [push, pull_request]` | Eventos que disparan el workflow |
| `jobs:` | Define uno o más trabajos |
| `runs-on: ubuntu-latest` | Runner/entorno del job |
| `steps:` | Lista de pasos dentro de un job |
| `uses: actions/checkout@v7` | Usa una action predefinida |
| `run: <comando>` | Ejecuta un comando shell |
| `env:` | Define variables de entorno |
| `secrets.<NOMBRE>` | Accede a un secreto configurado en el repo |
| `needs: <job>` | Define dependencia entre jobs |
| `strategy: matrix:` | Ejecuta el job con múltiples configuraciones |

!!! tip "Anatomía completa"
    Para ver cada clave en un workflow real comentado línea por línea (eventos, permisos, matrix, environments, outputs, reusable workflows y composite actions), consulta [Anatomía de los workflows de GitHub Actions](../anatomia/github-actions.md).

!!! example "Practica en el laboratorio"
    - [Lab 04: Flujo Git con ramas, pull requests y code review](../../laboratorios/devops/git-flujo-pull-request.md)
    - [Lab 07: Pipeline de CI con GitHub Actions](../../laboratorios/devops/github-actions-ci.md)
    - [Lab 13: Desplegar en AWS desde GitHub Actions con OIDC (sin llaves)](../../laboratorios/devsecops/oidc-github-aws.md)

