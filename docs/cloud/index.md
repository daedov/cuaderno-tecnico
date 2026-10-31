# Cloud :cloud:

**Cloud es dónde corre todo** (el control): los servicios de AWS, Azure y Google Cloud sobre los que se construye y despliega. Las notas de esta sección comparan los tres proveedores con el nombre oficial de cada servicio.

Cada tema se ve también desde [DevOps](../devops/index.md) (cómo se automatiza) y [DevSecOps](../devsecops/index.md) (cómo se verifica que es seguro). Los fundamentos de red que hay debajo están en [Networking](../networking/index.md). Ver el [mapa de relaciones](../mapa-de-relaciones.md).

## Fundamentos

- [Modelos de servicio y regiones](fundamentos/modelos-de-servicio-y-regiones.md): IaaS, PaaS, SaaS, regiones y Availability Zones
- [Shared Responsibility Model](fundamentos/responsabilidad-compartida.md)
- [IAM: AWS, Azure y GCP](fundamentos/iam-comparativa.md): identidades, permisos y equivalencias entre proveedores
- [Well-Architected Framework](fundamentos/well-architected.md)
- [FinOps y costos](fundamentos/finops-costos.md)

## Cómputo

- [Máquinas virtuales: AWS, Azure y GCP](computo/maquinas-virtuales.md)
- [Contenedores gestionados](computo/contenedores-gestionados.md): ECS, EKS, Fargate y equivalentes
- [Serverless](computo/serverless.md): Lambda, Azure Functions y Cloud Run functions

## Redes y datos

- [Redes en la nube](redes-y-datos/redes.md): VPC, subnets, routing, security groups, DNS, load balancers, VPN, CDN
- [Almacenamiento y datos](redes-y-datos/almacenamiento-datos.md): object, block y file storage, bases de datos, backups

## Seguridad en la nube

Controles y buenas prácticas de seguridad por servicio en AWS, Azure y Google Cloud: riesgos típicos y cómo verificarlos.

- [Fundamentos de seguridad cloud](seguridad/fundamentos-seguridad-cloud.md): principios, baselines oficiales y checklist de controles imprescindibles
- [Identidades y accesos](seguridad/seguridad-identidades.md): cuentas raíz, MFA, SSO, sin llaves de larga duración, guardrails
- [Cifrado y secretos](seguridad/seguridad-cifrado-secretos.md): KMS, Key Vault, Cloud KMS, rotación, certificados
- [Logging y detección](seguridad/seguridad-logging-deteccion.md): logs obligatorios, retención, detección y alertas mínimas
- [Redes](seguridad/seguridad-redes.md): segmentación, acceso administrativo seguro, private endpoints, WAF y DDoS
- [Máquinas virtuales](seguridad/seguridad-maquinas-virtuales.md): imágenes endurecidas, parches, metadatos, cifrado
- [Contenedores y Kubernetes](seguridad/seguridad-contenedores-kubernetes.md): EKS, AKS, GKE, Fargate, Container Apps, Cloud Run
- [Serverless](seguridad/seguridad-serverless.md): Lambda, Azure Functions, Cloud Run functions
- [Almacenamiento](seguridad/seguridad-almacenamiento.md): S3, Blob Storage, Cloud Storage, snapshots
- [Bases de datos](seguridad/seguridad-bases-datos.md): relacionales y NoSQL gestionadas
- [APIs y aplicaciones](seguridad/seguridad-apis-aplicaciones.md): API gateways, autenticación, rate limiting, identidad de usuarios
- [Servicios de IA](seguridad/seguridad-servicios-ia.md): Bedrock, Azure OpenAI, Vertex AI, prompt injection
- Terraform seguro, con el código de todos los controles anteriores: [AWS](seguridad/terraform/aws.md), [Azure](seguridad/terraform/azure.md) y [Google Cloud](seguridad/terraform/google-cloud.md)

## Operación y gobierno

- [Observabilidad nativa](operacion-y-gobierno/observabilidad-nativa.md): CloudWatch, Azure Monitor, Cloud Monitoring
- [Resiliencia](operacion-y-gobierno/resiliencia.md): high availability, autoscaling, disaster recovery, RTO/RPO
- [Gobernanza](operacion-y-gobierno/gobernanza.md): landing zone, tagging, guardrails, multi-account

## Arquitectura

- [Fundamentos de arquitectura de software](arquitectura/fundamentos-arquitectura-software.md): quality attributes, trade-offs, ADR, modelo C4
- [Estilos de arquitectura](arquitectura/estilos-arquitectura.md): monolito, microservicios, event-driven, serverless
- [Integración y APIs](arquitectura/integracion-apis.md): REST, gRPC, GraphQL, colas, pub/sub, sagas
- [Arquitectura en la nube](arquitectura/arquitectura-cloud.md): cloud-native, Twelve-Factor App, patrones de diseño cloud
- [Arquitecturas de referencia](arquitectura/arquitecturas-referencia.md): three-tier, API serverless, event-driven, multi-región
- [Migración a la nube](arquitectura/migracion-cloud.md): las 7 R, fases y herramientas

!!! note "Añadir una nota"
    Crea un `.md` en la subcarpeta del bloque que corresponda dentro de `docs/cloud/` y agrégalo a su archivo `.pages` para fijar su orden en el menú.
