---
tags:
  - cloud
  - seguridad
  - terraform
  - iac
---

# Terraform seguro en Azure

> Fragmentos de Terraform con los controles de seguridad de cada nota de [Seguridad en la nube](../fundamentos-seguridad-cloud.md), ordenados igual que el bloque. La explicación de cada control (por qué y cómo verificarlo) está en su nota; aquí solo el código.

!!! note "Versión del provider"
    Los fragmentos usan `hashicorp/azurerm` 5.x (la versión mayor vigente en octubre de 2026). Fija la versión con `~>` y pasa `terraform validate` y `terraform plan` antes de aplicar. Si vienes de una versión anterior, revisa la *upgrade guide* del provider. Por ejemplo, en azurerm 5 `azurerm_network_watcher_flow_log` ya solo acepta `target_resource_id`.

    ```hcl title="versions.tf"
    terraform {
      required_providers {
        azurerm = { source = "hashicorp/azurerm", version = "~> 5.0" }
      }
    }
    ```

Antes de aplicar, pasa el plan por un escáner de IaC (Checkov, Trivy): ver [IaC scanning](../../../devsecops/escaneos/iac-scanning.md). Equivalentes en los otros proveedores: [AWS](aws.md), [Google Cloud](google-cloud.md).

## Base de seguridad

Controles explicados en [Fundamentos de seguridad en la nube](../fundamentos-seguridad-cloud.md).

```hcl title="defender.tf"
# Defender CSPM y Defender for Servers en la suscripción
resource "azurerm_security_center_subscription_pricing" "cspm" {
  tier          = "Standard"
  resource_type = "CloudPosture"
}

resource "azurerm_security_center_subscription_pricing" "servers" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
  subplan       = "P2"
}

resource "azurerm_security_center_contact" "seguridad" {
  name                = "default"
  email               = "seguridad@ejemplo.com"
  alert_notifications = true
  alerts_to_admins    = true
}
```

## Identidades

Controles explicados en [Seguridad de identidades](../seguridad-identidades.md).

```hcl title="identidades.tf"
# Identidad de workload sin secretos: user-assigned managed identity
resource "azurerm_user_assigned_identity" "api" {
  name                = "id-api-pagos-prod"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
}

# Permiso mínimo y acotado: solo leer secretos de su propio Key Vault
resource "azurerm_role_assignment" "api_secretos" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# Owner solo como asignación eligible en PIM, con justificación
data "azurerm_subscription" "prod" {
  subscription_id = var.subscription_prod_id
}

data "azurerm_role_definition" "owner" {
  name = "Owner"
}

resource "azurerm_pim_eligible_role_assignment" "owner_plataforma" {
  scope              = data.azurerm_subscription.prod.id
  role_definition_id = "${data.azurerm_subscription.prod.id}${data.azurerm_role_definition.owner.id}"
  principal_id       = var.grupo_plataforma_object_id
  justification      = "Administración de la suscripción de producción"

  schedule {
    expiration {
      duration_days = 180
    }
  }
}
```

Las políticas de **Conditional Access** y las emergency access accounts se gestionan con el provider `hashicorp/azuread` (`azuread_conditional_access_policy`), no con `azurerm`.

## Cifrado, claves y secretos

Controles explicados en [Seguridad de cifrado, claves y secretos](../seguridad-cifrado-secretos.md).

```hcl title="key-vault.tf"
resource "azurerm_key_vault" "app" {
  name                          = "kv-pagos-prod"
  location                      = azurerm_resource_group.app.location
  resource_group_name           = azurerm_resource_group.app.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "premium"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

resource "azurerm_key_vault_key" "datos" {
  name         = "datos"
  key_vault_id = azurerm_key_vault.app.id
  key_type     = "RSA-HSM"
  key_size     = 3072
  key_opts     = ["wrapKey", "unwrapKey"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P365D"
    notify_before_expiry = "P29D"
  }
}

# Guardrail: exigir purge protection en todos los vaults del management group
resource "azurerm_management_group_policy_assignment" "kv_purge" {
  name                 = "kv-purge-protection"
  management_group_id  = data.azurerm_management_group.workloads.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
  parameters           = jsonencode({ effect = { value = "Deny" } })
}
```

En azurerm v5 se eliminó `enable_rbac_authorization` (el nombre de v4) y `rbac_authorization_enabled` pasó a ser **obligatorio** en `azurerm_key_vault`. La definición `0b60c0b2-…` es *Key vaults should have deletion protection enabled*; confirma el ID y los efectos permitidos en el portal antes de asignarla.

## Logging y detección

Controles explicados en [Seguridad de logging y detección](../seguridad-logging-deteccion.md).

