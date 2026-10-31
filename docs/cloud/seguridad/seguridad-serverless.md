---
tags:
  - seguridad
  - cloud
  - aws
  - azure
  - gcp
  - serverless
---

# Seguridad serverless

> Cómo proteger funciones en AWS Lambda, Azure Functions y Cloud Run functions: identidad mínima por función, secretos, variables de entorno, red, triggers públicos y autenticación, concurrencia, dependencias, logs y firma de código.

!!! info "Antes de leer"
    En serverless el proveedor gestiona servidores, sistema operativo y runtime base. Según el [Shared Responsibility Model](../fundamentos/responsabilidad-compartida.md), **tú sigues siendo responsable** del código y sus dependencias, de la identidad y los permisos de la función, de quién puede invocarla, de los secretos y de los datos. Conviene haber leído [Serverless](../computo/serverless.md) (triggers, planes, límites); aquí se profundiza en los controles.

## Riesgos típicos

| Riesgo | Ejemplo o incidente conocido | Control que lo evita |
| --- | --- | --- |
| Función con permisos excesivos | Un rol compartido con `s3:*` o `Editor` convierte un fallo de inyección en acceso a toda la cuenta | Un rol/identidad por función con permisos mínimos |
| **Event injection** (inyección a través de eventos) | Datos de un evento (nombre de archivo de S3, mensaje de cola) usados sin validar en un comando o consulta | Validar y sanear toda entrada; no ejecutar comandos de shell con datos del evento |
| Endpoint público sin autenticación | Function URL con `AuthType NONE`, función HTTP `anonymous`, Cloud Run con `allUsers` como invoker | Autenticación por IAM o por token, API gateway delante, guardrails de organización |
| Secretos en variables de entorno en texto plano | Contraseñas visibles para cualquiera con permiso de leer la configuración de la función | Secretos en Secrets Manager / Key Vault / Secret Manager, leídos con la identidad de la función |
| Dependencias vulnerables o maliciosas | Paquetes de npm/PyPI comprometidos que acaban dentro del ZIP o del layer | SCA en el pipeline, escaneo del proveedor (Inspector Lambda), *pinning* de versiones |
| Malware dirigido a serverless | Denonia (2022), primer malware conocido diseñado para ejecutarse en AWS Lambda | Least privilege, detección (GuardDuty Lambda Protection), egress controlado |
| **Denial of wallet** (ataque al costo) | Invocaciones masivas que escalan la función sin límite y disparan la factura | Límites de concurrencia o de instancias, throttling en el API gateway, presupuestos y alertas |
| Código desplegado sin control | Alguien sube un ZIP modificado directamente a la función | Firma de código (Lambda code signing), despliegue solo desde el pipeline |
| Runtime fuera de soporte | Funciones en runtimes sin parches de seguridad | Inventario de runtimes y actualización planificada |

## Controles por proveedor

| Prioridad | Control | AWS Lambda | Azure Functions | Cloud Run functions |
| --- | --- | --- | --- | --- |
| **Imprescindible** | Identidad mínima por función | Execution role propio | Managed identity (system o user-assigned) | Service account de runtime dedicada (no la default de Compute Engine) |
| **Imprescindible** | Quién puede invocar | Resource-based policy (sin `Principal: "*"`), Function URL con `AWS_IAM` | `authLevel` (`function`/`admin`), App Service Authentication (Easy Auth), access restrictions | IAM `roles/run.invoker`, *ingress settings* |
| **Imprescindible** | Secretos fuera de variables en texto plano | Secrets Manager / Parameter Store (con la AWS Parameters and Secrets Lambda Extension) | Key Vault references (`@Microsoft.KeyVault(...)`) | Secret Manager montado como variable o volumen |
| **Imprescindible** | Runtime soportado | Runtimes no *deprecated* | Versiones de lenguaje y de runtime soportadas | Runtimes soportados (*runtime support schedule*) |
| **Imprescindible** | Logs | CloudWatch Logs (formato JSON), AWS X-Ray | Application Insights / Azure Monitor | Cloud Logging, Cloud Trace |
| Recomendado | Red privada | VPC configuration (ENIs en subnets privadas) | VNet integration (Flex Consumption, Premium, Dedicated) + private endpoints de entrada | Direct VPC egress o Serverless VPC Access connector; ingress `internal` |
| Recomendado | Limitar escala (costo y abuso) | Reserved concurrency | Maximum instance count / `functionAppScaleLimit` | `max-instances` |
| Recomendado | Cifrado de variables de entorno con CMK | `KMSKeyArn` (por defecto clave de AWS) | Configuración de la app cifrada en reposo; CMK con Key Vault para el almacenamiento | CMEK en Cloud Run functions |
| Recomendado | Firma e integridad del código | Lambda code signing (AWS Signer) | Despliegue solo con identidad (sin credenciales de publicación básicas) | Binary Authorization en Cloud Run |
| Recomendado | Escaneo de código y dependencias | Amazon Inspector (Lambda standard y code scanning) | Defender for Cloud (Defender for App Service) | Artifact Analysis sobre la imagen generada |
| Recomendado | Detección de amenazas | GuardDuty Lambda Protection | Microsoft Defender for App Service | Security Command Center |

