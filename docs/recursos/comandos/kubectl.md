# Kubernetes
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
| `kubectl get pods,svc,deploy -A` | Ver varios tipos de recurso en todos los namespaces |
| `kubectl get nodes -o wide` | Ver nodos con IP, versión y sistema operativo |
| `kubectl logs deploy/<nombre> --tail=50` | Ver las últimas líneas de log de un deployment |
| `kubectl top pods` | Ver consumo de CPU y memoria (requiere metrics-server) |
| `kubectl create deployment <nombre> --image=<imagen>` | Crear un deployment sin manifiesto |
| `kubectl expose deployment <nombre> --type=LoadBalancer --port=80 --target-port=<puerto>` | Exponer un deployment con un load balancer |
| `kubectl autoscale deploy <nombre> --cpu-percent=60 --min=2 --max=10` | Crear un HorizontalPodAutoscaler |
| `kubectl create serviceaccount <ksa> -n <namespace>` | Crear una service account de Kubernetes |
| `kubectl annotate serviceaccount <ksa> -n <namespace> iam.gke.io/gcp-service-account=<sa-email>` | Vincular la KSA a una service account de Google (Workload Identity en GKE) |

!!! example "Practica en el laboratorio"
    - [Lab 06: Desplegar una app en Kubernetes local con kind](../../laboratorios/devops/kubernetes-local-kind.md)
    - [Lab 14: Endurecer un clúster: Pod Security, NetworkPolicy y Kyverno](../../laboratorios/devsecops/seguridad-kubernetes.md)

