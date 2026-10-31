---
tags:
  - cloud
  - seguridad
  - terraform
  - iac
---

# Terraform seguro en AWS

> Fragmentos de Terraform con los controles de seguridad de cada nota de [Seguridad en la nube](../fundamentos-seguridad-cloud.md), ordenados igual que el bloque. La explicación de cada control (por qué y cómo verificarlo) está en su nota; aquí solo el código.

!!! note "Versión del provider"
    Los fragmentos usan `hashicorp/aws` 6.x (la versión mayor vigente en octubre de 2026). Fija la versión con `~>` y pasa `terraform validate` y `terraform plan` antes de aplicar. Si vienes de una versión anterior, revisa la *upgrade guide* del provider.

    ```hcl title="versions.tf"
    terraform {
      required_providers {
        aws     = { source = "hashicorp/aws", version = "~> 6.0" }
      }
    }
    ```

Antes de aplicar, pasa el plan por un escáner de IaC (Checkov, Trivy): ver [IaC scanning](../../../devsecops/escaneos/iac-scanning.md). Equivalentes en los otros proveedores: [Azure](azure.md), [Google Cloud](google-cloud.md).

## Base de seguridad

Controles explicados en [Fundamentos de seguridad en la nube](../fundamentos-seguridad-cloud.md).

```hcl title="security-hub.tf"
data "aws_region" "current" {}

resource "aws_securityhub_account" "this" {
  enable_default_standards = false
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.region}::standards/cis-aws-foundations-benchmark/v/5.0.0"
  depends_on    = [aws_securityhub_account.this]
}
```

En el provider v6, `data.aws_region` expone `region` (el atributo `name` quedó obsoleto). En una organización, hazlo desde el administrador delegado con `aws_securityhub_configuration_policy`.

## Identidades

Controles explicados en [Seguridad de identidades](../seguridad-identidades.md).

```hcl title="identidades.tf"
# Gestión centralizada del root (desde la management account)
resource "aws_iam_organizations_features" "root" {
  enabled_features = ["RootCredentialsManagement", "RootSessions"]
}

# IAM Access Analyzer: accesos externos y accesos sin uso en toda la organización
resource "aws_accessanalyzer_analyzer" "externo" {
  analyzer_name = "org-external-access"
  type          = "ORGANIZATION"
}

resource "aws_accessanalyzer_analyzer" "sin_uso" {
  analyzer_name = "org-unused-access"
  type          = "ORGANIZATION_UNUSED_ACCESS"

  configuration {
    unused_access {
      unused_access_age = 90
    }
  }
}
```

```json title="scp-sin-claves-de-larga-duracion.json"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLongTermCredentials",
      "Effect": "Deny",
      "Action": ["iam:CreateUser", "iam:CreateAccessKey", "iam:CreateLoginProfile"],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:role/plataforma-excepciones-iam"
        }
      }
    }
  ]
}
```

## Cifrado, claves y secretos

Controles explicados en [Seguridad de cifrado, claves y secretos](../seguridad-cifrado-secretos.md).

```hcl title="kms-secretos.tf"
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

resource "aws_kms_key" "datos" {
  description             = "CMK de datos de la app de pagos (prod)"
  enable_key_rotation     = true
  rotation_period_in_days = 180
  deletion_window_in_days = 30
  policy                  = file("${path.module}/key-policy-datos.json")

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "datos" {
  name          = "alias/pagos-prod-datos"
  target_key_id = aws_kms_key.datos.key_id
}

resource "aws_secretsmanager_secret" "api_externa" {
  name       = "prod/pagos/api-externa"
  kms_key_id = aws_kms_key.datos.arn
}

resource "aws_secretsmanager_secret_rotation" "api_externa" {
  secret_id           = aws_secretsmanager_secret.api_externa.id
  rotation_lambda_arn = aws_lambda_function.rotar_api_externa.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

```json title="scp-proteger-claves.json"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ProtegerBorradoDeClaves",
      "Effect": "Deny",
      "Action": ["kms:ScheduleKeyDeletion", "kms:DisableKey", "kms:PutKeyPolicy"],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": { "aws:PrincipalArn": "arn:aws:iam::*:role/seguridad-kms-admin" }
      }
    }
  ]
}
```

## Logging y detección

Controles explicados en [Seguridad de logging y detección](../seguridad-logging-deteccion.md).

```hcl title="logging.tf"
# Bucket de logs en la cuenta Log Archive, inmutable 1 año
resource "aws_s3_bucket" "trail" {
  bucket              = "org-cloudtrail-logs-111122223333"
  object_lock_enabled = true
}

resource "aws_s3_bucket_object_lock_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id
  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = 365
    }
  }
}

