---
tags:
  - seguridad
  - cloud
  - aws
  - azure
  - gcp
  - kubernetes
  - contenedores
---

# Seguridad de contenedores y Kubernetes gestionado

> Los controles de plataforma de Amazon EKS, Azure Kubernetes Service (AKS) y Google Kubernetes Engine (GKE), sus registries, y lo esencial para ECS/Fargate, Azure Container Apps y Cloud Run.

!!! info "Antes de leer"
    En Kubernetes gestionado el proveedor opera y parchea el **control plane** (API server, etcd); **tú configuras** el acceso al API server, la identidad, los nodos (salvo en modos totalmente gestionados como GKE Autopilot o EKS Auto Mode), la red y todo lo que despliegas. Esta nota se centra en **lo que configuras en la nube**. Los controles propios de Kubernetes (RBAC en detalle, Pod Security Standards, NetworkPolicy, admission control, Falco) están en [Seguridad de Kubernetes](../../devsecops/infraestructura-y-contenedores/seguridad-kubernetes.md), y la imagen (Dockerfile, escaneo, firma) en [Seguridad de contenedores](../../devsecops/infraestructura-y-contenedores/seguridad-contenedores.md). Los servicios se presentan en [Contenedores gestionados](../computo/contenedores-gestionados.md).

## Riesgos típicos

| Riesgo | Ejemplo o incidente conocido | Control que lo evita |
| --- | --- | --- |
| API server o dashboard expuestos sin autenticación | Tesla (2018): una consola de Kubernetes sin contraseña permitió desplegar mineros de criptomonedas con credenciales de la nube | Endpoint privado o con redes autorizadas; dashboard desactivado; autenticación con la identidad de la nube |
| Pods que roban las credenciales del nodo | Un pod comprometido consulta el servicio de metadatos y obtiene el rol del nodo | Workload identity por pod; bloquear el acceso al metadata server desde los pods |
| Permisos excesivos en RBAC | `cluster-admin` repartido o *bindings* a grupos amplios | RBAC mínimo vinculado a grupos del IdP; cuentas locales desactivadas |
| Nodos y versiones sin actualizar | Clústeres en versiones fuera de soporte con CVE conocidos (ver [CVE en contenedores y Kubernetes](../../devsecops/vulnerabilidades/cve-contenedores-kubernetes.md)) | Release channels / auto-upgrade; imágenes de nodo mínimas |
| Contenedores privilegiados o como root | Escape del contenedor al host | Pod Security Admission (`restricted`), políticas de Azure Policy / Gatekeeper / Kyverno |
| Red plana dentro del clúster | Un pod comprometido llega a todas las bases de datos | Network policies con *default deny* |
| Imágenes vulnerables o no confiables | Imágenes públicas con malware o dependencias con CVE críticos | Registry privado con escaneo, etiquetas inmutables, firma y verificación en la admisión |
| Secretos legibles | Secretos de Kubernetes en base64 en etcd o en variables de entorno de la imagen | Cifrado de secrets con KMS; secretos desde el gestor de la nube |
| Sin rastro de lo que pasó | Nadie activó los logs de auditoría del control plane | Audit logs del API server enviados a la plataforma de logs |

## Controles por proveedor

