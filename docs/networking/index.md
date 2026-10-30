# Networking :material-lan:

**Networking es la base**: los fundamentos de redes que hay debajo de todo, tanto en un datacenter on-premise como en la nube. Una VPC, un security group o un load balancer son conceptos de red de siempre con otro nombre.

La sección va **de lo más básico a lo más complejo**. Cada nota asume solo lo visto en las anteriores, así que se recomienda leerla en orden.

Para ver cómo se aplica todo esto en AWS, Azure y Google Cloud, ver [Redes en la nube](../cloud/redes-y-datos/redes.md). Ver también el [mapa de relaciones](../mapa-de-relaciones.md).

## Básico

- **1.** [Fundamentos de redes](basico/fundamentos-redes.md): qué es una red, tipos, dispositivos, medios, latencia y bandwidth
- **2.** [Modelos OSI y TCP/IP](basico/modelos-osi-tcpip.md): capas, encapsulación y PDUs
- **3.** [Capa de enlace y Ethernet](basico/capa-enlace-ethernet.md): MAC, switching, ARP, VLANs
- **4.** [Direccionamiento IP](basico/direccionamiento-ip.md): IPv4, CIDR, subnetting con ejercicios, IPv6

## Intermedio

- **5.** [Routing y NAT](intermedio/routing-nat.md): tablas de rutas, OSPF y BGP en lo esencial, NAT y PAT
- **6.** [Capa de transporte](intermedio/capa-transporte.md): TCP, UDP, puertos, QUIC
- **7.** [Servicios de red](intermedio/servicios-red.md): DHCP, DNS en profundidad, NTP
- **8.** [Protocolos de aplicación](intermedio/protocolos-aplicacion.md): HTTP/1.1, HTTP/2, HTTP/3, TLS, SSH

## Avanzado

- **9.** [Seguridad de red](avanzado/seguridad-red.md): firewalls, DMZ, segmentación, VPN, zero trust
- **10.** [Balanceo y alta disponibilidad](avanzado/balanceo-alta-disponibilidad.md): L4 vs L7, reverse proxy, VRRP, anycast, CDN
- **11.** [Redes de datacenter e híbridas](avanzado/redes-datacenter-hibridas.md): spine-leaf, SDN, conectividad on-premise ↔ nube
- **12.** [Troubleshooting de red](avanzado/troubleshooting-red.md): metodología por capas y herramientas

!!! note "Añadir una nota"
    Crea un `.md` en el nivel que corresponda (`basico/`, `intermedio/` o `avanzado/`) y agrégalo a su `.pages` para fijar su orden en el menú.
