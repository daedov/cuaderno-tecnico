---
tags:
  - seguridad
  - cloud
  - aws
  - azure
  - gcp
  - almacenamiento
---

# Seguridad del almacenamiento de objetos

> Cómo blindar Amazon S3, Azure Blob Storage y Cloud Storage: bloqueo de acceso público desde la organización, adiós a las ACLs, cifrado, versionado e inmutabilidad, URLs firmadas con alcance corto, acceso privado, logs y detección de datos sensibles. Incluye snapshots y discos compartidos.

!!! info "Antes de leer"
    En el [Shared Responsibility Model](../fundamentos/responsabilidad-compartida.md) el proveedor garantiza la durabilidad y el cifrado físico, pero **quién puede leer tus objetos es 100 % tu responsabilidad**: políticas, ACLs, enlaces firmados y exposición de red. Conviene haber leído [Almacenamiento y datos](../redes-y-datos/almacenamiento-datos.md) (tipos de storage y clases). El cifrado con KMS, las claves y su rotación se tratan en [Cifrado y secretos](seguridad-cifrado-secretos.md).

## Riesgos típicos

El **object storage** (almacenamiento de objetos) es el lugar donde más datos se filtran en la nube, casi siempre por una mala configuración y no por un fallo del proveedor.

| Riesgo | Ejemplo o incidente conocido | Control que lo evita |
| --- | --- | --- |
| Bucket o contenedor público por error | Cientos de filtraciones de buckets S3 "abiertos" entre 2017 y 2020 (bases de clientes, backups, logs) | Bloqueo de acceso público **a nivel cuenta u organización** |
| Token de acceso demasiado amplio y sin caducidad | Microsoft AI Research (2023): un **SAS** (*Shared Access Signature*) publicado en GitHub daba acceso a toda una storage account (38 TB) con permisos de escritura y caducidad lejana | SAS con alcance mínimo y expiración corta, *user delegation SAS*, desactivar *shared key* |
| Credenciales robadas que leen los datos | Capital One (2019): un SSRF obtuvo credenciales de un rol con permisos de lectura amplios sobre S3 | Least privilege en roles, IMDSv2, acceso privado + condiciones de red en la política |
| Borrado o cifrado malicioso (*ransomware*) | Atacante con permisos borra objetos y versiones | Versioning, soft delete, Object Lock / immutable storage, copia en otra cuenta |
| ACLs heredadas que nadie revisa | Objeto con ACL `public-read` dentro de un bucket "privado" | Desactivar ACLs: S3 Object Ownership, Uniform bucket-level access |
| Snapshot o imagen de disco compartida públicamente | Snapshots de EBS y de RDS marcados como públicos con datos de producción | Block public access para snapshots, revisar permisos de compartición |
| Datos sensibles donde no deberían estar | PII en un bucket de logs o de analítica | Clasificación automática: Amazon Macie, Defender for Storage, Sensitive Data Protection |
| Tráfico sin cifrar o desde redes no confiables | Peticiones HTTP planas, acceso desde cualquier IP | TLS obligatorio, private endpoints, firewall de la storage account |

## Controles por proveedor

Los marcados con **(I)** son imprescindibles en cualquier entorno.

| Control | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| **(I)** Bloquear acceso público | S3 Block Public Access a nivel **cuenta** (y bucket) | *Allow Blob anonymous access* = deshabilitado (`allowBlobPublicAccess`) | **Public access prevention** (`enforced`) + Organization Policy `storage.publicAccessPrevention` |
| **(I)** Desactivar ACLs | S3 Object Ownership = *Bucket owner enforced* | No hay ACLs por objeto; control con Azure RBAC | **Uniform bucket-level access** + Organization Policy `storage.uniformBucketLevelAccess` |
| **(I)** Autenticación por identidad | IAM + bucket policy | Microsoft Entra ID + RBAC; **desactivar Shared Key** (`allowSharedKeyAccess = false`) | IAM (sin claves HMAC salvo necesidad) |
| **(I)** Cifrado en reposo | SSE-S3 por defecto; SSE-KMS con *customer managed key* para datos sensibles | Cifrado por defecto (Microsoft-managed keys); *customer-managed keys* en Key Vault; *infrastructure encryption* | Cifrado por defecto; **CMEK** con Cloud KMS |
| **(I)** TLS obligatorio | Bucket policy con `aws:SecureTransport = false` → Deny | *Secure transfer required* + `minimumTlsVersion = TLS1_2` | HTTPS en las APIs (TLS siempre) |
| **(I)** Versionado y recuperación | S3 Versioning (+ MFA delete opcional) | Blob versioning, soft delete de blobs y de contenedores | Object Versioning, **soft delete** (activo por defecto, 7 días) |
| Inmutabilidad (WORM) | **S3 Object Lock** (Governance / Compliance) | **Immutable storage** (time-based retention, legal hold; bloqueo de la política) | **Bucket Lock** (retention policy bloqueada), Object Retention Lock |
| URLs firmadas | Presigned URLs (SigV4, máx. 7 días) | SAS: preferir **user delegation SAS** (firmado con Entra ID), *stored access policies* | Signed URLs (V4, máx. 7 días) |
| Acceso privado | Gateway / Interface VPC endpoint + condición `aws:SourceVpce` | **Private endpoint** + `publicNetworkAccess = Disabled` o firewall de la storage account | Private Google Access, **VPC Service Controls** |
| Logs de acceso | CloudTrail **data events** para S3, S3 server access logs | Diagnostic settings (StorageRead/Write/Delete) | Cloud Audit Logs **Data Access** para Cloud Storage, usage logs |
| Datos sensibles y amenazas | **Amazon Macie**, GuardDuty S3 Protection, GuardDuty Malware Protection for S3 | **Microsoft Defender for Storage** (actividad, malware scanning, sensitive data threat detection) | **Sensitive Data Protection** (antes Cloud DLP), Security Command Center |
| Snapshots | **Block public access for EBS snapshots**; snapshots de RDS privados | Snapshots de Managed Disks con acceso por SAS deshabilitado; *disk access* privado | Snapshots e imágenes sin `allUsers`/`allAuthenticatedUsers` |

