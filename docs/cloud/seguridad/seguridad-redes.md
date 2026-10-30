---
tags:
  - seguridad
  - cloud
  - aws
  - azure
  - gcp
  - redes
---

# Seguridad de redes en la nube

> Los controles de red que reducen la superficie de ataque en AWS, Azure y Google Cloud: segmentación, firewalls mínimos, administración sin puertos abiertos, endpoints privados, control de egress, flow logs, WAF, DDoS y DNS.

!!! info "Antes de leer"
    En el [Shared Responsibility Model](../fundamentos/responsabilidad-compartida.md) el proveedor protege la red física y el aislamiento entre clientes; **la configuración de tu red virtual es tuya**: rutas, reglas de firewall, qué es público y por dónde sale el tráfico. Esta nota asume que conoces VPC/VNet, subnets, security groups y NAT, explicados en [Redes en la nube](../redes-y-datos/redes.md), y los conceptos de firewall stateful, DMZ y zero trust de [Seguridad de red](../../networking/avanzado/seguridad-red.md). Aquí no se repiten: se baja a los controles concretos y a cómo comprobarlos.

## Riesgos típicos

| Riesgo | Ejemplo o incidente conocido | Control que lo evita |
| --- | --- | --- |
| Puertos de administración abiertos a internet (SSH 22, RDP 3389) | RDP expuesto es una de las vías de entrada más citadas en informes de *ransomware* | Sin reglas `0.0.0.0/0` a puertos de administración; acceso por Session Manager, Azure Bastion o IAP |
| Bases de datos o caches expuestas | Oleadas de "secuestro" de bases MongoDB y Elasticsearch abiertas a internet (2017 en adelante) | Subnets privadas, firewall que solo acepta tráfico desde la capa de aplicación, endpoints privados |
| Red por defecto con reglas permisivas | Default VPC con subnets públicas; red `default` de Google Cloud con reglas que permiten SSH/RDP | Borrar o no crear la red por defecto; cerrar el default security group |
| **Lateral movement** (movimiento lateral) | Un atacante que entra en una VM llega a todo lo demás porque la red es "plana" | Segmentación por capas y por entorno; reglas que referencian grupos/tags, no rangos enteros |
| **Data exfiltration** (exfiltración de datos) por egress libre | Malware o un insider que sube datos a un bucket externo o a un dominio de comando y control | Control de egress (firewall con FQDN, DNS firewall), endpoints privados con políticas, VPC Service Controls |
| Tráfico hacia servicios del proveedor que sale por internet | Llamadas a S3/Storage/APIs de Google pasando por NAT | PrivateLink / Private Link / Private Service Connect y Private Google Access |
| Ataques web y DDoS | SQL injection, bots, *credential stuffing*; ataques volumétricos | WAF delante de las aplicaciones públicas y protección DDoS |
| Sin visibilidad del tráfico | Un incidente que no se puede reconstruir porque nadie activó flow logs | Flow logs y firewall logging enviados a la cuenta de logs |

## Controles por proveedor

