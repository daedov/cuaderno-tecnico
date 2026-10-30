---
tags:
  - seguridad
  - cloud
  - aws
  - azure
  - gcp
  - apis
---

# Seguridad de APIs y aplicaciones expuestas

> Cómo proteger lo que publicas a internet con Amazon API Gateway, Azure API Management y Apigee / API Gateway de Google Cloud: autenticación (JWT, OAuth 2.0, mTLS), autorización, rate limiting, WAF delante, validación de esquemas, CORS y logs; identidad de usuarios finales con Amazon Cognito, Microsoft Entra External ID e Identity Platform; y CDN con WAF. Con el OWASP API Security Top 10 como guía.

!!! info "Antes de leer"
    El proveedor opera el gateway, el WAF y el servicio de identidad, y absorbe parte de los ataques DDoS. **Tú decides qué rutas exigen autenticación, qué puede hacer cada token, cuántas peticiones aceptas y qué reglas aplica el WAF**; y la autorización a nivel de objeto sigue siendo cosa de tu código (ver [Shared Responsibility Model](../fundamentos/responsabilidad-compartida.md)). Conviene haber leído [Integración y APIs](../arquitectura/integracion-apis.md) (REST, API gateway, diseño) y [Seguridad de redes](seguridad-redes.md) (WAF y DDoS en el borde).

## Riesgos típicos

| Riesgo (OWASP API Security Top 10 2023) | Ejemplo o incidente conocido | Control que lo evita |
| --- | --- | --- |
| **API1** Broken Object Level Authorization (BOLA) | Cambiar `/pedidos/1001` por `/pedidos/1002` y ver el pedido de otro cliente | Autorización por objeto **en el código**; el gateway no la resuelve |
| **API2** Broken Authentication | Optus (2022): un endpoint de API accesible sin autenticación devolvía datos de clientes con IDs secuenciales | Autenticación obligatoria en todas las rutas (JWT / OAuth 2.0 / mTLS); nada de "endpoints internos" públicos |
| **API3** Broken Object Property Level Authorization | La API devuelve el objeto completo con campos internos, o acepta `"rol": "admin"` en el cuerpo | Validación de esquema de petición y respuesta; DTOs explícitos |
| **API4** Unrestricted Resource Consumption | Scraping masivo, facturas disparadas en funciones serverless | Rate limiting, cuotas, tamaño máximo de petición, timeouts |
| **API5** Broken Function Level Authorization | Usuario normal que llama a `DELETE /admin/usuarios` | Scopes / roles por ruta en el gateway + comprobación en el backend |
| **API6** Unrestricted Access to Sensitive Business Flows | Bots que compran todo el stock o crean miles de cuentas | Bot control, CAPTCHA, límites por usuario y por flujo |
| **API7** Server Side Request Forgery (SSRF) | Parámetro `url=` que hace que el servidor llame al servicio de metadatos | Validar destinos, IMDSv2, egress restringido |
| **API8** Security Misconfiguration | CORS con `*` y credenciales, TLS 1.0 activo, errores con stack traces | Políticas de TLS mínimas, CORS estricto, respuestas de error genéricas |
| **API9** Improper Inventory Management | Una `v1` olvidada sin los controles de la `v2` | Inventario de APIs y stages, retirar versiones, *shadow APIs* detectadas |
| **API10** Unsafe Consumption of APIs | Confiar ciegamente en respuestas de un tercero | Validar y sanear lo que viene de otras APIs; timeouts |

!!! warning "Una API key no es autenticación"
    Las API keys de API Gateway, las *subscription keys* de API Management y las API keys de Google identifican **a la aplicación cliente** para cuotas y analítica. No identifican a un usuario, se filtran con facilidad y no caducan solas. Úsalas como complemento, nunca como único control.

## Controles por proveedor

**(I)** = imprescindible.