!!! note "Valores por defecto que ya ayudan"
    Desde 2023 los buckets nuevos de S3 se crean con Block Public Access activo y ACLs desactivadas; las storage accounts nuevas de Azure no permiten acceso anónimo por defecto; y Cloud Storage aplica public access prevention cuando lo exige la política de la organización. **Los recursos antiguos no cambian solos**: revísalos.

## Buenas prácticas

Lista priorizada; empieza por arriba.

1. **Bloquea el acceso público desde lo más alto**: cuenta, organización o política, no bucket por bucket. Si necesitas contenido público (una web estática), sírvelo a través de una CDN con identidad propia (CloudFront con *Origin Access Control*, Azure Front Door con Private Link, Cloud CDN con backend bucket) y deja el bucket privado.
2. **Desactiva ACLs y claves compartidas**. El acceso se concede por identidad (IAM / RBAC) y en un solo sitio.
3. **Least privilege por bucket o contenedor**: un rol por aplicación con acceso solo a su prefijo. Nada de `s3:*` ni de `Storage Blob Data Owner` a nivel suscripción. Ver [Seguridad de identidades](seguridad-identidades.md).
4. **Cifra con claves propias los datos sensibles**. La clave por defecto cifra, pero con CMK controlas quién puede descifrar (la key policy es una segunda barrera) y puedes revocar.
5. **Versionado + soft delete siempre**; **inmutabilidad** para backups, logs de auditoría y datos regulados. Con modo *Compliance* / política bloqueada ni siquiera un administrador puede borrar antes de tiempo: pruébalo primero en un bucket de prueba.
6. **URLs firmadas cortas y acotadas**: un objeto, un verbo, minutos u horas. Nunca SAS de cuenta con caducidad de años.
7. **Acceso privado** desde las cargas de trabajo y política que rechace peticiones que no lleguen por tu red cuando aplique.
8. **Logs de acceso a datos** en buckets sensibles (son caros en buckets de mucho tráfico: actívalos de forma selectiva) y envíalos a la cuenta de logs centralizada. Ver [Logging y detección](seguridad-logging-deteccion.md).
9. **Descubre y clasifica** datos sensibles de forma periódica.
10. **Revisa snapshots, imágenes y discos compartidos** igual que los buckets.

=== "AWS"

    - Activa **S3 Block Public Access** en la cuenta y protégelo con una SCP que deniegue `s3:PutAccountPublicAccessBlock` a todos salvo al rol de plataforma.
    - Usa **IAM Access Analyzer** para encontrar buckets compartidos con cuentas externas o públicos.
    - Para acceso entre cuentas, prefiere **S3 Access Points** o condiciones `aws:PrincipalOrgID` en la bucket policy.
    - Con SSE-KMS activa **S3 Bucket Keys** para reducir llamadas (y costo) a KMS.
    - Los presigned URLs heredan los permisos de quien los firma y caducan antes si las credenciales temporales caducan antes.

=== "Azure"

    - En la storage account: `allowBlobPublicAccess = false`, `allowSharedKeyAccess = false`, `minimumTlsVersion = TLS1_2`, `publicNetworkAccess = Disabled` (o firewall con `defaultAction = Deny`).
    - Asigna roles de **data plane** (`Storage Blob Data Reader` / `Contributor`) a nivel contenedor, no a nivel suscripción.
    - Si necesitas SAS, que sea **user delegation SAS**; sin Shared Key no se pueden firmar SAS de cuenta ni de servicio.
    - Activa **Microsoft Defender for Storage** en la suscripción (incluye malware scanning bajo demanda o al subir).
    - Asigna las políticas integradas "Storage account public access should be disallowed" y "Storage accounts should prevent shared key access" con efecto `Deny`.

