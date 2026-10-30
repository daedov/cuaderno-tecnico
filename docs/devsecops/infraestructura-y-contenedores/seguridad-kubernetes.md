---
tags:
  - seguridad
  - kubernetes
  - contenedores
  - policy-as-code
  - iam
---

# Seguridad de Kubernetes

> Cómo verificar y limitar qué puede hacer cada pieza de un clúster: RBAC, Pod Security Standards, NetworkPolicies, admission control (Kyverno, Gatekeeper), runtime security (Falco), secretos e identidad de los pods hacia la nube.

## ¿Qué es?

Kubernetes trae muchos controles de seguridad, pero casi ninguno viene activado de forma estricta por defecto: un pod puede correr como root, hablar con cualquier otro pod y leer su *ServiceAccount token*. Asegurar un clúster es ir cerrando cada una de esas puertas.

| Capa | Pregunta | Control |
| --- | --- | --- |
| API del clúster | ¿Quién puede hacer qué con la API? | **RBAC** |
| Pods | ¿Con qué privilegios corre cada contenedor? | **Pod Security Standards**, `securityContext` |
| Red | ¿Con quién puede hablar cada pod? | **NetworkPolicy** |
| Admisión | ¿Qué objetos se aceptan en el clúster? | **Admission controllers**: Kyverno, Gatekeeper, ValidatingAdmissionPolicy |
| Runtime | ¿Qué está pasando dentro de los contenedores ahora? | **Falco** |
| Datos | ¿Están protegidos los Secrets? | Encryption at rest, gestores externos |
| Nube | ¿Con qué identidad accede el pod a servicios cloud? | IRSA / EKS Pod Identity, Entra Workload ID, Workload Identity Federation for GKE |

Conceptos de base (pods, deployments, services, Helm) en [Kubernetes](../../devops/contenedores/kubernetes.md); el endurecimiento de la imagen en [Seguridad de contenedores](seguridad-contenedores.md).

## RBAC

**RBAC** (*Role-Based Access Control*, control de acceso basado en roles) define qué verbos (`get`, `list`, `create`, `delete`…) puede usar una identidad sobre qué recursos de la API.

| Objeto | Alcance | Para qué |
| --- | --- | --- |
| **Role** | Un namespace | Conjunto de permisos dentro de ese namespace |
| **ClusterRole** | Todo el clúster | Permisos globales o recursos sin namespace (nodes, namespaces) |
| **RoleBinding** | Un namespace | Asigna un Role (o ClusterRole) a usuarios, grupos o ServiceAccounts en ese namespace |
| **ClusterRoleBinding** | Todo el clúster | Asigna un ClusterRole en todos los namespaces |
| **ServiceAccount** | Un namespace | Identidad de los pods ante la API de Kubernetes |

```yaml title="rbac-lector.yaml"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: lector-config
  namespace: app
automountServiceAccountToken: false # solo se monta en los pods que lo pidan
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: leer-configmaps
  namespace: app
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: lector-config-leer-configmaps
  namespace: app
subjects:
  - kind: ServiceAccount
    name: lector-config
    namespace: app
roleRef:
  kind: Role
  name: leer-configmaps
  apiGroup: rbac.authorization.k8s.io
```

Buenas prácticas de **least privilege** (mínimo privilegio):

- Prefiere **Role + RoleBinding** antes que permisos de todo el clúster.
- Evita `cluster-admin` y los comodines (`resources: ["*"]`, `verbs: ["*"]`).
- Ojo con permisos que escalan: `secrets` (`get`/`list`), `pods/exec`, `create` sobre pods o `escalate`/`bind`/`impersonate`.
- Un ServiceAccount por aplicación; no uses el `default`.
- `automountServiceAccountToken: false` si la app no habla con la API.

```bash
# ¿Puede este ServiceAccount leer secrets?
kubectl auth can-i get secrets -n app --as=system:serviceaccount:app:lector-config
```

## Pod Security Standards

Los **Pod Security Standards** definen tres perfiles de seguridad para pods:

| Perfil | Qué permite | Para qué |
| --- | --- | --- |
| **Privileged** | Todo, sin restricciones | Componentes del sistema (CNI, agentes de nodo) |
| **Baseline** | Bloquea lo claramente peligroso: `privileged`, `hostNetwork`, `hostPath`, capabilities peligrosas | Mínimo razonable para cualquier app |
| **Restricted** | Además exige no root, `allowPrivilegeEscalation: false`, `drop: ["ALL"]`, seccomp | Objetivo para aplicaciones |

Se aplican con **Pod Security Admission** (integrado en Kubernetes) mediante **labels** en el namespace, en tres modos: `enforce` (rechaza), `audit` (registra en el *audit log*) y `warn` (avisa al usuario).

```yaml title="namespace-app.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: app
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
```

!!! info "PodSecurityPolicy ya no existe"
    **PodSecurityPolicy** (PSP) se marcó como obsoleto en 1.21 y se **eliminó en Kubernetes 1.25**. Su sustituto integrado es Pod Security Admission; para reglas más finas se usan Kyverno o Gatekeeper.