| Control | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| Gateway | **Amazon API Gateway** (REST, HTTP y WebSocket APIs) | **Azure API Management** | **Apigee** (gestión completa) y **API Gateway** (ligero, para backends serverless) |
| **(I)** Autenticación de llamadas | JWT authorizer (HTTP APIs), Cognito authorizer, Lambda authorizer, IAM (SigV4) | Políticas `validate-jwt` / `validate-azure-ad-token`, `validate-client-certificate` | Apigee: OAuthV2, VerifyJWT, VerifyAPIKey; API Gateway: JWT en `securityDefinitions` |
| mTLS de clientes | Mutual TLS en *custom domain* (truststore en S3) | Certificados de cliente en API Management | mTLS en el Application Load Balancer (delante de Apigee) |
| **(I)** Autorización por ruta | Scopes en rutas con JWT/Cognito; Lambda authorizer con política | `required-claims` en `validate-jwt`; productos y suscripciones por API | Scopes y condiciones en políticas de Apigee |
| **(I)** Rate limiting y cuotas | Throttling por cuenta, stage y ruta; *usage plans* | `rate-limit-by-key`, `quota-by-key` | Apigee: SpikeArrest, Quota; API Gateway: cuotas por API key |
| **(I)** WAF delante | **AWS WAF** asociado al stage (REST) o a CloudFront | **Azure Web Application Firewall** en Application Gateway o Front Door | **Google Cloud Armor** en el load balancer |
| Validación de peticiones | *Request validators* con modelos JSON Schema (REST) | `validate-content`, `validate-parameters`, `validate-headers` contra la definición OpenAPI | Apigee: OASValidation |
| CORS | Configuración CORS (HTTP API) o respuestas OPTIONS (REST) | Política `cors` | Apigee: CORS policy |
| **(I)** Logs | Access logs + execution logs a CloudWatch Logs | Diagnostic settings (GatewayLogs) a Log Analytics, Application Insights | Apigee Analytics + Cloud Logging; API Gateway en Cloud Logging |
| **(I)** TLS mínimo | *Security policy* TLS 1.2 en custom domains | TLS 1.0/1.1 y SSL 3.0 deshabilitados (por defecto en instancias nuevas) | SSL policy del load balancer con TLS 1.2 mínimo |
| Exposición privada | Private APIs (VPC endpoint `execute-api`), resource policies | Modo VNet *Internal*, private endpoint | Apigee con acceso privado (PSC); API Gateway detrás de LB interno según el caso |
| Credenciales hacia el backend | IAM role de la integración, VPC Link | **Managed identity** (`authentication-managed-identity`), named values en Key Vault | Service account del proxy, Secret Manager |
| Protección específica de APIs | AWS WAF Bot Control y Fraud Control | **Microsoft Defender for APIs** | **Advanced API Security** de Apigee |
| Identidad de usuarios finales | **Amazon Cognito** (user pools) | **Microsoft Entra External ID** | **Identity Platform** (o Firebase Authentication) |
| CDN con WAF | CloudFront + AWS WAF + AWS Shield | Azure Front Door + WAF + Azure DDoS Protection | Cloud CDN / external Application Load Balancer + Cloud Armor |

!!! note "Azure AD B2C"
    Microsoft dejó de vender Azure AD B2C a clientes nuevos en 2025; para aplicaciones nuevas de clientes externos la opción es **Microsoft Entra External ID**. Los tenants B2C existentes siguen funcionando (revisa las fechas de soporte vigentes).

## Buenas prácticas

1. **Autenticación en todas las rutas** por defecto. Si una ruta es pública (salud, catálogo), que sea una excepción explícita y revisada.
2. **Tokens cortos y validados de verdad**: firma, emisor (`iss`), audiencia (`aud`), expiración (`exp`) y scopes. Usa OAuth 2.0 / OpenID Connect con el proveedor de identidad; no inventes tu propio esquema.
3. **Autorización en dos capas**: el gateway rechaza lo que no tiene el scope; el backend comprueba que el objeto pertenece a quien lo pide (BOLA). Ver [Pruebas dinámicas](../../devsecops/codigo-y-dependencias/pruebas-dinamicas.md) para probarlo.
4. **Límites siempre**: rate limit por cliente o usuario, cuotas y tamaño máximo de cuerpo. Protegen de abuso y de facturas sorpresa (ver [FinOps y costos](../fundamentos/finops-costos.md)).
5. **WAF con reglas gestionadas** (OWASP, IP reputation, bots) delante de cada API pública; empieza en modo *count/detection*, revisa falsos positivos y pasa a bloqueo.
6. **Valida contra el contrato** OpenAPI: tipos, campos obligatorios, campos no permitidos.
7. **CORS mínimo**: orígenes concretos, métodos concretos, nunca `*` con credenciales.
8. **Logs con identidad**: request ID, IP, usuario (`sub`), ruta y estado; sin tokens ni datos personales en claro. Envíalos a la cuenta de logs central ([Logging y detección](seguridad-logging-deteccion.md)).
9. **Inventario de APIs**: cada stage y versión, con dueño. Retira lo que no se usa.
10. **Backends no alcanzables saltándose el gateway**: integración privada, o el backend solo acepta tráfico del gateway (resource policy, ingress interno, identidad).