!!! note "Cloud Run functions es Cloud Run"
    Desde 2024, **Cloud Functions (2nd gen)** se llama **Cloud Run functions**: cada función es un servicio de Cloud Run construido con Cloud Build y guardado en Artifact Registry. Por eso la invocación se controla con `roles/run.invoker`, el ingress es el de Cloud Run y valen sus controles (ver [Seguridad de contenedores y Kubernetes](seguridad-contenedores-kubernetes.md)).

## Buenas prácticas

1. **Una función, una identidad.** Permisos solo sobre los recursos concretos que usa (un bucket, una tabla, una cola), nunca comodines (ver [Seguridad de identidades](seguridad-identidades.md)).
2. **Nada público sin autenticación.** Si la función es una API, pon delante un API gateway con autenticación, WAF y throttling (ver [Seguridad de APIs y aplicaciones](seguridad-apis-aplicaciones.md)); si es interna, invocación solo por IAM.
3. **Secretos desde el gestor de secretos**, con caché en memoria y rotación; en variables de entorno solo el *nombre* o ARN del secreto (ver [Seguridad de cifrado y secretos](seguridad-cifrado-secretos.md)).
4. **Valida cada evento** como entrada no confiable, también los que vienen de servicios internos (colas, buckets, eventos de la nube).
5. **Limita la escala**: concurrencia o instancias máximas acordes con lo que soportan los sistemas de atrás, más presupuestos y alertas de costo.
6. **Dependencias mínimas y escaneadas.** Bloquea versiones (*lockfile*), escanea con SCA en el pipeline y revisa los layers o paquetes compartidos.
7. **Despliegue solo desde el pipeline**, con firma de código donde exista y sin credenciales de publicación de larga duración (ver [Seguridad del pipeline](../../devsecops/identidades-y-pipeline/seguridad-pipeline.md)).
8. **Red privada cuando la función accede a datos privados**; controla el egress igual que en cualquier otra carga (ver [Seguridad de redes en la nube](seguridad-redes.md)).
9. **Logs estructurados sin datos sensibles**, con retención definida y alertas sobre errores de autorización y picos de invocaciones.

=== "AWS"

    - Una **Function URL** con `AuthType NONE` es un endpoint público en internet. Usa `AWS_IAM` o pon CloudFront con *origin access control* delante.
    - Revisa la **resource-based policy** (`aws lambda get-policy`): un `Principal: "*"` sin condiciones (`aws:SourceArn`, `aws:SourceAccount`) permite que cualquiera la invoque.
    - **Lambda code signing**: creas un *signing profile* en AWS Signer y un *code signing config* con `UntrustedArtifactOnDeployment = Enforce`; Lambda rechaza paquetes ZIP no firmados por perfiles permitidos. No aplica a funciones desplegadas como imagen de contenedor.
    - Las variables de entorno se cifran en reposo con una clave de AWS; con una CMK controlas quién puede descifrarlas, pero **siguen visibles para quien puede leer la configuración**: no son un lugar para secretos.
    - Una función en VPC necesita NAT o VPC endpoints para llegar a otros servicios de AWS.

=== "Azure"

    - Para apps nuevas en Linux, Microsoft recomienda el plan **Flex Consumption**, que admite VNet integration; el plan Consumption clásico no la admite.
    - `authLevel: function` exige una *function key*, que es un secreto compartido: para APIs expuestas prefiere **App Service Authentication** (Microsoft Entra ID) o API Management delante.
    - Usa **identity-based connections** para triggers y bindings (por ejemplo `AzureWebJobsStorage__accountName`) en vez de cadenas de conexión con claves.
    - Desactiva **FTP/FTPS** y las **basic auth publishing credentials**, `httpsOnly = true`, TLS mínimo 1.2, sin *remote debugging* y CORS con orígenes concretos.