| Prioridad | Control | AWS | Azure | Google Cloud |
| --- | --- | --- | --- | --- |
| **Imprescindible** | Firewall de instancia con reglas mínimas | Security groups | Network security groups (NSG), application security groups (ASG) | VPC firewall rules, network firewall policies (Cloud NGFW) |
| **Imprescindible** | Administración sin puertos abiertos | AWS Systems Manager Session Manager, EC2 Instance Connect Endpoint | Azure Bastion, just-in-time VM access (Defender for Servers Plan 2) | Identity-Aware Proxy (IAP) TCP forwarding |
| **Imprescindible** | Cerrar la red por defecto | Default security group sin reglas; no usar la default VPC | No hay red por defecto; desactivar *default outbound access* en subnets nuevas | Org policy `compute.skipDefaultNetworkCreation` |
| **Imprescindible** | Flow logs | VPC Flow Logs | Virtual network flow logs (Network Watcher) | VPC Flow Logs + Firewall Rules Logging |
| **Imprescindible** | WAF delante de apps públicas | AWS WAF | Azure Web Application Firewall (Front Door, Application Gateway) | Google Cloud Armor |
| Recomendado | Acceso privado a servicios gestionados | VPC endpoints (gateway e interface, AWS PrivateLink) | Private Endpoint (Azure Private Link), service endpoints | Private Service Connect, Private Google Access |
| Recomendado | Bloqueo de internet a nivel cuenta/región | VPC Block Public Access | Azure Virtual Network Manager (security admin rules) | Hierarchical firewall policies, org policy `compute.vmExternalIpAccess` |
| Recomendado | Firewall gestionado / control de egress | AWS Network Firewall, Route 53 Resolver DNS Firewall | Azure Firewall (con reglas FQDN) | Cloud NGFW, Secure Web Proxy |
| Recomendado | Perímetro de datos para APIs del proveedor | VPC endpoint policies, condiciones `aws:SourceVpce` | Políticas de Private Endpoint, *network security perimeter* | VPC Service Controls |
| Recomendado | DDoS | AWS Shield Standard (incluido), Shield Advanced | Protección de infraestructura incluida; Azure DDoS Network Protection / IP Protection | Protección incluida en Cloud Armor; Cloud Armor Enterprise |
| Recomendado | DNS seguro | Route 53 DNSSEC, query logging, DNS Firewall | Azure DNS (DNSSEC en zonas públicas), Azure DNS Private Resolver, DNS security policy | Cloud DNS DNSSEC, DNS logging, response policies |
| Recomendado | Gestión central de reglas | AWS Firewall Manager | Azure Firewall Manager, Azure Virtual Network Manager | Hierarchical firewall policies |

!!! note "Nombres que cambian"
    En Azure, los **NSG flow logs** ya no se pueden crear desde el 30 de junio de 2025 y se retiran en septiembre de 2027: el reemplazo son los **virtual network flow logs**. En Google Cloud, las firewall rules y firewall policies se agrupan ahora bajo el nombre **Cloud Next Generation Firewall (Cloud NGFW)**, con niveles Essentials, Standard y Enterprise.

## Buenas prácticas

1. **Diseña la red por capas y por entorno.** Subnet pública solo para el load balancer (y NAT); aplicación y datos en subnets privadas; producción y no-producción en VPC/VNet (o cuentas/proyectos) distintas. El modelo **hub-and-spoke** (concentrador y radios) con un firewall en el hub permite inspeccionar el tráfico entre *spokes* y hacia internet (ver [Redes de datacenter e híbridas](../../networking/avanzado/redes-datacenter-hibridas.md)).
2. **Reglas mínimas que referencian identidades, no rangos.** La base de datos acepta su puerto solo desde el security group / ASG / service account de la aplicación. Nada de `0.0.0.0/0` salvo 80/443 en el load balancer.
3. **Cero puertos de administración abiertos.** Acceso a VMs por Session Manager, Azure Bastion o IAP, autenticado con la identidad de la nube y auditado (detalle en [Seguridad de máquinas virtuales](seguridad-maquinas-virtuales.md)).
4. **Endpoints privados para servicios gestionados.** Storage, bases de datos, registries y Key Vault/Secrets Manager accesibles por IP privada, con el acceso público desactivado en el propio servicio.
5. **Controla el egress.** Por defecto todo puede salir a internet. En producción, sal por un punto controlado (NAT + firewall con listas de FQDN permitidos) y filtra DNS.
6. **Activa flow logs y logging de firewall** en todas las redes y envíalos a la cuenta o proyecto de logs central (ver [Seguridad de logging y detección](seguridad-logging-deteccion.md)).
7. **WAF y DDoS delante de todo lo público.** Empieza con reglas gestionadas en modo *count/detection*, revisa falsos positivos y pasa a bloquear. La protección de APIs se amplía en [Seguridad de APIs y aplicaciones](seguridad-apis-aplicaciones.md).
8. **Guardrails a nivel organización** para que nadie pueda saltarse lo anterior: impedir IPs públicas, internet gateways no aprobados o la red por defecto (ver [Gobernanza](../operacion-y-gobierno/gobernanza.md)).

=== "AWS"

    - Activa **VPC Block Public Access** en modo `block-ingress` o `block-bidirectional` en las cuentas que no deben tener nada expuesto; puedes crear exclusiones para VPCs o subnets concretas.
    - Session Manager necesita que la instancia alcance los endpoints de Systems Manager: en subnets sin salida a internet crea interface endpoints para `ssm` y `ssmmessages` (y `ec2messages` según la versión del agente).
    - Los **gateway endpoints** de S3 y DynamoDB no cuestan y evitan pasar por el NAT; añádeles una **endpoint policy** que limite qué buckets se pueden usar.
    - Las **Network ACLs** son una segunda capa *stateless*: útiles para bloquear rangos completos, no para sustituir a los security groups.

