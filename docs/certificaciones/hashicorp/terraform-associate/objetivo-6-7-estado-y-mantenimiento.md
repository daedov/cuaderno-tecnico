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

Salidas reales con **Terraform 1.12.2** y los providers `random`, `local` y `archive`.

## 6a. El backend local

El **backend** define **dónde se guarda el state** (y, en algunos casos, dónde se ejecutan las operaciones). Si no declaras ninguno, Terraform usa el backend **`local`**: el archivo `terraform.tfstate` en el directorio de trabajo, con una copia `terraform.tfstate.backup` del estado anterior.

```hcl title="backend.tf (probado)"
terraform {
  backend "local" {
    path = "estado/terraform.tfstate" # opcional: cambia la ruta
  }
}
```

Al añadir o cambiar un bloque `backend`, el siguiente comando falla hasta que reinicializas (salida real):

```console
$ terraform plan
Error: Backend initialization required, please run "terraform init"
Reason: Initial configuration of the requested backend "local"
$ terraform init -migrate-state
Initializing the backend...
Successfully configured the backend "local"! Terraform will automatically
use this backend unless the backend configuration changes.
```

| Ventajas del backend local | Limitaciones |
| --- | --- |
| Cero configuración; ideal para aprender y pruebas | Solo vive en **una** máquina: no sirve para equipos |
| Bloqueo con el sistema de archivos | Se pierde si se borra la carpeta; sin versionado ni cifrado propios |
| | Riesgo de subirlo a Git por error (contiene secretos) |