| Prioridad | Control | Amazon EKS | AKS | GKE |
| --- | --- | --- | --- | --- |
| **Imprescindible** | API server privado o restringido | Endpoint *private access* y *public access* desactivado (o `publicAccessCidrs`) | Private cluster, API Server VNet Integration o *authorized IP ranges* | Private endpoint / DNS-based endpoint, *authorized networks* |
| **Imprescindible** | Autenticación con la identidad de la nube | IAM + **access entries** (modo `API`, sin `aws-auth` ConfigMap) | Microsoft Entra ID + **Azure RBAC for Kubernetes**, `disableLocalAccounts` | IAM + RBAC (Google Groups for RBAC); certificados de cliente y basic auth desactivados |
| **Imprescindible** | Workload identity | **EKS Pod Identity** o **IRSA** | **Microsoft Entra Workload ID** | **Workload Identity Federation for GKE** |
| **Imprescindible** | Versiones y nodos actualizados | Versión en *standard support*; actualizar AMIs de nodos (EKS Auto Mode lo hace) | *Auto-upgrade channel* + *node OS upgrade channel* | Release channels + node auto-upgrade y auto-repair |
| **Imprescindible** | Audit logs del control plane | Control plane logging (`audit`, `authenticator`, `api`) a CloudWatch Logs | Diagnostic settings (`kube-audit-admin`, `guard`) | Cloud Audit Logs (Admin Activity siempre activo) + system logs |
| **Imprescindible** | Registry privado con escaneo | Amazon ECR + escaneo básico o *enhanced* (Amazon Inspector) | Azure Container Registry + Defender for Containers | Artifact Registry + Artifact Analysis |
| Recomendado | Cifrado de datos del API (secrets) con KMS | Envelope encryption por defecto (1.28+) con clave AWS; opcional CMK de AWS KMS | KMS etcd encryption con Azure Key Vault | Application-layer secrets encryption con Cloud KMS |
| Recomendado | Pod Security | Pod Security Admission (labels por namespace) | Pod Security Admission + Azure Policy add-on | Pod Security Admission; Autopilot aplica restricciones propias |
| Recomendado | Network policies | VPC CNI con network policy activada, o Calico/Cilium | Azure CNI Powered by Cilium, Calico o Azure NPM | GKE Dataplane V2 (incluido en Autopilot) |
| Recomendado | Nodos endurecidos | Bottlerocket o AMIs optimizadas de EKS; IMDSv2 con hop limit 1 | Azure Linux o Ubuntu; Trusted Launch en node pools | Container-Optimized OS, Shielded GKE Nodes con Secure Boot, `GKE_METADATA` |
| Recomendado | Firma y verificación de imágenes | AWS Signer + Notation; políticas de admisión (Kyverno, Gatekeeper) | Notation con Azure Key Vault; Ratify / Azure Policy | Binary Authorization |
| Recomendado | Detección en runtime | GuardDuty EKS Protection y Runtime Monitoring | Microsoft Defender for Containers | GKE Threat Detection / Container Threat Detection (Security Command Center) |
| Recomendado | Postura del clúster | Security Hub CSPM, *EKS cluster insights* | Defender for Containers (recomendaciones) | GKE security posture dashboard |

!!! info "Cifrado de secrets en EKS"
    Desde Kubernetes 1.28, Amazon EKS cifra **todos los datos del API de Kubernetes** (no solo los Secrets) con *envelope encryption* KMS v2 y una clave propiedad de AWS, sin que tengas que hacer nada. Si tu cumplimiento exige controlar la clave, asocia una **customer managed key** de AWS KMS: si la deshabilitas o la borras, el clúster queda degradado o irrecuperable, así que protégela con políticas de clave estrictas.

## Identidad de pods hacia la nube