=== "AWS"

    - **HTTP APIs** con JWT authorizer apuntando al user pool de Cognito (o a tu IdP OIDC); **REST APIs** cuando necesites WAF directo en el stage, request validation, usage plans o private APIs.
    - Protege el user pool: MFA, *threat protection* de Cognito y políticas de contraseña fuertes; identity pools sin identidades no autenticadas salvo que haga falta.
    - Una Lambda authorizer es código tuyo: cachea con cuidado (la caché se indexa por la fuente de identidad) y falla cerrado.
    - Si publicas por CloudFront, impide el acceso directo al endpoint del API (resource policy o cabecera secreta comprobada en el WAF del stage).

=== "Azure"

    - Define las políticas a nivel **global o de producto** y que las APIs hereden con `<base />`; así nadie publica una API sin JWT ni límites.
    - Usa **managed identity** de API Management para llamar al backend y guarda los secretos como *named values* referenciados a Key Vault.
    - Despliega en modo VNet **Internal** con Application Gateway + WAF delante, o Front Door + WAF con Private Link.
    - Desactiva la autenticación por usuario y contraseña del portal y el endpoint de administración directa si no los usas.
    - Activa **Defender for APIs** para inventario, detección de anomalías y datos sensibles en las APIs publicadas.

=== "Google Cloud"

    - **Apigee** para APIs de negocio con muchos consumidores (OAuth, cuotas, monetización, Advanced API Security); **API Gateway** para exponer Cloud Run o Cloud Run functions con JWT y API keys de forma sencilla.
    - Pon un **external Application Load Balancer + Cloud Armor** delante de Apigee (reglas WAF preconfiguradas, rate-based ban, Adaptive Protection).
    - Los backends de Cloud Run detrás del gateway: ingress interno o *require authentication* con la service account del gateway como invocador.
    - Restringe las API keys de Google a APIs y orígenes concretos y rótalas.

## Cómo verificarlo

=== "AWS"

    ```bash
    # Rutas de una HTTP API y su tipo de autorización (NONE = abierta)
    aws apigatewayv2 get-routes --api-id a1b2c3 --query "Items[].{ruta:RouteKey, auth:AuthorizationType}" --output table

    # Stages de una REST API: WAF asociado, logs y throttling
    aws apigateway get-stages --rest-api-id x9y8z7 --query "item[].{stage:stageName, waf:webAclArn, ajustes:methodSettings}"

    # Política TLS de los dominios personalizados
    aws apigateway get-domain-names --query "items[].{dominio:domainName, tls:securityPolicy}"

    # Cognito: MFA y protección contra amenazas
    aws cognito-idp describe-user-pool --user-pool-id us-east-1_AbCdEf --query "UserPool.{mfa:MfaConfiguration, proteccion:UserPoolAddOns}"
    ```

=== "Azure"

    ```bash
    az apim show -g rg-api -n apim-acme --query "{red:virtualNetworkType, publica:publicNetworkAccess}"

    # APIs que no exigen suscripción y protocolos permitidos
    az apim api list -g rg-api --service-name apim-acme --query "[].{api:name, suscripcion:subscriptionRequired, protocolos:protocols}" -o table

    # Plan de Defender for APIs
    az security pricing show -n Api
    ```

=== "Google Cloud"

    ```bash
    # Configuración desplegada en API Gateway (incluye la especificación OpenAPI)
    gcloud api-gateway api-configs describe pedidos-v3 --api=pedidos --view=FULL

    # Políticas de Cloud Armor y backend al que protegen
    gcloud compute security-policies list
    gcloud compute backend-services describe apigee-backend --global --format="value(securityPolicy)"

    # API keys sin restricciones
    gcloud services api-keys list --format="table(displayName, restrictions)"
    ```

| Control | AWS Security Hub CSPM | Azure (MCSB / Azure Policy) | Security Command Center |
| --- | --- | --- | --- |
| Autenticación en rutas | **APIGateway.8** | "API Management calls to API backends should be authenticated" | — |
| WAF delante | **APIGateway.4** | "Azure Web Application Firewall should be enabled for Azure Front Door entry-points" | — |
| Logs | **APIGateway.1**, APIGateway.9 | — | — |
| TLS | APIGateway.11, APIGateway.2 | "API Management APIs should use only encrypted protocols" | — |
| Exposición de red | — | "API Management services should use a virtual network", "API Management should disable public network access to the service configuration endpoints" | — |
| Secretos | — | "API Management secret named values should be stored in Azure Key Vault" | — |
| Alcance de suscripciones | — | "API Management subscriptions should not be scoped to all APIs" | — |
| Identidad de usuarios | Cognito.1, Cognito.2, Cognito.5 | — | — |
| API keys | — | — | `API_KEY_APIS_UNRESTRICTED`, `API_KEY_APPS_UNRESTRICTED`, `API_KEY_NOT_ROTATED` |

