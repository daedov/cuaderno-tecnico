# Git 

## 1. Configuración inicial
| Comando | Descripción |
|---------|-------------|
| `git config --global user.name "<nombre>"` | Configurar nombre de usuario |
| `git config --global user.email "<email>"` | Configurar correo de usuario |
| `git config --list --show-origin` | Ver configuración activa y de qué archivo viene cada valor |
| `git config --global pull.rebase true` | Hacer que `git pull` use rebase en vez de merge |
| `git config --global rerere.enabled true` | Recordar cómo resolviste un conflicto y reaplicarlo si vuelve a aparecer |
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

## 3. Área de trabajo, staging y árbol del repositorio
Git maneja tres "árboles": el **working tree** (área de trabajo, tus archivos), el **index** (staging, lo que irá en el próximo commit) y **HEAD** (el último commit de la rama).

| Comando | Descripción |
|---------|-------------|
| `git add -p` | Elegir por bloques qué cambios pasan a staging |
| `git restore -p <archivo>` | Descartar por bloques cambios del área de trabajo |
| `git diff --staged` | Ver lo que está en staging (lo que entrará al commit) |
| `git diff --stat <commit1> <commit2>` | Resumen de archivos y líneas cambiadas entre dos commits |
| `git diff <rama1>...<rama2>` | Ver cambios de `rama2` desde que se separó de `rama1` (lo que mostraría un PR) |
| `git rm --cached <archivo>` | Dejar de seguir un archivo sin borrarlo del disco (por ejemplo, tras añadirlo a `.gitignore`) |
| `git mv <origen> <destino>` | Mover o renombrar un archivo manteniendo su historial |
| `git check-ignore -v <archivo>` | Ver qué regla de `.gitignore` ignora un archivo |
| `git ls-files` | Listar los archivos que Git sigue |
| `git show <commit>:<ruta>` | Ver un archivo tal como estaba en un commit, sin cambiar nada |
| `git ls-tree -r --name-only <commit>` | Listar los archivos que existían en un commit |
| `git cat-file -p <objeto>` | Ver el contenido de un objeto interno (commit, tree o blob) |
| `git clean -n` | Simular qué archivos no rastreados se borrarían |
| `git clean -fd` | Borrar archivos y carpetas no rastreados |
| `git clean -fdx` | Borrar también los ignorados (`node_modules`, `.terraform`, builds) |

## 4. Ramas y navegación
| Comando | Descripción |
|---------|-------------|
| `git branch` | Listar ramas locales |
| `git branch -r` | Listar ramas remotas |
| `git branch -vv` | Ver ramas con su upstream y si van adelante o atrás |
| `git branch <nombre>` | Crear rama |
| `git branch -m <nuevo-nombre>` | Renombrar la rama actual |
| `git switch -c <nombre>` | Crear y cambiar a una rama nueva (equivale a `git checkout -b`) |
| `git switch <rama>` | Cambiar de rama |
| `git switch -` | Volver a la rama anterior |
| `git switch -c <rama> <tag-o-commit>` | Crear una rama desde un tag o commit (por ejemplo, un hotfix sobre `v1.2.0`) |
| `git branch --merged` / `--no-merged` | Ver qué ramas ya están (o no) fusionadas en la actual |
| `git branch --contains <commit>` | Ver qué ramas incluyen un commit |
| `git merge-base <rama1> <rama2>` | Ver el commit donde se separaron dos ramas |
| `git branch -d <rama>` | Eliminar rama fusionada |
| `git branch -D <rama>` | Forzar eliminación de rama no fusionada |
| `git push origin --delete <rama>` | Eliminar rama remota |
| `git fetch --prune` | Sincronizar y limpiar referencias de ramas remotas eliminadas |
| `git merge <rama>` | Fusionar rama actual con otra |
| `git merge --no-ff <rama>` | Fusionar forzando un commit de merge (trazabilidad en Git Flow) |
| `git merge --abort` | Cancelar un merge con conflictos y volver al estado anterior |
| `git rebase <rama>` | Reaplicar commits sobre otra base |
| `git rebase --continue` / `--skip` / `--abort` | Seguir tras resolver un conflicto, saltar el commit o cancelar el rebase |
| `git rebase --onto <nueva_base> <base_antigua> <rama>` | Rebase avanzado moviendo commits a otra base |