Un pod que cumple `restricted`:

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: registry.example.com/app@sha256:<digest>
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
```

## NetworkPolicy

Por defecto **todos los pods pueden hablar con todos**. Una **NetworkPolicy** limita el tráfico de entrada (*ingress*) y salida (*egress*) de los pods que selecciona. El patrón recomendado es **default deny** (denegar por defecto) y abrir solo lo necesario.

!!! warning "Requiere un CNI que las aplique"
    Kubernetes guarda las NetworkPolicies, pero quien las aplica es el **CNI** (*Container Network Interface*, el plugin de red): Calico, Cilium y otros sí; algunos CNI básicos no, y entonces la política existe pero no hace nada. En EKS, AKS y GKE hay que activar o elegir la opción correspondiente; revísalo en [Contenedores gestionados](../../cloud/computo/contenedores-gestionados.md).

```yaml title="default-deny.yaml"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: app
spec:
  podSelector: {}          # todos los pods del namespace
  policyTypes: [Ingress, Egress]
```

```yaml title="permitir-frontend-a-api.yaml"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-desde-frontend
  namespace: app
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

Con *default deny* en egress, recuerda permitir el DNS (puerto 53 UDP/TCP hacia `kube-dns`) o nada resolverá nombres. Es la misma idea que los security groups y la segmentación de [Redes en la nube](../../cloud/redes-y-datos/redes.md), pero dentro del clúster.

## Admission control

Un **admission controller** (controlador de admisión) intercepta cada petición a la API **antes** de guardar el objeto y puede rechazarlo (*validating*) o modificarlo (*mutating*). Es policy as code dentro del clúster (ver también [Seguridad de IaC](seguridad-iac.md)).

| | **Kyverno** | **OPA Gatekeeper** |
| --- | --- | --- |
| Proyecto | CNCF | CNCF (OPA) |
| Lenguaje de políticas | YAML (patrones) y CEL | Rego (ConstraintTemplates) |
| Curva de aprendizaje | Baja si ya conoces YAML de Kubernetes | Más alta (Rego) |
| Mutar objetos | Sí | Sí |
| Generar recursos (p. ej. NetworkPolicy por namespace) | Sí | No |
| Verificar firmas de imágenes | Sí (cosign, Notation) | Con integraciones externas |
| Reutilizar políticas fuera del clúster | Kyverno CLI | Las mismas políticas Rego con OPA/Conftest |

!!! note "Opción nativa: ValidatingAdmissionPolicy"
    Kubernetes incluye **ValidatingAdmissionPolicy** (estable desde 1.30), con reglas en **CEL** (*Common Expression Language*) sin instalar nada. Sirve para validaciones sencillas; Kyverno y Gatekeeper siguen aportando mutación, generación, informes y bibliotecas de políticas.

```yaml title="kyverno-disallow-latest.yaml"
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  background: true
  rules:
    - name: require-image-tag
      match:
        any:
          - resources:
              kinds: [Pod]
      validate:
        failureAction: Enforce   # Audit para solo reportar
        message: "Usa una etiqueta de imagen fija; ':latest' no está permitido."
        pattern:
          spec:
            containers:
              - image: "!*:latest"
```

## Runtime security con Falco

Lo anterior previene; **Falco** (proyecto graduado de la CNCF) **detecta** comportamiento sospechoso mientras los contenedores corren, leyendo las *syscalls* (llamadas al sistema) del kernel mediante eBPF. Ejemplos: una shell dentro de un contenedor, lectura de `/etc/shadow`, un binario nuevo que se ejecuta, conexiones a destinos inesperados.

```yaml title="reglas-propias.yaml"
- rule: Shell interactiva en contenedor
  desc: Alguien abrió una shell con terminal dentro de un contenedor
  condition: >
    spawned_process and container
    and proc.name in (bash, sh, zsh)
    and proc.tty != 0
  output: >
    Shell en contenedor (user=%user.name container=%container.name
    image=%container.image.repository cmd=%proc.cmdline)
  priority: WARNING
  tags: [container, shell]
```

Las alertas de Falco se envían (con **Falcosidekick**) a Slack, a un SIEM o a un sistema de respuesta. Ver [Detección y respuesta](../gobierno-y-respuesta/deteccion-respuesta.md).

## Secretos en Kubernetes

!!! danger "Un Secret no está cifrado por defecto"
    Los **Secrets** de Kubernetes se guardan en etcd codificados en **base64**, que no es cifrado: cualquiera con acceso a etcd o permiso `get secrets` los lee.

Medidas:

