---
tags:
  - seguridad
  - cloud
  - aws
  - azure
  - gcp
  - bases-de-datos
---

# Seguridad de bases de datos gestionadas

> Controles para RDS/Aurora, Azure SQL Database y Azure Database for PostgreSQL/MySQL, Cloud SQL/AlloyDB y las NoSQL (DynamoDB, Cosmos DB, Firestore): sin acceso público, autenticación por identidad, TLS obligatorio, cifrado, backups protegidos contra borrado, auditoría, parches y deletion protection.

!!! info "Antes de leer"
    En una **managed database** (base de datos gestionada) el proveedor parchea el sistema operativo y el motor, hace los backups automáticos y opera la alta disponibilidad. Tú sigues siendo responsable de **quién se conecta, desde dónde, con qué credenciales, qué puede hacer y cuánto tiempo guardas las copias** (ver [Shared Responsibility Model](../fundamentos/responsabilidad-compartida.md)). Conviene haber leído [Almacenamiento y datos](../redes-y-datos/almacenamiento-datos.md) (servicios, réplicas, backups y PITR) y [Seguridad de redes](seguridad-redes.md).

## Riesgos típicos

| Riesgo | Ejemplo o incidente conocido | Control que lo evita |
| --- | --- | --- |
| Base de datos expuesta a internet | Oleadas de MongoDB/Elasticsearch abiertas y "secuestradas" (2017 en adelante); DeepSeek (2025): una base ClickHouse accesible sin autenticación con historiales de chat y claves | Sin IP pública, subnets privadas, private endpoints |
| Contraseña de administrador débil o compartida | Usuario `admin`/`postgres` con contraseña en el código o en un wiki | Autenticación con IAM / Entra ID, contraseña gestionada en el gestor de secretos con rotación |
| Tráfico sin cifrar | Aplicación que se conecta sin TLS dentro de la VPC | Forzar TLS en el servidor (parámetro o modo SSL) |
| Snapshot compartido o público | Snapshot manual de RDS marcado como público | Snapshots privados y cifrados con CMK, revisión de compartición |
| Borrado accidental o malicioso | `terraform destroy` en el workspace equivocado; atacante que borra la instancia **y** sus backups automáticos | Deletion protection, backups retenidos tras borrar, backups inmutables en otra cuenta |
| Reglas de acceso de cliente abiertas (NoSQL serverless) | Bases Firestore/Firebase con reglas `allow read, write: if true` | Firestore Security Rules revisadas, App Check, acceso solo por backend |
| Claves maestras de cuenta filtradas | Primary key de Cosmos DB en una cadena de conexión publicada | Desactivar *local authentication* y usar RBAC de data plane |
| Motor sin parches | Versión de motor al final de su soporte con CVEs conocidos | Auto minor version upgrade, ventanas de mantenimiento, seguimiento de fin de soporte |
| Abuso que nadie ve | Exfiltración lenta con un usuario legítimo | Logs de auditoría del motor + detección de amenazas |

## Controles por proveedor

**(I)** = imprescindible.

