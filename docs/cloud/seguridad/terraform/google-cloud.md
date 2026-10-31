---
tags:
  - cloud
  - seguridad
  - terraform
  - iac
---

# Terraform seguro en Google Cloud

> Fragmentos de Terraform con los controles de seguridad de cada nota de [Seguridad en la nube](../fundamentos-seguridad-cloud.md), ordenados igual que el bloque. La explicación de cada control (por qué y cómo verificarlo) está en su nota; aquí solo el código.

!!! note "Versión del provider"
    Los fragmentos usan `hashicorp/google` 8.x (la versión mayor vigente en octubre de 2026). Fija la versión con `~>` y pasa `terraform validate` y `terraform plan` antes de aplicar. Si vienes de una versión anterior, revisa la *upgrade guide* del provider. Por ejemplo, en google 7 `google_compute_subnetwork` perdió `enable_flow_logs` en favor de `log_config`.

    ```hcl title="versions.tf"
    terraform {
      required_providers {
        google  = { source = "hashicorp/google", version = "~> 8.0" }
      }
    }
    ```

Antes de aplicar, pasa el plan por un escáner de IaC (Checkov, Trivy): ver [IaC scanning](../../../devsecops/escaneos/iac-scanning.md). Equivalentes en los otros proveedores: [AWS](aws.md), [Azure](azure.md).

## Base de seguridad

Controles explicados en [Fundamentos de seguridad en la nube](../fundamentos-seguridad-cloud.md).

```hcl title="org-policies.tf"
# Secure-by-default: aplicar a mano en organizaciones anteriores a mayo de 2024
locals {
  constraints_booleanas = [
    "iam.managed.disableServiceAccountKeyCreation",
    "iam.disableServiceAccountKeyUpload",
    "iam.automaticIamGrantsForDefaultServiceAccounts",
    "storage.uniformBucketLevelAccess",
  ]
}

resource "google_org_policy_policy" "baseline" {
  for_each = toset(local.constraints_booleanas)
  name     = "organizations/${var.org_id}/policies/${each.value}"
  parent   = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
```

## Identidades

Controles explicados en [Seguridad de identidades](../seguridad-identidades.md).

```hcl title="identidades.tf"
# Solo identidades del dominio de la organización
resource "google_org_policy_policy" "dominios" {
  name   = "organizations/${var.org_id}/policies/iam.allowedPolicyMemberDomains"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        allowed_values = [var.customer_id] # ID de cliente de Cloud Identity, p. ej. C0xxxxxxx
      }
    }
  }
}

# Sin service account keys
resource "google_org_policy_policy" "sin_keys" {
  name   = "organizations/${var.org_id}/policies/iam.managed.disableServiceAccountKeyCreation"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# Service account propia de la aplicación con un rol predefinido acotado
resource "google_service_account" "api" {
  project      = var.project_id
  account_id   = "api-pagos"
  display_name = "API de pagos (prod)"
}

resource "google_project_iam_member" "api_secretos" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.api.email}"
}
```

## Cifrado, claves y secretos

Controles explicados en [Seguridad de cifrado, claves y secretos](../seguridad-cifrado-secretos.md).

```hcl title="kms-secretos.tf"
resource "google_kms_key_ring" "pagos" {
  project  = var.kms_project_id
  name     = "pagos-prod"
  location = "us-central1"
}

resource "google_kms_crypto_key" "datos" {
  name                       = "datos"
  key_ring                   = google_kms_key_ring.pagos.id
  rotation_period            = "7776000s" # 90 días
  destroy_scheduled_duration = "2592000s" # 30 días

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "HSM"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Solo el service agent de Cloud Storage del proyecto de la app puede usar la clave
resource "google_kms_crypto_key_iam_member" "gcs" {
  crypto_key_id = google_kms_crypto_key.datos.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.app_project_number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_secret_manager_secret" "api_externa" {
  project   = var.app_project_id
  secret_id = "api-externa"

  replication {
    auto {}
  }

  rotation {
    rotation_period    = "2592000s"
    next_rotation_time = "2026-12-01T00:00:00Z"
  }

  topics {
    name = google_pubsub_topic.rotacion.id
  }
}

# Guardrail: Cloud Storage solo con CMEK en la carpeta de producción
resource "google_org_policy_policy" "cmek" {
  name   = "folders/${var.folder_prod_id}/policies/gcp.restrictNonCmekServices"
  parent = "folders/${var.folder_prod_id}"

  spec {
    rules {
      values {
        denied_values = ["storage.googleapis.com"]
      }
    }
  }
}
```

