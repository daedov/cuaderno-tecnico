# Git 

## 1. Configuración inicial
| Comando | Descripción |
|---------|-------------|
| `git config --global user.name "<nombre>"` | Configurar nombre de usuario |
| `git config --global user.email "<email>"` | Configurar correo de usuario |
| `git config --list` | Ver configuración activa |
| `git init` | Inicializar un repositorio nuevo |
| `git clone <url>` | Clonar repositorio |

## 2. Operaciones básicas
| Comando | Descripción |
|---------|-------------|
| `git status` | Estado del repositorio |
| `git add <archivo>` | Agregar cambios |
| `git add .` | Agregar todos los cambios |
| `git commit -m "<mensaje>"` | Confirmar cambios |
| `git commit --amend` | Modificar el último commit |
| `git commit --amend --no-edit` | Modificar el último commit sin cambiar el mensaje |
| `git pull` | Actualizar repositorio local |
| `git push` | Subir cambios |
| `git push -u origin <rama>` | Subir rama y establecer upstream |
| `git diff` | Ver diferencias no confirmadas |

## 3. Ramas y navegación
| Comando | Descripción |
|---------|-------------|
| `git branch` | Listar ramas locales |
| `git branch -r` | Listar ramas remotas |
| `git branch <nombre>` | Crear rama |
| `git checkout -b <nombre>` | Crear y cambiar a una rama nueva |
| `git switch <rama>` | Cambiar de rama |
| `git branch -d <rama>` | Eliminar rama fusionada |
| `git branch -D <rama>` | Forzar eliminación de rama no fusionada |
| `git push origin --delete <rama>` | Eliminar rama remota |
| `git fetch --prune` | Sincronizar y limpiar referencias de ramas remotas eliminadas |
| `git merge <rama>` | Fusionar rama actual con otra |
| `git merge --no-ff <rama>` | Fusionar forzando un commit de merge (trazabilidad en Git Flow) |
| `git rebase <rama>` | Reaplicar commits sobre otra base |
| `git rebase --onto <nueva_base> <base_antigua> <rama>` | Rebase avanzado moviendo commits a otra base |

## 4. Cambios temporales (stash)
| Comando | Descripción |
|---------|-------------|
| `git stash` | Guardar cambios temporalmente |
| `git stash pop` | Recuperar y eliminar el último stash |
| `git stash list` | Listar stashes guardados |
| `git stash apply` | Aplicar un stash sin eliminarlo |
| `git stash drop` | Eliminar un stash sin aplicarlo |

## 5. Historial y depuración
| Comando | Descripción |
|---------|-------------|
| `git log` | Ver historial |
| `git log --oneline --graph --all --decorate` | Historial visual completo con ramas y tags |
| `git log --author="<nombre>"` | Filtrar commits por autor |
| `git log --since="2 weeks ago"` | Filtrar commits por fecha |
| `git log -p <archivo>` | Ver historial de cambios de un archivo específico |
| `git show <commit>` | Ver detalles y diff de un commit específico |
| `git blame <archivo>` | Ver quién modificó cada línea de un archivo |
| `git bisect start` | Iniciar búsqueda binaria de un commit que introdujo un bug |
| `git bisect good/bad <commit>` | Marcar commit como bueno/malo durante el bisect |
| `git reflog` | Ver historial de referencias (recuperar commits "perdidos") |

## 6. Deshacer cambios
| Comando | Descripción |
|---------|-------------|
| `git restore <archivo>` | Descartar cambios locales de un archivo |
| `git restore --staged <archivo>` | Sacar un archivo del área de staging |
| `git reset --soft HEAD~1` | Deshacer el último commit conservando cambios en staging |
| `git reset --mixed HEAD~1` | Deshacer el último commit conservando cambios sin stage |
| `git reset --hard <commit>` | Revertir a un commit (descarta todos los cambios) |
| `git revert <commit>` | Revertir un commit creando uno nuevo (seguro en ramas compartidas) |

## 7. Reescritura de historial
| Comando | Descripción |
|---------|-------------|
| `git rebase -i HEAD~<n>` | Rebase interactivo de los últimos n commits (squash, reorder, edit) |
| `git rebase -i --autosquash` | Aplicar automáticamente los commits `fixup`/`squash` |
| `git commit --fixup <commit>` | Crear commit de corrección para un commit anterior |
| `git cherry-pick <commit>` | Aplicar un commit específico de otra rama |
| `git filter-repo --path <ruta>` | Reescribir historial (extraer/eliminar rutas), reemplaza a `filter-branch` |

