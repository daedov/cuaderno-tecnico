---
tags:
  - certificacion
---

# Cómo preparar un examen de certificación

> Lo que sirve para cualquier examen de AWS, Azure, Google Cloud o HashiCorp. Cada guía de certificación solo añade lo propio: formato, dominios, servicios y trampas específicas.

## Antes de empezar

- **La guía oficial manda**: dominios, pesos y servicios en alcance cambian. Descárgala al empezar y vuelve a revisarla antes de agendar. Precio, idiomas y política de renovación también cambian.
- **Estudia según el peso**: los dominios con más porcentaje se llevan más horas. Si el proveedor no publica pesos (HashiCorp, Google), reparte por igual.
- **Practica en una cuenta real**: crea alertas de presupuesto el primer día y borra lo que crees al terminar cada práctica. Ver [Laboratorios](../laboratorios/index.md).
- **Aprende los nombres en inglés**: aunque presentes en español, servicios y opciones de respuesta suelen quedar en inglés.

!!! tip "Señal de que estás lista"
    Agenda cuando superes con holgura (80 % o más) el simulacro oficial o varios de calidad, explicando por qué cada opción incorrecta lo es.

!!! warning "Evita los *dumps*"
    Los bancos de "preguntas reales" filtradas violan el acuerdo del candidato y pueden anular la certificación. Usa preguntas oficiales u originales, como las de estas notas.

## Durante el examen

- **Primera pasada completa**: responde todo, marca (*flag for review*) las dudosas y vuelve al final. Calcula tu ritmo: minutos disponibles ÷ número de preguntas.
- **No dejes ninguna en blanco**: en AWS, Azure, Google y HashiCorp una pregunta sin responder cuenta como incorrecta y no hay penalización por adivinar.
- **Lee primero la última frase**: ahí está lo que piden ("Which service…", "What should you do?", "Choose two"). En las de respuesta múltiple el enunciado dice cuántas elegir y solo puntúan si aciertas todas.
- **Descarta primero**: casi siempre hay dos opciones fuera de lugar (otra categoría de servicio o algo que viola un requisito). Decide entre las otras dos con la palabra clave del enunciado.
- **No sobrepienses**: si una opción exige construir algo a mano y otra lo resuelve con un servicio gestionado, casi siempre gana la gestionada.

## Palabras clave que deciden la respuesta

Valen para cualquier proveedor. Cada guía añade las suyas.

| Frase en la pregunta | Qué suele significar |
| --- | --- |
| *MOST cost-effective* / *minimize cost* | La opción más barata **que cumpla todos los requisitos**, no la más barata a secas |
| *LEAST operational overhead* / *fully managed* / *minimize administrative effort* | Servicio gestionado o serverless; nada de scripts, cron en una VM ni software autogestionado |
| *MOST secure* / *least privilege* | Rol o permiso más acotado, cifrado, tráfico privado, sin credenciales de larga duración |
| *Highly available* | Varias zonas de disponibilidad |
| *Fault tolerant* | Sigue funcionando **sin degradación**: capacidad de sobra en varias zonas (más exigente que HA) |
| *Disaster recovery*, *data sovereignty*, *latencia global* | Varias regiones |
| *Without changing the application code* | Cambios de infraestructura: balanceador, autoscaling, proxy, caché |
| *Decouple* | Colas y eventos |
| *Audit* / "quién hizo qué" | Logs de auditoría del proveedor (CloudTrail, Activity Log, Cloud Audit Logs) |

## Trampas que se repiten

Opciones que **funcionan pero son incorrectas** porque violan una buena práctica:

- Crear usuarios con claves de acceso de larga duración para una aplicación (en vez de roles, managed identities o service accounts sin clave).
- Dar permisos amplios (*Owner*, *Editor*, *AdministratorAccess*) para resolver un problema puntual.
- Abrir `0.0.0.0/0` en SSH o RDP.
- "Escribir un script en una VM" cuando existe un servicio gestionado que lo hace.
- Guardar secretos en el código o en variables sin cifrar.

## Examen en línea (*online proctored*)

- Escritorio despejado, un solo monitor y nada escrito a la vista.
- Documento de identidad vigente con el mismo nombre del registro.
- Haz la prueba técnica del equipo y la red **días antes**, no el mismo día.
- Si tomas una pausa no programada, el examen puede terminar o no dejarte volver a preguntas anteriores: revisa la política del proveedor.

## Después de aprobar

- **Credencial digital** (Credly u otra): añádela a LinkedIn y al CV.
- **Descuentos**: AWS suele dar un voucher de 50 % para el siguiente examen.
- **Renovación**: AWS cada 3 años, Google cada 2 o 3 según el nivel (revisa la página de cada una), HashiCorp cada 2 y Microsoft cada año (con un *renewal assessment* gratuito). Apunta la fecha.
- **Qué demuestra**: que conoces el vocabulario y las decisiones típicas. **No** demuestra experiencia práctica, así que acompáñala con un proyecto propio. Qué certificación encaja con cada puesto está en [Roles profesionales](roles-profesionales.md).