## Logging y detección

Controles explicados en [Seguridad de logging y detección](../seguridad-logging-deteccion.md).

```hcl title="logging.tf"
# Log bucket central con retención bloqueada (irreversible)
resource "google_logging_project_bucket_config" "auditoria" {
  project        = var.logging_project_id
  location       = "global"
  bucket_id      = "auditoria-org"
  retention_days = 400
  locked         = true
}

# Aggregated sink: audit logs de toda la organización
resource "google_logging_organization_sink" "auditoria" {
  name             = "auditoria-org"
  org_id           = var.org_id
  include_children = true
  destination      = "logging.googleapis.com/${google_logging_project_bucket_config.auditoria.id}"
  filter           = "logName:\"cloudaudit.googleapis.com\""
}

resource "google_project_iam_member" "sink_writer" {
  project = var.logging_project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_organization_sink.auditoria.writer_identity
}

# Data Access logs selectivos: solo secretos y claves
resource "google_organization_iam_audit_config" "secretos" {
  for_each = toset(["secretmanager.googleapis.com", "cloudkms.googleapis.com"])
  org_id   = var.org_id
  service  = each.value

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

# Alerta CIS: cambios en la configuración de auditoría
resource "google_monitoring_alert_policy" "audit_config" {
  project      = var.security_project_id
  display_name = "Cambio en audit config"
  combiner     = "OR"

  conditions {
    display_name = "SetIamPolicy con auditConfigDeltas"
    condition_matched_log {
      filter = "protoPayload.methodName=\"SetIamPolicy\" AND protoPayload.serviceData.policyDelta.auditConfigDeltas:*"
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
  }

  notification_channels = [google_monitoring_notification_channel.seguridad.id]
}
```

Una **log-based alert** solo ve los logs del proyecto donde se define (o los que le lleguen por sink): defínela en el proyecto central o usa un *log scope* que cubra los proyectos que quieres vigilar.

## Redes

Controles explicados en [Seguridad de redes en la nube](../seguridad-redes.md).

```hcl title="red-segura.tf"
resource "google_compute_subnetwork" "app" {
  name                     = "snet-app"
  region                   = var.region
  network                  = google_compute_network.main.id
  ip_cidr_range            = "10.20.1.0/24"
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# SSH solo desde el rango de IAP y solo a VMs con la etiqueta
resource "google_compute_firewall" "ssh_desde_iap" {
  name          = "allow-ssh-from-iap"
  network       = google_compute_network.main.id
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["ssh-iap"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
```

### Guardrails de organización: redes

```hcl title="org-policy-red.tf"
resource "google_org_policy_policy" "skip_default_network" {
  name   = "organizations/${var.org_id}/policies/compute.skipDefaultNetworkCreation"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
```

## Máquinas virtuales

Controles explicados en [Seguridad de máquinas virtuales](../seguridad-maquinas-virtuales.md).

```hcl title="vm-segura.tf"
resource "google_compute_instance" "app" {
  name         = "vm-app-01"
  zone         = var.zone
  machine_type = "e2-standard-2"
  tags         = ["ssh-iap"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  # Sin bloque access_config = sin IP externa
  network_interface {
    subnetwork = google_compute_subnetwork.app.id
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.app.email # dedicada, no la default
    scopes = ["cloud-platform"]               # los permisos los decide IAM
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
    serial-port-enable     = "FALSE"
  }
}
```