# Organization trail (desde la management account o el admin delegado)
resource "aws_cloudtrail" "org" {
  name                          = "org-trail"
  s3_bucket_name                = aws_s3_bucket.trail.id
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.trail.arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.trail_to_cwl.arn

  advanced_event_selector {
    name = "Management events"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  advanced_event_selector {
    name = "S3 data events solo en buckets sensibles"
    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }
    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }
    field_selector {
      field       = "resources.ARN"
      starts_with = ["arn:aws:s3:::pagos-prod-datos/"]
    }
  }
}

# Alerta CIS: uso del root user
resource "aws_cloudwatch_log_metric_filter" "root" {
  name           = "uso-root"
  log_group_name = aws_cloudwatch_log_group.trail.name
  pattern        = "{$.userIdentity.type=\"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType !=\"AwsServiceEvent\"}"

  metric_transformation {
    name      = "RootUsage"
    namespace = "CISBenchmark"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root" {
  alarm_name          = "uso-root"
  namespace           = "CISBenchmark"
  metric_name         = "RootUsage"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_sns_topic.seguridad.arn]
}

# GuardDuty para toda la organización (en la cuenta administradora delegada)
resource "aws_guardduty_detector" "this" {
  enable = true
}

resource "aws_guardduty_organization_configuration" "this" {
  detector_id                      = aws_guardduty_detector.this.id
  auto_enable_organization_members = "ALL"
}
```

```json title="scp-proteger-logs-y-deteccion.json"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ProtegerLogsYDeteccion",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:StopLogging", "cloudtrail:DeleteTrail", "cloudtrail:UpdateTrail",
        "cloudtrail:PutEventSelectors",
        "guardduty:DeleteDetector", "guardduty:UpdateDetector",
        "guardduty:DisassociateFromAdministratorAccount",
        "securityhub:DisableSecurityHub",
        "config:StopConfigurationRecorder", "config:DeleteConfigurationRecorder",
        "config:DeleteDeliveryChannel"
      ],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": { "aws:PrincipalArn": "arn:aws:iam::*:role/plataforma-seguridad" }
      }
    }
  ]
}
```

## Redes

Controles explicados en [Seguridad de redes en la nube](../seguridad-redes.md).

```hcl title="red-segura.tf"
# Deja el default security group sin reglas (EC2.2)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
}

# Flow logs de toda la VPC hacia el bucket de logs central
resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = var.flow_logs_bucket_arn
}

# Endpoints para administrar instancias sin salida a internet
resource "aws_vpc_endpoint" "ssm" {
  for_each            = toset(["ssm", "ssmmessages", "ec2messages"])
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

# Bloquea el tráfico entrante desde internet gateways en toda la región
resource "aws_vpc_block_public_access_options" "this" {
  internet_gateway_block_mode = "block-ingress"
}
```

### Guardrails de organización: redes

```json title="scp-red.json"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SoloRedPuedeAbrirInternet",
      "Effect": "Deny",
      "Action": [
        "ec2:CreateInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:ModifyVpcBlockPublicAccessOptions",
        "ec2:CreateVpcBlockPublicAccessExclusion"
      ],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:role/NetworkAdmin"
        }
      }
    }
  ]
}
```

## Máquinas virtuales

Controles explicados en [Seguridad de máquinas virtuales](../seguridad-maquinas-virtuales.md).

```hcl title="vm-segura.tf"
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

resource "aws_ec2_instance_metadata_defaults" "this" {
  http_tokens                 = "required"
  http_put_response_hop_limit = 1
}

resource "aws_launch_template" "app" {
  name_prefix   = "app-"
  image_id      = var.golden_ami_id
  instance_type = "t4g.small"

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name # incluye AmazonSSMManagedInstanceCore
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type = "gp3"
      encrypted   = true
      kms_key_id  = aws_kms_key.ebs.arn
    }
  }
}
```

### Guardrails de organización: máquinas virtuales

```json title="scp-imdsv2.json"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ExigirIMDSv2",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringNotEquals": { "ec2:MetadataHttpTokens": "required" }
      }
    },
    {
      "Sid": "NoVolverAIMDSv1",
      "Effect": "Deny",
      "Action": "ec2:ModifyInstanceMetadataOptions",
      "Resource": "*",
      "Condition": {
        "ArnNotLike": { "aws:PrincipalArn": "arn:aws:iam::*:role/PlatformAdmin" }
      }
    }
  ]
}
```

## Contenedores y Kubernetes

Controles explicados en [Seguridad de contenedores y Kubernetes gestionado](../seguridad-contenedores-kubernetes.md).

```hcl title="eks-seguro.tf"
resource "aws_eks_cluster" "main" {
  name     = "plataforma"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn # opcional: CMK en vez de la clave de AWS
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]
}

resource "aws_eks_pod_identity_association" "pagos" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "pagos"
  service_account = "pagos-api"
  role_arn        = aws_iam_role.pagos_api.arn
}

