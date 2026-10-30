

## Terraform
| Comando | Descripción |
|---------|-------------|
| `terraform init` | Inicializar Terraform |
| `terraform fmt` | Formatear archivos `.tf` |
| `terraform validate` | Validar sintaxis de la configuración |
| `terraform plan` | Planificar cambios |
| `terraform plan -out=<archivo>` | Guardar el plan en un archivo |
| `terraform apply` | Aplicar cambios |
| `terraform apply <archivo>.tfplan` | Aplicar un plan previamente guardado |
| `terraform destroy` | Destruir infraestructura |
| `terraform state list` | Listar recursos en el state |
| `terraform state show <recurso>` | Mostrar detalles de un recurso |
| `terraform workspace list` | Listar workspaces |
| `terraform workspace new <nombre>` | Crear workspace |
| `terraform output` | Mostrar outputs definidos |
| `terraform import <recurso> <id>` | Importar recurso existente al state |

!!! example "Practica en el laboratorio"
    - [Lab 08: Terraform sin nube: providers locales y workspaces](../../laboratorios/devops/terraform-local-workspaces.md)
    - [Lab 09: Terraform en AWS con remote state en S3](../../laboratorios/devops/terraform-aws-backend-remoto.md)