### Guardrails de organización: máquinas virtuales

```hcl title="org-policy-vm.tf"
resource "google_org_policy_policy" "sin_ip_externa" {
  name   = "organizations/${var.org_id}/policies/compute.vmExternalIpAccess"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      deny_all = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "shielded_vm" {
  name   = "organizations/${var.org_id}/policies/compute.requireShieldedVm"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
```

## Contenedores y Kubernetes

Controles explicados en [Seguridad de contenedores y Kubernetes gestionado](../seguridad-contenedores-kubernetes.md).

```hcl title="gke-seguro.tf"
resource "google_container_cluster" "main" {
  name                     = "plataforma"
  location                 = var.region
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = true
  datapath_provider        = "ADVANCED_DATAPATH" # Dataplane V2: network policies

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.30.0.0/24"
      display_name = "red-de-operaciones"
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.gke.id
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }
}

resource "google_container_node_pool" "app" {
  name       = "app"
  cluster    = google_container_cluster.main.id
  node_count = 2

  management {
    auto_upgrade = true
    auto_repair  = true
  }

  node_config {
    machine_type    = "e2-standard-4"
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}
```

### Guardrails de organización: contenedores y Kubernetes

```hcl title="org-policy-cloud-run.tf"
# Cloud Run: solo ingress interno o a través de load balancer
resource "google_org_policy_policy" "run_ingress" {
  name   = "organizations/${var.org_id}/policies/run.allowedIngress"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        allowed_values = ["internal", "internal-and-cloud-load-balancing"]
      }
    }
  }
}
```

## Serverless

Controles explicados en [Seguridad serverless](../seguridad-serverless.md).

```hcl title="function-segura.tf"
resource "google_cloudfunctions2_function" "pagos" {
  name     = "pagos-api"
  location = var.region

  build_config {
    runtime         = "python312"
    entry_point     = "handler"
    service_account = google_service_account.build.id

    source {
      storage_source {
        bucket = var.source_bucket
        object = var.source_object
      }
    }
  }

  service_config {
    service_account_email         = google_service_account.pagos.email
    ingress_settings              = "ALLOW_INTERNAL_AND_GCLB"
    max_instance_count            = 20
    vpc_connector                 = google_vpc_access_connector.main.id
    vpc_connector_egress_settings = "ALL_TRAFFIC"

    secret_environment_variables {
      key        = "DB_PASSWORD"
      project_id = var.project_id
      secret     = google_secret_manager_secret.db.secret_id
      version    = "3"
    }
  }
}

# Solo el servicio llamador puede invocar la función
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  location = var.region
  name     = google_cloudfunctions2_function.pagos.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.caller.email}"
}
```

### Guardrails de organización: serverless

```hcl title="org-policy-funciones.tf"
# Ninguna función nueva con ingress abierto a todo internet
resource "google_org_policy_policy" "functions_ingress" {
  name   = "organizations/${var.org_id}/policies/cloudfunctions.allowedIngressSettings"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        allowed_values = ["ALLOW_INTERNAL_ONLY", "ALLOW_INTERNAL_AND_GCLB"]
      }
    }
  }
}

# Impide conceder permisos a allUsers / allAuthenticatedUsers
resource "google_org_policy_policy" "dominios_permitidos" {
  name   = "organizations/${var.org_id}/policies/iam.allowedPolicyMemberDomains"
  parent = "organizations/${var.org_id}"

  spec {
    rules {
      values {
        allowed_values = [var.customer_id] # ID de cliente de Cloud Identity / Workspace
      }
    }
  }
}
```

## Almacenamiento de objetos

Controles explicados en [Seguridad del almacenamiento de objetos](../seguridad-almacenamiento.md).

