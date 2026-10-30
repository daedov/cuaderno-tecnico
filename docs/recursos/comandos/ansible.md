---
tags:
  - ansible
  - ci-cd
---
## Ansible
| Comando | Descripción |
|---------|-------------|
| `ansible <hosts> -m ping` | Verificar conectividad |
| `ansible-playbook <archivo.yml>` | Ejecutar playbook |
| `ansible-playbook <archivo.yml> --check` | Simular ejecución (dry-run) |
| `ansible-playbook <archivo.yml> -i <inventario>` | Ejecutar con inventario específico |
| `ansible-playbook <archivo.yml> --tags <tag>` | Ejecutar solo tareas con cierta etiqueta |
| `ansible-inventory --list` | Ver inventario en formato JSON |
| `ansible-vault encrypt <archivo>` | Cifrar archivo con datos sensibles |
| `ansible-vault decrypt <archivo>` | Descifrar archivo |
| `ansible-vault edit <archivo>` | Editar archivo cifrado |
| `ansible-galaxy install <rol>` | Instalar rol de Ansible Galaxy |

!!! example "Practica en el laboratorio"
    - [Lab 10: Configurar servidores con Ansible](../../laboratorios/devops/ansible-configuracion.md)
    - [Lab 22: Endurecer un servidor Linux con Ansible y medirlo con Lynis y OpenSCAP](../../laboratorios/devsecops/hardening-linux-ansible.md)