| Control | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| **(I)** Sin acceso público | RDS/Aurora `PubliclyAccessible = false` en subnets privadas; DynamoDB vía VPC endpoint | `publicNetworkAccess = Disabled` + **private endpoint** (Azure SQL, flexible server, Cosmos DB) | Cloud SQL / AlloyDB solo **IP privada** (Private Service Access o Private Service Connect); Organization Policy `sql.restrictPublicIp` |
| **(I)** Autenticación por identidad | **IAM database authentication** (RDS/Aurora); DynamoDB solo IAM | **Microsoft Entra authentication**, *Microsoft Entra-only authentication* en Azure SQL; Entra en flexible server; Cosmos DB con RBAC y `disableLocalAuth` | **IAM database authentication** (Cloud SQL, AlloyDB); Firestore con IAM (servidor) o Security Rules (clientes) |
| **(I)** Credencial del admin gestionada | `ManageMasterUserPassword` (Secrets Manager con rotación) | Admin de Entra; contraseñas en Key Vault | Contraseñas en Secret Manager; **IAM** para usuarios |
| **(I)** TLS obligatorio | `rds.force_ssl = 1` (PostgreSQL), `require_secure_transport = ON` (MySQL/MariaDB) | `minimalTlsVersion = 1.2` (Azure SQL), `require_secure_transport = ON` (flexible server), `minimalTlsVersion` en Cosmos DB | `sslMode = ENCRYPTED_ONLY` o `TRUSTED_CLIENT_CERTIFICATE_REQUIRED`; Cloud SQL Auth Proxy / conectores |
| **(I)** Cifrado en reposo | Activado por defecto en instancias nuevas; KMS con CMK (se elige al crear: no se puede cambiar después) | **TDE** (*Transparent Data Encryption*) por defecto; CMK en Key Vault | Cifrado por defecto; **CMEK** con Cloud KMS |
| **(I)** Backups y PITR | Backups automáticos + PITR; DynamoDB PITR | PITR automático (Azure SQL, flexible server); Cosmos DB *continuous backup* | Backups automáticos + PITR (Cloud SQL), *continuous backup* (AlloyDB), Firestore PITR |
| **(I)** Backups protegidos contra borrado | **AWS Backup Vault Lock**, *logically air-gapped vault*, copia entre cuentas | Immutable vaults y soft delete en Azure Backup; *long-term retention* | Backup and DR con **backup vaults** y retención forzada; retained backups tras borrar la instancia |
| **(I)** Deletion protection | `DeletionProtection` (RDS, Aurora, DynamoDB) | **Resource locks** (`CanNotDelete`) | `deletion_protection_enabled` (Cloud SQL), Firestore *delete protection* |
| Auditoría del motor | Logs a CloudWatch Logs, `pgaudit`, *Database Activity Streams* | **Azure SQL Auditing**, `pgaudit` en flexible server, diagnostic settings | Cloud Audit Logs + `pgaudit` (`cloudsql.enable_pgaudit`) |
| Detección de amenazas | GuardDuty RDS Protection | **Microsoft Defender for SQL**, Defender for open-source relational databases, Defender for Azure Cosmos DB | Security Command Center (Security Health Analytics, Event Threat Detection) |
| Parches del motor | Auto minor version upgrade, mantenimiento | Automático en Azure SQL; ventana de mantenimiento en flexible server | Mantenimiento automático con ventana y *deny period* |

## Buenas prácticas

1. **Nunca accesible desde internet.** La base vive en subnets privadas y solo acepta conexiones de las aplicaciones (security group / NSG referenciando al de la app, no rangos amplios). Para administración usa un bastión gestionado o el proxy del proveedor, no una IP pública. Ver [Seguridad de redes](seguridad-redes.md).
2. **Identidad en lugar de contraseñas.** Las aplicaciones se autentican con su rol o identidad gestionada y tokens de corta duración. Si el motor necesita contraseña, que la gestione el gestor de secretos con rotación automática. Ver [Cifrado y secretos](seguridad-cifrado-secretos.md).
3. **Usuarios con privilegios mínimos dentro del motor**: un usuario por aplicación con permisos solo sobre su esquema; el admin no se usa en la aplicación. El IAM de la nube no sustituye a los `GRANT` del motor.
4. **TLS forzado en el servidor**, no "opcional en el cliente".
5. **Cifrado con CMK** para datos sensibles, decidido **al crear** (en RDS no se puede cifrar una instancia existente sin restaurar desde un snapshot cifrado).
6. **Backups con dos capas**: PITR para errores de hoy y copias **inmutables en otra cuenta o suscripción** para el día que comprometan producción. Prueba restauraciones (ver [Resiliencia](../operacion-y-gobierno/resiliencia.md)).
7. **Deletion protection en producción** y en el código IaC; quitarla debe ser un cambio revisado.
8. **Auditoría a nivel motor** (quién consultó qué) enviada a la cuenta de logs central; vigila logins fallidos, cambios de privilegios y exportaciones masivas.
9. **Parches**: activa minor upgrades automáticos y planifica los major antes del fin de soporte.
10. **NoSQL**: desactiva claves maestras (Cosmos DB), revisa las reglas de cliente (Firestore) y aplica condiciones de IAM por clave de partición cuando varios usuarios comparten tabla (DynamoDB).

=== "AWS"

    - Crea la instancia con `publicly_accessible = false` y un *DB subnet group* solo con subnets privadas.
    - `iam_database_authentication_enabled = true` y el rol de la app con `rds-db:connect` sobre el usuario concreto.
    - `manage_master_user_password = true`: la contraseña del admin vive en Secrets Manager y rota sola.
    - Comparte snapshots solo con cuentas concretas y cifrados con una CMK que la otra cuenta pueda usar; nunca `all`.
    - DynamoDB: activa PITR y deletion protection; accede mediante un **gateway VPC endpoint** con política restrictiva.

=== "Azure"

    - Azure SQL: activa **Microsoft Entra-only authentication** (desactiva los logins SQL) con un grupo de Entra como administrador.
    - Flexible server: créalo con **private access (VNet integration)** o private endpoint; no habilites la regla "Allow public access from any Azure service".
    - Cosmos DB: `disableLocalAuth = true` y roles de data plane (`Cosmos DB Built-in Data Reader/Contributor`).
    - Bloquea con un **resource lock** `CanNotDelete` el servidor de producción y el vault de backups.
    - Activa **Defender for Cloud** con los planes de bases de datos que uses.