resource "aws_ecr_repository" "pagos" {
  name                 = "pagos-api"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}
```

### Guardrails de organización: contenedores y Kubernetes

```json title="scp-eks.json"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SoloPlataformaCambiaControlesDeClusterYRegistry",
      "Effect": "Deny",
      "Action": [
        "eks:UpdateClusterConfig",
        "eks:DisassociateEncryptionConfig",
        "ecr:PutImageTagMutability",
        "ecr:PutImageScanningConfiguration",
        "ecr:PutRegistryScanningConfiguration",
        "guardduty:UpdateDetector",
        "guardduty:DeleteDetector"
      ],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": { "aws:PrincipalArn": "arn:aws:iam::*:role/PlatformAdmin" }
      }
    }
  ]
}
```

Antes de aplicar una SCP, comprueba en la *Service Authorization Reference* que cada acción existe con ese nombre: una acción mal escrita no da error, simplemente no deniega nada. Prueba también que no rompe al pipeline que gestiona los clústeres.

## Serverless

Controles explicados en [Seguridad serverless](../seguridad-serverless.md).

```hcl title="lambda-segura.tf"
resource "aws_signer_signing_profile" "lambda" {
  name_prefix = "lambda"
  platform_id = "AWSLambda-SHA384-ECDSA"
}

resource "aws_lambda_code_signing_config" "this" {
  allowed_publishers {
    signing_profile_version_arns = [aws_signer_signing_profile.lambda.version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce"
  }
}

resource "aws_lambda_function" "pagos" {
  function_name = "pagos-api"
  role          = aws_iam_role.pagos_api.arn # rol propio, permisos mínimos
  runtime       = "python3.13"
  handler       = "app.handler"
  s3_bucket     = var.artifacts_bucket
  s3_key        = var.signed_zip_key # ZIP firmado por un signing job de AWS Signer

  code_signing_config_arn        = aws_lambda_code_signing_config.this.arn
  kms_key_arn                    = aws_kms_key.lambda.arn
  reserved_concurrent_executions = 50

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN = aws_secretsmanager_secret.db.arn # el ARN, no el valor
    }
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.pagos.name
  }

  tracing_config {
    mode = "Active"
  }
}
```

### Guardrails de organización: serverless

```json title="scp-lambda.json"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SinFunctionUrlsPublicas",
      "Effect": "Deny",
      "Action": ["lambda:CreateFunctionUrlConfig", "lambda:UpdateFunctionUrlConfig"],
      "Resource": "*",
      "Condition": {
        "StringEquals": { "lambda:FunctionUrlAuthType": "NONE" }
      }
    },
    {
      "Sid": "ExigirCodeSigning",
      "Effect": "Deny",
      "Action": "lambda:CreateFunction",
      "Resource": "*",
      "Condition": {
        "Null": { "lambda:CodeSigningConfigArn": "true" }
      }
    }
  ]
}
```

La segunda regla bloquea también funciones desplegadas como imagen de contenedor (no admiten code signing): aplícala solo en las cuentas donde todas las funciones sean ZIP.

## Almacenamiento de objetos

Controles explicados en [Seguridad del almacenamiento de objetos](../seguridad-almacenamiento.md).

```hcl title="s3.tf"
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "datos" {
  bucket = "acme-datos-prod"
}

resource "aws_s3_bucket_ownership_controls" "datos" {
  bucket = aws_s3_bucket.datos.id
  rule {
    object_ownership = "BucketOwnerEnforced" # ACLs desactivadas
  }
}

resource "aws_s3_bucket_versioning" "datos" {
  bucket = aws_s3_bucket.datos.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datos" {
  bucket = aws_s3_bucket.datos.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.datos.arn
    }
    bucket_key_enabled = true
  }
}

data "aws_iam_policy_document" "solo_tls" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.datos.arn,
      "${aws_s3_bucket.datos.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "datos" {
  bucket = aws_s3_bucket.datos.id
  policy = data.aws_iam_policy_document.solo_tls.json
}

resource "aws_ebs_snapshot_block_public_access" "this" {
  state = "block-all-sharing"
}
```

### Guardrails de organización: almacenamiento de objetos

```json title="scp-s3-bpa.json"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ProtegerBlockPublicAccess",
      "Effect": "Deny",
      "Action": [
        "s3:PutAccountPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock"
      ],
      "Resource": "*",
      "Condition": {
        "ArnNotLike": {
          "aws:PrincipalARN": "arn:aws:iam::*:role/PlatformAdmin"
        }
      }
    }
  ]
}
```

## Bases de datos

Controles explicados en [Seguridad de bases de datos gestionadas](../seguridad-bases-datos.md).

```hcl title="rds.tf"
resource "aws_db_instance" "pedidos" {
  identifier     = "pedidos-prod"
  engine         = "postgres"
  engine_version = "17"
  instance_class = "db.t4g.medium"

  allocated_storage    = 50
  db_subnet_group_name = aws_db_subnet_group.privadas.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible  = false

  username                    = "dbadmin"
  manage_master_user_password = true  # Secrets Manager con rotación
  iam_database_authentication_enabled = true

  storage_encrypted = true
  kms_key_id        = aws_kms_key.datos.arn
  parameter_group_name = aws_db_parameter_group.pg_tls.name

  backup_retention_period    = 14
  copy_tags_to_snapshot      = true
  deletion_protection        = true
  auto_minor_version_upgrade = true
  enabled_cloudwatch_logs_exports = ["postgresql"]
  multi_az = true
}

