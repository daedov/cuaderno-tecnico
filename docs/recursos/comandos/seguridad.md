## Seguridad y escaneo
| Comando | Descripción |
|---------|-------------|
| `checkov -d <directorio>` | Escanear IaC (Terraform, CloudFormation, K8s) |
| `trivy image <imagen>` | Escanear vulnerabilidades en imagen Docker |
| `trivy fs <directorio>` | Escanear vulnerabilidades en el sistema de archivos |
| `tfsec <directorio>` | Escanear configuración de Terraform |
| `snyk test` | Analizar vulnerabilidades en dependencias del proyecto |
| `snyk container test <imagen>` | Analizar vulnerabilidades en imagen de contenedor |