---
tags:
  - aws-cli
  - cloud
---

# AWS CLI
| Comando | Descripción |
|---------|-------------|
| `aws configure` | Configurar credenciales y región |
| `aws s3 ls` | Listar buckets S3 |
| `aws s3 cp <origen> <destino>` | Copiar archivo hacia/desde S3 |
| `aws s3 sync <origen> <destino>` | Sincronizar carpeta con S3 |
| `aws ec2 describe-instances` | Listar instancias EC2 |
| `aws lambda list-functions` | Listar funciones Lambda |
| `aws lambda invoke --function-name <nombre> out.json` | Invocar función Lambda |
| `aws dynamodb scan --table-name <tabla>` | Escanear tabla DynamoDB |
| `aws logs tail <log-group> --follow` | Ver logs de CloudWatch en tiempo real |
| `aws iam list-users` | Listar usuarios IAM |
| `aws sts get-caller-identity` | Ver identidad/cuenta actual autenticada |

!!! example "Practica en el laboratorio"
    - [Lab 00 (parte 1): Herramientas locales](../../laboratorios/fundamentos/preparar-entorno.md)
    - [Lab 00 (parte 2): Cuentas cloud, presupuestos e identidades](../../laboratorios/fundamentos/preparar-cuentas-cloud.md)
    - [Lab 09: Terraform en AWS con remote state en S3](../../laboratorios/devops/terraform-aws-backend-remoto.md)
    - [Lab 13: Desplegar en AWS desde GitHub Actions con OIDC (sin llaves)](../../laboratorios/devsecops/oidc-github-aws.md)