Los checks de postura no ven la lógica (BOLA, BFLA): para eso están las pruebas dinámicas contra la API. Ver [DAST](../../devsecops/escaneos/dast.md).

## Configuración segura con IaC

=== "AWS"

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

=== "Azure"

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

=== "Google Cloud"

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

Como guardrail, en Azure asigna con efecto `Deny` "API Management services should use a virtual network" y "API Management subscriptions should not be scoped to all APIs". En AWS y Google Cloud no hay una restricción de organización equivalente: el control se hace en el pipeline (escaneo de IaC que exija authorizer y WAF) y con CSPM.

## Errores comunes

- Rutas con `AuthorizationType = NONE` que "solo usa el frontend".
- Validar la firma del JWT pero no la audiencia: cualquier token del mismo IdP para otra aplicación sirve.
- Confiar en la API key como autenticación, o meterla en el código del frontend creyendo que es secreta.
- CORS `*` como solución rápida a un error del navegador.
- WAF en modo detección durante meses sin que nadie mire los logs.
- Exponer el backend (Cloud Run, Lambda function URL, App Service) además del gateway, sin restringirlo.
- Sin límites de tasa en endpoints de login, registro o recuperación de contraseña.
- Logs con el header `Authorization` completo o con datos personales.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Diseño de APIs, gateway y estilos de integración | [Integración y APIs](../arquitectura/integracion-apis.md), [Arquitecturas de referencia](../arquitectura/arquitecturas-referencia.md) |
| Cloud (el control) | WAF, DDoS, identidades y backends serverless | [Seguridad de redes](seguridad-redes.md), [Seguridad de identidades](seguridad-identidades.md), [Seguridad serverless](seguridad-serverless.md), [Seguridad de servicios de IA](seguridad-servicios-ia.md) |
| DevOps (la automatización) | Publicar APIs y políticas desde el pipeline | [Despliegue continuo](../../devops/ci-cd/despliegue-continuo.md), [Infrastructure as Code](../../devops/iac/infraestructura-como-codigo.md) |
| DevSecOps (la verificación) | Probar autenticación, BOLA y abuso contra la API | [Pruebas dinámicas](../../devsecops/codigo-y-dependencias/pruebas-dinamicas.md), [DAST](../../devsecops/escaneos/dast.md), [Fundamentos DevSecOps](../../devsecops/fundamentos-devsecops.md) |
| Networking (la base) | TLS, HTTP, proxies y WAF | [Protocolos de aplicación](../../networking/intermedio/protocolos-aplicacion.md), [Seguridad de red](../../networking/avanzado/seguridad-red.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 15: DAST con OWASP ZAP sobre OWASP Juice Shop](../../laboratorios/devsecops/dast-zap-juice-shop.md) |

## Referencias

- [OWASP API Security Top 10 (2023)](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
- [Security in Amazon API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/security.html)
- [Controlling access to HTTP APIs with JWT authorizers](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-jwt-authorizer.html)
- [Security Hub CSPM controls for API Gateway](https://docs.aws.amazon.com/securityhub/latest/userguide/apigateway-controls.html)
- [Security features of Amazon Cognito](https://docs.aws.amazon.com/cognito/latest/developerguide/security.html)
- [Azure security baseline for API Management](https://learn.microsoft.com/security/benchmark/azure/baselines/api-management-security-baseline)
- [API Management policy reference](https://learn.microsoft.com/azure/api-management/api-management-policies)
- [Microsoft Defender for APIs](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-apis-introduction)
- [Microsoft Entra External ID](https://learn.microsoft.com/entra/external-id/)
- [Apigee: security overview](https://cloud.google.com/apigee/docs/api-platform/security/security-overview)
- [API Gateway: authenticating users](https://cloud.google.com/api-gateway/docs/authenticating-users-firebase)
- [Google Cloud Armor: preconfigured WAF rules](https://cloud.google.com/armor/docs/waf-rules)