=== "Google Cloud"

    - Por defecto la función corre con la **Compute Engine default service account**; asigna una service account propia con solo los roles que necesita.
    - Separa la **build service account** (la que usa Cloud Build para construir la función) de la de runtime y dale permisos mínimos.
    - `--no-allow-unauthenticated` en el despliegue y `ingress_settings = ALLOW_INTERNAL_ONLY` o `ALLOW_INTERNAL_AND_GCLB` para funciones que no deben ser públicas.
    - Los triggers de Eventarc invocan la función con su propia service account, que necesita `roles/run.invoker` sobre ella.
    - Monta secretos con versión fija (no `latest`) si quieres despliegues reproducibles; con `latest` la función toma la versión vigente al arrancar cada instancia.

## Cómo verificarlo

Solo comandos de lectura.

=== "AWS"

    ```bash
    # Runtime, rol, VPC, CMK y layers de una función
    aws lambda get-function-configuration --function-name <funcion> --query \
      "{runtime:Runtime,rol:Role,subnets:VpcConfig.SubnetIds,kms:KMSKeyArn,layers:Layers[].Arn,firma:SigningProfileVersionArn}"

    # ¿Quién puede invocarla? ¿Tiene Function URL pública?
    aws lambda get-policy --function-name <funcion> --query Policy --output text
    aws lambda list-function-url-configs --function-name <funcion> --query "FunctionUrlConfigs[].{url:FunctionUrl,auth:AuthType}"

    # Concurrencia reservada y code signing
    aws lambda get-function-concurrency --function-name <funcion>
    aws lambda get-function-code-signing-config --function-name <funcion>

    # Inventario de runtimes de todas las funciones de la región
    aws lambda list-functions --query "Functions[].{f:FunctionName,runtime:Runtime}" --output table
    ```

=== "Azure"

    ```bash
    # HTTPS, identidad y acceso público
    az functionapp show -g <rg> -n <app> --query \
      "{httpsOnly:httpsOnly,identidad:identity.type,accesoPublico:publicNetworkAccess,subnet:virtualNetworkSubnetId}"

    # TLS, FTPS, remote debugging y CORS
    az functionapp config show -g <rg> -n <app> --query \
      "{tls:minTlsVersion,ftps:ftpsState,remoteDebug:remoteDebuggingEnabled,cors:cors.allowedOrigins}"

    # Autenticación integrada (Easy Auth)
    az webapp auth show -g <rg> -n <app>

    # Solo los NOMBRES de las app settings (los valores pueden ser secretos)
    az functionapp config appsettings list -g <rg> -n <app> --query "[].name" -o tsv
    ```

=== "Google Cloud"

    ```bash
    # Service account, ingress, conector de VPC, instancias máximas y secretos
    gcloud functions describe <funcion> --region <region> --format="yaml(
      serviceConfig.serviceAccountEmail, serviceConfig.ingressSettings,
      serviceConfig.vpcConnector, serviceConfig.maxInstanceCount,
      serviceConfig.secretEnvironmentVariables, buildConfig.serviceAccount)"

    # ¿Quién puede invocarla? Buscar allUsers o allAuthenticatedUsers
    gcloud run services get-iam-policy <funcion> --region <region>

    # Hallazgos de secretos en variables de entorno (requiere el detector de Sensitive Data Protection)
    gcloud scc findings list organizations/<org-id> --location=global \
      --filter='category="SECRETS_IN_ENVIRONMENT_VARIABLES" AND state="ACTIVE"'
    ```

| Control | AWS Security Hub CSPM | Microsoft Defender for Cloud (MCSB) | Security Command Center |
| --- | --- | --- | --- |
| Invocación pública | Lambda.1 | — (revisa `authLevel`, Easy Auth y acceso público) | `EXTERNALLY_EXPOSED_SERVERLESS_WORKLOAD` (Cloud Run) |
| Runtime soportado | Lambda.2 | — | — |
| Alta disponibilidad en VPC | Lambda.5 | — | — |
| Secretos en variables | — | — | `SECRETS_IN_ENVIRONMENT_VARIABLES` |
| HTTPS y configuración web | — | *Function App should only be accessible over HTTPS*; *FTPS should be required in function apps*; *Remote debugging should be turned off for Function App*; *CORS should not allow every resource to access Function Apps*; *TLS should be updated to the latest version for function apps*; *Function apps should have Client Certificates (Incoming client certificates) enabled* | — |
| Identidad | — | *Managed identity should be used in function apps* | `DEFAULT_SERVICE_ACCOUNT_USED` (VMs; en funciones revisa la service account a mano) |
| Escaneo y detección | Inspector.3, Inspector.4, GuardDuty.6 | *Microsoft Defender for App Service should be enabled* | — |