resource "aws_db_parameter_group" "pg_tls" {
  name   = "pg17-tls"
  family = "postgres17"
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

resource "aws_dynamodb_table" "sesiones" {
  name         = "sesiones"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  deletion_protection_enabled = true
  point_in_time_recovery {
    enabled = true
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.datos.arn
  }
}
```

### Guardrails de organización: bases de datos

```json title="scp-rds.json"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenegarRDSSinCifrar",
      "Effect": "Deny",
      "Action": ["rds:CreateDBInstance", "rds:CreateDBCluster"],
      "Resource": "*",
      "Condition": {
        "Bool": { "rds:StorageEncrypted": "false" }
      }
    }
  ]
}
```

Antes de imponerla, confirma en la *Service Authorization Reference* de RDS qué acciones admiten la clave `rds:StorageEncrypted` y prueba en una cuenta aislada qué pasa si la petición no envía el parámetro (una condición `Bool` no se evalúa si la clave no existe).

## APIs y aplicaciones

Controles explicados en [Seguridad de APIs y aplicaciones expuestas](../seguridad-apis-aplicaciones.md).

```hcl title="api.tf"
resource "aws_apigatewayv2_api" "pedidos" {
  name          = "pedidos"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://app.acme.com"]
    allow_methods = ["GET", "POST"]
    allow_headers = ["authorization", "content-type"]
  }
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id           = aws_apigatewayv2_api.pedidos.id
  name             = "cognito"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.web.id]
    issuer   = "https://cognito-idp.${var.region}.amazonaws.com/${aws_cognito_user_pool.clientes.id}"
  }
}

resource "aws_apigatewayv2_route" "listar" {
  api_id               = aws_apigatewayv2_api.pedidos.id
  route_key            = "GET /pedidos"
  target               = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.jwt.id
  authorization_scopes = ["pedidos/read"]
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.pedidos.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 50  # peticiones por segundo
    throttling_burst_limit = 100
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId = "$context.requestId"
      ip        = "$context.identity.sourceIp"
      ruta      = "$context.routeKey"
      estado    = "$context.status"
      usuario   = "$context.authorizer.claims.sub"
    })
  }
}
```

Para una REST API, el WAF se asocia al stage con `aws_wafv2_web_acl_association` (`resource_arn` = ARN del stage) y una web ACL con `AWSManagedRulesCommonRuleSet` y `AWSManagedRulesKnownBadInputsRuleSet`.

## Servicios de IA generativa

Controles explicados en [Seguridad de servicios de IA generativa](../seguridad-servicios-ia.md).

```hcl title="bedrock.tf"
resource "aws_vpc_endpoint" "bedrock_runtime" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.privadas[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

resource "aws_bedrock_guardrail" "soporte" {
  name                      = "asistente-soporte"
  blocked_input_messaging   = "No puedo ayudarte con esa solicitud."
  blocked_outputs_messaging = "No puedo responder a eso."

  content_policy_config {
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE" # los ataques de prompt solo se evalúan en la entrada
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
  }

  sensitive_information_policy_config {
    pii_entities_config {
      type   = "EMAIL"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_NUMBER"
      action = "BLOCK"
    }
  }
}

resource "aws_bedrock_model_invocation_logging_configuration" "this" {
  logging_config {
    text_data_delivery_enabled      = true
    image_data_delivery_enabled     = false
    embedding_data_delivery_enabled = false
    s3_config {
      bucket_name = aws_s3_bucket.logs_ia.id
      key_prefix  = "bedrock"
    }
  }
}

# Rol de la aplicación: un modelo concreto y solo con el guardrail aprobado
data "aws_iam_policy_document" "app_chat" {
  statement {
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = [var.modelo_arn]
    condition {
      test     = "StringEquals"
      variable = "bedrock:GuardrailIdentifier"
      values   = ["${aws_bedrock_guardrail.soporte.guardrail_arn}:${var.guardrail_version}"]
    }
  }
}
```

Verifica en la documentación de Bedrock el formato exacto que espera `bedrock:GuardrailIdentifier` (ARN con versión) antes de aplicarlo.
