// Botón de copiar junto a cada comando de las tablas en Recursos > Comandos.
// Usa el portapapeles de Material (data-clipboard-text), que muestra el aviso "Copiado".
// document$ se dispara en cada carga de página, también con navigation.instant.
document$.subscribe(function () {
  if (!location.pathname.includes("/recursos/comandos/")) return

  document.querySelectorAll(".md-typeset table td:first-child > code").forEach(function (code) {
    if (code.nextElementSibling && code.nextElementSibling.classList.contains("cmd-copy")) return

    var boton = document.createElement("button")
    boton.className = "md-clipboard md-icon cmd-copy"
    boton.title = "Copiar comando"
    boton.setAttribute("data-clipboard-text", code.textContent)
    code.after(boton)
  })
})
