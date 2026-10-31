---
tags:
  - aws
  - certificacion
  - saa-c03
  - seguridad
  - iam
---

# Dominio 1: Design Secure Architectures (30%)

> El dominio con más peso: acceso seguro a recursos con IAM y multi-cuenta, cargas de trabajo protegidas en la VPC y en el borde, y controles de datos con cifrado, gestión de claves y backups.

!!! info "Qué evalúa este dominio"
    - **Task 1.1 – Design secure access to AWS resources**: mínimo privilegio, roles y STS entre cuentas, multi-cuenta con Organizations y SCPs, resource policies y federación.
    - **Task 1.2 – Design secure workloads and applications**: segmentación de la VPC, endpoints, Cognito, WAF/Shield, detección de amenazas, VPN y Direct Connect.
    - **Task 1.3 – Determine appropriate data security controls**: cifrado en reposo (KMS) y en tránsito (ACM/TLS), rotación de claves y certificados, backups, retención y cumplimiento.

    Formato y resto de dominios en el [resumen del examen](resumen-examen.md).

## IAM: identidades y tipos de políticas

Usuarios, grupos, roles, MFA y root están en [Cloud Practitioner](../cloud-practitioner/dominio-2-seguridad-cumplimiento.md#gestion-de-identidades-y-accesos). Regla de diseño: personas por **IAM Identity Center**, aplicaciones con **roles** y credenciales temporales de **AWS STS** (instance profile en EC2, execution role en Lambda, task role en ECS).

| Tipo de política | Se adjunta a | ¿Concede? | Para qué |
| --- | --- | --- | --- |
| **Identity-based** | Usuario, grupo o rol | Sí | Qué puede hacer esa identidad |
| **Resource-based** | Bucket S3, cola SQS, clave KMS, Lambda | Sí, incluso a otras cuentas | Quién usa el recurso; lleva `Principal` |
| **Permissions boundary** (límite de permisos) | Usuario o rol | No, solo limita | Delegar la creación de roles sin escalar privilegios |
| **SCP** (service control policy) | Cuenta u OU | No, solo limita | Guardrail (barrera) para las cuentas miembro, incluido su root |
| **RCP** (resource control policy) | Cuenta u OU | No, solo limita | Perímetro de datos sobre los recursos de la organización |
| **Session policy** | Sesión al asumir un rol | No, solo limita | Reducir permisos de una sesión concreta |

**Evaluación**: todo empieza denegado; un **explicit deny** gana siempre; las políticas que solo limitan deben permitir la acción (intersección) y una identity-based **o** resource-based debe concederla. **Entre cuentas** hacen falta las dos partes: origen y destino.

!!! tip "En el examen"
    - Las SCPs **no afectan a la management account** (cuenta de administración) y **no conceden** permisos: si una pregunta propone "dar acceso con una SCP", es incorrecta.
    - "Los desarrolladores deben poder crear roles para sus Lambdas, pero sin superar ciertos permisos" → **permissions boundary**.
    - "Impedir que cualquier cuenta de la organización use regiones fuera de la UE" → **SCP** con `aws:RequestedRegion`.

### Acceso entre cuentas (cross-account)

- Rol en B con **trust policy** (política de confianza) que nombra a A; la identidad de A necesita `sts:AssumeRole`. Para un SaaS de terceros, añade **External ID** (evita el *confused deputy*).
- Alternativa en S3, SQS, SNS o KMS: **resource-based policy**. La identidad conserva sus permisos; al asumir un rol, los cambia por los del rol.

### Federación e identidades de usuarios

| Necesidad | Servicio |
| --- | --- |
| Empleados con usuario corporativo (Entra ID, Okta, AD) en muchas cuentas | **IAM Identity Center** con permission sets (SAML 2.0 + SCIM) |
| Apps en AWS que necesitan AD real (Kerberos, GPO) | **AWS Managed Microsoft AD** |
| Usar el AD on-premises sin copiar usuarios | **AD Connector** (proxy) |
| Usuarios finales de una app web o móvil | **Cognito user pools** |
| Esos usuarios acceden **directamente** a S3 o DynamoDB | **Cognito identity pools** |

!!! tip "En el examen: Cognito"
    **User pool = autenticación** (quién eres; devuelve tokens JWT). **Identity pool = autorización a recursos AWS** (credenciales temporales de un rol IAM). Muchas apps usan los dos.

## Estrategia multi-cuenta

La cuenta es el límite de seguridad más fuerte de AWS (teoría en [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md#estrategia-multi-cuenta)). **AWS Organizations** aporta OUs, consolidated billing, SCPs y RCPs; **AWS Control Tower** despliega una **landing zone** con cuentas de log archive y audit, guardrails preventivos (SCP) y detectivos (Config) y Account Factory; **AWS RAM** (Resource Access Manager) comparte recursos entre cuentas sin duplicarlos (subnets, Transit Gateway, reglas de Route 53 Resolver), y un **CloudTrail organization trail** lleva los logs de todas las cuentas a un bucket central.

## Seguridad de red en la VPC

La tabla básica está en [Security groups vs network ACLs](../cloud-practitioner/dominio-3-tecnologia-servicios.md#security-groups-vs-network-acls). Lo que añade SAA: la NACL, por ser stateless, necesita reglas de retorno para los **puertos efímeros** (1024–65535) y evalúa en orden por número (gana la primera que coincide); el security group puede usar **otro security group como origen**, la NACL solo CIDR.

!!! tip "En el examen"
    "Bloquear una IP maliciosa concreta" → **NACL** (los security groups no tienen deny). "Permitir que solo la capa de aplicación llegue a la base de datos" → regla en el security group de la DB con **origen = security group de la app**.

**Segmentación típica**: subnets públicas (ruta `0.0.0.0/0` → Internet Gateway) solo para load balancers y NAT gateways; subnets privadas para aplicación y datos, que salen por el **NAT gateway**. Para administrar instancias privadas sin bastion ni puerto 22: **Systems Manager Session Manager**.

### VPC endpoints y PrivateLink

Llegar a servicios de AWS **sin pasar por internet ni por el NAT gateway**.

| Aspecto | Gateway endpoint | Interface endpoint (AWS PrivateLink) |
| --- | --- | --- |
| Servicios | Solo **S3 y DynamoDB** | Casi todos los de AWS, SaaS y tus propios servicios |
| Cómo funciona | Entrada en la **route table** | **ENI con IP privada** en tu subnet |
| Costo | Sin cargo | Por hora por AZ + por GB procesado |
| Acceso desde on-premises (VPN/DX) o desde otra región | No | Sí |
| Control | Endpoint policy | Endpoint policy + security group |

- Forzar en la **bucket policy** el acceso solo desde un endpoint: condición `aws:SourceVpce`.
- **Exponer tu propio servicio** a otras VPC o cuentas sin peering ni solapamiento de CIDR: **endpoint service** detrás de un **Network Load Balancer** (o Gateway Load Balancer).

### Conexiones externas seguras

Site-to-Site VPN (IPsec), Client VPN (TLS) y Direct Connect se comparan en el [Dominio 3](dominio-3-arquitecturas-alto-rendimiento.md#conectividad-hibrida-vpn-vs-direct-connect). La trampa de seguridad: **Direct Connect no cifra por defecto**. Si piden enlace privado **y** cifrado → Direct Connect + VPN IPsec sobre DX, o MACsec en conexiones dedicadas compatibles.

## Protección del borde y detección de amenazas

Qué hace cada servicio (GuardDuty, Inspector, Macie, Detective, Security Hub, WAF, Shield) está en [Servicios que hay que distinguir](../cloud-practitioner/dominio-2-seguridad-cumplimiento.md#servicios-que-hay-que-distinguir). En SAA importa **dónde se aplica**: **WAF** en CloudFront, ALB, API Gateway, AppSync, Cognito user pools, App Runner y Verified Access; **Shield Advanced** en CloudFront, Route 53, Global Accelerator, ELB y Elastic IP (costo alto y compromiso anual); **Firewall Manager** aplica reglas WAF, Shield Advanced, security groups y Network Firewall en toda la organización; **AWS Network Firewall** hace filtrado stateful, IPS y por dominio en subnets de inspección de la VPC.

!!! tip "En el examen"
    Palabras clave: "PII en buckets" → **Macie**; "actividad maliciosa o comprometida" → **GuardDuty**; "CVE en instancias o imágenes" → **Inspector**; "SQL injection / XSS" → **WAF**; "DDoS con soporte 24/7 y protección de costos" → **Shield Advanced**; "quién borró el recurso" → **CloudTrail**; "el recurso cambió de configuración / no cumple" → **Config**.

## Cifrado y gestión de claves

KMS vs CloudHSM a nivel básico en [Cloud Practitioner](../cloud-practitioner/dominio-2-seguridad-cumplimiento.md); envelope encryption en [Seguridad de cifrado y secretos](../../../cloud/seguridad/seguridad-cifrado-secretos.md#envelope-encryption-y-modelos-de-clave).

| Tipo de clave | Rotación | Key policy editable | Uso típico |
| --- | --- | --- | --- |
| **AWS owned key** | AWS | No (ni la ves) | Cifrado por defecto de algunos servicios |
| **AWS managed key** (`aws/s3`, `aws/rds`) | Automática anual | No | Cifrado sencillo sin control fino |
| **Customer managed key** | Automática opcional (periodo configurable) o manual | **Sí** | Controlar quién la usa, acceso entre cuentas, auditoría, desactivarla |
| Material importado (BYOK) | Solo manual | Sí | Generar la clave fuera de AWS |
| **AWS CloudHSM** | Tú | N/A | HSM dedicado de un solo tenant, FIPS 140 nivel 3 |

- KMS cifra directamente solo datos de hasta 4 KB; para lo demás, **envelope encryption** con data keys.
- Las claves KMS son **regionales**; para cifrar en una región y descifrar en otra, **multi-Region keys**.
- Compartir un snapshot cifrado entre cuentas exige una **customer managed key** cuya key policy permita a la otra cuenta (no se puede con una AWS managed key).

### Cifrado en S3

| Opción | Clave | Cuándo |
| --- | --- | --- |
| **SSE-S3** | Gestionada por S3 | Cifrado por defecto de todos los objetos nuevos desde 2023 |
| **SSE-KMS** | Clave KMS | Auditoría de cada uso en CloudTrail; **S3 Bucket Keys** reduce llamadas (y costo) a KMS |
| **DSSE-KMS** | Clave KMS, doble capa | Cumplimiento que exige dos capas de cifrado |
| **SSE-C** | La envías tú en cada petición | No quieres que AWS guarde la clave |
| Client-side encryption | Cifras antes de subir | Los datos no pueden llegar sin cifrar a AWS |

Forzar cifrado en tránsito: `Deny` con `aws:SecureTransport` = `false` en la bucket policy.

### Secretos y certificados

Secrets Manager vs Parameter Store en [Cloud Practitioner](../cloud-practitioner/dominio-2-seguridad-cumplimiento.md#gestion-de-identidades-y-accesos). SAA añade: Secrets Manager rota de forma **gestionada** RDS, Aurora, Redshift y DocumentDB (Lambda para el resto) y replica entre regiones. **ACM** da certificados TLS públicos gratis con **renovación automática** para ELB, CloudFront y API Gateway; para CloudFront, en **us-east-1**. Internos: **AWS Private CA**.

!!! tip "En el examen"
    "Rotar la contraseña de RDS automáticamente cada 30 días con el menor esfuerzo" → **Secrets Manager**. "Guardar parámetros de configuración de forma barata" → **Parameter Store**. "Certificado que se renueve solo en el ALB" → **ACM**.

## Protección, retención y recuperación de datos

| Necesidad | Solución |
| --- | --- |
| Recuperar objetos borrados o sobrescritos | **S3 Versioning** (+ MFA Delete) |
| WORM: nadie borra durante X años | **Object Lock** modo **Compliance** (ni root); **Governance** se salta con permiso especial; **Legal hold** sin fecha |
| Copia en otra región | **S3 Cross-Region Replication (CRR)**; requiere versioning |
| Evitar buckets públicos por error | **S3 Block Public Access** a nivel de cuenta + ACLs desactivadas |
| Compartir un objeto temporalmente | **Presigned URL** (URL prefirmada) |
| Backups centralizados entre regiones o cuentas | **AWS Backup** + **Backup Vault Lock** (inmutable) |
| Point-in-time recovery | RDS/Aurora (backups automáticos, retención hasta 35 días), DynamoDB PITR |

## Casos de uso

1. **40 cuentas no deben poder desactivar CloudTrail, ni con su root** → SCP que deniegue `cloudtrail:StopLogging` y `cloudtrail:DeleteTrail` en la OU raíz.
2. **EC2 lee un bucket de otra cuenta** → rol de instancia en A + bucket policy en B que permita ese rol. Nunca access keys.
3. **Factura alta del NAT gateway por descargas de S3** → **gateway endpoint** de S3 (gratis y más seguro).
4. **Banco: enlace privado, latencia estable y cifrado** → Direct Connect + Site-to-Site VPN (o MACsec).
5. **Saber quién usó la clave de los datos de clientes y poder revocarla** → SSE-KMS con **customer managed key**.

## Preguntas de práctica

**1.** Una empresa usa AWS Organizations. Quiere que los desarrolladores de la cuenta Dev puedan crear roles IAM para sus funciones Lambda, pero sin que esos roles tengan más permisos que los del propio desarrollador. ¿Qué debe usar?

- A. Una SCP aplicada a la OU de Dev
- B. Un permissions boundary obligatorio al crear roles
- C. Una resource-based policy en cada función Lambda
- D. AWS IAM Identity Center con un permission set de administrador

??? success "Respuesta"
    **B.** Un permissions boundary limita el máximo de permisos de los roles creados; se exige con una condición `iam:PermissionsBoundary` en la política del desarrollador. **A** limita la cuenta entera, no lo que un desarrollador delega. **C** controla quién invoca la función, no los permisos del rol. **D** da más permisos, no menos.

**2.** Unas instancias EC2 en subnets privadas deben acceder a una tabla DynamoDB sin que el tráfico salga a internet y con el menor costo. ¿Qué solución cumple?

- A. NAT gateway en cada AZ
- B. Interface endpoint de DynamoDB
- C. Gateway endpoint de DynamoDB y actualizar las route tables
- D. VPC peering con la VPC de DynamoDB

??? success "Respuesta"
    **C.** El gateway endpoint es gratuito y mantiene el tráfico en la red de AWS. **A** sale por internet y cobra por GB. **B** funciona, pero tiene costo por hora y por GB (tiene sentido si necesitas acceso desde on-premises). **D** no existe: DynamoDB no vive en una VPC tuya.

**3.** Una aplicación web debe protegerse contra SQL injection y además limitar a 2,000 peticiones cada 5 minutos por IP. Se sirve con CloudFront delante de un ALB. ¿Qué es lo MÁS adecuado?

- A. Security groups en el ALB
- B. AWS Shield Standard
- C. AWS WAF con reglas administradas de SQLi y una rate-based rule asociada a CloudFront
- D. Network ACL en las subnets públicas

??? success "Respuesta"
    **C.** WAF inspecciona capa 7 y tiene rate-based rules. **A** y **D** filtran por IP y puerto, no por contenido. **B** protege contra DDoS de capa 3/4, no contra SQLi.

**4.** Una empresa necesita rotar automáticamente las credenciales de su base de datos Aurora sin escribir código propio. ¿Qué servicio usar?

- A. SSM Parameter Store con SecureString
- B. AWS Secrets Manager con rotación gestionada
- C. AWS KMS con rotación automática de claves
- D. Variables de entorno cifradas en la Lambda

??? success "Respuesta"
    **B.** Secrets Manager rota credenciales de Aurora de forma gestionada. **A** no rota. **C** rota la clave de cifrado, no la contraseña de la base de datos. **D** no rota nada y es mala práctica.

**5.** Una auditoría exige que nadie, ni siquiera el usuario root, pueda borrar los objetos de un bucket durante 5 años. ¿Qué configuración lo garantiza? (Elige DOS.)

- A. S3 Versioning
- B. S3 Object Lock en modo Governance
- C. S3 Object Lock en modo Compliance con retención de 5 años
- D. MFA Delete
- E. Lifecycle rule que expire objetos a los 5 años

??? success "Respuesta"
    **A y C.** Object Lock requiere versioning, y el modo Compliance impide borrar o acortar la retención a cualquiera, incluido root. **B** permite saltarlo con un permiso especial. **D** añade fricción pero root con MFA puede borrar. **E** borra, no protege.

**6.** Usuarios de una aplicación móvil deben autenticarse con Google y luego subir archivos directamente a S3 con credenciales temporales. ¿Qué combinación es correcta?

- A. IAM users por cada usuario de la app
- B. Cognito user pool con federación de Google + Cognito identity pool que entregue un rol IAM
- C. IAM Identity Center con Google como IdP
- D. Bucket público con presigned URLs generadas en el cliente

??? success "Respuesta"
    **B.** El user pool autentica (incluida la federación social) y el identity pool intercambia el token por credenciales temporales. **A** no escala y usa credenciales fijas. **C** es para personal de la empresa, no usuarios finales. **D** es inseguro: las presigned URLs se generan en el backend y el bucket no debe ser público.

## Para profundizar

- [IAM: AWS, Azure y GCP](../../../cloud/fundamentos/iam-comparativa.md): políticas, roles y buenas prácticas.
- [Fundamentos de seguridad cloud](../../../cloud/seguridad/fundamentos-seguridad-cloud.md): cifrado, KMS, secretos, WAF, detección y auditoría.
- [Gobernanza](../../../cloud/operacion-y-gobierno/gobernanza.md): landing zone, SCPs y multi-cuenta.
- [Redes en la nube](../../../cloud/redes-y-datos/redes.md) y [Seguridad de red](../../../networking/avanzado/seguridad-red.md): segmentación, firewalls y VPN.
- [Seguridad de IaC](../../../devsecops/infraestructura-y-contenedores/seguridad-iac.md) y [CSPM](../../../devsecops/escaneos/cspm.md): detectar `*:*`, puertos abiertos y buckets públicos.
- [Lab 17: AWS: VPC con subnets públicas y privadas y una EC2](../../../laboratorios/cloud/aws-vpc-ec2.md).

## Referencias

- [Exam guide SAA-C03: Domain 1](https://docs.aws.amazon.com/aws-certification/latest/solutions-architect-associate-03/solutions-architect-associate-03-domain1.html)
- [Policy evaluation logic (IAM)](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html)
- [Service control policies](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
- [AWS PrivateLink y VPC endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html)
- [AWS KMS concepts](https://docs.aws.amazon.com/kms/latest/developerguide/concepts.html)
- [AWS Security Reference Architecture](https://docs.aws.amazon.com/prescriptive-guidance/latest/security-reference-architecture/welcome.html)