=== "Google Cloud"

    - Cloud SQL/AlloyDB solo con IP privada; impón `sql.restrictPublicIp` y `sql.restrictAuthorizedNetworks` en la organización.
    - Conecta con **Cloud SQL Auth Proxy** o los conectores de lenguaje: cifran con TLS y autorizan por IAM sin listas de IPs.
    - Activa el flag de IAM database authentication (`cloudsql.iam_authentication` en PostgreSQL) y crea usuarios IAM para service accounts.
    - `deletion_protection_enabled` en la instancia y retención de backups tras el borrado.
    - Firestore: escribe y prueba las **Security Rules** con el emulador antes de publicarlas; activa PITR y delete protection.

## Cómo verificarlo

=== "AWS"

    ```bash
    aws rds describe-db-instances --query "DBInstances[].{id:DBInstanceIdentifier, publica:PubliclyAccessible, cifrada:StorageEncrypted, iam:IAMDatabaseAuthenticationEnabled, borrado:DeletionProtection, backupDias:BackupRetentionPeriod, minorAuto:AutoMinorVersionUpgrade}" --output table

    # ¿Algún snapshot manual compartido con "all"?
    aws rds describe-db-snapshot-attributes --db-snapshot-identifier mi-snapshot

    # Parámetro de TLS (PostgreSQL)
    aws rds describe-db-parameters --db-parameter-group-name pg-prod --query "Parameters[?ParameterName=='rds.force_ssl']"

    # DynamoDB
    aws dynamodb describe-continuous-backups --table-name pedidos
    aws dynamodb describe-table --table-name pedidos --query "Table.{borrado:DeletionProtectionEnabled, sse:SSEDescription}"
    ```

=== "Azure"

    ```bash
    az sql server show -g rg-datos -n sql-prod --query "{publica:publicNetworkAccess, tls:minimalTlsVersion}"
    az sql server ad-only-auth get -g rg-datos -n sql-prod
    az sql server audit-policy show -g rg-datos -n sql-prod

    az postgres flexible-server show -g rg-datos -n pg-prod --query "{red:network, auth:authConfig, backup:backup}"
    az postgres flexible-server parameter show -g rg-datos -s pg-prod -n require_secure_transport --query value

    az cosmosdb show -g rg-datos -n cosmos-prod --query "{publica:publicNetworkAccess, sinClaves:disableLocalAuth, tls:minimalTlsVersion, backup:backupPolicy.type}"

    az lock list -g rg-datos -o table
    ```

=== "Google Cloud"

    ```bash
    gcloud sql instances describe sql-prod --format="yaml(settings.ipConfiguration, settings.backupConfiguration, settings.deletionProtectionEnabled, settings.databaseFlags, diskEncryptionConfiguration)"

    gcloud alloydb clusters describe alloy-prod --region=us-central1 --format="yaml(continuousBackupConfig, automatedBackupPolicy, encryptionConfig)"

    gcloud firestore databases describe --database="(default)" --format="yaml(pointInTimeRecoveryEnablement, deleteProtectionState)"
    ```

| Control | AWS Security Hub CSPM | Azure (MCSB / Azure Policy) | Security Command Center |
| --- | --- | --- | --- |
| Sin acceso público | **RDS.2**, RDS.46 | "Public network access on Azure SQL Database should be disabled", "Public network access should be disabled for PostgreSQL flexible servers", "Azure Cosmos DB should disable public network access" | `PUBLIC_SQL_INSTANCE`, `SQL_PUBLIC_IP`, `ALLOYDB_PUBLIC_IP` |
| Autenticación por identidad | RDS.10, RDS.12 | "Azure SQL Database should have Microsoft Entra-only authentication enabled", "A Microsoft Entra administrator should be provisioned for PostgreSQL flexible servers", "Cosmos DB database accounts should have local authentication methods disabled" | `SQL_NO_ROOT_PASSWORD`, `SQL_WEAK_ROOT_PASSWORD` |
| TLS | RDS.38, RDS.39, RDS.41 (por motor) | "Enforce SSL connection should be enabled for PostgreSQL flexible servers" | `SSL_NOT_ENFORCED`, `ALLOYDB_SSL_NOT_ENFORCED` |
| Cifrado | **RDS.3**, RDS.4, RDS.27 | "Transparent Data Encryption on SQL databases should be enabled" | `SQL_CMEK_DISABLED`, `ALLOYDB_CMEK_DISABLED` |
| Snapshots privados | **RDS.1** | — | — |
| Backups | RDS.11, RDS.26, DynamoDB.2, DynamoDB.4 | — | `AUTO_BACKUP_DISABLED`, `ALLOYDB_AUTO_BACKUP_DISABLED` |
| Deletion protection | RDS.7, RDS.8, DynamoDB.6 | — | — |
| Auditoría y logs | RDS.9, RDS.34, RDS.36, RDS.37 | "Auditing on SQL server should be enabled" | `SQL_LOG_CONNECTIONS_DISABLED`, `SQL_LOG_DISCONNECTIONS_DISABLED` y demás `SQL_LOG_*` |
| Parches | RDS.13, RDS.35 | — | — |

