# Puertos comunes

## Bases de datos
| Herramienta/Servicio | Uso | Puerto |
| :--- | :--- | :--- |
| **MySQL / MariaDB** | Base de datos relacional | **3306** |
| **PostgreSQL** | Base de datos relacional | **5432** |
| **SQL Server** | Base de datos relacional | **1433** |
| **MongoDB** | Base de datos NoSQL | **27017** |
| **Redis** | Cache/Base de datos | **6379** |
| **Memcached** | Cache en memoria | **11211** |
| **Cassandra** | Base de datos NoSQL | **9042** |
| **CouchDB** | Base de datos NoSQL | **5984** |
| **Couchbase** | Base de datos | **8091** |
| **InfluxDB** | Base de datos de series temporales | **8086** |
| **MySQL Cluster (NDB)** | Gestión de clúster (ndb_mgmd) | **1186** |
| **Elasticsearch** | Buscador (HTTP / transporte nodo a nodo) | **9200, 9300** |
| **Oracle Database** | Base de datos relacional | **1521** |

## Mensajería y streaming
| Herramienta/Servicio | Uso | Puerto |
| :--- | :--- | :--- |
| **RabbitMQ** | Mensajería (AMQP) | **5672** |
| **RabbitMQ Management** | Panel web | **15672** |
| **Kafka** | Streaming de eventos | **9092** |
| **Kafka Connect** | API REST de conectores | **8083** |
| **Zookeeper** | Coordinación (usado por Kafka) | **2181** |
| **NATS** | Mensajería | **4222** |

## Web y aplicaciones
| Herramienta/Servicio | Uso | Puerto |
| :--- | :--- | :--- |
| **HTTP** | Web (sin cifrar) | **80** |
| **HTTPS** | Web (cifrado TLS) | **443** |
| **Apache HTTP Server** | Servidor web | **80, 443** |
| **Nginx** | Servidor web / proxy | **80, 443** |
| **Tomcat** | Aplicaciones Java | **8080** |
| **Node.js (convención)** | Apps de desarrollo | **3000** |
| **HAProxy** | Balanceo de carga | **80, 443 (o custom)** |
| **Traefik** | Reverse proxy / dashboard | **80, 443, 8080 (dashboard)** |
| **Squid** | Proxy | **3128** |

## CI/CD y gestión de artefactos
| Herramienta/Servicio | Uso | Puerto |
| :--- | :--- | :--- |
| **Jenkins** | CI/CD | **8080** |
| **GitLab** | Repositorio / CI-CD (web) | **80, 443** (SSH: **22**) |
| **Nexus Repository Manager** | Repositorio de artefactos | **8081** |
| **JFrog Artifactory** | Repositorio de artefactos | **8081, 8082** |
| **SonarQube** | Análisis de calidad de código | **9000** |
| **Docker Registry** | Registro privado de imágenes | **5000** |
| **ArgoCD** | GitOps/CD (interno del contenedor) | **8080 (http), 8443 (https)**¹ |

¹ Al exponerlo por Ingress/LoadBalancer suele mapearse a 80/443.

## Contenedores y orquestación
| Herramienta/Servicio | Uso | Puerto |
| :--- | :--- | :--- |
| **Docker daemon (TCP)** | API remota sin TLS / con TLS | **2375 / 2376** |
| **Kubernetes API Server** | Control plane | **6443** |
| **kubelet API** | Agente de nodo | **10250** |
| **etcd** | Almacén clave-valor del clúster | **2379, 2380** |
| **NodePort (rango K8s)** | Exposición de servicios | **30000–32767** |

## Observabilidad
| Herramienta/Servicio | Uso | Puerto |
| :--- | :--- | :--- |
| **Grafana** | Dashboards | **3000** |
| **Prometheus** | Métricas | **9090** |
| **Alertmanager** | Alertas de Prometheus | **9093** |
| **Zabbix** | Monitoreo | **10050, 10051** |
| **Nagios** | Monitoreo | **80 (web)** |

## Acceso remoto y transferencia de archivos
| Herramienta/Servicio | Uso | Puerto |
| :--- | :--- | :--- |
| **SSH** | Acceso remoto Linux | **22** |
| **RDP** | Escritorio remoto Windows | **3389** |
| **VNC** | Escritorio remoto | **5900** |
| **FTP** | Transferencia de archivos | **21** |
| **SFTP** | Transferencia de archivos segura (sobre SSH) | **22** |
| **Telnet** | Acceso remoto (no cifrado) | **23** |

## Redes e infraestructura base
| Herramienta/Servicio | Uso | Puerto |
| :--- | :--- | :--- |
| **DNS** | Resolución de nombres | **53** |
| **DHCP** | Asignación de IP | **67, 68** |
| **NTP** | Sincronización de hora | **123** |
| **SNMP** | Monitoreo de red | **161, 162** |
| **Syslog** | Registro remoto | **514** |
| **LDAP** | Directorio | **389, 636 (LDAPS)** |
| **NFS** | Sistema de archivos de red | **2049** |
| **SMB/CIFS** | Compartición de archivos Windows | **445** |
| **SMTP** | Envío de correo | **25, 587** |
| **IMAP / IMAPS** | Recepción de correo | **143 / 993** |
| **POP3 / POP3S** | Recepción de correo | **110 / 995** |

## Automatización y herramientas varias
| Herramienta/Servicio | Uso | Puerto |
| :--- | :--- | :--- |
| **n8n** | Automatización de flujos | **5678** |
| **Consul** | Descubrimiento de servicios / UI | **8500** |
| **Vault** | Gestión de secretos | **8200** |
| **Portainer** | Panel de gestión Docker | **9000, 9443** |
| **MinIO** | Almacenamiento S3-compatible | **9000 (API), 9001 (consola)** |

!!! example "Practica en el laboratorio"
    - [Lab 01: Diagnóstico de red desde Linux](../laboratorios/fundamentos/linux-red-diagnostico.md)