```hcl title="logging.tf"
# Activity Log de la suscripción hacia el workspace central
resource "azurerm_monitor_diagnostic_setting" "activity" {
  name                       = "activity-a-central"
  target_resource_id         = data.azurerm_subscription.actual.id
  log_analytics_workspace_id = var.workspace_central_id

  dynamic "enabled_log" {
    for_each = ["Administrative", "Security", "Policy", "Alert", "Recommendation", "ServiceHealth", "ResourceHealth", "Autoscale"]
    content {
      category = enabled_log.value
    }
  }
}

# Logs de Microsoft Entra ID hacia el workspace central
resource "azurerm_monitor_aad_diagnostic_setting" "entra" {
  name                       = "entra-a-central"
  log_analytics_workspace_id = var.workspace_central_id

  dynamic "enabled_log" {
    for_each = ["SignInLogs", "NonInteractiveUserSignInLogs", "ServicePrincipalSignInLogs", "ManagedIdentitySignInLogs", "AuditLogs", "RiskyUsers", "UserRiskEvents"]
    content {
      category = enabled_log.value
    }
  }
}

# Planes de Defender for Cloud
resource "azurerm_security_center_subscription_pricing" "planes" {
  for_each      = toset(["CloudPosture", "VirtualMachines", "StorageAccounts", "KeyVaults", "Arm", "Containers"])
  tier          = "Standard"
  resource_type = each.value
}

# Alerta: borrado de una asignación de Azure Policy
resource "azurerm_monitor_activity_log_alert" "policy_delete" {
  name                = "borrado-policy-assignment"
  resource_group_name = azurerm_resource_group.seguridad.name
  location            = "global"
  scopes              = [data.azurerm_subscription.actual.id]

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Authorization/policyAssignments/delete"
  }

  action {
    action_group_id = azurerm_monitor_action_group.seguridad.id
  }
}

# Evitar que se borre el workspace central
resource "azurerm_management_lock" "workspace" {
  name       = "no-borrar-workspace-seguridad"
  scope      = var.workspace_central_id
  lock_level = "CanNotDelete"
}
```

En azurerm v5 ya no existen el bloque `enabled_log.retention_policy` ni el bloque `metric` (usa `enabled_metric`): la retención se define en el workspace, no en el diagnostic setting.

Para desplegar diagnostic settings en **todas** las suscripciones y recursos, asigna las iniciativas integradas de Azure Policy de *resource logging* (`DeployIfNotExists`) en el management group en lugar de repetir este bloque.

## Redes

Controles explicados en [Seguridad de redes en la nube](../seguridad-redes.md).

```hcl title="red-segura.tf"
resource "azurerm_subnet" "app" {
  name                            = "snet-app"
  resource_group_name             = azurerm_resource_group.net.name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = ["10.10.1.0/24"]
  default_outbound_access_enabled = false # subnet privada: sale por NAT o firewall
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app"
  location            = azurerm_resource_group.net.location
  resource_group_name = azurerm_resource_group.net.name

  security_rule {
    name                       = "https-desde-appgw"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "10.10.0.0/24" # subnet del Application Gateway
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "443"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# Virtual network flow logs (reemplazo de los NSG flow logs)
resource "azurerm_network_watcher_flow_log" "vnet" {
  name                 = "fl-vnet-main"
  network_watcher_name = "NetworkWatcher_${var.location}"
  resource_group_name  = "NetworkWatcherRG"
  target_resource_id   = azurerm_virtual_network.main.id
  storage_account_id   = var.logs_storage_account_id
  enabled              = true
  version              = 2

  retention_policy {
    enabled = true
    days    = 90
  }
}
```

### Guardrails de organización: redes

```json title="deny-admin-ports-from-internet.json"
{
  "if": {
    "allOf": [
      { "field": "type", "equals": "Microsoft.Network/networkSecurityGroups/securityRules" },
      { "field": "Microsoft.Network/networkSecurityGroups/securityRules/direction", "equals": "Inbound" },
      { "field": "Microsoft.Network/networkSecurityGroups/securityRules/access", "equals": "Allow" },
      { "field": "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix", "in": ["*", "Internet", "0.0.0.0/0"] },
      { "field": "Microsoft.Network/networkSecurityGroups/securityRules/destinationPortRange", "in": ["22", "3389"] }
    ]
  },
  "then": { "effect": "deny" }
}
```

Esta regla cubre las reglas creadas como recurso separado. Las reglas definidas dentro del propio NSG se evalúan con los alias `securityRules[*]`, y los rangos (`"1-65535"`) o listas de puertos necesitan condiciones extra: prueba la política en modo `audit` antes de pasar a `deny`.

## Máquinas virtuales

Controles explicados en [Seguridad de máquinas virtuales](../seguridad-maquinas-virtuales.md).