=== "Google Cloud"

    - Aplica en la organización las restricciones `storage.publicAccessPrevention` y `storage.uniformBucketLevelAccess`.
    - Concede roles a nivel bucket (`roles/storage.objectViewer`) y evita los roles básicos (`Owner`/`Editor`) a nivel proyecto.
    - Protege los buckets con datos de **VPC Service Controls** para impedir la exfiltración aunque se roben credenciales.
    - Evita las claves HMAC; si una herramienta las exige, asócialas a una service account con permisos mínimos.
    - Usa **Bucket Lock** solo cuando la retención sea definitiva: una retention policy bloqueada no se puede reducir ni quitar.

!!! danger "Snapshots y discos: el bucket que nadie mira"
    Un snapshot público de EBS o de RDS, una imagen compartida o un disco exportado con un SAS vigente exponen el disco entero. Activa el bloqueo de acceso público para snapshots de EBS, revisa con Access Analyzer qué está compartido y, en Azure, deshabilita el acceso a discos por SAS (*network access policy*) cuando no se use.

## Cómo verificarlo

Todos los comandos son **de solo lectura**.

=== "AWS"

    ```bash
    # Block Public Access a nivel cuenta y a nivel bucket
    aws s3control get-public-access-block --account-id 123456789012
    aws s3api get-public-access-block --bucket mi-bucket

    # ACLs desactivadas (debe decir BucketOwnerEnforced)
    aws s3api get-bucket-ownership-controls --bucket mi-bucket

    # ¿La política hace público el bucket?
    aws s3api get-bucket-policy-status --bucket mi-bucket

    # Cifrado, versionado, Object Lock y logs
    aws s3api get-bucket-encryption --bucket mi-bucket
    aws s3api get-bucket-versioning --bucket mi-bucket
    aws s3api get-object-lock-configuration --bucket mi-bucket
    aws s3api get-bucket-logging --bucket mi-bucket

    # Snapshots de EBS
    aws ec2 get-snapshot-block-public-access-state
    ```

=== "Azure"

    ```bash
    az storage account show -n mistorage -g rg-datos --query "{anonimo:allowBlobPublicAccess, sharedKey:allowSharedKeyAccess, https:enableHttpsTrafficOnly, tls:minimumTlsVersion, red:publicNetworkAccess, firewall:networkRuleSet.defaultAction}"

    az storage account blob-service-properties show --account-name mistorage -g rg-datos --query "{versionado:isVersioningEnabled, softDelete:deleteRetentionPolicy, softDeleteContenedores:containerDeleteRetentionPolicy}"

    # Plan de Defender for Storage en la suscripción
    az security pricing show -n StorageAccounts
    ```

=== "Google Cloud"

    ```bash
    gcloud storage buckets describe gs://mi-bucket --format="yaml(public_access_prevention, uniform_bucket_level_access, versioning_enabled, default_kms_key, retention_policy, soft_delete_policy, logging_config)"

    # ¿Hay allUsers o allAuthenticatedUsers en la política?
    gcloud storage buckets get-iam-policy gs://mi-bucket --format=json | grep -E "allUsers|allAuthenticatedUsers"

    # Restricciones de la organización aplicadas al proyecto
    gcloud org-policies describe storage.publicAccessPrevention --project=mi-proyecto --effective
    ```

Checks de CSPM y benchmarks que cubren los controles imprescindibles:

| Control | AWS Security Hub CSPM (FSBP / CIS) | Azure (MCSB / Azure Policy) | Security Command Center |
| --- | --- | --- | --- |
| Acceso público | **S3.1** (cuenta), **S3.8** (bucket), S3.2 / S3.3 (lectura / escritura pública) | "Storage account public access should be disallowed" | `PUBLIC_BUCKET_ACL` |
| ACLs | **S3.12** | — | `BUCKET_POLICY_ONLY_DISABLED` (uniform bucket-level access) |
| TLS | **S3.5** | "Secure transfer to storage accounts should be enabled" | — |
| Shared Key / acceso por identidad | — | "Storage accounts should prevent shared key access" | — |
| Red | — | "Storage accounts should restrict network access", "Storage accounts should disable public network access" | — |
| Cifrado con CMK | S3.17 | — (recomendación de CMK según el estándar) | `BUCKET_CMEK_DISABLED` |
| Versionado e inmutabilidad | S3.14, S3.15 | — | `OBJECT_VERSIONING_DISABLED`, `LOCKED_RETENTION_POLICY_NOT_SET` (logs) |
| Logs | S3.9, S3.22 / S3.23 (data events) | — | `BUCKET_LOGGING_DISABLED` |
| Snapshots | **EC2.1**, EC2.182, RDS.1 | — | — |