## 5. Cambios temporales (stash)
| Comando | Descripción |
|---------|-------------|
| `git stash` | Guardar cambios temporalmente |
| `git stash push -m "<mensaje>"` | Guardar con un nombre para encontrarlo después |
| `git stash push -p` | Guardar solo algunos bloques de cambios |
| `git stash -u` | Incluir también los archivos no rastreados |
| `git stash pop` | Recuperar y eliminar el último stash |
| `git stash list` | Listar stashes guardados |
| `git stash show -p stash@{<n>}` | Ver el diff de un stash |
| `git stash apply` | Aplicar un stash sin eliminarlo |
| `git stash branch <rama>` | Crear una rama a partir de un stash (útil si al aplicarlo hay conflictos) |
| `git stash drop` | Eliminar un stash sin aplicarlo |

## 6. Historial y depuración
| Comando | Descripción |
|---------|-------------|
| `git log` | Ver historial |
| `git log --oneline --graph --all --decorate` | Historial visual completo con ramas y tags |
| `git log --first-parent main` | Ver solo los commits de merge y directos de `main` (historial "de releases") |
| `git log --oneline <rama1>..<rama2>` | Commits que están en `rama2` y no en `rama1` |
| `git log --author="<nombre>"` | Filtrar commits por autor |
| `git log --since="2 weeks ago"` | Filtrar commits por fecha |
| `git log -p <archivo>` | Ver historial de cambios de un archivo específico |
| `git log --follow <archivo>` | Seguir el historial de un archivo aunque se haya renombrado |
| `git log -S "<texto>"` | Buscar el commit que añadió o quitó un texto (*pickaxe*) |
| `git log -L <inicio>,<fin>:<archivo>` | Ver la historia de un rango de líneas |
| `git show <commit>` | Ver detalles y diff de un commit específico |
| `git blame <archivo>` | Ver quién modificó cada línea de un archivo |
| `git blame -w -C <archivo>` | Igual, ignorando cambios de espacios y código movido entre archivos |
| `git grep "<texto>"` | Buscar texto en los archivos del repositorio |
| `git shortlog -sn` | Contar commits por autor |
| `git bisect start` | Iniciar búsqueda binaria de un commit que introdujo un bug |
| `git bisect good/bad <commit>` | Marcar commit como bueno/malo durante el bisect |
| `git bisect run <script>` | Automatizar el bisect: el script devuelve 0 si el commit está bien |
| `git bisect reset` | Terminar el bisect y volver a la rama original |
| `git reflog` | Ver historial de referencias (recuperar commits "perdidos") |

## 7. Volver atrás y rollback
| Comando | Descripción |
|---------|-------------|
| `git restore <archivo>` | Descartar cambios locales de un archivo |
| `git restore --staged <archivo>` | Sacar un archivo del área de staging |
| `git restore --source <commit> <archivo>` | Traer un archivo tal como estaba en un commit u otra rama |
| `git restore --source <commit> --staged --worktree .` | Dejar todo el proyecto como en un commit sin mover la rama; luego haces un commit nuevo |
| `git switch --detach <commit>` | Ver el proyecto como estaba en un commit, sin cambiar ninguna rama (`git switch -` para volver) |
| `git revert <commit>` | Revertir un commit creando uno nuevo (seguro en ramas compartidas) |
| `git revert -m 1 <commit-merge>` | Revertir un merge, conservando el lado de la rama principal |
| `git revert --no-commit <commit>..HEAD` | Revertir todo lo posterior a un commit; luego `git commit` para dejarlo en un solo commit |
| `git revert --abort` | Cancelar un revert con conflictos |
| `git reset --soft HEAD~1` | Deshacer el último commit conservando cambios en staging |
| `git reset --mixed HEAD~1` | Deshacer el último commit conservando cambios sin stage |
| `git reset --keep <commit>` | Mover la rama a un commit conservando tus cambios sin commitear (se detiene si chocan) |
| `git reset --hard <commit>` | Revertir a un commit (descarta todos los cambios) |
| `git reset --hard ORIG_HEAD` | Deshacer el merge, rebase o reset que acabas de hacer |
| `git reset --hard @{u}` | Dejar la rama local igual que la remota |
| `git reset --hard HEAD@{<n>}` | Volver a un estado anterior que aparece en `git reflog` |
| `git branch <rama> <hash>` | Recuperar una rama borrada (el hash sale de `git reflog`) |
| `git push --force-with-lease` | Subir historial reescrito sin pisar commits que otra persona haya subido |

