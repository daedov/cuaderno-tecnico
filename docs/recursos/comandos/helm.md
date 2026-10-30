
## Helm
| Comando | Descripción |
|---------|-------------|
| `helm repo add <nombre> <url>` | Agregar repositorio de charts |
| `helm repo update` | Actualizar repositorios |
| `helm search repo <nombre>` | Buscar chart en repositorios |
| `helm install <release> <chart>` | Instalar un chart |
| `helm upgrade <release> <chart>` | Actualizar un release |
| `helm uninstall <release>` | Eliminar un release |
| `helm list` | Listar releases instalados |
| `helm rollback <release> <revision>` | Revertir a una revisión anterior |

!!! example "Practica en el laboratorio"
    - [Lab 06: Desplegar una app en Kubernetes local con kind](../../laboratorios/devops/kubernetes-local-kind.md)
    - [Lab 14: Endurecer un clúster: Pod Security
    - NetworkPolicy y Kyverno](../../laboratorios/devsecops/seguridad-kubernetes.md)

