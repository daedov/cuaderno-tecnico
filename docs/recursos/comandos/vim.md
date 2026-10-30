# Vim

Vim tiene **modos**: se abre en modo *normal* (para moverse y operar sobre el texto), `i` pasa a modo *inserción* (para escribir) y `Esc` vuelve al modo normal. Los comandos que empiezan con `:` se escriben desde el modo normal y se confirman con `Enter`.

## 1. Abrir, guardar y salir
| Comando | Descripción |
|---------|-------------|
| `vim <archivo>` | Abrir un archivo (lo crea al guardar si no existe) |
| `vim +<n> <archivo>` | Abrir un archivo en la línea n |
| `vim -R <archivo>` | Abrir en solo lectura |
| `vimdiff <archivo1> <archivo2>` | Comparar dos archivos lado a lado |
| `:w` | Guardar |
| `:w <archivo>` | Guardar con otro nombre |
| `:q` | Salir (falla si hay cambios sin guardar) |
| `:wq` | Guardar y salir |
| `:x` | Guardar solo si hubo cambios y salir |
| `:q!` | Salir descartando los cambios |
| `:w !sudo tee %` | Guardar un archivo abierto sin permisos de root |
| `:e <archivo>` | Abrir otro archivo en la misma ventana |
| `:e!` | Recargar el archivo descartando los cambios |

## 2. Modos
| Comando | Descripción |
|---------|-------------|
| `Esc` | Volver al modo normal |
| `i` | Insertar antes del cursor |
| `a` | Insertar después del cursor |
| `I` | Insertar al inicio de la línea |
| `A` | Insertar al final de la línea |
| `o` | Abrir una línea nueva debajo e insertar |
| `O` | Abrir una línea nueva encima e insertar |
| `v` | Modo visual (selección por caracteres) |
| `V` | Modo visual por líneas |
| `Ctrl+v` | Modo visual por bloques (columnas) |
| `R` | Modo reemplazo (sobrescribe al escribir) |

## 3. Movimiento
| Comando | Descripción |
|---------|-------------|
| `h` `j` `k` `l` | Izquierda, abajo, arriba, derecha |
| `w` / `b` | Siguiente palabra / palabra anterior |
| `e` | Final de la palabra |
| `0` / `^` / `$` | Inicio de línea / primer carácter no blanco / final de línea |
| `gg` / `G` | Inicio / final del archivo |
| `<n>G` o `:<n>` | Ir a la línea n |
| `Ctrl+d` / `Ctrl+u` | Bajar / subir media pantalla |
| `Ctrl+f` / `Ctrl+b` | Bajar / subir una pantalla completa |
| `%` | Saltar al paréntesis, corchete o llave pareja |
| `f<c>` / `t<c>` | Ir a / justo antes de la siguiente aparición de `<c>` en la línea |
| `Ctrl+o` / `Ctrl+i` | Volver a la posición anterior / siguiente |

## 4. Edición
| Comando | Descripción |
|---------|-------------|
| `x` | Borrar el carácter bajo el cursor |
| `dd` | Cortar la línea actual |
| `<n>dd` | Cortar n líneas |
| `dw` | Cortar hasta el inicio de la siguiente palabra |
| `D` | Cortar hasta el final de la línea |
| `cw` | Cambiar una palabra (borra y entra en inserción) |
| `cc` | Cambiar la línea completa |
| `ciw` | Cambiar la palabra bajo el cursor |
| `ci"` | Cambiar el texto dentro de las comillas |
| `r<c>` | Reemplazar el carácter bajo el cursor por `<c>` |
| `J` | Unir la línea actual con la siguiente |
| `>>` / `<<` | Indentar / desindentar la línea |
| `~` | Cambiar mayúsculas/minúsculas del carácter |
| `u` | Deshacer |
| `Ctrl+r` | Rehacer |
| `.` | Repetir el último cambio |

## 5. Copiar y pegar
| Comando | Descripción |
|---------|-------------|
| `yy` | Copiar la línea actual |
| `<n>yy` | Copiar n líneas |
| `yw` | Copiar una palabra |
| `y` | Copiar la selección (en modo visual) |
| `d` | Cortar la selección (en modo visual) |
| `p` / `P` | Pegar después / antes del cursor |
| `"+y` / `"+p` | Copiar al / pegar desde el portapapeles del sistema |
| `:set paste` | Pegar texto externo sin que se autoindente (`:set nopaste` para volver) |

## 6. Buscar y reemplazar
| Comando | Descripción |
|---------|-------------|
| `/<patrón>` | Buscar hacia adelante |
| `?<patrón>` | Buscar hacia atrás |
| `n` / `N` | Siguiente / anterior coincidencia |
| `*` | Buscar la palabra bajo el cursor |
| `:noh` | Quitar el resaltado de la búsqueda |
| `:s/<viejo>/<nuevo>/` | Reemplazar la primera coincidencia de la línea |
| `:s/<viejo>/<nuevo>/g` | Reemplazar todas las coincidencias de la línea |
| `:%s/<viejo>/<nuevo>/g` | Reemplazar en todo el archivo |
| `:%s/<viejo>/<nuevo>/gc` | Reemplazar en todo el archivo pidiendo confirmación |
| `:<n>,<m>s/<viejo>/<nuevo>/g` | Reemplazar entre las líneas n y m |
| `:g/<patrón>/d` | Borrar todas las líneas que coinciden |
| `:v/<patrón>/d` | Borrar todas las líneas que **no** coinciden |

## 7. Ventanas, pestañas y buffers
| Comando | Descripción |
|---------|-------------|
| `:sp <archivo>` | Dividir la ventana en horizontal |
| `:vsp <archivo>` | Dividir la ventana en vertical |
| `Ctrl+w w` | Cambiar a la siguiente ventana |
| `Ctrl+w h/j/k/l` | Moverse a la ventana de la izquierda/abajo/arriba/derecha |
| `Ctrl+w q` | Cerrar la ventana actual |
| `:tabnew <archivo>` | Abrir un archivo en una pestaña nueva |
| `gt` / `gT` | Pestaña siguiente / anterior |
| `:ls` | Listar los buffers abiertos |
| `:b <n>` | Cambiar al buffer n |
| `:bd` | Cerrar el buffer actual |

## 8. Configuración útil
Estos ajustes se pueden escribir en la sesión o dejarse fijos en `~/.vimrc` (sin los `:`).

| Comando | Descripción |
|---------|-------------|
| `:set number` | Mostrar números de línea |
| `:set relativenumber` | Números de línea relativos al cursor |
| `:syntax on` | Activar el resaltado de sintaxis |
| `:set expandtab tabstop=2 shiftwidth=2` | Usar 2 espacios en vez de tabuladores (YAML) |
| `:set list` | Mostrar caracteres invisibles (tabs, fin de línea) |
| `:set ignorecase smartcase` | Buscar sin distinguir mayúsculas, salvo si el patrón las tiene |
| `:set hlsearch` | Resaltar las coincidencias de la búsqueda |
| `:set ff=unix` | Convertir finales de línea de Windows (CRLF) a Unix (LF) |

## 9. Comandos externos
| Comando | Descripción |
|---------|-------------|
| `:!<comando>` | Ejecutar un comando del shell |
| `:r !<comando>` | Insertar la salida de un comando en el archivo |
| `:%!<comando>` | Filtrar todo el archivo por un comando (p. ej. `:%!jq .`) |
| `:r <archivo>` | Insertar el contenido de otro archivo |
| `Ctrl+z` | Suspender Vim y volver al shell (`fg` para regresar) |
| `vimtutor` | Tutorial interactivo de unos 30 minutos (desde el shell) |