```hcl title="gcs.tf"
resource "google_storage_bucket" "datos" {
  name     = "acme-datos-prod"
  location = "US-CENTRAL1"

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.datos.id
  }

  soft_delete_policy {
    retention_duration_seconds = 2592000 # 30 días
  }

  logging {
    log_bucket = google_storage_bucket.logs.name
  }
}
```

### Guardrails de organización: almacenamiento de objetos

```hcl title="org-policy.tf"
resource "google_org_policy_policy" "public_access_prevention" {
  name   = "organizations/${var.org_id}/policies/storage.publicAccessPrevention"
  parent = "organizations/${var.org_id}"
  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "uniform_access" {
  name   = "organizations/${var.org_id}/policies/storage.uniformBucketLevelAccess"
  parent = "organizations/${var.org_id}"
  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
```

## Bases de datos

Controles explicados en [Seguridad de bases de datos gestionadas](../seguridad-bases-datos.md).

```hcl title="cloudsql.tf"
resource "google_sql_database_instance" "pedidos" {
  name                = "pedidos-prod"
  database_version    = "POSTGRES_17"
  region              = "us-central1"
  encryption_key_name = google_kms_crypto_key.datos.id
  deletion_protection = true # protección en Terraform

  settings {
    tier                        = "db-custom-2-7680"
    availability_type           = "REGIONAL"
    deletion_protection_enabled = true # protección en la API

    ip_configuration {
      ipv4_enabled    = false # sin IP pública
      private_network = google_compute_network.vpc.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }
  }
}
```

### Guardrails de organización: bases de datos

```hcl title="org-policy-sql.tf"
resource "google_org_policy_policy" "sql_sin_ip_publica" {
  name   = "organizations/${var.org_id}/policies/sql.restrictPublicIp"
  parent = "organizations/${var.org_id}"
  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
```

## APIs y aplicaciones

Controles explicados en [Seguridad de APIs y aplicaciones expuestas](../seguridad-apis-aplicaciones.md).

API Gateway con JWT de Identity Platform en la especificación OpenAPI 2.0:

```yaml title="openapi-pedidos.yaml"
swagger: "2.0"
info:
  title: pedidos
  version: "1.0.0"
schemes:
  - https
produces:
  - application/json
securityDefinitions:
  identity_platform:
    authorizationUrl: ""
    flow: implicit
    type: oauth2
    x-google-issuer: "https://securetoken.google.com/mi-proyecto"
    x-google-jwks_uri: "https://www.googleapis.com/service_accounts/v1/metadata/x509/securetoken@system.gserviceaccount.com"
    x-google-audiences: "mi-proyecto"
paths:
  /pedidos:
    get:
      operationId: listarPedidos
      x-google-backend:
        address: https://pedidos-abc123-uc.a.run.app
      security:
        - identity_platform: []
      responses:
        "200":
          description: OK
```

Cloud Armor delante del load balancer (Apigee o cualquier backend):

```hcl title="cloud-armor.tf"
resource "google_compute_security_policy" "api" {
  name = "api-waf"

  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Regla por defecto"
  }
}
```

## Servicios de IA generativa

Controles explicados en [Seguridad de servicios de IA generativa](../seguridad-servicios-ia.md).

```hcl title="vpc-sc.tf"
resource "google_access_context_manager_service_perimeter" "ia" {
  parent = "accessPolicies/${var.access_policy_id}"
  name   = "accessPolicies/${var.access_policy_id}/servicePerimeters/ia_prod"
  title  = "ia_prod"

  status {
    resources = ["projects/${var.project_number}"]
    restricted_services = [
      "aiplatform.googleapis.com",
      "storage.googleapis.com",
      "bigquery.googleapis.com",
    ]
  }
}
```

Pon el perímetro primero en modo *dry run* (bloque `spec` con `use_explicit_dry_run_spec = true`) y revisa las violaciones en los logs antes de aplicarlo.