!!! tip "¿Qué uso para volver atrás?"
    | Situación | Comando |
    | --- | --- |
    | Solo quiero **ver** cómo estaba | `git switch --detach <commit>` o `git show <commit>:<archivo>` |
    | Recuperar **un archivo** | `git restore --source <commit> <archivo>` |
    | Deshacer algo ya **subido a una rama compartida** (`main`, `develop`) | `git revert`: no reescribe historia |
    | Deshacer commits que **solo tienes en local** | `git reset` (`--soft` para conservar los cambios) |
    | Me equivoqué con un merge, rebase o reset | `git reset --hard ORIG_HEAD` o buscar el estado en `git reflog` |
    | Rollback de una release | Desplegar el tag anterior desde el pipeline, o `git revert` del merge y dejar que el pipeline despliegue |

!!! warning "Antes de un `reset --hard` o un push forzado"
    `git reset --hard` borra los cambios sin commitear y no se pueden recuperar. Los commits sí: siguen en `git reflog` unas semanas. En ramas compartidas no reescribas historia: usa `git revert`.

## 8. Reescritura de historial
| Comando | Descripción |
|---------|-------------|
| `git rebase -i HEAD~<n>` | Rebase interactivo de los últimos n commits (squash, reorder, edit) |
| `git rebase -i --autosquash` | Aplicar automáticamente los commits `fixup`/`squash` |
| `git commit --fixup <commit>` | Crear commit de corrección para un commit anterior |
| `git cherry-pick <commit>` | Aplicar un commit específico de otra rama |
| `git cherry-pick -x <commit>` | Igual, anotando en el mensaje de qué commit viene (útil para backports) |
| `git cherry-pick <inicio>^..<fin>` | Aplicar un rango de commits |
| `git cherry-pick --abort` | Cancelar un cherry-pick con conflictos |
| `git range-diff <base> <rama-antes> <rama-después>` | Comparar dos versiones de una rama tras un rebase |
| `git filter-repo --path <ruta>` | Reescribir historial (extraer/eliminar rutas), reemplaza a `filter-branch` |

## 9. Tags y releases (versionado para CI/CD)
| Comando | Descripción |
|---------|-------------|
| `git tag` | Listar tags |
| `git tag -a v1.0.0 -m "<mensaje>"` | Crear tag anotado (recomendado para releases) |
| `git tag -a v1.0.0 <commit> -m "<mensaje>"` | Crear un tag sobre un commit anterior |
| `git tag --contains <commit>` | Ver en qué releases está un commit |
| `git push origin v1.0.0` | Subir un tag específico |
| `git push origin --tags` | Subir todos los tags al remoto |
| `git tag -d v1.0.0` | Eliminar tag local |
| `git push origin --delete v1.0.0` | Eliminar tag remoto |
| `git describe --tags` | Obtener el tag más reciente relativo al commit actual (útil para versionado automático en pipelines) |

## 10. Remotos
| Comando | Descripción |
|---------|-------------|
| `git remote -v` | Ver repositorios remotos |
| `git remote add <nombre> <url>` | Agregar un remoto |
| `git remote set-url origin <url>` | Cambiar la URL de un remoto (por ejemplo, de HTTPS a SSH) |
| `git remote remove <nombre>` | Eliminar un remoto |
| `git fetch --all --prune` | Traer cambios de todos los remotos y limpiar ramas borradas |
| `git pull --rebase` | Actualizar poniendo tus commits locales encima de los remotos |

