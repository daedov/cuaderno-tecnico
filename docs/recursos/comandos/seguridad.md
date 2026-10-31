# Seguridad y escaneo
| Comando | Descripción |
|---------|-------------|
| `checkov -d <directorio>` | Escanear IaC (Terraform, CloudFormation, K8s) |
| `trivy image <imagen>` | Escanear vulnerabilidades en imagen Docker |
| `trivy fs <directorio>` | Escanear vulnerabilidades en el sistema de archivos |
| `trivy config <directorio>` | Escanear IaC y Dockerfiles (sucesor de `tfsec`) |
| `snyk test` | Analizar vulnerabilidades en dependencias del proyecto |
| `snyk container test <imagen>` | Analizar vulnerabilidades en imagen de contenedor |

Qué hace cada tipo de escaneo y cómo integrarlo en el pipeline: [SAST](../../devsecops/escaneos/sast.md), [SCA](../../devsecops/escaneos/sca.md), [secretos](../../devsecops/escaneos/secret-scanning.md), [IaC](../../devsecops/escaneos/iac-scanning.md), [contenedores](../../devsecops/escaneos/container-scanning.md) y [DAST](../../devsecops/escaneos/dast.md).