Un pod que necesita leer un bucket o una cola **no debe** llevar access keys en un Secret. Cada proveedor federa la identidad del ServiceAccount de Kubernetes con su IAM para entregar credenciales temporales; es el mismo principio que OIDC en el pipeline (ver [Secretos e identidades](../../devsecops/identidades-y-pipeline/secretos-identidades.md#oidc-entre-el-pipeline-y-la-nube)).

=== "AWS (EKS)"

    - **EKS Pod Identity** (más reciente y sencillo): se instala el add-on *Pod Identity Agent* y se crea una *pod identity association* entre ServiceAccount e IAM role, sin anotaciones ni OIDC provider por clúster.
    - **IRSA** (*IAM Roles for Service Accounts*): el clúster tiene un OIDC provider en IAM; el ServiceAccount lleva la anotación `eks.amazonaws.com/role-arn` y el pod asume ese IAM role.

    ```bash
    aws eks create-pod-identity-association \
      --cluster-name prod --namespace app \
      --service-account lector-s3 \
      --role-arn arn:aws:iam::111122223333:role/app-lector-s3
    ```

=== "Azure (AKS)"

    **Microsoft Entra Workload ID**: se activa el OIDC issuer y Workload Identity en el clúster, se crea una *federated identity credential* en una managed identity (o app registration) que confía en el ServiceAccount, y:

    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: lector-blob
      namespace: app
      annotations:
        azure.workload.identity/client-id: "<client-id-de-la-managed-identity>"
    ```

    Los pods que la usan llevan la label `azure.workload.identity/use: "true"`.

=== "Google Cloud (GKE)"

    **Workload Identity Federation for GKE**: en GKE Standard se activa en el clúster (`workload_pool`) y en cada node pool con `GKE_METADATA`, que además oculta las credenciales del nodo; en Autopilot ya viene así. Después se da el role de IAM directamente al ServiceAccount de Kubernetes como *principal*:

    ```bash
    gcloud projects add-iam-policy-binding mi-proyecto \
      --role=roles/storage.objectViewer \
      --member="principal://iam.googleapis.com/projects/123456789/locations/global/workloadIdentityPools/mi-proyecto.svc.id.goog/subject/ns/app/sa/lector-gcs"
    ```

    También puede vincularse a una service account de IAM con la anotación `iam.gke.io/gcp-service-account`.

## Buenas prácticas

1. **Prefiere el modo más gestionado**: GKE Autopilot, EKS Auto Mode o AKS Automatic reducen lo que tienes que endurecer en los nodos.
2. **API server privado** y acceso de operadores por VPN, bastion o redes autorizadas; el pipeline despliega desde runners dentro de la red o con GitOps.
3. **Identidad de la nube para personas**: grupos del IdP mapeados a roles de RBAC; nada de cuentas locales ni kubeconfigs con certificados estáticos.
4. **Workload identity para pods**: cada ServiceAccount de Kubernetes con su propio rol/identidad de nube, con permisos mínimos; bloquea el acceso de los pods al metadata server del nodo (ver [Identidad de pods hacia la nube](#identidad-de-pods-hacia-la-nube)).
5. **Actualizaciones continuas**: release channel o auto-upgrade, ventanas de mantenimiento y *PodDisruptionBudgets* para que actualizar no dé miedo.
6. **Pod Security `restricted`** en los namespaces de aplicaciones y *default deny* de red por namespace. Las labels de Pod Security Admission y las NetworkPolicies están en [Seguridad de Kubernetes](../../devsecops/infraestructura-y-contenedores/seguridad-kubernetes.md#pod-security-standards).
7. **Supply chain**: imágenes solo desde tu registry privado, etiquetas inmutables o *digest*, escaneo continuo y verificación de firma en la admisión (ver [Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md)).
8. **Secretos desde el gestor de la nube** (Secrets Store CSI Driver, External Secrets) en vez de Secrets escritos a mano (ver [Seguridad de cifrado y secretos](seguridad-cifrado-secretos.md)).
9. **Logs de auditoría y detección en runtime** activos, enviados a la plataforma central.

=== "AWS"

    - Usa el **authentication mode `API`** (access entries) y crea el clúster con `bootstrapClusterCreatorAdminPermissions = false`, para que quien lo creó no quede como administrador invisible.
    - Los managed node groups **no actualizan la AMI solos**: planifica las actualizaciones o usa EKS Auto Mode.
    - **ECS/Fargate**: separa el *task execution role* (bajar la imagen, leer secretos) del *task role* (lo que hace la aplicación); pasa secretos con el campo `secrets` (Secrets Manager / Parameter Store), contenedores sin `privileged`, con `readonlyRootFilesystem` y usuario no root, y sin IP pública asignada.

=== "Azure"

    - Integra AKS con Microsoft Entra ID, activa **Azure RBAC for Kubernetes Authorization** y **desactiva las cuentas locales** (`--disable-local-accounts`): así no existe un kubeconfig de administrador fuera de Entra.
    - Configura el **node OS upgrade channel** (`NodeImage` o `SecurityPatch`) además del canal de versión del clúster.
    - Activa el **Azure Policy add-on** para aplicar políticas de Kubernetes (contenedores privilegiados, registries permitidos) y **Defender for Containers** para escaneo y runtime.
    - **Azure Container Apps**: *ingress* interno salvo que sea público a propósito, managed identity para bajar imágenes de ACR y leer Key Vault, secretos como referencias a Key Vault, entorno con VNet propia, y *built-in authentication* para apps web.

=== "Google Cloud"

    - Inscribe el clúster en un **release channel**; GKE actualiza control plane y nodos de forma automática.
    - **Binary Authorization** bloquea imágenes que no tengan las atestaciones requeridas (por ejemplo, "escaneada" y "aprobada").
    - **Cloud Run**: service account dedicada por servicio (nunca la default de Compute Engine), *ingress* `internal` o `internal-and-cloud-load-balancing` cuando no deba ser público, autenticación obligatoria (`roles/run.invoker`) salvo webs públicas detrás de un load balancer con Cloud Armor, secretos desde Secret Manager y Binary Authorization.

## Cómo verificarlo

Solo comandos de lectura.

=== "AWS"

    ```bash
    # Endpoint, autenticación, logs y cifrado del clúster
    aws eks describe-cluster --name <cluster> --query \
      "cluster.{version:version,publico:resourcesVpcConfig.endpointPublicAccess,cidrs:resourcesVpcConfig.publicAccessCidrs,privado:resourcesVpcConfig.endpointPrivateAccess,auth:accessConfig.authenticationMode,logs:logging.clusterLogging,kms:encryptionConfig}"

    aws eks list-access-entries --cluster-name <cluster>
    aws eks list-pod-identity-associations --cluster-name <cluster>

    # Repositorios de ECR: inmutabilidad y escaneo
    aws ecr describe-repositories --query \
      "repositories[].{repo:repositoryName,tags:imageTagMutability,scanOnPush:imageScanningConfiguration.scanOnPush}" --output table
    aws ecr get-registry-scanning-configuration

    # Task definition de ECS: privilegios, root filesystem y usuario
    aws ecs describe-task-definition --task-definition <familia> --query \
      "taskDefinition.containerDefinitions[].{nombre:name,privileged:privileged,readOnly:readonlyRootFilesystem,usuario:user,secrets:secrets[].name}"
    ```

=== "Azure"

    ```bash
    az aks show -g <rg> -n <cluster> --query \
      "{version:kubernetesVersion,privado:apiServerAccessProfile.enablePrivateCluster,ips:apiServerAccessProfile.authorizedIpRanges,azureRbac:aadProfile.enableAzureRbac,cuentasLocalesOff:disableLocalAccounts,workloadId:securityProfile.workloadIdentity.enabled,kms:securityProfile.azureKeyVaultKms.enabled,upgrade:autoUpgradeProfile,netpol:networkProfile.networkPolicy,policy:addonProfiles.azurepolicy.enabled}"

    # Registry: usuario admin y acceso público
    az acr show -n <registry> --query "{admin:adminUserEnabled,publico:publicNetworkAccess}"

    # Container Apps: ingress externo o interno
    az containerapp show -g <rg> -n <app> --query "properties.configuration.ingress.external"
    ```

=== "Google Cloud"

    ```bash
    gcloud container clusters describe <cluster> --location <region> --format="yaml(
      currentMasterVersion, releaseChannel, privateClusterConfig, controlPlaneEndpointsConfig,
      masterAuthorizedNetworksConfig, workloadIdentityConfig, databaseEncryption,
      networkConfig.datapathProvider, binaryAuthorization, legacyAbac, loggingConfig)"

    gcloud container node-pools list --cluster <cluster> --location <region> \
      --format="table(name,config.imageType,management.autoUpgrade,config.shieldedInstanceConfig.enableSecureBoot,config.workloadMetadataConfig.mode)"

    # Cloud Run: ingress, service account y quién puede invocar
    gcloud run services describe <servicio> --region <region> \
      --format="yaml(metadata.annotations,spec.template.spec.serviceAccountName)"
    gcloud run services get-iam-policy <servicio> --region <region>
    ```

Las comprobaciones con `kubectl` dentro del clúster (RBAC, Pod Security, NetworkPolicy) están en [Seguridad de Kubernetes](../../devsecops/infraestructura-y-contenedores/seguridad-kubernetes.md#como-verificarlo).

| Control | AWS Security Hub CSPM | Microsoft Defender for Cloud (MCSB) | Security Command Center (Security Health Analytics) |
| --- | --- | --- | --- |
| API server expuesto | EKS.1 | *Kubernetes API server should be configured with restricted access* | `PRIVATE_CLUSTER_DISABLED`, `MASTER_AUTHORIZED_NETWORKS_DISABLED` |
| Versión soportada | EKS.2, EKS.9 | *Upgrade Azure Kubernetes Service to remove vulnerabilities from AKS system pods* | `AUTO_UPGRADE_DISABLED`, `RELEASE_CHANNEL_DISABLED`, `AUTO_REPAIR_DISABLED` |
| Audit logs | EKS.8 | *Diagnostic logs in Kubernetes services should be enabled* | `CLUSTER_LOGGING_DISABLED` |
| Autenticación / RBAC | — | *Role-Based Access Control should be used on Kubernetes Services* | `LEGACY_AUTHORIZATION_ENABLED`, `WEB_UI_ENABLED` |
| Workload identity / metadatos | — | *Kubernetes clusters should disable automounting API credentials* | `WORKLOAD_IDENTITY_DISABLED`, `LEGACY_METADATA_ENABLED` |
| Cifrado de secrets | (por defecto en 1.28+) | — | `CLUSTER_SECRETS_ENCRYPTION_DISABLED` |
| Network policies | — | — | `NETWORK_POLICY_DISABLED` |
| Nodos endurecidos | — | *Azure Kubernetes Service clusters should have Defender profile enabled* | `COS_NOT_USED`, `CLUSTER_SHIELDED_NODES_DISABLED`, `NODEPOOL_SECURE_BOOT_DISABLED` |
| Contenedores privilegiados | ECS.4, ECS.5, ECS.20 | *Privileged containers should be avoided*; *Running containers as root user should be avoided*; *Immutable (read-only) root filesystem should be enforced for containers* | (KSPM / Policy Controller) |
| Registry | ECR.1, ECR.2, ECR.3, Inspector.2 | *Azure registry container images should have vulnerabilities resolved…*; *Container registries should use private link* | `CONTAINER_IMAGE_VULNERABILITY` (Artifact Analysis) |
| Detección en runtime | GuardDuty.5, GuardDuty.7, GuardDuty.12 | *Microsoft Defender for Containers should be enabled* | `BINARY_AUTHORIZATION_DISABLED` |
| Secretos en ECS | ECS.8 | *Secrets should be configured for containers to prevent the use of sensitive plaintext environment variables* (AWS) | `SECRETS_IN_ENVIRONMENT_VARIABLES` (Cloud Run) |

Los escáneres de postura dentro del clúster (kube-bench, Kubescape, Trivy Operator) se ven en [KSPM](../../devsecops/escaneos/kspm.md).

## Configuración segura con IaC

Los fragmentos de Terraform con estos controles (y los guardrails de organización, cuando aplican) están en las páginas por proveedor: [AWS](terraform/aws.md#contenedores-y-kubernetes), [Azure](terraform/azure.md#contenedores-y-kubernetes) y [Google Cloud](terraform/google-cloud.md#contenedores-y-kubernetes).

## Errores comunes

- Crear el clúster con el endpoint público abierto a `0.0.0.0/0` "porque así viene por defecto" (en EKS lo es).
- Seguir usando el ConfigMap `aws-auth` o kubeconfigs con certificados locales que nadie puede revocar.
- Dar permisos de nube al **nodo** (rol del node group, service account del node pool) para que "los pods puedan acceder a S3": todos los pods heredan ese permiso.
- Actualizar el control plane y olvidar los nodos, o quedarse en versiones de *extended support*.
- Activar Pod Security en modo `warn` y no pasar nunca a `enforce`.
- Network policies escritas pero un CNI que no las aplica.
- Etiquetas `:latest` y registries públicos en producción.
- En Cloud Run, marcar "Allow unauthenticated" (`allUsers` con `roles/run.invoker`) en servicios internos.
- Usar la clave CMK del clúster para todo y luego deshabilitarla sin saber que deja el clúster inservible.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Servicios de contenedores; identidad de pods; red del clúster; cifrado y logs | [Contenedores gestionados](../computo/contenedores-gestionados.md), [Seguridad de identidades](seguridad-identidades.md), [Seguridad de redes](seguridad-redes.md), [Seguridad de cifrado y secretos](seguridad-cifrado-secretos.md), [Seguridad de logging y detección](seguridad-logging-deteccion.md), [Seguridad serverless](seguridad-serverless.md) |
| DevOps (la automatización) | Construir imágenes, desplegar en Kubernetes, GitOps | [Docker](../../devops/contenedores/docker.md), [Kubernetes](../../devops/contenedores/kubernetes.md), [Despliegue continuo](../../devops/ci-cd/despliegue-continuo.md) |
| DevSecOps (la verificación) | RBAC, Pod Security, NetworkPolicy y admisión; escaneo y firma de imágenes; postura del clúster | [Seguridad de Kubernetes](../../devsecops/infraestructura-y-contenedores/seguridad-kubernetes.md), [Seguridad de contenedores](../../devsecops/infraestructura-y-contenedores/seguridad-contenedores.md), [Container scanning](../../devsecops/escaneos/container-scanning.md), [KSPM](../../devsecops/escaneos/kspm.md), [Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md), [CVE en contenedores y Kubernetes](../../devsecops/vulnerabilidades/cve-contenedores-kubernetes.md) |

## Referencias

- [Amazon EKS Best Practices Guide: Security](https://docs.aws.amazon.com/eks/latest/best-practices/security.html)
- [Grant IAM users access to Kubernetes with EKS access entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [Default envelope encryption for all Kubernetes API data (EKS)](https://docs.aws.amazon.com/eks/latest/userguide/envelope-encryption.html)
- [Security Hub CSPM: controles de Amazon EKS](https://docs.aws.amazon.com/securityhub/latest/userguide/eks-controls.html)
- [Amazon ECS security best practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/security.html)
- [Conceptos de seguridad de AKS](https://learn.microsoft.com/es-es/azure/aks/concepts-security)
- [Procedimientos recomendados de seguridad del clúster de AKS](https://learn.microsoft.com/es-es/azure/aks/operator-best-practices-cluster-security)
- [Microsoft Entra Workload ID con AKS](https://learn.microsoft.com/es-es/azure/aks/workload-identity-overview)
- [Recomendaciones de contenedores de Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/recommendations-reference-container)
- [Seguridad en Azure Container Apps](https://learn.microsoft.com/es-es/azure/container-apps/security)
- [Harden your GKE cluster's security](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
- [Workload Identity Federation for GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity)
- [Binary Authorization](https://cloud.google.com/binary-authorization/docs/overview)
- [Cloud Run security design overview](https://cloud.google.com/run/docs/securing/security)
- [CIS Benchmarks para EKS, AKS y GKE](https://www.cisecurity.org/benchmark/kubernetes)