!!! warning "Revisa los IDs y nombres"
    Los catálogos de controles cambian: AWS añade y retira controles, Microsoft renombra recomendaciones y Google añade detectores. No hay un control de FSBP para Lambda code signing ni para function URLs públicas con `AuthType NONE`: compruébalos con los comandos de arriba o con una regla de AWS Config propia.

## Configuración segura con IaC

Los fragmentos de Terraform con estos controles (y los guardrails de organización, cuando aplican) están en las páginas por proveedor: [AWS](terraform/aws.md#serverless), [Azure](terraform/azure.md#serverless) y [Google Cloud](terraform/google-cloud.md#serverless).

## Errores comunes

- Reutilizar un mismo rol "lambda-role" con permisos amplios para todas las funciones.
- Guardar la contraseña de la base de datos como variable de entorno "porque está cifrada en reposo".
- Exponer una función con Function URL `NONE`, `authLevel: anonymous` o `allUsers` para "probar" y llevarla así a producción.
- No poner límite de concurrencia/instancias y descubrir el problema en la factura o tumbando la base de datos.
- Meter dependencias completas (y vulnerables) en un layer compartido que nadie actualiza.
- Registrar el evento completo en los logs, con tokens, datos personales o tarjetas incluidos.
- Dejar funciones en runtimes *deprecated* porque "siguen funcionando".
- Olvidar que la service account por defecto de Compute Engine es la identidad de las funciones en Google Cloud.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Qué es serverless y sus límites; identidad, secretos, APIs y red de la función | [Serverless](../computo/serverless.md), [Seguridad de identidades](seguridad-identidades.md), [Seguridad de cifrado y secretos](seguridad-cifrado-secretos.md), [Seguridad de APIs y aplicaciones](seguridad-apis-aplicaciones.md), [Seguridad de redes](seguridad-redes.md), [Fundamentos de seguridad cloud](fundamentos-seguridad-cloud.md), [FinOps y costos](../fundamentos/finops-costos.md) (el costo como superficie de ataque) |
| DevOps (la automatización) | Empaquetar, firmar y desplegar funciones desde el pipeline | [Despliegue continuo](../../devops/ci-cd/despliegue-continuo.md), [Integración continua](../../devops/ci-cd/integracion-continua.md), [Infrastructure as Code](../../devops/iac/infraestructura-como-codigo.md) |
| DevSecOps (la verificación) | SCA de dependencias, secretos en el código, permisos del pipeline, pruebas de la API | [Software supply chain](../../devsecops/codigo-y-dependencias/cadena-suministro.md), [SCA](../../devsecops/escaneos/sca.md), [Secret scanning](../../devsecops/escaneos/secret-scanning.md), [Seguridad del pipeline](../../devsecops/identidades-y-pipeline/seguridad-pipeline.md), [Pruebas dinámicas](../../devsecops/codigo-y-dependencias/pruebas-dinamicas.md) |

## Referencias

- [Security in AWS Lambda](https://docs.aws.amazon.com/lambda/latest/dg/lambda-security.html)
- [Configuring code signing for Lambda](https://docs.aws.amazon.com/lambda/latest/dg/configuration-codesigning.html)
- [Security and auth model for Lambda function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html)
- [Security Hub CSPM: controles de Lambda](https://docs.aws.amazon.com/securityhub/latest/userguide/lambda-controls.html)
- [Protección de Azure Functions](https://learn.microsoft.com/es-es/azure/azure-functions/security-concepts)
- [Plan Flex Consumption de Azure Functions](https://learn.microsoft.com/es-es/azure/azure-functions/flex-consumption-plan)
- [Referencias de Key Vault en App Service y Azure Functions](https://learn.microsoft.com/es-es/azure/app-service/app-service-key-vault-references)
- [Recomendaciones de App Service de Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/recommendations-reference-app-services)
- [Cloud Run functions: secure your function](https://cloud.google.com/run/docs/securing/managing-access)
- [Configure secrets for Cloud Run](https://cloud.google.com/run/docs/configuring/services/secrets)
- [Restricting ingress for Cloud Run](https://cloud.google.com/run/docs/securing/ingress)
- [OWASP Serverless Top 10](https://owasp.org/www-project-serverless-top-10/)