## Configuración segura con IaC

Los fragmentos de Terraform con estos controles (y los guardrails de organización, cuando aplican) están en las páginas por proveedor: [AWS](terraform/aws.md#bases-de-datos), [Azure](terraform/azure.md#bases-de-datos) y [Google Cloud](terraform/google-cloud.md#bases-de-datos).

!!! tip "Prueba los guardrails antes de imponerlos"
    Pon primero las políticas en modo auditoría (`Audit` en Azure Policy, *dry run* en Organization Policy) y revisa qué recursos fallarían. Un `Deny` repentino rompe pipelines que ya funcionaban.

## Errores comunes

- Abrir el puerto 5432/3306/1433 a `0.0.0.0/0` "para conectarme desde casa". Usa el proxy o un bastión.
- Activar IAM authentication pero dejar la aplicación usando el usuario admin con contraseña.
- Pensar que la réplica en otra región es un backup: replica también el `DROP TABLE`.
- Guardar los backups solo en la misma cuenta: si comprometen la cuenta, los borran junto con la base.
- Quitar `deletion_protection` en Terraform para un cambio y no volver a ponerla.
- Exportar un dump a un bucket sin las protecciones de [Seguridad del almacenamiento](seguridad-almacenamiento.md).
- Dejar Firestore en "modo de prueba" (reglas abiertas con caducidad) y pasar a producción así.
- Olvidar las bases de datos de *staging* con copias de datos reales de producción.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Servicios, réplicas, backups y PITR | [Almacenamiento y datos](../redes-y-datos/almacenamiento-datos.md), [Resiliencia](../operacion-y-gobierno/resiliencia.md) |
| Cloud (el control) | Red privada, identidades, claves y logs | [Seguridad de redes](seguridad-redes.md), [Seguridad de identidades](seguridad-identidades.md), [Cifrado y secretos](seguridad-cifrado-secretos.md), [Logging y detección](seguridad-logging-deteccion.md) |
| DevOps (la automatización) | Bases de datos como código y credenciales inyectadas en el despliegue | [Infrastructure as Code](../../devops/iac/infraestructura-como-codigo.md), [Despliegue continuo](../../devops/ci-cd/despliegue-continuo.md) |
| DevSecOps (la verificación) | Escanear la IaC y la postura; contraseñas en commits | [Seguridad de IaC](../../devsecops/infraestructura-y-contenedores/seguridad-iac.md), [CSPM](../../devsecops/escaneos/cspm.md), [Secretos e identidades](../../devsecops/identidades-y-pipeline/secretos-identidades.md) |
| DevSecOps (la verificación) | Inyección SQL desde la aplicación | [SAST](../../devsecops/escaneos/sast.md), [DAST](../../devsecops/escaneos/dast.md) |
| Networking (la base) | Segmentación y firewalls delante de la base | [Seguridad de red](../../networking/avanzado/seguridad-red.md) |

## Referencias

- [Security in Amazon RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.html)
- [IAM database authentication for RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html)
- [Security Hub CSPM controls for Amazon RDS](https://docs.aws.amazon.com/securityhub/latest/userguide/rds-controls.html)
- [Security Hub CSPM controls for DynamoDB](https://docs.aws.amazon.com/securityhub/latest/userguide/dynamodb-controls.html)
- [Azure SQL Database security best practices](https://learn.microsoft.com/azure/azure-sql/database/security-best-practice)
- [Microsoft Entra-only authentication with Azure SQL](https://learn.microsoft.com/azure/azure-sql/database/authentication-azure-ad-only-authentication)
- [Security in Azure Database for PostgreSQL flexible server](https://learn.microsoft.com/azure/postgresql/flexible-server/concepts-security)
- [Security considerations for Azure Cosmos DB](https://learn.microsoft.com/azure/cosmos-db/database-security)
- [Cloud SQL for PostgreSQL: security overview](https://cloud.google.com/sql/docs/postgres/security-overview)
- [Cloud SQL: IAM database authentication](https://cloud.google.com/sql/docs/postgres/iam-authentication)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Security Command Center: vulnerability findings](https://cloud.google.com/security-command-center/docs/concepts-vulnerabilities-findings)
