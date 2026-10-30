---
tags:
  - redes
  - networking
  - subnetting
---

# Direccionamiento IP

> Cómo se escriben y se reparten las direcciones IPv4 e IPv6: binario, máscaras, CIDR, subnetting paso a paso con ejercicios resueltos, rangos privados, direcciones especiales y las IPs que cada nube reserva en una subnet.

!!! info "Antes de leer"
    Esta nota asume lo visto en [Capa de enlace y Ethernet](capa-enlace-ethernet.md): que la MAC sirve dentro de la red local, que ARP traduce IP a MAC y que, para salir de la red local, se usa el **default gateway** (router).

## ¿Qué es una dirección IP?

Una **dirección IP** (*IP address*) es la dirección **lógica** de una interfaz en capa 3. A diferencia de la MAC (fija de fábrica y útil solo en la red local), la IP depende de **en qué red estás** y sirve para llegar a cualquier red del mundo.

Analogía: la IP es como una dirección postal con dos partes, **calle** y **número**. La calle es la **parte de red** (*network portion*): todos los vecinos la comparten. El número es la **parte de host** (*host portion*): distingue a cada casa. Los routers solo miran la calle para decidir el camino; el número solo importa al llegar.

## IPv4 en decimal y en binario

Una dirección **IPv4** tiene **32 bits**, que se escriben en **notación decimal con puntos** (*dotted decimal*): cuatro **octetos** (grupos de 8 bits) de 0 a 255.

Para pasar un octeto a binario, usa los pesos de cada bit:

| Bit | 1.º | 2.º | 3.º | 4.º | 5.º | 6.º | 7.º | 8.º |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Peso | 128 | 64 | 32 | 16 | 8 | 4 | 2 | 1 |

Ejemplo con `192.168.10.37`:

| Octeto | Suma de pesos | Binario |
| --- | --- | --- |
| 192 | 128 + 64 | `11000000` |
| 168 | 128 + 32 + 8 | `10101000` |
| 10 | 8 + 2 | `00001010` |
| 37 | 32 + 4 + 1 | `00100101` |

`192.168.10.37` = `11000000.10101000.00001010.00100101`

## Máscara de red y CIDR

La **máscara de red** (*subnet mask*) indica qué bits son de red (los `1`) y cuáles de host (los `0`). Los unos siempre van seguidos y a la izquierda.

La notación **CIDR** (*Classless Inter-Domain Routing*) escribe la máscara como **cuántos bits de red** tiene, después de una barra: `/24` significa 24 unos.

| CIDR | Máscara | Direcciones totales | Hosts usables (on-premise) |
| --- | --- | --- | --- |
| `/8` | `255.0.0.0` | 16 777 216 | 16 777 214 |
| `/16` | `255.255.0.0` | 65 536 | 65 534 |
| `/20` | `255.255.240.0` | 4096 | 4094 |
| `/22` | `255.255.252.0` | 1024 | 1022 |
| `/23` | `255.255.254.0` | 512 | 510 |
| `/24` | `255.255.255.0` | 256 | 254 |
| `/25` | `255.255.255.128` | 128 | 126 |
| `/26` | `255.255.255.192` | 64 | 62 |
| `/27` | `255.255.255.224` | 32 | 30 |
| `/28` | `255.255.255.240` | 16 | 14 |
| `/29` | `255.255.255.248` | 8 | 6 |
| `/30` | `255.255.255.252` | 4 | 2 |
| `/31` | `255.255.255.254` | 2 | 2 (solo enlaces punto a punto, RFC 3021) |
| `/32` | `255.255.255.255` | 1 | 1 (un único host) |

Las dos fórmulas que lo explican todo, con *n* = longitud del prefijo:

- Direcciones totales = **2^(32 − n)**
- Hosts usables = **2^(32 − n) − 2**, porque en cada subred se reservan dos:
    - la **dirección de red** (*network address*): todos los bits de host en `0`; identifica a la subred.
    - la **dirección de broadcast**: todos los bits de host en `1`; llega a todos los hosts de la subred.

