# Docker
| Comando | Descripción |
|---------|-------------|
| `docker pull <imagen>` | Descargar imagen |
| `docker push <imagen>` | Subir imagen |
| `docker build -t <nombre> .` | Construir imagen |
| `docker run -d -p <host>:<contenedor> <imagen>` | Ejecutar contenedor en segundo plano |
| `docker run -it <imagen> /bin/bash` | Ejecutar contenedor de forma interactiva |
| `docker ps` | Listar contenedores activos |
| `docker ps -a` | Listar todos los contenedores |
| `docker stop <contenedor>` | Detener contenedor |
| `docker rm <contenedor>` | Eliminar contenedor |
| `docker rmi <imagen>` | Eliminar imagen |
| `docker images` | Listar imágenes locales |
| `docker exec -it <contenedor> /bin/bash` | Acceder a un contenedor en ejecución |
| `docker logs -f <contenedor>` | Ver logs en tiempo real |
| `docker network ls` | Listar redes |
| `docker volume ls` | Listar volúmenes |
| `docker-compose up -d` | Levantar servicios definidos en compose |
| `docker-compose down` | Detener y eliminar servicios de compose |
| `docker system prune -a` | Limpiar imágenes/contenedores/redes sin uso |

!!! example "Practica en el laboratorio"
    - [Lab 05: Imagen multi-stage y Docker Compose](../../laboratorios/devops/docker-multistage-compose.md)
    - [Lab 11: Observabilidad con Prometheus y Grafana](../../laboratorios/devops/observabilidad-prometheus-grafana.md)