## 11. Submódulos y monorepos
| Comando | Descripción |
|---------|-------------|
| `git submodule add <url> <ruta>` | Agregar un submódulo |
| `git submodule update --init --recursive` | Inicializar/actualizar submódulos (común en pipelines de CI) |
| `git subtree add --prefix=<ruta> <url> <rama>` | Incorporar un repo externo como subdirectorio |
| `git subtree pull --prefix=<ruta> <url> <rama>` | Actualizar un subtree existente |
| `git sparse-checkout init --cone` | Habilitar checkout parcial (útil en monorepos grandes) |
| `git sparse-checkout set <carpeta1> <carpeta2>` | Definir qué carpetas descargar del monorepo |

## 12. Worktrees (múltiples ramas en paralelo)
| Comando | Descripción |
|---------|-------------|
| `git worktree add <ruta> <rama>` | Crear un directorio de trabajo adicional para otra rama (útil para hotfixes) |
| `git worktree list` | Listar worktrees activos |
| `git worktree remove <ruta>` | Eliminar un worktree |

## 13. Optimización para pipelines CI/CD
| Comando | Descripción |
|---------|-------------|
| `git clone --depth 1 <url>` | Clonado superficial (shallow clone), más rápido en runners de CI |
| `git clone --filter=blob:none <url>` | Clonado parcial: trae todo el historial pero descarga los archivos solo cuando hacen falta |
| `git clone --branch <rama> --single-branch <url>` | Clonar solo una rama específica |
| `git fetch --depth 1` | Actualizar historial superficial en un shallow clone |
| `git archive --format=tar HEAD \| gzip > release.tar.gz` | Generar artefacto/paquete de release sin metadatos `.git` |
| `git diff --name-only <base>...<rama>` | Listar archivos modificados entre ramas (útil para pipelines condicionales) |
| `git rev-parse --short HEAD` | Obtener hash corto del commit actual (para etiquetar imágenes Docker, ej. `myapp:$(git rev-parse --short HEAD)`) |

## 14. Seguridad y firma de commits
| Comando | Descripción |
|---------|-------------|
| `git commit -S -m "<mensaje>"` | Firmar un commit con GPG |
| `git config --global gpg.format ssh` | Firmar con tu llave SSH en vez de GPG (junto con `user.signingkey <ruta-a-la-llave.pub>`) |
| `git config commit.gpgsign true` | Firmar todos los commits automáticamente |
| `git config --global tag.gpgSign true` | Firmar tags automáticamente |
| `git verify-commit <commit>` | Verificar la firma de un commit |
| `git log --show-signature` | Ver las firmas en el historial |
| `gitleaks git -v` | Escanear el historial en busca de credenciales expuestas (ver [Secret scanning](../../devsecops/escaneos/secret-scanning.md)) |
| `git config core.hooksPath .githooks` | Usar un directorio de hooks versionado en el repo (útil para pre-commit checks) |

## 15. Hooks útiles en DevOps
| Hook | Uso típico |
|------|-----------|
| `pre-commit` | Ejecutar linters, formateadores, o escáneres de secretos antes de confirmar |
| `commit-msg` | Validar formato de mensajes de commit (ej. Conventional Commits) |
| `pre-push` | Ejecutar tests o validaciones antes de subir cambios |
| `post-merge` | Reinstalar dependencias automáticamente tras un `pull`/`merge` |

## 16. Recuperación y mantenimiento
| Comando | Descripción |
|---------|-------------|
| `git fsck` | Verificar integridad del repositorio |
| `git fsck --lost-found` | Encontrar commits y archivos huérfanos (por ejemplo, un stash borrado) |
| `git maintenance start` | Programar el mantenimiento automático del repo (reemplaza al `git gc` manual) |
| `git maintenance run` | Ejecutar el mantenimiento ahora |
| `git count-objects -vH` | Ver cuánto ocupa el repositorio |

!!! example "Practica en el laboratorio"
    - [Lab 04: Flujo Git con ramas, pull requests y code review](../../laboratorios/devops/git-flujo-pull-request.md)
    - [Lab 07: Pipeline de CI con GitHub Actions](../../laboratorios/devops/github-actions-ci.md)