- **Encryption at rest** (cifrado en reposo) de etcd con `EncryptionConfiguration`, idealmente con un proveedor **KMS** (*envelope encryption*). En clústeres gestionados (EKS, AKS, GKE) se activa con una opción del servicio y una key de KMS; revisa si tu proveedor ya lo hace por defecto.
- **RBAC estricto** sobre `secrets`.
- Guardar el secreto en un gestor externo (Vault, AWS Secrets Manager, Azure Key Vault, Secret Manager) y traerlo al clúster con:
    - **External Secrets Operator**: sincroniza el secreto externo como Secret de Kubernetes.
    - **Secrets Store CSI Driver**: lo monta como archivo en el pod, sin necesidad de crear un Secret.

Más en [Secretos e identidades](../identidades-y-pipeline/secretos-identidades.md).

## CIS Kubernetes Benchmark

El **CIS Kubernetes Benchmark** es una guía de configuración segura del plano de control, etcd, kubelet y políticas. **kube-bench** (Aqua Security) la comprueba automáticamente:

```bash
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
kubectl logs job/kube-bench
```

En servicios gestionados el proveedor controla el plano de control, así que se usan los benchmarks específicos (**CIS Amazon EKS**, **CIS AKS**, **CIS GKE**), que solo revisan lo que tú gestionas. Ver [Cumplimiento y gobierno](../gobierno-y-respuesta/cumplimiento.md).

!!! tip "Escaneo en detalle"
    Escanear la postura del clúster en ejecución con kube-bench, Kubescape (NSA/CISA, MITRE), Trivy k8s y Trivy Operator o Polaris, las ofertas nativas de cada nube y en qué se diferencia del escaneo de manifests y de la detección en runtime: [KSPM](../escaneos/kspm.md).

## Identidad de pods hacia la nube

Un pod que necesita leer un bucket o una cola **no debe** llevar access keys en un Secret. Cada nube federa la identidad del ServiceAccount de Kubernetes con su IAM para entregar credenciales temporales:

=== "AWS (EKS)"

    - **IRSA** (*IAM Roles for Service Accounts*): el clúster tiene un OIDC provider en IAM; el ServiceAccount lleva la anotación `eks.amazonaws.com/role-arn` y el pod asume ese IAM role.
    - **EKS Pod Identity** (más reciente y sencillo): se instala el add-on *Pod Identity Agent* y se crea una *pod identity association* entre ServiceAccount e IAM role, sin anotaciones ni OIDC provider por clúster.

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

    **Workload Identity Federation for GKE**: se activa en el clúster y se da el role de IAM directamente al ServiceAccount de Kubernetes como *principal*:

    ```bash
    gcloud projects add-iam-policy-binding mi-proyecto \
      --role=roles/storage.objectViewer \
      --member="principal://iam.googleapis.com/projects/123456789/locations/global/workloadIdentityPools/mi-proyecto.svc.id.goog/subject/ns/app/sa/lector-gcs"
    ```

    También puede vincularse a una service account de IAM con la anotación `iam.gke.io/gcp-service-account`.

Es el mismo principio que OIDC en el pipeline: credenciales temporales en lugar de llaves estáticas (ver [IAM: AWS, Azure y GCP](../../cloud/identidad-y-seguridad/iam-comparativa.md)).

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | EKS, AKS y GKE: opciones de red, cifrado y federación de identidad; segmentación de red | [Contenedores gestionados](../../cloud/computo/contenedores-gestionados.md), [Redes en la nube](../../cloud/redes-y-datos/redes.md), [IAM: AWS, Azure y GCP](../../cloud/identidad-y-seguridad/iam-comparativa.md) |
| DevOps (la automatización) | Manifiestos, Helm y Kustomize que estas políticas validan | [Kubernetes](../../devops/contenedores/kubernetes.md), [Despliegue continuo](../../devops/ci-cd/despliegue-continuo.md) |
| DevSecOps (la verificación) | Imagen endurecida, secretos, alertas de runtime y benchmarks | [Seguridad de contenedores](seguridad-contenedores.md), [Secretos e identidades](../identidades-y-pipeline/secretos-identidades.md), [Detección y respuesta](../gobierno-y-respuesta/deteccion-respuesta.md), [KSPM](../escaneos/kspm.md), [CVE en contenedores y Kubernetes](../vulnerabilidades/cve-contenedores-kubernetes.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 06: Desplegar una app en Kubernetes local con kind](../../laboratorios/devops/kubernetes-local-kind.md), [Lab 14: Endurecer un clúster: Pod Security, NetworkPolicy y Kyverno](../../laboratorios/devsecops/seguridad-kubernetes.md) |

## Referencias

- [Kubernetes: Security overview](https://kubernetes.io/docs/concepts/security/)
- [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [ValidatingAdmissionPolicy](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/)
- [Encrypting Secret data at rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- [Kyverno](https://kyverno.io/docs/)
- [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/)
- [Falco](https://falco.org/docs/)
- [kube-bench](https://github.com/aquasecurity/kube-bench)
- [External Secrets Operator](https://external-secrets.io/)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [Microsoft Entra Workload ID en AKS](https://learn.microsoft.com/es-es/azure/aks/workload-identity-overview)
- [Workload Identity Federation for GKE](https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity)
- [Comandos de kubectl](../../recursos/comandos/kubectl.md)