```hcl title="vm-segura.tf"
resource "azurerm_linux_virtual_machine" "app" {
  name                            = "vm-app-01"
  resource_group_name             = azurerm_resource_group.app.name
  location                        = azurerm_resource_group.app.location
  size                            = "Standard_D2as_v5"
  admin_username                  = "azureops"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.app.id] # NIC sin public IP

  admin_ssh_key {
    username   = "azureops"
    public_key = var.ssh_public_key
  }

  # Trusted Launch
  secure_boot_enabled = true
  vtpm_enabled        = true

  encryption_at_host_enabled = true
  patch_mode                 = "AutomaticByPlatform"
  patch_assessment_mode      = "AutomaticByPlatform"

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
```

### Guardrails de organización: máquinas virtuales

```hcl title="policy-sin-ip-publica.tf"
data "azurerm_policy_definition" "nic_sin_ip_publica" {
  display_name = "Network interfaces should not have public IPs"
}

resource "azurerm_subscription_policy_assignment" "nic_sin_ip_publica" {
  name                 = "deny-nic-public-ip"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = data.azurerm_policy_definition.nic_sin_ip_publica.id
}
```

## Contenedores y Kubernetes

Controles explicados en [Seguridad de contenedores y Kubernetes gestionado](../seguridad-contenedores-kubernetes.md).

```hcl title="aks-seguro.tf"
resource "azurerm_kubernetes_cluster" "main" {
  name                      = "aks-plataforma"
  location                  = azurerm_resource_group.aks.location
  resource_group_name       = azurerm_resource_group.aks.name
  dns_prefix                = "plataforma"
  private_cluster_enabled   = true
  local_account_disabled    = true
  oidc_issuer_enabled       = true # ya es el valor por defecto en azurerm 5
  workload_identity_enabled = true
  azure_policy_enabled      = true
  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = var.tenant_id
  }

  # Obligatorio desde azurerm 5.0
  node_provisioning_profile {
    mode = "Manual" # "Auto" activa node auto-provisioning
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = "Standard_D4as_v5"
    node_count                   = 3
    vnet_subnet_id               = azurerm_subnet.aks.id
    only_critical_addons_enabled = true
    temporary_name_for_rotation  = "systemtmp"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    network_data_plane = "cilium"
    network_policy     = "cilium"
  }

  key_management_service {
    key_vault_key_id         = azurerm_key_vault_key.aks.id
    key_vault_network_access = "Private"
  }

  microsoft_defender {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }
}
```

### Guardrails de organización: contenedores y Kubernetes

```hcl title="policy-aks.tf"
data "azurerm_policy_set_definition" "pod_security_restricted" {
  display_name = "Kubernetes cluster pod security restricted standards for Linux-based workloads"
}

resource "azurerm_subscription_policy_assignment" "aks_restricted" {
  name                 = "aks-pod-security-restricted"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = data.azurerm_policy_set_definition.pod_security_restricted.id
  parameters           = jsonencode({ effect = { value = "audit" } }) # pasa a "deny" tras revisar
}
```

## Serverless

Controles explicados en [Seguridad serverless](../seguridad-serverless.md).

```hcl title="function-segura.tf"
resource "azurerm_linux_function_app" "pagos" {
  name                          = "func-pagos"
  resource_group_name           = azurerm_resource_group.app.name
  location                      = azurerm_resource_group.app.location
  service_plan_id               = azurerm_service_plan.premium.id
  storage_account_name          = azurerm_storage_account.func.name
  storage_uses_managed_identity = true
  https_only                    = true
  public_network_access_enabled = false # entrada por private endpoint
  virtual_network_subnet_id     = azurerm_subnet.functions.id

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    minimum_tls_version      = "1.2"
    ftps_state               = "Disabled"
    remote_debugging_enabled = false
    vnet_route_all_enabled   = true
    app_scale_limit          = 20

    application_stack {
      python_version = "3.12"
    }

    cors {
      allowed_origins = ["https://app.ejemplo.com"]
    }
  }

  app_settings = {
    DB_PASSWORD = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db.versionless_id})"
  }
}
```

### Guardrails de organización: serverless

```hcl title="policy-functions.tf"
data "azurerm_policy_definition" "func_https" {
  display_name = "Function apps should only be accessible over HTTPS"
}

resource "azurerm_subscription_policy_assignment" "func_https" {
  name                 = "func-https-only"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = data.azurerm_policy_definition.func_https.id
  parameters           = jsonencode({ effect = { value = "Deny" } })
}
```

## Almacenamiento de objetos

Controles explicados en [Seguridad del almacenamiento de objetos](../seguridad-almacenamiento.md).