Para correr estos checks fuera del portal (Prowler, Steampipe) ver [CSPM](../../devsecops/escaneos/cspm.md).

## Configuración segura con IaC

Los fragmentos de Terraform con estos controles (y los guardrails de organización, cuando aplican) están en las páginas por proveedor: [AWS](terraform/aws.md#almacenamiento-de-objetos), [Azure](terraform/azure.md#almacenamiento-de-objetos) y [Google Cloud](terraform/google-cloud.md#almacenamiento-de-objetos).

Antes de aplicar, pasa los planes por un escáner de IaC (Checkov, Trivy) para detectar buckets sin cifrado o públicos: ver [Seguridad de IaC](../../devsecops/infraestructura-y-contenedores/seguridad-iac.md).

## Errores comunes

- Desactivar Block Public Access "un momento" para probar algo y olvidarlo. Usa una CDN o un presigned URL en lugar de abrir el bucket.
- Creer que "privado" significa "seguro": un rol con `s3:GetObject` sobre `*` lee todos los buckets de la cuenta.
- Generar SAS de cuenta con todos los permisos y caducidad de años, y pegarlos en código, wikis o tickets.
- Activar versionado sin reglas de **lifecycle** para las versiones antiguas: el costo crece sin control (ver [FinOps y costos](../fundamentos/finops-costos.md)).
- Activar Object Lock en modo Compliance o bloquear una retention policy sin probar: no se puede deshacer.
- Guardar los logs de acceso en el mismo bucket o en la misma cuenta que vigilan.
- Revisar buckets pero olvidar snapshots, imágenes y backups exportados.
- Cifrar con CMK y dar `kms:Decrypt` a todo el mundo en la key policy: el cifrado deja de ser una barrera.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Tipos de storage, clases, replicación y backups | [Almacenamiento y datos](../redes-y-datos/almacenamiento-datos.md) |
| Cloud (el control) | Claves, cifrado y guardrails de la organización | [Cifrado y secretos](seguridad-cifrado-secretos.md), [Gobernanza](../operacion-y-gobierno/gobernanza.md) |
| Cloud (el control) | Resto del bloque de seguridad | [Fundamentos de seguridad cloud](fundamentos-seguridad-cloud.md), [Seguridad de identidades](seguridad-identidades.md), [Seguridad de redes](seguridad-redes.md), [Seguridad de bases de datos](seguridad-bases-datos.md) |
| DevOps (la automatización) | Buckets definidos como código con valores seguros | [Infrastructure as Code](../../devops/iac/infraestructura-como-codigo.md), [Terraform básico](../../devops/iac/terraform-basico.md) |
| DevSecOps (la verificación) | Detectar buckets públicos y sin cifrar antes y después del despliegue | [Seguridad de IaC](../../devsecops/infraestructura-y-contenedores/seguridad-iac.md), [CSPM](../../devsecops/escaneos/cspm.md), [Cumplimiento](../../devsecops/gobierno-y-respuesta/cumplimiento.md) |
| DevSecOps (la verificación) | Tokens SAS y claves filtrados en repositorios | [Secret scanning](../../devsecops/escaneos/secret-scanning.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 16: Auditar tu cuenta cloud con Prowler (CSPM)](../../laboratorios/devsecops/cspm-prowler.md) |

## Referencias

- [Security best practices for Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [Blocking public access to your Amazon S3 storage](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html)
- [Security Hub CSPM controls for Amazon S3](https://docs.aws.amazon.com/securityhub/latest/userguide/s3-controls.html)
- [Azure security baseline for Storage](https://learn.microsoft.com/security/benchmark/azure/baselines/storage-security-baseline)
- [Security recommendations for Blob storage](https://learn.microsoft.com/azure/storage/blobs/security-recommendations)
- [Prevent Shared Key authorization for an Azure Storage account](https://learn.microsoft.com/azure/storage/common/shared-key-authorization-prevent)
- [Overview of Microsoft Defender for Storage](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-storage-introduction)
- [Cloud Storage: Public access prevention](https://cloud.google.com/storage/docs/public-access-prevention)
- [Cloud Storage: Uniform bucket-level access](https://cloud.google.com/storage/docs/uniform-bucket-level-access)
- [Cloud Storage: Bucket Lock](https://cloud.google.com/storage/docs/bucket-lock)
- [Security Command Center: vulnerability findings](https://cloud.google.com/security-command-center/docs/concepts-vulnerabilities-findings)
- [CIS Benchmarks (AWS, Azure y Google Cloud Foundations)](https://www.cisecurity.org/cis-benchmarks)
