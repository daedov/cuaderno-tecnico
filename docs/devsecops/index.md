# DevSecOps :lock:

**DevSecOps es cómo compruebas que es seguro** (la verificación): controles de seguridad automáticos en cada fase, desde el código hasta la operación. Las prácticas son las mismas en cualquier nube; solo se indica el proveedor donde cambia el servicio nativo.

Cada tema se ve también desde [Cloud](../cloud/index.md) (dónde corre) y [DevOps](../devops/index.md) (cómo se automatiza). Ver el [mapa de relaciones](../mapa-de-relaciones.md).

## Fundamentos

- [Fundamentos DevSecOps](fundamentos-devsecops.md): shift-left, tríada CIA, threat modeling (STRIDE), OWASP Top 10, gestión de riesgo

## Escaneos de seguridad

Una nota por cada tipo de escaneo: qué detecta, herramientas, cómo ejecutarlo, cómo integrarlo en el pipeline y cómo gestionar los hallazgos.

- [Escaneos en el pipeline](escaneos/escaneo-en-pipeline.md): vista general, en qué fase va cada escaneo y workflow de ejemplo
- [SAST](escaneos/sast.md): análisis estático del código fuente
- [SCA](escaneos/sca.md): dependencias de terceros, vulnerabilidades y licencias
- [Secret scanning](escaneos/secret-scanning.md): credenciales en commits e historial
- [Container image scanning](escaneos/container-scanning.md): vulnerabilidades en imágenes de contenedor
- [IaC scanning](escaneos/iac-scanning.md): malas configuraciones en Terraform, CloudFormation, Kubernetes y Helm
- [DAST](escaneos/dast.md): pruebas sobre la aplicación en ejecución, APIs y fuzzing
- [KSPM](escaneos/kspm.md): postura de seguridad del clúster de Kubernetes
- [CSPM](escaneos/cspm.md): postura de seguridad de las cuentas cloud

## Vulnerabilidades y CVE

Cómo funciona el sistema de CVE y los casos más importantes, con enlaces a la información oficial de cada uno.

- [Fundamentos de CVE](vulnerabilidades/fundamentos-cve.md): CVE, CWE, CVSS, EPSS, CISA KEV y fuentes oficiales
- [Investigar un CVE](vulnerabilidades/investigar-un-cve.md): paso a paso, de la alerta a saber si te afecta y mitigarlo
- [Aplicaciones y librerías](vulnerabilidades/cve-aplicaciones-librerias.md): Log4Shell, Spring4Shell, Apache Struts y otros
- [Supply chain y CI/CD](vulnerabilidades/cve-supply-chain-cicd.md): xz utils, tj-actions/changed-files, Jenkins, TeamCity
- [Contenedores y Kubernetes](vulnerabilidades/cve-contenedores-kubernetes.md): runc, Leaky Vessels, IngressNightmare
- [Linux y sistemas base](vulnerabilidades/cve-linux-sistemas.md): Heartbleed, Shellshock, Dirty Pipe, PwnKit, regreSSHion
- [Windows y Active Directory](vulnerabilidades/cve-windows-active-directory.md): EternalBlue, Zerologon, PrintNightmare, ProxyLogon
- [Perímetro y VPN](vulnerabilidades/cve-perimetro-vpn.md): Fortinet, Ivanti, Citrix Bleed, PAN-OS, MOVEit
- [Protocolos y hardware](vulnerabilidades/cve-protocolos-hardware.md): HTTP/2 Rapid Reset, Spectre, Meltdown, KRACK, POODLE

## Código y dependencias

- [Seguridad del código](codigo-y-dependencias/seguridad-codigo.md): secure coding, SAST, detección de secretos, pre-commit hooks
- [Software supply chain](codigo-y-dependencias/cadena-suministro.md): SCA, SBOM, firma con cosign, SLSA, version pinning
- [Pruebas dinámicas](codigo-y-dependencias/pruebas-dinamicas.md): DAST, fuzzing, seguridad de APIs, pentesting básico

## Infraestructura y contenedores

- [Seguridad de IaC](infraestructura-y-contenedores/seguridad-iac.md): Checkov, Trivy, policy as code, drift detection
- [Seguridad de contenedores](infraestructura-y-contenedores/seguridad-contenedores.md): escaneo de imágenes, distroless, ejecución sin root
- [Seguridad de Kubernetes](infraestructura-y-contenedores/seguridad-kubernetes.md): RBAC, Pod Security Standards, network policies, admission control, Falco

## Hardening

Reducir la superficie de ataque de sistemas y servicios con configuraciones seguras de referencia, y verificarlas de forma continua.

- [Fundamentos de hardening](hardening/fundamentos-hardening.md): principios, baselines (CIS Benchmarks, DISA STIG, Microsoft), ciclo y excepciones
- [Hardening de Linux](hardening/hardening-linux.md): SSH, sysctl, servicios, auditd, SELinux/AppArmor, firewall, Lynis y OpenSCAP
- [Hardening de Windows Server](hardening/hardening-windows.md): security baselines, GPO, LAPS, ASR, Credential Guard, RDP, PowerShell logging
- [Hardening de servidores web](hardening/hardening-servidores-web.md): NGINX y Apache, TLS y cabeceras de seguridad
- [Hardening de servicios](hardening/hardening-servicios.md): PostgreSQL, MySQL y el daemon de Docker
- [Hardening como código](hardening/hardening-como-codigo.md): Ansible, golden images, verificación continua y drift
- Práctica: [Lab 22: Hardening de Linux con Ansible](../laboratorios/devsecops/hardening-linux-ansible.md)

## Identidades y pipeline

- [Secretos e identidades](identidades-y-pipeline/secretos-identidades.md): Vault, rotación, OIDC entre pipeline y cloud
- [Seguridad del pipeline](identidades-y-pipeline/seguridad-pipeline.md): permisos mínimos, branch protection, aprobaciones, aislamiento de entornos

## Gobierno y respuesta

- [Cumplimiento y gobierno](gobierno-y-respuesta/cumplimiento.md): CIS Benchmarks, ISO 27001, SOC 2, NIST, CSPM
- [Detección y respuesta](gobierno-y-respuesta/deteccion-respuesta.md): SIEM, vulnerability management, playbooks de incidentes
- [Fuentes oficiales de seguridad](gobierno-y-respuesta/fuentes-oficiales-seguridad.md): avisos de las nubes, CERT/CSIRT, bases de vulnerabilidades y feeds en tiempo real

!!! note "Añadir una nota"
    Crea un `.md` en la subcarpeta del bloque que corresponda dentro de `docs/devsecops/` y agrégalo a su archivo `.pages` para fijar su orden en el menú.