=== "Azure"

    - Las subnets nuevas deberían ser **private subnets** (`defaultOutboundAccess = false`) y salir por **Azure NAT Gateway** o **Azure Firewall** mediante UDR.
    - Usa **service tags** (`AzureLoadBalancer`, `Storage`, `AzureCloud`…) y **ASG** en las reglas en vez de listas de IPs.
    - **Azure Bastion** Standard o Premium permite *native client* (SSH/RDP desde tu terminal) y Premium añade grabación de sesiones y despliegue solo privado.
    - **Azure Virtual Network Manager** aplica *security admin rules* que se evalúan antes que los NSG: sirven como guardrail central ("nunca permitir 3389 desde Internet").

=== "Google Cloud"

    - Crea las redes en **custom mode** y aplica la org policy `compute.skipDefaultNetworkCreation`.
    - Para IAP, la única regla de entrada necesaria es desde `35.235.240.0/20` al puerto 22/3389, dirigida por *network tag* o *service account*; el acceso se concede con el rol `roles/iap.tunnelResourceAccessor`.
    - **Hierarchical firewall policies** a nivel organización o carpeta permiten denegar (o delegar con `goto_next`) antes de que actúen las reglas de cada proyecto.
    - **VPC Service Controls** crea un perímetro alrededor de las APIs de Google (Cloud Storage, BigQuery…) para que los datos no se copien a proyectos fuera del perímetro aunque alguien tenga credenciales válidas.

## Cómo verificarlo

Solo comandos de lectura.

=== "AWS"

    ```bash
    # Security groups con alguna regla de entrada desde 0.0.0.0/0
    aws ec2 describe-security-groups \
      --filters Name=ip-permission.cidr,Values=0.0.0.0/0 \
      --query "SecurityGroups[].{id:GroupId,name:GroupName,vpc:VpcId}" --output table

    # VPCs y si tienen flow logs
    aws ec2 describe-vpcs --query "Vpcs[].VpcId"
    aws ec2 describe-flow-logs --query "FlowLogs[].{recurso:ResourceId,estado:FlowLogStatus,destino:LogDestination}"

    # VPC Block Public Access y endpoints privados
    aws ec2 describe-vpc-block-public-access-options
    aws ec2 describe-vpc-endpoints --query "VpcEndpoints[].{svc:ServiceName,tipo:VpcEndpointType}" --output table

    # WAF y Shield
    aws wafv2 list-web-acls --scope REGIONAL
    aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1
    aws shield describe-subscription   # falla si no tienes Shield Advanced

    # Hallazgos de Security Hub CSPM para un control concreto
    aws securityhub get-findings --filters \
      '{"ComplianceSecurityControlId":[{"Value":"EC2.19","Comparison":"EQUALS"}],"RecordState":[{"Value":"ACTIVE","Comparison":"EQUALS"}]}' \
      --query "Findings[].Resources[].Id"
    ```

=== "Azure"

    ```bash
    # Reglas de entrada permitidas desde cualquier origen en un NSG
    az network nsg rule list -g <rg> --nsg-name <nsg> \
      --query "[?direction=='Inbound' && access=='Allow' && (sourceAddressPrefix=='*' || sourceAddressPrefix=='Internet' || sourceAddressPrefix=='0.0.0.0/0')]" \
      -o table

    # Flow logs, Bastion, private endpoints y planes DDoS
    az network watcher flow-log list --location <region> -o table
    az network bastion list -o table
    az network private-endpoint list -o table
    az network ddos-protection list -o table

    # Recomendaciones de Defender for Cloud que no se cumplen
    az security assessment list \
      --query "[?status.code=='Unhealthy' && displayName=='Management ports should be closed on your virtual machines'].{recurso:resourceDetails.Id}" \
      -o table
    ```