!!! note "Clases A, B y C: historia"
    Antes de CIDR (1993), las redes se repartían en **clases** fijas: A (`/8`), B (`/16`) y C (`/24`). Desperdiciaba muchísimas direcciones y está obsoleto, pero aún oirás "una clase C" para decir "una `/24`".

### Cómo se calcula la red: la operación AND

Un equipo sabe a qué red pertenece haciendo un **AND bit a bit** entre su IP y la máscara (1 AND 1 = 1; cualquier otra combinación = 0).

Ejemplo: `192.168.10.37/26`. La máscara `/26` es `255.255.255.192`; los tres primeros octetos quedan iguales, así que solo hay que mirar el último:

```text
IP       37  = 0 0 1 0 0 1 0 1
Máscara 192  = 1 1 0 0 0 0 0 0
               ---------------  AND
Red          = 0 0 0 0 0 0 0 0  = 0
```

- Red: `192.168.10.0/26`
- Broadcast: bits de host en `1` → `00111111` = 63 → `192.168.10.63`
- Hosts: `192.168.10.1` a `192.168.10.62`

Así decide un equipo si un destino está **en su misma red** (lo entrega directo con ARP) o **en otra** (lo envía al gateway). Lo verás en [Routing y NAT](../intermedio/routing-nat.md).

## Subnetting paso a paso

**Subnetting** es dividir una red en redes más pequeñas tomando bits de la parte de host. Sirve para separar entornos, aplicar reglas de firewall por segmento y no desperdiciar direcciones.

El método, que sirve para cualquier ejercicio:

1. **Cuántos bits** necesitas: para *S* subredes, el menor *b* con 2^b ≥ *S*; para *H* hosts, el menor *h* con 2^h − 2 ≥ *H*.
2. **Nuevo prefijo**: prefijo original + *b* (o 32 − *h*).
3. **Tamaño de bloque** (*block size*): 2^(32 − nuevo prefijo) en total; en el octeto donde cae el corte, es 256 menos el valor de la máscara en ese octeto.
4. **Enumera** las redes sumando el tamaño de bloque desde la primera.
5. Para cada una: red = primera, broadcast = siguiente red − 1, hosts = lo de en medio.

### Ejercicio 1: dividir una /24 en 4 subredes

**Enunciado:** divide `192.168.10.0/24` en 4 subredes iguales.

1. 4 subredes → 2^2 = 4 → **2 bits**.
2. Nuevo prefijo: 24 + 2 = **/26** (máscara `255.255.255.192`).
3. Bloque: 2^(32 − 26) = **64** direcciones (256 − 192 = 64).
4. Los 2 bits prestados son los dos primeros del último octeto; sus cuatro combinaciones dan las cuatro redes:

| Bits prestados | Último octeto en binario | Red | Primer host | Último host | Broadcast |
| --- | --- | --- | --- | --- | --- |
| `00` | `00`000000 = 0 | `192.168.10.0/26` | `.1` | `.62` | `.63` |
| `01` | `01`000000 = 64 | `192.168.10.64/26` | `.65` | `.126` | `.127` |
| `10` | `10`000000 = 128 | `192.168.10.128/26` | `.129` | `.190` | `.191` |
| `11` | `11`000000 = 192 | `192.168.10.192/26` | `.193` | `.254` | `.255` |

Cada subred tiene 64 direcciones y **62 hosts usables**.

### Ejercicio 2: cuántos hosts en una /27 y a qué red pertenece una IP

**Enunciado:** ¿cuántos hosts caben en una `/27`? ¿En qué subred está `10.0.5.77/27`?