## 8. Tags y releases (versionado para CI/CD)
| Comando | Descripción |
|---------|-------------|
| `git tag` | Listar tags |
| `git tag -a v1.0.0 -m "<mensaje>"` | Crear tag anotado (recomendado para releases) |
| `git push origin v1.0.0` | Subir un tag específico |
| `git push origin --tags` | Subir todos los tags al remoto |
| `git tag -d v1.0.0` | Eliminar tag local |
| `git push origin --delete v1.0.0` | Eliminar tag remoto |
| `git describe --tags` | Obtener el tag más reciente relativo al commit actual (útil para versionado automático en pipelines) |

## 9. Remotos
| Comando | Descripción |
|---------|-------------|
| `git remote -v` | Ver repositorios remotos |
| `git remote add <nombre> <url>` | Agregar un remoto |
| `git remote remove <nombre>` | Eliminar un remoto |

## 10. Submódulos y monorepos
| Comando | Descripción |
|---------|-------------|
| `git submodule add <url> <ruta>` | Agregar un submódulo |
| `git submodule update --init --recursive` | Inicializar/actualizar submódulos (común en pipelines de CI) |
| `git subtree add --prefix=<ruta> <url> <rama>` | Incorporar un repo externo como subdirectorio |
| `git subtree pull --prefix=<ruta> <url> <rama>` | Actualizar un subtree existente |
| `git sparse-checkout init --cone` | Habilitar checkout parcial (útil en monorepos grandes) |
| `git sparse-checkout set <carpeta1> <carpeta2>` | Definir qué carpetas descargar del monorepo |

## 11. Worktrees (múltiples ramas en paralelo)
| Comando | Descripción |
|---------|-------------|
| `git worktree add <ruta> <rama>` | Crear un directorio de trabajo adicional para otra rama (útil para hotfixes) |
| `git worktree list` | Listar worktrees activos |
| `git worktree remove <ruta>` | Eliminar un worktree |

## 12. Optimización para pipelines CI/CD
| Comando | Descripción |
|---------|-------------|
| `git clone --depth 1 <url>` | Clonado superficial (shallow clone), más rápido en runners de CI |
| `git clone --branch <rama> --single-branch <url>` | Clonar solo una rama específica |
| `git fetch --depth 1` | Actualizar historial superficial en un shallow clone |
| `git archive --format=tar HEAD \| gzip > release.tar.gz` | Generar artefacto/paquete de release sin metadatos `.git` |
| `git diff --name-only <base>...<rama>` | Listar archivos modificados entre ramas (útil para pipelines condicionales) |
| `git rev-parse --short HEAD` | Obtener hash corto del commit actual (para etiquetar imágenes Docker, ej. `myapp:$(git rev-parse --short HEAD)`) |

## 13. Seguridad y firma de commits
| Comando | Descripción |
|---------|-------------|
| `git commit -S -m "<mensaje>"` | Firmar un commit con GPG |
| `git config commit.gpgsign true` | Firmar todos los commits automáticamente |
| `git config --global tag.gpgSign true` | Firmar tags automáticamente |
| `git verify-commit <commit>` | Verificar la firma de un commit |
| `git secrets --scan` | Escanear el repo en busca de credenciales expuestas (AWS Git Secrets) |
| `git config core.hooksPath .githooks` | Usar un directorio de hooks versionado en el repo (útil para pre-commit checks) |

## 14. Hooks útiles en DevOps
| Hook | Uso típico |
|------|-----------|
| `pre-commit` | Ejecutar linters, formateadores, o escáneres de secretos antes de confirmar |
| `commit-msg` | Validar formato de mensajes de commit (ej. Conventional Commits) |
| `pre-push` | Ejecutar tests o validaciones antes de subir cambios |
| `post-merge` | Reinstalar dependencias automáticamente tras un `pull`/`merge` |

## 15. Recuperación y mantenimiento
| Comando | Descripción |
|---------|-------------|
| `git fsck` | Verificar integridad del repositorio |
| `git gc --aggressive` | Optimizar y limpiar el repositorio (reduce tamaño) |
| `git clean -fd` | Eliminar archivos y carpetas no rastreados |

!!! example "Practica en el laboratorio"
    - [Lab 04: Flujo Git con ramas
    - pull requests y code review](../../laboratorios/devops/git-flujo-pull-request.md)
    - [Lab 07: Pipeline de CI con GitHub Actions](../../laboratorios/devops/github-actions-ci.md)