```hcl title="storage.tf"
resource "azurerm_storage_account" "datos" {
  name                     = "acmedatosprod"
  resource_group_name      = azurerm_resource_group.datos.name
  location                 = azurerm_resource_group.datos.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"

  allow_nested_items_to_be_public = false # sin acceso anónimo (default en v5)
  shared_access_key_enabled       = false # solo Entra ID
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false # acceso por private endpoint
  infrastructure_encryption_enabled = true

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }
}
```

!!! warning "Shared Key y Terraform"
    Con `shared_access_key_enabled = false`, configura el provider con `storage_use_azuread = true` para que Terraform gestione contenedores con Entra ID en lugar de con la clave de la cuenta.

### Guardrails de organización: almacenamiento de objetos

```hcl title="policy.tf"
# Política integrada "Storage account public access should be disallowed"
resource "azurerm_management_group_policy_assignment" "no_blob_publico" {
  name                 = "deny-public-blob"
  management_group_id  = azurerm_management_group.plataforma.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/4fa4b6c0-31ca-4c0d-b10d-24b96f62a751"
  parameters = jsonencode({
    effect = { value = "Deny" }
  })
}
```

## Bases de datos

Controles explicados en [Seguridad de bases de datos gestionadas](../seguridad-bases-datos.md).

```hcl title="sql.tf"
resource "azurerm_mssql_server" "prod" {
  name                          = "sql-acme-prod"
  resource_group_name           = azurerm_resource_group.datos.name
  location                      = azurerm_resource_group.datos.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  azuread_administrator {
    login_username              = "grp-dba"
    object_id                   = var.grupo_dba_object_id
    azuread_authentication_only = true # sin logins SQL
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_management_lock" "sql_prod" {
  name       = "no-borrar"
  scope      = azurerm_mssql_server.prod.id
  lock_level = "CanNotDelete"
}

resource "azurerm_cosmosdb_account" "app" {
  name                          = "cosmos-acme-prod"
  resource_group_name           = azurerm_resource_group.datos.name
  location                      = azurerm_resource_group.datos.location
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB"
  local_authentication_enabled  = false # solo RBAC de Entra ID (v5)
  public_network_access_enabled = false
  minimal_tls_version           = "Tls12"

  consistency_policy {
    consistency_level = "Session"
  }
  geo_location {
    location          = azurerm_resource_group.datos.location
    failover_priority = 0
  }
  backup {
    type = "Continuous"
    tier = "Continuous30Days"
  }
}
```

### Guardrails de organización: bases de datos

Asigna con efecto `Deny` las políticas integradas "Public network access on Azure SQL Database should be disabled" y "Azure SQL Database should have Microsoft Entra-only authentication enabled" en el management group de producción (mismo patrón que en [Seguridad del almacenamiento](#almacenamiento-de-objetos)).

## APIs y aplicaciones

Controles explicados en [Seguridad de APIs y aplicaciones expuestas](../seguridad-apis-aplicaciones.md).

Política de API Management aplicada a nivel global o de producto (con Terraform: `azurerm_api_management_api_policy` o `azurerm_api_management_product_policy` con `xml_content`):

```xml title="politica-api.xml"
<policies>
  <inbound>
    <base />
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>https://app.acme.com</origin>
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
      </allowed-methods>
      <allowed-headers>
        <header>Authorization</header>
        <header>Content-Type</header>
      </allowed-headers>
    </cors>
    <validate-jwt header-name="Authorization" require-scheme="Bearer" failed-validation-httpcode="401">
      <openid-config url="https://login.microsoftonline.com/{tenant-id}/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience>api://pedidos</audience>
      </audiences>
      <required-claims>
        <claim name="scp" match="any" separator=" ">
          <value>Pedidos.Read</value>
        </claim>
      </required-claims>
    </validate-jwt>
    <rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
    <validate-content unspecified-content-type-action="prevent" max-size="102400" size-exceeded-action="prevent">
      <content type="application/json" validate-as="json" action="prevent" />
    </validate-content>
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
```

## Servicios de IA generativa

Controles explicados en [Seguridad de servicios de IA generativa](../seguridad-servicios-ia.md).

```hcl title="foundry.tf"
resource "azurerm_cognitive_account" "foundry" {
  name                          = "foundry-acme-prod"
  resource_group_name           = azurerm_resource_group.ia.name
  location                      = azurerm_resource_group.ia.location
  kind                          = "AIServices"
  sku_name                      = "S0"
  custom_subdomain_name         = "foundry-acme-prod" # necesario para Entra ID
  local_auth_enabled            = false                # sin API keys
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_private_endpoint" "foundry" {
  name                = "pe-foundry"
  resource_group_name = azurerm_resource_group.ia.name
  location            = azurerm_resource_group.ia.location
  subnet_id           = azurerm_subnet.endpoints.id

  private_service_connection {
    name                           = "foundry"
    private_connection_resource_id = azurerm_cognitive_account.foundry.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }
}
```
