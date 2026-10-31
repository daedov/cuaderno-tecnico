---
tags:
  - terraform
  - certificacion
  - terraform-associate
  - iac
  - observabilidad
---

# Objetivos 6 y 7: Terraform state management y Maintain infrastructure with Terraform

> Dónde vive el state (backend local y remotos), cómo se bloquea, cómo se gestiona el drift y la refactorización (`-refresh-only`, `moved`, `removed`, `-replace`), cómo se importa infraestructura existente, cómo se inspecciona el state y cuándo activar `TF_LOG`.

!!! info "Qué evalúan estos objetivos"
    Sub-objetivos oficiales de la versión 004:

    - **6a** Describe the local backend (describir el backend local).
    - **6b** Describe state locking (describir el bloqueo del state).
    - **6c** Configure remote state using the backend block (configurar state remoto con el bloque backend).
    - **6d** Manage resource drift and Terraform state (gestionar el drift y el state).
    - **7a** Import existing infrastructure into your Terraform workspace (importar infraestructura existente).
    - **7b** Use the CLI to inspect state (inspeccionar el state con la CLI).
    - **7c** Describe when and how to use verbose logging (cuándo y cómo usar logging detallado).

    Vuelve al [resumen del examen](resumen-examen.md) para ver el formato y el plan de estudio. Qué es el state y para qué sirve está en [objetivos 1 y 2](objetivo-1-2-iac-y-fundamentos.md#2d-como-usa-y-gestiona-terraform-el-state).

## 6a. El backend local

El **backend** define **dónde se guarda el state**. Sin bloque `backend`, Terraform usa **`local`**: `terraform.tfstate` en el directorio de trabajo, más una copia `terraform.tfstate.backup`. Con `backend "local" { path = "..." }` cambias la ruta. Al añadir o cambiar un `backend`, `plan` falla con `Backend initialization required` hasta ejecutar `terraform init` (con `-migrate-state` si hay que copiar el state).

| Ventajas del backend local | Limitaciones |
| --- | --- |
| Cero configuración; ideal para aprender y pruebas | Solo vive en **una** máquina: no sirve para equipos |
| Bloqueo con el sistema de archivos | Se pierde si se borra la carpeta; sin versionado ni cifrado propios |
| | Riesgo de subirlo a Git por error (contiene secretos) |

Con **CLI workspaces**, el backend local guarda cada state en `terraform.tfstate.d/<workspace>/` (ver [Terraform workspaces](../../../devops/iac/terraform-workspaces.md#donde-se-guarda-cada-state)).

## 6b. State locking

**State locking** impide que dos operaciones escriban el state a la vez y lo corrompan. Terraform bloquea **automáticamente** en toda operación que puede escribir (plan, apply, destroy, import, state…), si el backend lo soporta. Si otra operación tiene el lock, falla con `Error acquiring the state lock`.

| Opción o comando | Para qué |
| --- | --- |
| `-lock-timeout=5m` | Espera hasta 5 minutos a que se libere el lock en vez de fallar |
| `-lock=false` | Desactiva el bloqueo (peligroso; solo para lecturas controladas) |
| `terraform force-unlock LOCK_ID` | Libera un lock **huérfano** (por ejemplo, si un pipeline murió a mitad). Solo si estás segura de que nadie más está ejecutando |

| Backend | Locking |
| --- | --- |
| `local` | Sí (bloqueo de archivo del sistema operativo) |
| `s3` | Sí, con `use_lockfile = true` (archivo `.tflock` en el bucket, Terraform 1.10+). La tabla DynamoDB está **deprecated** |
| `azurerm` | Sí (blob lease de Azure Storage) |
| `gcs`, `consul`, `pg`, `kubernetes` | Sí |
| `remote` / HCP Terraform (`cloud`) | Sí, gestionado por la plataforma |
| `http` | Opcional (si el servidor implementa los endpoints de lock) |

## 6c. Remote state con el bloque backend

Un **remote backend** guarda el state en un servicio compartido con locking, cifrado y versionado. El ejemplo con S3 y las buenas prácticas del bucket están en [Remote state](../../../devops/iac/terraform-basico.md#remote-state-estado-remoto). Reglas que el examen pregunta:

- Solo **un** bloque `backend` por configuración, dentro de `terraform { }`.
- **No admite variables, locals ni referencias** (se evalúa antes que nada). Lo que no quieres en el código va por **partial configuration**: `terraform init -backend-config="bucket=..." -backend-config=prod.s3.tfbackend`.
- Las **credenciales** del backend no van en el bloque: variables de entorno, perfiles o identidad del runner.
- Cambiar de backend → `terraform init -migrate-state` (copia el state) o `-reconfigure` (empieza de cero sin migrar).
- `backend` y `cloud` (HCP Terraform) son **mutuamente excluyentes** ([objetivo 8](objetivo-8-hcp-terraform.md#8d-integracion-de-la-cli-con-hcp-terraform)).

### Leer outputs de otro state: terraform_remote_state

El data source `terraform_remote_state` lee los **outputs del módulo raíz** de otra configuración:

```hcl
data "terraform_remote_state" "lab" {
  backend = "local"
  config  = { path = "../lab/terraform.tfstate" }
}

# uso: data.terraform_remote_state.lab.outputs.nombre
```

!!! warning "terraform_remote_state necesita acceso a todo el state"
    Aunque solo expone outputs, quien lo usa necesita **permiso de lectura sobre el state completo**, que puede contener secretos. HashiCorp recomienda, cuando sea posible, publicar los datos en un sistema pensado para eso (un parámetro de SSM, DNS, una etiqueta) y leerlo con su data source; en HCP Terraform existe el data source `tfe_outputs`.

## 6d. Drift y refactorización del state

**Drift** (desviación) es la diferencia entre el state y la infraestructura real, normalmente por cambios manuales. Terraform hace refresh antes de cada plan, así que lo detecta: `plan -refresh-only` muestra `Objects have changed outside of Terraform` y el `plan` normal propone volver al código.

| Decisión ante un drift | Cómo |
| --- | --- |
| Volver a lo que dice el código | `terraform apply` normal: revierte el cambio manual |
| Aceptar la realidad en el state (sin tocar infraestructura) | `terraform apply -refresh-only`, y después actualizar el código para que coincida |
| Detectarlo en un pipeline | `terraform plan -detailed-exitcode` (exit 2 = hay cambios) |
| Detectarlo de forma continua | **Drift detection** de HCP Terraform ([objetivo 8](objetivo-8-hcp-terraform.md#8b-colaboracion-y-gobierno)) |

!!! note "`terraform refresh` está deprecated"
    Sigue existiendo pero actualiza el state sin mostrarte qué cambia. Usa `terraform apply -refresh-only`, que enseña los cambios y pide confirmación.

### Refactorizar sin destruir: moved, removed y -replace

| Necesidad | Forma recomendada (declarativa, pasa por plan) | Forma antigua (CLI, modifica el state al instante) |
| --- | --- | --- |
| Renombrar un recurso o moverlo a un módulo | Bloque **`moved`** | `terraform state mv` |
| Dejar de gestionar un recurso **sin destruirlo** | Bloque **`removed`** con `destroy = false` (1.7+) | `terraform state rm` |
| Recrear un recurso sin cambiar código | `terraform apply -replace=DIRECCIÓN` | `terraform taint` (deprecated) |

Renombrar **sin** `moved` = destruir uno y crear otro. Con los bloques, el plan queda en `0 to add, 0 to change, 0 to destroy`:

```hcl
moved {
  from = random_pet.proyecto
  to   = random_pet.app # plan: "random_pet.proyecto has moved to random_pet.app"
}

removed {
  from = random_string.legado
  lifecycle {
    destroy = false # plan: "will no longer be managed by Terraform, but will not be destroyed"
  }
}
```

!!! tip "En el examen"
    - Los bloques `moved` y `removed` son **preferibles** a `state mv`/`state rm` porque quedan en el código, se revisan en un PR y pasan por `plan` (también funcionan en HCP Terraform, donde no tienes acceso directo al state).
    - `state rm` y `removed` **no destruyen** el objeto real: sigue existiendo (y cobrando).
    - `taint` sigue funcionando pero está deprecated: la respuesta moderna es `-replace`.

## 7a. Importar infraestructura existente

**Import** trae al state un objeto que ya existe (creado a mano o por otra herramienta) para que Terraform lo gestione. Ejemplo del bloque en [Import](../../../devops/iac/terraform-basico.md#import-importar-recursos-existentes).

- **Bloque `import`** (1.5+, recomendado): `to` + `id` (el ID que el provider usa para ese tipo). Con `terraform plan -generate-config-out=generado.tf` Terraform **escribe el HCL** como punto de partida (marcado `# __generated__ by Terraform`). Desde 1.7 admite `for_each`. Se puede **borrar** tras el apply.
- **Comando `terraform import DIRECCIÓN ID`**: escribe el state al instante; el bloque `resource` tiene que existir antes.

Lección de la prueba: el `resource` se escribió con `special = false` pero el objeto real tenía `special = true`, y el plan propuso **reemplazar** el recurso importado. **Siempre revisa el plan después de importar** y ajusta el código hasta ver `No changes`.

| | Bloque `import` | `terraform import` |
| --- | --- | --- |
| Pasa por `plan` y revisión | Sí | No: escribe el state al instante |
| Genera el código | Sí, con `-generate-config-out` | No: tienes que escribir el `resource` antes |
| Varios objetos | Sí, con `for_each` | Uno por comando |
| Funciona en HCP Terraform (VCS) | Sí | Requiere ejecución local/CLI |

## 7b. Inspeccionar el state con la CLI

| Comando | Qué muestra |
| --- | --- |
| `terraform state list` | Direcciones de todos los recursos del state (admite filtro) |
| `terraform state show DIRECCIÓN` | Atributos de un recurso |
| `terraform show` | Todo el state legible (o un plan guardado: `terraform show tfplan`); `-json` para máquinas |
| `terraform output [NOMBRE]` | Outputs (`-json`, `-raw`) |
| `terraform state pull` | El state crudo en JSON (también de backends remotos) |
| `terraform state push` | Sube un state local al backend (peligroso; casi nunca necesario) |
| `terraform console` | Evalúa expresiones contra el state actual |

Las direcciones con índices o claves (`local_file.config["api"]`) van entre comillas simples en Bash; en PowerShell suele hacer falta escapar las comillas dobles internas.

## 7c. Logging detallado

Cuando un error no se entiende (provider, red, autenticación), activa los logs con variables de entorno:

| Variable | Valores / efecto |
| --- | --- |
| `TF_LOG` | Activa los logs (en stderr). Niveles de más a menos detalle: `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`. `JSON` da nivel TRACE en formato JSON |
| `TF_LOG_CORE` | Nivel solo para Terraform core |
| `TF_LOG_PROVIDER` | Nivel solo para los providers |
| `TF_LOG_PATH` | Archivo al que se **añade** el log (requiere `TF_LOG` activo) |

Ejemplo: `TF_LOG=DEBUG TF_LOG_PATH=tf-debug.log terraform plan` en Bash; en PowerShell, `$env:TF_LOG = "DEBUG"; $env:TF_LOG_PATH = "tf-debug.log"; terraform plan`.

!!! warning "Los logs pueden contener secretos"
    En `TRACE` o `DEBUG` aparecen peticiones a las APIs, con posibles tokens. No los pegues en un issue público sin revisarlos. Si Terraform se cae (*panic*), escribe un `crash.log`, que también puede contener datos sensibles.

!!! tip "En el examen"
    - El nivel **más detallado** es `TRACE`; sin `TF_LOG_PATH`, los logs salen por **stderr**.
    - `TF_LOG_PATH` **sin** `TF_LOG` no genera logs.
    - Para separar problemas del provider de los de core, usa `TF_LOG_PROVIDER` y `TF_LOG_CORE`.

## Casos de uso

1. **Dos personas aplican a la vez y el state se corrompe** → remote backend con locking.
2. **Un pipeline murió a mitad y todo falla por el lock** → confirmar que no hay otra ejecución y `terraform force-unlock <LOCK_ID>`.
3. **El nombre del bucket del state no debe estar en el repo** → partial configuration con `-backend-config`.
4. **Aplicaciones necesita el ID de la VPC que publica red** → output + `terraform_remote_state` (o, mejor, un parámetro compartido).
5. **Alguien cambió una regla de firewall en la consola** → `plan -refresh-only`; revertir con `apply` o aceptar con `apply -refresh-only` y actualizar el código.
6. **Mover recursos a un módulo** → bloques `moved` en el mismo PR.
7. **Un bucket creado a mano debe pasar a Terraform** → bloque `import` + `-generate-config-out` y aplicar hasta `No changes`.
8. **Un recurso debe seguir existiendo pero dejar de gestionarse** → `removed` con `destroy = false`.
9. **Error de autenticación poco claro del provider** → `TF_LOG_PROVIDER=DEBUG` y `TF_LOG_PATH`.

## Preguntas de práctica

**1.** ¿Qué backend usa Terraform si la configuración no tiene bloque `backend` ni `cloud`?

- A. `s3`
- B. `remote`
- C. `local`
- D. Ninguno: Terraform no guarda state.

??? success "Respuesta"
    **C.** El backend por defecto es `local` (`terraform.tfstate` en el directorio de trabajo).

**2.** ¿Qué afirmaciones sobre el bloque `backend` son correctas? (Elige DOS.)

- A. Puede usar `var.region` para elegir la región.
- B. Admite partial configuration con `terraform init -backend-config`.
- C. Al cambiarlo hay que ejecutar `terraform init` de nuevo.
- D. Puede convivir con un bloque `cloud` en la misma configuración.

??? success "Respuesta"
    **B y C.** A es falsa: el backend no admite variables. D es falsa: `backend` y `cloud` son excluyentes.

**3.** Un compañero cambió un recurso a mano y quieres actualizar el state con la realidad **sin modificar** infraestructura. ¿Qué ejecutas?

- A. `terraform apply -refresh-only`
- B. `terraform apply -replace=...`
- C. `terraform state rm`
- D. `terraform destroy`

??? success "Respuesta"
    **A.** B recrea el recurso; C lo saca del state; D destruye todo.

**4.** Renombras `aws_instance.web` a `aws_instance.frontend` en el código. ¿Qué evita que Terraform destruya y recree la instancia, quedando registrado en el código?

- A. `depends_on`
- B. Un bloque `moved`
- C. `terraform taint`
- D. `lifecycle { ignore_changes = all }`

??? success "Respuesta"
    **B.** `terraform state mv` también funcionaría, pero no queda en el código ni pasa por plan. C fuerza un reemplazo (lo contrario). A y D no tienen relación.

**5.** Verdadero o falso: `terraform state rm aws_s3_bucket.logs` elimina el bucket de AWS.

??? success "Respuesta"
    **Falso.** Solo lo quita del state; el bucket sigue existiendo y deja de estar gestionado por Terraform.

**6.** ¿Qué ventaja tiene el bloque `import` frente al comando `terraform import`? (Elige DOS.)

- A. Puede generar el código HCL del recurso con `-generate-config-out`.
- B. No necesita conocer el ID del recurso.
- C. Pasa por `plan`, así que se revisa antes de modificar el state.
- D. Importa automáticamente todos los recursos de una cuenta.

??? success "Respuesta"
    **A y C.** B es falsa: siempre necesitas el ID. D es falsa: hay que declarar cada objeto (o usar `for_each`).

**7.** Quieres los logs más detallados de Terraform guardados en un archivo. ¿Qué configuras?

- A. `TF_LOG=ERROR` y `TF_LOG_PATH=terraform.log`
- B. `TF_LOG=TRACE` y `TF_LOG_PATH=terraform.log`
- C. Solo `TF_LOG_PATH=terraform.log`
- D. `terraform plan -verbose`

??? success "Respuesta"
    **B.** `TRACE` es el nivel más detallado. C no genera nada sin `TF_LOG`. D no existe.

**8.** ¿Qué comando muestra todos los atributos de un único recurso del state?

- A. `terraform state list`
- B. `terraform state show <dirección>`
- C. `terraform output`
- D. `terraform validate`

??? success "Respuesta"
    **B.** A solo lista direcciones; C muestra outputs; D valida la configuración.

## Para profundizar

- [Infrastructure as Code con Terraform](../../../devops/iac/terraform-basico.md#remote-state-estado-remoto): backend S3, buenas prácticas del bucket, `.gitignore` e import.
- [Terraform workspaces](../../../devops/iac/terraform-workspaces.md): un state por workspace en el mismo backend.
- [Seguridad de IaC](../../../devsecops/infraestructura-y-contenedores/seguridad-iac.md#drift-detection): drift detection en pipelines y servicios de cada nube.
- [Secretos e identidades](../../../devsecops/identidades-y-pipeline/secretos-identidades.md): proteger el state y las credenciales del backend.
- [Troubleshooting](../../../devops/operacion/troubleshooting.md): método para diagnosticar fallos.
- Siguiente: [Objetivo 8: HCP Terraform](objetivo-8-hcp-terraform.md).

!!! example "Practica en el laboratorio"
    - [Lab 08: Terraform sin nube: providers locales y workspaces](../../../laboratorios/devops/terraform-local-workspaces.md)
    - [Lab 09: Terraform en AWS con remote state en S3](../../../laboratorios/devops/terraform-aws-backend-remoto.md)

## Referencias

- [Backend block configuration](https://developer.hashicorp.com/terraform/language/backend)
- [State locking](https://developer.hashicorp.com/terraform/language/state/locking)
- [The terraform_remote_state data source](https://developer.hashicorp.com/terraform/language/state/remote-state-data)
- [Refactoring (moved)](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) y [Removed block reference](https://developer.hashicorp.com/terraform/language/block/removed)
- [Import](https://developer.hashicorp.com/terraform/language/import) y [Command: state](https://developer.hashicorp.com/terraform/cli/commands/state)
- [Debugging Terraform](https://developer.hashicorp.com/terraform/internals/debugging)
