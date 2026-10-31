---
tags:
  - azure
  - certificacion
  - az-104
  - almacenamiento
---

# Implement and manage storage (15–20%)

> Storage accounts, redundancia, acceso con SAS, keys e identidades, firewalls, Azure Files, Blob Storage con tiers, lifecycle, versioning y soft delete, y herramientas como AzCopy y Storage Explorer.

!!! info "Qué evalúa esta área"
    Tres grupos de habilidades del *study guide* vigente:

    - **Configure access to storage**: firewalls y redes virtuales, **SAS** (*shared access signature*, firma de acceso compartido), *stored access policies*, *access keys* y acceso basado en identidad para Azure Files.
    - **Configure and manage storage accounts**: crear y configurar cuentas, redundancia, *object replication*, cifrado, Azure Storage Explorer y AzCopy.
    - **Configure Azure Files and Azure Blob Storage**: file shares, containers, *storage tiers*, soft delete de blobs y containers, snapshots y soft delete de Azure Files, lifecycle management y blob versioning.

    Vuelve al [resumen del examen](resumen-examen.md) para ver el resto.

## Storage accounts

Una **storage account** agrupa **Blob Storage**, **Azure Files**, **Queue Storage** y **Table Storage**, cada uno con su endpoint (`https://<cuenta>.blob.core.windows.net`…). La comparación con S3 y Cloud Storage está en [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md).

| Tipo de cuenta | Rendimiento | Para qué |
| --- | --- | --- |
| **Standard general-purpose v2** | Standard (HDD) | La opción por defecto: blobs, files, queues y tables |
| **Premium block blobs** | Premium (SSD) | Muchas transacciones pequeñas o baja latencia en blobs |
| **Premium file shares** | Premium (SSD) | Azure Files de alto rendimiento; único tipo que admite **NFS** |
| **Premium page blobs** | Premium (SSD) | Page blobs (discos no administrados y casos especiales) |

Nombre: 3 a 24 caracteres, solo minúsculas y números, **único en todo Azure** (forma parte del DNS).

## Redundancia