=== "Google Cloud"

    ```bash
    # Firewall rules de entrada abiertas a internet
    gcloud compute firewall-rules list \
      --filter="direction=INGRESS AND sourceRanges:0.0.0.0/0 AND disabled=false" \
      --format="table(name,network,sourceRanges.list(),allowed[].map().firewall_rule().list(),targetTags.list())"

    # ¿Existe la red default? ¿Flow logs y Private Google Access por subnet?
    gcloud compute networks list
    gcloud compute networks subnets list \
      --format="table(name,region.basename(),logConfig.enable,privateIpGoogleAccess)"

    # Políticas de Cloud Armor, firewall policies y DNSSEC
    gcloud compute security-policies list
    gcloud compute network-firewall-policies list
    gcloud dns managed-zones list --format="table(name,visibility,dnssecConfig.state)"

    # Hallazgos activos de Security Health Analytics
    gcloud scc findings list organizations/<org-id> --location=global \
      --filter='category="OPEN_SSH_PORT" AND state="ACTIVE"'
    ```

| Control | AWS Security Hub CSPM | Microsoft Defender for Cloud (MCSB) | Security Command Center (Security Health Analytics) |
| --- | --- | --- | --- |
| Puertos de administración abiertos | EC2.13 (22), EC2.14 (3389) en CIS; EC2.53/EC2.54; EC2.19 (puertos de alto riesgo) y EC2.18 en FSBP | *Management ports should be closed on your virtual machines*; *Management ports of virtual machines should be protected with just-in-time network access control* | `OPEN_SSH_PORT`, `OPEN_RDP_PORT`, `OPEN_FIREWALL` |
| Default security group / red por defecto | EC2.2 | — | `DEFAULT_NETWORK`, `LEGACY_NETWORK` |
| Flow logs | EC2.6 | Flow logs (Network Watcher) en los estándares regulatorios | `FLOW_LOGS_DISABLED`, `VPC_FLOW_LOGS_SETTINGS_NOT_RECOMMENDED`, `FIREWALL_RULE_LOGGING_DISABLED` |
| Subnets expuestas o sin firewall | EC2.15 (IP pública automática en subnets) | *Subnets should be associated with a network security group*; *Internet-facing virtual machines should be protected with network security groups* | — |
| Bloqueo público a nivel cuenta | EC2.172 (VPC Block Public Access) | — | — |
| Acceso privado a APIs | EC2.10, EC2.55–EC2.57 (endpoints) | — | `PRIVATE_GOOGLE_ACCESS_DISABLED` |
| WAF y DDoS | CloudFront.6, APIGateway.4, WAF.10 | *Azure DDoS Protection Standard should be enabled*; *Virtual networks should be protected by Azure Firewall* | — |
| DNS | Route53.2 (query logging) | — | `DNSSEC_DISABLED` |
| Egress | — | — | `EGRESS_DENY_RULE_NOT_SET` |

Para escanearlo de forma continua y multi-cuenta, ver [CSPM](../../devsecops/escaneos/cspm.md).

## Configuración segura con IaC

!!! note "Versiones de provider"
    Los fragmentos de este bloque usan `hashicorp/aws` 6.x, `hashicorp/azurerm` 5.x y `hashicorp/google` 8.x (las versiones mayores vigentes en octubre de 2026). Fija la versión con `~>` y pasa `terraform validate` y `terraform plan` antes de aplicar. Si vienes de versiones anteriores, revisa las *upgrade guides*: por ejemplo, en azurerm 5 `azurerm_network_watcher_flow_log` ya solo acepta `target_resource_id`, y en google 7 `google_compute_subnetwork` perdió `enable_flow_logs` en favor de `log_config`.

    ```hcl title="versions.tf"
    terraform {
      required_providers {
        aws     = { source = "hashicorp/aws", version = "~> 6.0" }
        azurerm = { source = "hashicorp/azurerm", version = "~> 5.0" }
        google  = { source = "hashicorp/google", version = "~> 8.0" }
      }
    }
    ```

=== "AWS"

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

=== "Azure"

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

=== "Google Cloud"

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

### Guardrails de organización

=== "AWS (SCP)"

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

=== "Azure Policy"

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

=== "Google Cloud (Organization Policy)"

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

El escaneo de estas configuraciones antes del `apply` (Checkov, Trivy) se ve en [Seguridad de IaC](../../devsecops/infraestructura-y-contenedores/seguridad-iac.md).

## Errores comunes