Con **CLI workspaces**, el backend local guarda cada state en `terraform.tfstate.d/<workspace>/` (detalle en [Terraform workspaces](../../../devops/iac/terraform-workspaces.md#donde-se-guarda-cada-state)).

## 6b. State locking

**State locking** (bloqueo del state) impide que dos operaciones escriban el state a la vez y lo corrompan. Terraform bloquea **automáticamente** en toda operación que puede escribir (plan, apply, destroy, import, state…), siempre que el backend lo soporte.

Prueba real: con una sesión de `terraform console` abierta (mantiene el state bloqueado), un `plan` en otra terminal falla:

```console
$ terraform plan
Error: Error acquiring the state lock
...
Terraform acquires a state lock to protect the state from being written
by multiple users at the same time. Please resolve the issue above and try
again. For most commands, you can disable locking with the "-lock=false"
flag, but this is not recommended.
```

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
| `gcs` | Sí |
| `remote` / HCP Terraform (`cloud`) | Sí, gestionado por la plataforma |
| `consul`, `pg`, `kubernetes` | Sí |
| `http` | Opcional (si el servidor implementa los endpoints de lock) |

## 6c. Remote state con el bloque backend

Un **remote backend** guarda el state en un servicio compartido: todo el equipo y el pipeline usan el mismo, con locking, cifrado y versionado.

```hcl title="backend.tf (ilustrativo, AWS)"
terraform {
  backend "s3" {
    bucket       = "mi-empresa-terraform-state"
    key          = "red/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Reglas del bloque `backend` que el examen pregunta:

- Solo **un** bloque `backend` por configuración, dentro de `terraform { }`.
- **No admite variables, locals ni referencias** (se evalúa antes que nada). Los valores que no quieres en el código se pasan con **partial configuration**:

    ```console
    $ terraform init -backend-config="bucket=mi-empresa-terraform-state" -backend-config=prod.s3.tfbackend
    ```

- Las **credenciales** del backend no van en el bloque: variables de entorno, perfiles o identidad del runner.
- Cambiar de backend → `terraform init -migrate-state` (copia el state) o `-reconfigure` (empieza de cero sin migrar).
- `backend` y `cloud` (HCP Terraform) son **mutuamente excluyentes** ([objetivo 8](objetivo-8-hcp-terraform.md#8d-integracion-de-la-cli-con-hcp-terraform)).

Ejemplos de backend por plataforma: `s3` (AWS), `azurerm` (Azure Storage), `gcs` (Google Cloud Storage), `consul`, `pg` (PostgreSQL), `kubernetes`, `http`. El detalle del backend S3 y las buenas prácticas del bucket están en [Infrastructure as Code con Terraform](../../../devops/iac/terraform-basico.md#remote-state-estado-remoto).

### Leer outputs de otro state: terraform_remote_state

El data source `terraform_remote_state` lee los **outputs del módulo raíz** de otra configuración (probado leyendo el state local del laboratorio):

```hcl title="main.tf (probado)"
data "terraform_remote_state" "lab" {
  backend = "local"

  config = {
    path = "../lab/terraform.tfstate"
  }
}

output "nombre_desde_lab" {
  value = data.terraform_remote_state.lab.outputs.nombre
}
```

```console
$ terraform apply -auto-approve
Outputs:

nombre_desde_lab = "lab-dev-massive-koala"
tags_desde_lab = "plataforma"
```

!!! warning "terraform_remote_state necesita acceso a todo el state"
    Aunque solo expone outputs, quien lo usa necesita **permiso de lectura sobre el state completo**, que puede contener secretos. HashiCorp recomienda, cuando sea posible, publicar los datos en un sistema pensado para eso (un parámetro de SSM, DNS, una etiqueta) y leerlo con su data source; en HCP Terraform existe el data source `tfe_outputs`.

## 6d. Drift y refactorización del state

**Drift** (desviación) es la diferencia entre el state y la infraestructura real, normalmente por cambios manuales. Terraform hace refresh antes de cada plan, así que lo detecta.

### Detectar e incorporar drift

Prueba real: se borró a mano un archivo gestionado por Terraform.

```console
$ terraform plan -refresh-only
Note: Objects have changed outside of Terraform
  # local_file.config["api"] has been deleted
  - resource "local_file" "config" {
...
You can apply this plan to save these new output values to the Terraform
state, without changing any real infrastructure.
$ terraform plan
  # local_file.config["api"] will be created
Plan: 1 to add, 0 to change, 0 to destroy.
```

| Decisión ante un drift | Cómo |
| --- | --- |
| Volver a lo que dice el código | `terraform apply` normal: revierte el cambio manual |
| Aceptar la realidad en el state (sin tocar infraestructura) | `terraform apply -refresh-only`, y después actualizar el código para que coincida |
| Detectarlo en un pipeline | `terraform plan -detailed-exitcode` (exit 2 = hay cambios) |
| Detectarlo de forma continua | **Drift detection** de HCP Terraform ([objetivo 8](objetivo-8-hcp-terraform.md#8b-colaboracion-y-gobierno)) |

!!! note "`terraform refresh` está deprecated"
    El comando `terraform refresh` sigue existiendo pero está **deprecated**: actualiza el state sin mostrarte qué cambia. Usa `terraform apply -refresh-only`, que enseña los cambios y pide confirmación.

### Refactorizar sin destruir: moved, removed y -replace

Pruebas reales en el laboratorio:

| Necesidad | Forma recomendada (declarativa, pasa por plan) | Forma antigua (CLI, modifica el state al instante) |
| --- | --- | --- |
| Renombrar un recurso o moverlo a un módulo | Bloque **`moved`** | `terraform state mv` |
| Dejar de gestionar un recurso **sin destruirlo** | Bloque **`removed`** con `destroy = false` (1.7+) | `terraform state rm` |
| Recrear un recurso sin cambiar código | `terraform apply -replace=DIRECCIÓN` | `terraform taint` (deprecated) |

**Renombrar sin `moved`**: Terraform lo interpreta como destruir uno y crear otro.

```console
  # random_pet.nombre will be destroyed
  # (because random_pet.nombre is not in configuration)
  # random_pet.proyecto will be created
```

**Con `moved`**:

```hcl title="refactor.tf (probado)"
moved {
  from = random_pet.proyecto
  to   = random_pet.app
}
```

```console
$ terraform plan
  # random_pet.proyecto has moved to random_pet.app
Plan: 0 to add, 0 to change, 0 to destroy.
```

**Con `removed`**:

```hcl title="legado.tf (probado)"
removed {
  from = random_string.legado

  lifecycle {
    destroy = false
  }
}
```

```console
$ terraform plan
 # random_string.legado will no longer be managed by Terraform, but will not be destroyed
 # (destroy = false is set in the configuration)
Plan: 0 to add, 0 to change, 0 to destroy.
Warning: Some objects will no longer be managed by Terraform
```

**Equivalentes por CLI**:

```console
$ terraform state mv random_string.legado random_string.heredado
Move "random_string.legado" to "random_string.heredado"
Successfully moved 1 object(s).
$ terraform state rm random_string.heredado
Removed random_string.heredado
Successfully removed 1 resource instance(s).
$ terraform taint 'random_string.sufijo[1]'
Resource instance random_string.sufijo[1] has been marked as tainted.
```

!!! tip "En el examen"
    - Los bloques `moved` y `removed` son **preferibles** a `state mv`/`state rm` porque quedan en el código, se revisan en un PR y pasan por `plan` (también funcionan en HCP Terraform, donde no tienes acceso directo al state).
    - `state rm` y `removed` **no destruyen** el objeto real: sigue existiendo (y cobrando).
    - `taint` sigue funcionando pero está deprecated: la respuesta moderna es `-replace`.

## 7a. Importar infraestructura existente

**Import** trae al state un objeto que ya existe (creado a mano o por otra herramienta) para que Terraform lo gestione.

### Bloque import (Terraform 1.5+, recomendado)

```hcl title="importar.tf (probado)"
import {
  to = random_string.legado
  id = "x7k2pq" # el ID que el provider usa para ese tipo de recurso
}
```

Con `-generate-config-out`, Terraform **escribe el HCL** del recurso como punto de partida (salida real):

```console
$ terraform plan -generate-config-out=generado.tf
random_string.legado: Preparing import... [id=x7k2pq]
  # random_string.legado will be imported
  # (config will be generated)
Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.
$ terraform apply -auto-approve
random_string.legado: Importing... [id=x7k2pq]
random_string.legado: Import complete [id=x7k2pq]
Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.
```

```hcl title="generado.tf (generado por Terraform)"
# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform from "x7k2pq"
resource "random_string" "legado" {
  keepers          = null
  length           = 6
  lower            = true
  # ...
  special          = true
  upper            = true
}
```

Desde Terraform 1.7, el bloque `import` admite `for_each` para importar varios objetos a la vez. El bloque se puede **borrar** después del apply.

### Comando terraform import (forma clásica)

```console
$ terraform import random_string.legado x7k2pq
The resources that were imported are shown above. These resources are now in
your Terraform state and will henceforth be managed by Terraform.
$ terraform plan
  # random_string.legado must be replaced
      ~ special     = true -> false # forces replacement
```

Lección de la prueba: el bloque `resource` se escribió con `special = false`, pero el objeto real tenía `special = true`; el plan propone **reemplazar** el recurso importado. **Siempre revisa el plan después de importar** y ajusta el código hasta ver `No changes`.

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

Salidas reales:

```console
$ terraform state list
data.archive_file.paquete
local_file.config["api"]
local_file.config["web"]
random_pet.proyecto
random_string.sufijo[0]
random_string.sufijo[1]
$ terraform state show 'random_string.sufijo[0]'
# random_string.sufijo[0]:
resource "random_string" "sufijo" {
    id          = "ac1tt2"
    length      = 6
    lower       = true
    ...
    result      = "ac1tt2"
    special     = false
    upper       = false
}
```

!!! tip "Comillas en Windows y Linux"
    Las direcciones con índices o claves (`local_file.config["api"]`) llevan corchetes y comillas: en Bash ponlas entre comillas simples; en PowerShell suele hacer falta escapar las comillas dobles internas.

## 7c. Logging detallado

Cuando un error no se entiende (un provider que falla, un problema de red o de autenticación), activa los logs con variables de entorno:

| Variable | Valores / efecto |
| --- | --- |
| `TF_LOG` | Activa los logs (en stderr). Niveles de más a menos detalle: `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`. `JSON` da nivel TRACE en formato JSON |
| `TF_LOG_CORE` | Nivel solo para Terraform core |
| `TF_LOG_PROVIDER` | Nivel solo para los providers |
| `TF_LOG_PATH` | Archivo al que se **añade** el log (requiere `TF_LOG` activo) |

Prueba real (Bash):

```console
$ TF_LOG=DEBUG TF_LOG_PATH=tf-debug.log terraform plan
$ wc -l tf-debug.log
253 tf-debug.log
$ head -3 tf-debug.log
2026-10-26T11:02:15.022-0600 [INFO]  Terraform version: 1.12.2
2026-10-26T11:02:15.030-0600 [DEBUG] using github.com/hashicorp/go-tfe v1.74.1
2026-10-26T11:02:15.030-0600 [DEBUG] using github.com/hashicorp/hcl/v2 v2.23.1-...
```

En PowerShell: `$env:TF_LOG = "DEBUG"; $env:TF_LOG_PATH = "tf-debug.log"; terraform plan`, y después `Remove-Item Env:TF_LOG`.

!!! warning "Los logs pueden contener secretos"
    En nivel `TRACE` o `DEBUG` aparecen peticiones a las APIs, que pueden incluir tokens o valores sensibles. No los pegues en un issue público sin revisarlos. Si Terraform se cae (*panic*), escribe un `crash.log`, que también puede contener datos sensibles.

!!! tip "En el examen"
    - El nivel **más detallado** es `TRACE`; sin `TF_LOG_PATH`, los logs salen por **stderr**.
    - `TF_LOG_PATH` **sin** `TF_LOG` no genera logs.
    - Para separar problemas del provider de los de core, usa `TF_LOG_PROVIDER` y `TF_LOG_CORE`.

## Casos de uso

1. **Dos personas aplican a la vez y el state se corrompe.** Remote backend con locking (`s3` con `use_lockfile`, `azurerm`, `gcs` o HCP Terraform).
2. **Un pipeline murió a mitad del apply y ahora todo falla por el lock.** Confirmar que no hay otra ejecución activa y `terraform force-unlock <LOCK_ID>`.
3. **El nombre del bucket del state no debe estar en el repositorio.** Partial configuration con `-backend-config` en `init`.
4. **El equipo de red publica el ID de la VPC y el de aplicaciones lo necesita.** Output en la configuración de red y `terraform_remote_state` (o, mejor, un parámetro compartido leído con su data source).
5. **Alguien cambió una regla de firewall desde la consola.** `terraform plan -refresh-only` para verlo; decidir entre revertir (`apply`) o aceptar (`apply -refresh-only` y actualizar el código).
6. **Reorganizas el código y mueves recursos a un módulo.** Bloques `moved` en el mismo PR.
7. **Un bucket creado a mano debe pasar a Terraform.** Bloque `import` + `-generate-config-out`, limpiar el código generado y aplicar hasta `No changes`.
8. **Un recurso debe seguir existiendo pero dejar de gestionarse con este código.** Bloque `removed` con `destroy = false`.
9. **El provider falla con un error de autenticación poco claro.** `TF_LOG_PROVIDER=DEBUG` y `TF_LOG_PATH` para ver la petición.

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
- [Leer logs](../../../devops/operacion/leer-logs.md) y [Troubleshooting](../../../devops/operacion/troubleshooting.md): método para diagnosticar fallos.
- Siguiente: [Objetivo 8: HCP Terraform](objetivo-8-hcp-terraform.md).

!!! example "Practica en el laboratorio"
    - [Lab 08: Terraform sin nube: providers locales y workspaces](../../../laboratorios/devops/terraform-local-workspaces.md)
    - [Lab 09: Terraform en AWS con remote state en S3](../../../laboratorios/devops/terraform-aws-backend-remoto.md)

## Referencias

- [State](https://developer.hashicorp.com/terraform/language/state)
- [Backend block configuration](https://developer.hashicorp.com/terraform/language/backend) y [Backend type: local](https://developer.hashicorp.com/terraform/language/backend/local)
- [State locking](https://developer.hashicorp.com/terraform/language/state/locking)
- [The terraform_remote_state data source](https://developer.hashicorp.com/terraform/language/state/remote-state-data)
- [Refactoring (moved)](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) y [Removed block reference](https://developer.hashicorp.com/terraform/language/block/removed)
- [Use refresh-only mode to sync Terraform state](https://developer.hashicorp.com/terraform/tutorials/state/refresh)
- [Import](https://developer.hashicorp.com/terraform/language/import) y [Command: import](https://developer.hashicorp.com/terraform/cli/commands/import)
- [Command: state](https://developer.hashicorp.com/terraform/cli/commands/state)
- [Debugging Terraform](https://developer.hashicorp.com/terraform/internals/debugging)