1. Bits de host: 32 − 27 = 5 → 2^5 = **32 direcciones**, **30 hosts usables**.
2. Máscara: 27 bits → último octeto `11100000` = 128 + 64 + 32 = **224** → `255.255.255.224`. Bloque: 256 − 224 = **32**.
3. Las redes van de 32 en 32: 0, 32, **64**, 96… El 77 cae entre 64 y 95.
4. Comprobación en binario: 77 = `01001101`; AND con `11100000` = `01000000` = **64**.

Resultado: red `10.0.5.64/27`, hosts `10.0.5.65` a `10.0.5.94`, broadcast `10.0.5.95`.

### Ejercicio 3: cuando el corte cae en el tercer octeto

**Enunciado:** ¿a qué subred pertenece `172.16.45.200/20`?

1. `/20` = 8 + 8 + 4: el corte cae en el **tercer octeto**, que tiene 4 bits de red: `11110000` = 240 → máscara `255.255.240.0`.
2. Bloque en el tercer octeto: 256 − 240 = **16**. Redes: 0, 16, **32**, 48…
3. 45 cae entre 32 y 47. En binario: 45 = `00101101`; AND `11110000` = `00100000` = **32**.
4. El cuarto octeto es todo de host: va de 0 a 255.

Resultado: red `172.16.32.0/20`, broadcast `172.16.47.255`, hosts de `172.16.32.1` a `172.16.47.254` (4096 direcciones, 4094 usables). El `.200` no influye: lo que manda es el octeto donde cae el corte.

### Ejercicio 4: planificar una VPC /16 en subredes /24

**Enunciado:** tienes `10.0.0.0/16` para una VPC con tres zonas de disponibilidad (*Availability Zones*) y tres capas por zona: pública, aplicación y datos.

1. ¿Cuántas `/24` caben en una `/16`? 2^(24 − 16) = **256** subredes, de `10.0.0.0/24` a `10.0.255.0/24`.
2. Necesitas 3 × 3 = 9. Usa un esquema que se lea solo, dejando huecos para crecer:

    | Capa | Zona a | Zona b | Zona c |
    | --- | --- | --- | --- |
    | Pública | `10.0.1.0/24` | `10.0.2.0/24` | `10.0.3.0/24` |
    | Aplicación | `10.0.11.0/24` | `10.0.12.0/24` | `10.0.13.0/24` |
    | Datos | `10.0.21.0/24` | `10.0.22.0/24` | `10.0.23.0/24` |

