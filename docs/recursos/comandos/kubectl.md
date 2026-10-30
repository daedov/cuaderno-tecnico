## Kubernetes
| Comando | Descripción |
|---------|-------------|
| `kubectl apply -f <archivo>` | Aplicar manifiesto |
| `kubectl delete -f <archivo>` | Eliminar manifiesto |
| `kubectl get pods` | Listar pods |
| `kubectl get pods -o wide` | Listar pods con detalle (nodo, IP) |
| `kubectl get svc` | Listar servicios |
| `kubectl get deploy` | Listar deployments |
| `kubectl get nodes` | Listar nodos del clúster |
| `kubectl get ns` | Listar namespaces |
| `kubectl describe pod <pod>` | Ver detalles/eventos de un pod |
| `kubectl logs <pod>` | Ver logs |
| `kubectl logs -f <pod>` | Ver logs en tiempo real |
| `kubectl exec -it <pod> -- /bin/bash` | Acceder al contenedor |
| `kubectl scale deploy <nombre> --replicas=<n>` | Escalar deployment |
| `kubectl rollout restart deploy <nombre>` | Reiniciar deployment |
| `kubectl rollout status deploy <nombre>` | Ver estado de despliegue |
| `kubectl rollout undo deploy <nombre>` | Revertir a versión anterior |
| `kubectl config get-contexts` | Ver contextos disponibles |
| `kubectl config use-context <contexto>` | Cambiar de contexto/clúster |
| `kubectl port-forward <pod> <local>:<remoto>` | Redirigir puerto local al pod |

!!! example "Practica en el laboratorio"
    - [Lab 06: Desplegar una app en Kubernetes local con kind](../../laboratorios/devops/kubernetes-local-kind.md)
    - [Lab 14: Endurecer un clúster: Pod Security
    - NetworkPolicy y Kyverno](../../laboratorios/devsecops/seguridad-kubernetes.md)