- Abrir SSH/RDP a `0.0.0.0/0` "solo un momento" para depurar y olvidarlo.
- Creer que una subnet es privada porque se llama `private`: lo que cuenta son sus **rutas** y si los recursos tienen IP pública.
- Usar la default VPC o la red `default` en producción.
- Crear un private endpoint pero dejar el **acceso público del servicio** activado: el endpoint no lo desactiva solo.
- Olvidar el DNS de los endpoints privados (zonas privadas de Private Link), con lo que las aplicaciones siguen resolviendo la IP pública.
- Activar flow logs sin retención ni nadie que los consulte, o solo en una región.
- Poner el WAF en modo bloqueo el primer día y desactivarlo por falsos positivos, en lugar de empezar en modo detección.
- Permitir todo el egress "porque es saliente": es justo el camino de la exfiltración.
- Mantener reglas con rangos amplios (`10.0.0.0/8`) que convierten la segmentación en decorado.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Networking (la base) | Firewalls stateful, DMZ, microsegmentación, zero trust; hub-and-spoke; troubleshooting con flow logs | [Seguridad de red](../../networking/avanzado/seguridad-red.md), [Redes de datacenter e híbridas](../../networking/avanzado/redes-datacenter-hibridas.md), [Troubleshooting de red](../../networking/avanzado/troubleshooting-red.md) |
| Cloud (el control) | Cómo se arma la red; WAF y detección; guardrails de organización; el resto del bloque de seguridad | [Redes en la nube](../redes-y-datos/redes.md), [Seguridad base](../identidad-y-seguridad/seguridad-base.md), [Gobernanza](../operacion-y-gobierno/gobernanza.md), [Fundamentos de seguridad cloud](fundamentos-seguridad-cloud.md), [Seguridad de máquinas virtuales](seguridad-maquinas-virtuales.md), [Seguridad de APIs y aplicaciones](seguridad-apis-aplicaciones.md) |
| DevOps (la automatización) | Definir VPC, reglas y endpoints como código | [Infrastructure as Code](../../devops/iac/infraestructura-como-codigo.md), [Terraform](../../devops/iac/terraform-basico.md) |
| DevSecOps (la verificación) | Detectar reglas abiertas a `0.0.0.0/0` en el pipeline y en la cuenta; network policies dentro del clúster | [Seguridad de IaC](../../devsecops/infraestructura-y-contenedores/seguridad-iac.md), [CSPM](../../devsecops/escaneos/cspm.md), [Seguridad de Kubernetes](../../devsecops/infraestructura-y-contenedores/seguridad-kubernetes.md), [Cumplimiento y gobierno](../../devsecops/gobierno-y-respuesta/cumplimiento.md) |

## Referencias

- [Security best practices for your VPC (AWS)](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [VPC Block Public Access](https://docs.aws.amazon.com/vpc/latest/userguide/security-vpc-bpa.html)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [AWS Foundational Security Best Practices: controles de Amazon EC2](https://docs.aws.amazon.com/securityhub/latest/userguide/ec2-controls.html)
- [AWS Shield](https://docs.aws.amazon.com/waf/latest/developerguide/shield-chapter.html)
- [Procedimientos recomendados de seguridad de red de Azure](https://learn.microsoft.com/es-es/azure/security/fundamentals/network-best-practices)
- [Microsoft Cloud Security Benchmark: seguridad de red](https://learn.microsoft.com/es-es/security/benchmark/azure/mcsb-network-security)
- [Registros de flujo de red virtual](https://learn.microsoft.com/es-es/azure/network-watcher/vnet-flow-logs-overview)
- [Azure Bastion](https://learn.microsoft.com/es-es/azure/bastion/bastion-overview)
- [Recomendaciones de redes de Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/recommendations-reference-networking)
- [Best practices for VPC network design (Google Cloud)](https://cloud.google.com/architecture/best-practices-vpc-design)
- [Cloud Next Generation Firewall](https://cloud.google.com/firewall/docs/about-firewalls)
- [Use IAP for TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)
- [VPC Service Controls](https://cloud.google.com/vpc-service-controls/docs/overview)
- [Security Health Analytics findings](https://cloud.google.com/security-command-center/docs/concepts-vulnerabilities-findings)
- [CIS Benchmarks (Foundations de AWS, Azure y Google Cloud)](https://www.cisecurity.org/cis-benchmarks)