3. Hosts por subred: 256 − 5 = **251** en AWS y Azure, 256 − 4 = **252** en Google Cloud (ver [En la nube](#en-la-nube)).
4. Quedan 247 `/24` libres para nuevas capas, otra zona o servicios gestionados.

!!! tip "Piensa en lo que consume IPs"
    Las `/24` son cómodas de leer, pero pueden quedarse cortas. En Kubernetes gestionado, según el plugin de red, **cada pod** puede recibir una IP de la subred (es lo que hace por defecto el VPC CNI de Amazon EKS). En ese caso, reserva subredes de aplicación mayores (por ejemplo, `/20`) desde el principio: ampliar o mover una subred en uso es mucho más difícil que planificarla bien.

### Ejercicio 5: VLSM, subredes de distinto tamaño

**VLSM** (*Variable Length Subnet Masking*, máscaras de longitud variable) consiste en dar a cada segmento el tamaño que necesita. **Enunciado:** de `192.168.50.0/24` necesitas una red de 100 hosts, otra de 50, otra de 20 y dos enlaces punto a punto (2 hosts cada uno).

Regla: **asigna de mayor a menor**, para que los bloques queden alineados.

| Necesidad | Bits de host | Prefijo | Red asignada | Hosts usables | Broadcast |
| --- | --- | --- | --- | --- | --- |
| 100 hosts | 7 (2^7 − 2 = 126) | `/25` | `192.168.50.0/25` | `.1`–`.126` | `.127` |
| 50 hosts | 6 (2^6 − 2 = 62) | `/26` | `192.168.50.128/26` | `.129`–`.190` | `.191` |
| 20 hosts | 5 (2^5 − 2 = 30) | `/27` | `192.168.50.192/27` | `.193`–`.222` | `.223` |
| Enlace 1 | 2 (2^2 − 2 = 2) | `/30` | `192.168.50.224/30` | `.225`–`.226` | `.227` |
| Enlace 2 | 2 | `/30` | `192.168.50.228/30` | `.229`–`.230` | `.231` |

Queda libre `192.168.50.232` a `.255`, que se puede expresar como `192.168.50.232/29` + `192.168.50.240/28`.

### Comprobar con Python

El módulo estándar `ipaddress` es ideal para verificar cálculos o validar planes de red en un script:

```python title="subredes.py"
import ipaddress

red = ipaddress.ip_network("192.168.10.0/24")
for subred in red.subnets(new_prefix=26):
    print(subred, subred[1], subred[-2], subred.broadcast_address)

iface = ipaddress.ip_interface("172.16.45.200/20")
print(iface.network, iface.network.num_addresses)
```

```text
192.168.10.0/26 192.168.10.1 192.168.10.62 192.168.10.63
192.168.10.64/26 192.168.10.65 192.168.10.126 192.168.10.127
192.168.10.128/26 192.168.10.129 192.168.10.190 192.168.10.191
192.168.10.192/26 192.168.10.193 192.168.10.254 192.168.10.255
172.16.32.0/20 4096
```

## Rangos privados y públicos

Las **direcciones públicas** son únicas en internet y las asignan los registros regionales (en América Latina, **LACNIC**) a proveedores y organizaciones. Las **privadas** (RFC 1918) se pueden reutilizar en cualquier red interna, pero **no se enrutan en internet**: para salir necesitan **NAT** (ver [Routing y NAT](../intermedio/routing-nat.md)).

| Rango (RFC 1918) | CIDR | Desde | Hasta |
| --- | --- | --- | --- |
| 10.x | `10.0.0.0/8` | `10.0.0.0` | `10.255.255.255` |
| 172.16–31.x | `172.16.0.0/12` | `172.16.0.0` | `172.31.255.255` |
| 192.168.x | `192.168.0.0/16` | `192.168.0.0` | `192.168.255.255` |

!!! warning "172.16.0.0/12 no es todo el 172.x"
    Solo de `172.16` a `172.31` es privado. `172.32.0.1`, por ejemplo, es una dirección pública.

También existe `100.64.0.0/10` (*shared address space*, RFC 6598), pensado para el **CGNAT** de los proveedores de internet. Algunas nubes lo aceptan como rango interno cuando se acaban las direcciones RFC 1918.

## Direcciones especiales

| Dirección o rango | Uso |
| --- | --- |
| `0.0.0.0` | "Esta máquina, cualquier interfaz": un servicio que escucha en `0.0.0.0:8000` acepta conexiones por todas sus IPs |
| `0.0.0.0/0` | "Cualquier destino": la **ruta por defecto** y el origen "todo internet" en reglas de firewall |
| `127.0.0.0/8` | **Loopback**: el propio equipo. `127.0.0.1` es `localhost` |
| `169.254.0.0/16` | **Link-local**: Windows y otros sistemas se autoasignan una (APIPA) cuando no consiguen IP por DHCP. Si ves una, el equipo no recibió configuración |
| `169.254.169.254` | En las tres nubes, el **servicio de metadatos** de la VM (credenciales temporales, datos de la instancia). Protegerlo es clave: ver [Máquinas virtuales](../../cloud/computo/maquinas-virtuales.md) |
| `255.255.255.255` | **Broadcast limitado**: todos los hosts de la red local |
| `224.0.0.0/4` | **Multicast** |
| `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24` | **Documentación** (RFC 5737): para ejemplos, nunca se usan en redes reales. Por eso aparecen en estas notas |
| `240.0.0.0/4` | Reservado para uso futuro |

## IPv6

IPv4 tiene unos 4300 millones de direcciones (2^32) y se agotaron hace años. **IPv6** usa **128 bits**, que dan para asignar direcciones públicas a todo sin NAT.

### Formato y abreviación

Ocho grupos de 16 bits en **hexadecimal**, separados por dos puntos:

`2001:0db8:0000:0000:0000:ff00:0042:8329`

Reglas para abreviar (RFC 5952, el formato recomendado):

1. Quita los **ceros a la izquierda** de cada grupo: `0db8` → `db8`, `0042` → `42`, `0000` → `0`.
2. Sustituye **la secuencia más larga** de grupos `0` consecutivos (dos o más) por `::`. **Solo una vez** por dirección; si hay empate, la primera.
3. Escribe en minúsculas.

| Completa | Abreviada |
| --- | --- |
| `2001:0db8:0000:0000:0000:ff00:0042:8329` | `2001:db8::ff00:42:8329` |
| `2001:0db8:0000:0001:0000:0000:0000:0001` | `2001:db8:0:1::1` |
| `2001:0db8:0000:0000:0001:0000:0000:0001` | `2001:db8::1:0:0:1` (empate: se comprime la primera secuencia) |
| `fe80:0000:0000:0000:0000:0000:0000:0001` | `fe80::1` |

Para expandir, cuenta los grupos que hay y rellena con `0` hasta llegar a ocho: `fe80::1` tiene 2 grupos escritos, así que `::` vale 6 grupos de ceros.

### Prefijos y tipos de dirección

En IPv6 también se usa CIDR. Lo normal es que **una subred sea `/64`**: 64 bits de red y 64 de host (la autoconfiguración **SLAAC** lo necesita). Una organización suele recibir una `/48` o una `/56` y la reparte en `/64`.

| Tipo | Prefijo | Para qué |
| --- | --- | --- |
| **Global unicast** (GUA) | `2000::/3` | Direcciones públicas, enrutables en internet |
| **Unique local** (ULA) | `fc00::/7` (en la práctica `fd00::/8`) | Equivalente a las privadas de IPv4 |
| **Link-local** | `fe80::/10` | Solo válidas en el enlace local; toda interfaz IPv6 tiene una |
| **Loopback** | `::1/128` | El propio equipo |
| **Unspecified** | `::/128` | "Sin dirección" (equivale a `0.0.0.0`) |
| **Multicast** | `ff00::/8` | Grupos; por ejemplo `ff02::1` = todos los nodos del enlace |
| **Documentación** | `2001:db8::/32` | Ejemplos |

IPv6 **no tiene broadcast**: usa multicast. Tampoco usa ARP, sino **NDP** (ver [Capa de enlace y Ethernet](capa-enlace-ethernet.md#arp-de-ip-a-mac)). Hoy lo habitual es **dual stack** (IPv4 e IPv6 a la vez en cada interfaz).

## En la nube

Las subnets de la nube usan las mismas reglas de CIDR, con dos diferencias: **reservan más direcciones** que la red y el broadcast, y tienen **tamaños mínimos y máximos**.

| | AWS | Azure | Google Cloud |
| --- | --- | --- | --- |
| IPs reservadas por subnet IPv4 | **5** | **5** | **4** |
| Cuáles (ejemplo `10.0.1.0/24`) | `.0` red, `.1` VPC router, `.2` DNS, `.3` uso futuro, `.255` broadcast | `.0` red, `.1` default gateway, `.2` y `.3` DNS de Azure, `.255` broadcast | `.0` red, `.1` default gateway, `.254` uso futuro, `.255` broadcast |
| Hosts usables en una `/24` | 251 | 251 | 252 |
| Subnet IPv4 más pequeña | `/28` (11 usables) | `/29` (3 usables) | `/29` (4 usables) |
| Subnet IPv4 más grande | `/16` | `/2` | Depende del rango de la VPC (revisa los límites vigentes) |
| Subnet IPv6 | Habitualmente `/64` (admite de `/44` a `/64`) | Exactamente `/64` | `/64` |

Más diseño de VPCs y subnets en [Redes en la nube](../../cloud/redes-y-datos/redes.md).

!!! warning "Rangos que no se solapen"
    Elige el rango de cada VPC/VNet pensando en **todas** las redes con las que se conectará algún día: otras VPCs, la oficina, la VPN, otras nubes. Dos redes con rangos solapados no se pueden conectar por peering ni enrutar entre sí sin trucos de NAT. Lo retoma [Redes de datacenter e híbridas](../avanzado/redes-datacenter-hibridas.md).

## Conclusión práctica

- Una IPv4 son 32 bits; la máscara (o el `/n`) separa red y host.
- Totales = 2^(32 − n); usables on-premise = totales − 2; en la nube, totales − 5 (AWS, Azure) o − 4 (Google Cloud).
- Para subnetting: bits necesarios → nuevo prefijo → tamaño de bloque → enumerar.
- Usa rangos RFC 1918 sin solapes y deja espacio para crecer.
- En IPv6, las subredes son `/64`, `::` solo una vez, y no hay broadcast ni ARP.
- Comprueba tus cálculos con `ipaddress` de Python o una calculadora CIDR antes de aplicarlos.

## Relación con otras secciones

| Enfoque | Qué se mira desde ahí | Nota |
| --- | --- | --- |
| Cloud (el control) | Rangos de VPC/VNet, subnets por zona, IPs reservadas, metadatos en `169.254.169.254` | [Redes en la nube](../../cloud/redes-y-datos/redes.md), [Máquinas virtuales](../../cloud/computo/maquinas-virtuales.md) |
| DevOps (la automatización) | Definir rangos y subnets como código (`cidrsubnet()` en Terraform); IPs de pods en Kubernetes | [Infrastructure as Code](../../devops/iac/infraestructura-como-codigo.md), [Terraform](../../devops/iac/terraform-basico.md), [Kubernetes](../../devops/contenedores/kubernetes.md) |
| DevSecOps (la verificación) | Detectar `0.0.0.0/0` en reglas de firewall; proteger el servicio de metadatos | [Seguridad de IaC](../../devsecops/infraestructura-y-contenedores/seguridad-iac.md) |
| Laboratorios (la práctica) | Practicar esto paso a paso | [Lab 01: Diagnóstico de red desde Linux](../../laboratorios/fundamentos/linux-red-diagnostico.md), [Lab 02: Plan de direccionamiento IP para una VPC](../../laboratorios/fundamentos/subnetting-plan-ips.md), [Lab 17: AWS: VPC con subnets públicas y privadas y una EC2](../../laboratorios/cloud/aws-vpc-ec2.md), [Lab 19: Azure: VNet, NSG y una VM con Azure CLI](../../laboratorios/cloud/azure-vnet-vm.md) |

**Siguiente:** [Routing y NAT](../intermedio/routing-nat.md)

## Referencias

- [RFC 1918: Address Allocation for Private Internets](https://www.rfc-editor.org/rfc/rfc1918)
- [RFC 4632: Classless Inter-Domain Routing (CIDR)](https://www.rfc-editor.org/rfc/rfc4632)
- [RFC 6890: Special-Purpose IP Address Registries](https://www.rfc-editor.org/rfc/rfc6890)
- [RFC 5952: A Recommendation for IPv6 Address Text Representation](https://www.rfc-editor.org/rfc/rfc5952)
- [RFC 4291: IP Version 6 Addressing Architecture](https://www.rfc-editor.org/rfc/rfc4291)
- [Python: módulo ipaddress](https://docs.python.org/es/3/library/ipaddress.html)
- [AWS: Subnet CIDR blocks](https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html)
- [Azure Virtual Network FAQ (direcciones reservadas)](https://learn.microsoft.com/es-es/azure/virtual-network/virtual-networks-faq)
- [Google Cloud: Subnets](https://cloud.google.com/vpc/docs/subnets)