Qué protege cada sigla (LRS, ZRS, GRS, GZRS) está en [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md#object-storage). Lo que distingue el examen es dónde puedes **leer**:

| SKU | Sobrevive a | Lectura en la secundaria |
| --- | --- | --- |
| **LRS** | Fallo de disco o rack | No aplica |
| **ZRS** | Caída de una zona | No aplica |
| **GRS** / **RA-GRS** | Caída de la región | No / **Sí** (endpoint `-secondary`) |
| **GZRS** / **RA-GZRS** | Zona y región | No / **Sí** |

!!! tip "En el examen"
    - "Leer los datos aunque la región primaria esté caída, sin esperar un failover" → **RA-GRS** o **RA-GZRS**.
    - "Sobrevivir a la caída de un datacenter dentro de la región con el menor costo" → **ZRS**.
    - Las cuentas **Premium** solo admiten LRS o ZRS.
    - El tier **Archive** no está disponible con ZRS, GZRS ni RA-GZRS.
    - Si la primaria cae, puedes iniciar un **customer-managed failover** (conmutación iniciada por el cliente); la secundaria pasa a ser primaria y puedes perder los datos que aún no se habían replicado.

## Acceso a los datos

De más a menos recomendado:

| Método | Cómo funciona | Cuándo |
| --- | --- | --- |
| **Microsoft Entra ID + RBAC** | Roles de datos como **Storage Blob Data Reader/Contributor** | Aplicaciones con managed identity y personas |
| **User delegation SAS** | SAS firmada con credenciales de Entra (solo Blob Storage y Data Lake) | Dar acceso temporal sin exponer keys |
| **Service SAS** | SAS firmada con la account key para **un** servicio | Acceso temporal a un container, blob, share o queue |
| **Account SAS** | SAS firmada con la account key para uno o varios servicios | Operaciones a nivel de cuenta |
| **Access keys** (*Shared Key*) | Dos claves con acceso total a la cuenta | Evitarlas; si se usan, guardarlas en Key Vault y rotarlas |

- Una SAS es una URL con permisos (`r`, `w`, `d`, `l`…), inicio, expiración, IPs y protocolo.
- Una **stored access policy** se define en un container, share, queue o table (máximo **cinco** por container); las service SAS que la referencian heredan sus valores y se pueden **revocar** cambiándola.
- **key1** y **key2** permiten rotar sin corte (apps a key2, regenerar key1, y al revés). Si todo usa Entra ID, puedes **deshabilitar Shared Key** (`--allow-shared-key-access false`).

!!! warning "Cómo revocar cada tipo de SAS"
    | SAS | Cómo revocarla antes de que expire |
    | --- | --- |
    | Service SAS **con** stored access policy | Borrar o cambiar la policy |
    | Service SAS o account SAS **sin** policy | Rotar la access key que la firmó |
    | User delegation SAS | Revocar las *user delegation keys* o quitar el rol al usuario |

### Acceso basado en identidad para Azure Files

1. Fuente de identidad en la cuenta: **AD DS** local, **Microsoft Entra Domain Services** o **Microsoft Entra Kerberos** (identidades híbridas).
2. Permisos **a nivel de share** con RBAC: **Storage File Data SMB Share Reader**, **Contributor** o **Elevated Contributor** (puede cambiar ACLs).
3. Permisos de archivo y carpeta con **ACLs de NTFS** desde un equipo unido al dominio.

!!! tip "En el examen"
    Los permisos efectivos son la combinación: share-level (RBAC) **y** ACL de NTFS. Si uno de los dos niega, no hay acceso.

## Firewalls, service endpoints y private endpoints

*Public network access*: **Enabled from all networks**, **Enabled from selected virtual networks and IP addresses** o **Disabled**.

- **IP network rules**: rangos de IP **públicas** (no admite IPs privadas).
- **Virtual network rules**: subnets que llegan por **service endpoint** `Microsoft.Storage`.
- **Resource instances** y **trusted Microsoft services**: excepciones para servicios de Azure (p. ej. Azure Backup).
- **Private endpoint**: NIC con IP privada de tu VNet; se combina con *Public network access: Disabled* y la zona DNS privada `privatelink.blob.core.windows.net`.

La diferencia entre service endpoint y private endpoint está en [Implement and manage virtual networking](area-4-redes-virtuales.md#service-endpoints-y-private-endpoints).

## Cifrado de la cuenta

- **Storage Service Encryption** (SSE): todo se cifra en reposo con AES-256, siempre y sin costo extra.
- **Microsoft-managed keys** (por defecto) o **customer-managed keys** (CMK) en **Key Vault** o Managed HSM; la cuenta usa una managed identity para leer la clave.
- **Infrastructure encryption** (doble cifrado): se habilita **al crear** la cuenta y no se puede activar después.
- **Encryption scopes**: claves distintas por container o blob dentro de la misma cuenta.

## Blob Storage: tiers, lifecycle y protección

El acceso anónimo de un container (*Private*, *Blob*, *Container*) solo funciona si la cuenta lo permite (`allowBlobPublicAccess`, deshabilitado por defecto).

| Access tier | Retención mínima | Disponibilidad | Uso típico |
| --- | --- | --- | --- |
| **Hot** | No tiene | Online | Datos que se leen a menudo |
| **Cool** | 30 días | Online | Datos poco usados (backups recientes) |
| **Cold** | 90 días | Online | Datos rara vez leídos pero que necesitas al instante |
| **Archive** | 180 días | **Offline** | Archivo legal y backups de largo plazo |

- Mover o borrar antes de la retención mínima cobra una **early deletion fee** proporcional.
- **Archive** se asigna por blob; para leerlo hay que **rehidratar** a un tier online con prioridad **Standard** (hasta 15 horas) o **High** (normalmente menos de una hora para blobs pequeños), o copiarlo a otro blob.

Una **lifecycle management policy** mueve blobs de tier o los borra por antigüedad (`tierToCool`, `tierToArchive`, `delete` con `daysAfterModificationGreaterThan`, filtrando con `prefixMatch`). Se ejecuta una vez al día; la primera ejecución puede tardar hasta 24 horas.

!!! tip "En el examen"
    - Para reglas basadas en **último acceso** (`daysAfterLastAccessTimeGreaterThan`) hay que activar **last access time tracking**.
    - `prefixMatch` filtra por container y prefijo (`logs/` = container `logs`).
    - Lifecycle no mueve blobs a Archive en cuentas ZRS/GZRS (Archive no existe ahí).

| Función | Qué protege | Detalle |
| --- | --- | --- |
| **Blob versioning** | Sobrescrituras y borrados | Cada cambio guarda una versión anterior automáticamente |
| **Blob soft delete** | Borrado de blobs y snapshots | Retención de 1 a 365 días; se recupera con *undelete* |
| **Container soft delete** | Borrado de un container entero | Retención de 1 a 365 días |
| **Point-in-time restore** | Volver un conjunto de block blobs a un momento anterior | Requiere versioning, change feed y blob soft delete |
| **Blob snapshots** | Copia de solo lectura de un blob en un momento | Manual |
| **Immutable storage** (WORM) | Que nadie borre ni modifique durante un periodo | *Time-based retention* o *legal hold* |

**Object replication** copia de forma asíncrona block blobs a un container de **otra cuenta** (normalmente otra región). Requiere **versioning** en ambas cuentas y **change feed** en la origen. No sirve para Archive ni sustituye a GRS (con GRS no eliges el destino ni puedes leerlo, salvo RA-GRS).

## Azure Files

File shares administrados por **SMB** (puerto 445) y **NFS** 4.1 (solo premium). Se montan desde Windows, Linux o macOS, o se cachean en servidores locales con **Azure File Sync**.

| Tier | Medio | Uso |
| --- | --- | --- |
| **Premium** | SSD | Bases de datos, cargas sensibles a latencia, NFS |
| **Transaction optimized** | HDD | Muchas transacciones, sin necesidad de baja latencia |
| **Hot** | HDD | Shares de uso general |
| **Cool** | HDD | Archivo online barato |

- Además del *pay-as-you-go*, existe el modelo **provisioned v2** (pagas capacidad, IOPS y throughput aprovisionados).
- **Share snapshots**: copias de solo lectura del share (hasta 200); en Windows aparecen como *Previous Versions*.
- **Soft delete de file shares**: recupera un share borrado durante la retención (1 a 365 días).

## AzCopy y Azure Storage Explorer

| Herramienta | Qué es | Cuándo |
| --- | --- | --- |
| **AzCopy** | CLI para copiar hacia, desde y entre cuentas (servidor a servidor) | Copias grandes, scripts, migraciones |
| **Azure Storage Explorer** | App de escritorio para navegar blobs, files, queues y tables | Tareas manuales, revisar contenido, generar SAS |
| **Azure Data Box** | Dispositivo físico | Terabytes con poco ancho de banda |
| **Azure Import/Export** | Discos propios enviados al datacenter | Similar a Data Box con tus discos |

## Casos de uso

1. App que debe seguir leyendo si cae la región primaria, sin intervención → **RA-GZRS** (o RA-GRS) leyendo del endpoint `-secondary`.
2. Proveedor que sube archivos durante 48 horas → **SAS** con `w` (y `c`), 48 h y HTTPS; mejor user delegation SAS o service SAS con **stored access policy** para poder revocarla.
3. Logs consultados una semana, guardados un año → **lifecycle**: Cool a los 30 días, Archive a los 90, borrar a los 365.
4. Container de facturas borrado por error → **container soft delete**, si estaba activado.
5. Cuenta accesible solo desde la VNet y sin IP pública → **private endpoint** + *Public network access: Disabled* + zona DNS privada.
6. Reemplazar un servidor de archivos Windows con permisos NTFS → **Azure Files** con **AD DS** (o Entra Kerberos), roles SMB y ACLs NTFS; File Sync para caché local.
7. Copia de blobs de producción en otra región y otra cuenta para analítica → **object replication**.

## Preguntas de práctica

**1.** Necesitas que una cuenta de almacenamiento sobreviva a la caída de una availability zone y de la región completa, con la menor cantidad de cambios en la aplicación. ¿Qué redundancia eliges?

- A. LRS.
- B. ZRS.
- C. GRS.
- D. GZRS.

??? success "Respuesta"
    **D.** GZRS replica en tres zonas de la primaria y en la región pareja. A no sobrevive a la caída de una zona. B no protege ante la caída de la región. C protege ante la región, pero en la primaria usa LRS, que no sobrevive a la caída de una zona.

**2.** Emitiste varias service SAS sin stored access policy y una se filtró. ¿Cuál es la forma de invalidarla?

- A. Borrar el container.
- B. Regenerar la access key que se usó para firmarla.
- C. Crear una stored access policy nueva.
- D. Cambiar el tier del blob a Archive.

??? success "Respuesta"
    **B.** Sin policy, la única forma de revocar una SAS firmada con key es rotar esa key (y las demás SAS firmadas con ella también dejan de funcionar). A es destructivo. C no afecta a SAS ya emitidas que no la referencian. D no invalida la firma.

**3.** Una regla de lifecycle debe mover a Archive los blobs a los 60 días, pero la cuenta es Standard ZRS y la regla no tiene efecto. ¿Por qué?

- A. Lifecycle management requiere cuentas Premium.
- B. El tier Archive no está disponible en cuentas ZRS.
- C. Hay que activar blob versioning.
- D. Las reglas solo se aplican a blobs creados después de la regla.

??? success "Respuesta"
    **B.** Archive solo existe en LRS, GRS y RA-GRS. A es falso: lifecycle funciona en general-purpose v2. C no es requisito para mover de tier. D es falso: las reglas evalúan todos los blobs que cumplen el filtro.

**4.** Debes permitir acceso a una storage account solo desde la subnet `snet-app` sin crear IPs privadas nuevas. ¿Qué configuras?

- A. Un private endpoint.
- B. Un service endpoint `Microsoft.Storage` en la subnet y una virtual network rule en el firewall de la cuenta.
- C. Una IP network rule con el rango de la subnet.
- D. Un NSG en la subnet que permita el puerto 443.

??? success "Respuesta"
    **B.** El service endpoint identifica el tráfico de esa subnet ante la cuenta, sin crear IPs. A crea una IP privada. C no funciona: las IP rules solo aceptan IPs públicas. D no restringe el acceso a la cuenta desde otros orígenes.

**5.** ¿Qué combinación necesitas para configurar object replication?

- A. Change feed en la cuenta destino y soft delete en la origen.
- B. Blob versioning en origen y destino, y change feed en la origen.
- C. Cuentas GRS en ambas regiones.
- D. Lock ReadOnly en el container de destino.

??? success "Respuesta"
    **B.** Es el requisito documentado. A invierte los papeles. C no es necesario. D impediría la escritura de las réplicas.

**6.** Un usuario monta un share de Azure Files con su identidad de AD DS. Tiene **Storage File Data SMB Share Contributor**, pero la ACL de NTFS de una carpeta solo le da lectura. ¿Qué puede hacer en esa carpeta?

- A. Leer y escribir, porque RBAC gana.
- B. Solo leer.
- C. Nada.
- D. Cambiar la ACL.

??? success "Respuesta"
    **B.** Se aplican los dos niveles y el más restrictivo limita: el share permite escribir, pero NTFS solo lectura. A es falso. C: tiene lectura. D requiere Elevated Contributor y permisos NTFS de control total.

**7.** Necesitas copiar 2 TB de una storage account a otra en otra región, de forma programada y sin pasar los datos por tu equipo. ¿Qué herramienta usas?

- A. Azure Storage Explorer descargando y volviendo a subir.
- B. AzCopy con copia servidor a servidor.
- C. Azure Data Box.
- D. Object replication sobre Azure Files.

??? success "Respuesta"
    **B.** AzCopy copia entre cuentas directamente en el backend de Azure y es fácil de programar. A pasa por tu equipo. C es para mover datos físicamente desde on-premises. D no existe para Azure Files (object replication es de block blobs).

## Para profundizar

| Tema | Nota del cuaderno |
| --- | --- |
| Object, block y file storage en las tres nubes, clases y redundancia | [Almacenamiento y datos](../../../cloud/redes-y-datos/almacenamiento-datos.md) |
| Cifrado, Key Vault y gestión de secretos | [Seguridad de cifrado y secretos](../../../cloud/seguridad/seguridad-cifrado-secretos.md) |
| Private endpoints, DNS privado y redes | [Redes en la nube](../../../cloud/redes-y-datos/redes.md) |
| Backups, réplicas y RPO | [Resiliencia](../../../cloud/operacion-y-gobierno/resiliencia.md) |
| Costos de tiers y retención | [FinOps y costos](../../../cloud/fundamentos/finops-costos.md) |
| Práctica guiada | [Lab: Azure VNet, NSG y una VM con Azure CLI](../../../laboratorios/cloud/azure-vnet-vm.md) |

## Referencias

- [Study guide del examen AZ-104](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-104)
- [Redundancia de Azure Storage](https://learn.microsoft.com/es-es/azure/storage/common/storage-redundancy)
- [Conceder acceso limitado con SAS](https://learn.microsoft.com/es-es/azure/storage/common/storage-sas-overview)
- [Niveles de acceso de los blobs](https://learn.microsoft.com/es-es/azure/storage/blobs/access-tiers-overview)
- [Protección de datos de blobs](https://learn.microsoft.com/es-es/azure/storage/blobs/data-protection-overview)
- [Azure Files: autenticación basada en identidad](https://learn.microsoft.com/es-es/azure/storage/files/storage-files-active-directory-overview)
