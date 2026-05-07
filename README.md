# Support Ticket Classifier Pipeline (OpenTofu + AWS)

## Descripción

Este proyecto implementa una pipeline serverless en AWS para el procesamiento automático de tickets de soporte. El objetivo es simular un sistema de clasificación de tickets que determina su nivel de urgencia y los organiza en almacenamiento según su severidad.

La infraestructura está definida completamente como código utilizando OpenTofu, y el despliegue se realiza sin intervención manual mediante prácticas de infraestructura reproducible.

## Arquitectura

La solución está compuesta por los siguientes elementos:

- 3 funciones AWS Lambda:
  - **validate_ticket**: valida la estructura y contenido del ticket.
  - **classify_ticket**: determina la severidad del ticket (urgent, normal, low).
  - **route_ticket**: almacena el resultado en un bucket de S3 según su clasificación.

- AWS Step Functions:
  - Orquesta el flujo de ejecución entre las tres Lambdas.
  - Incluye un estado **Choice** que evalúa la severidad del ticket.
  - Contiene estados de éxito (**Succeed**) y fallo (**Fail**).

- Amazon S3:
  - Almacena los tickets procesados en carpetas según su severidad:
    - `urgent/`
    - `normal/`
    - `low/`

## Flujo de ejecución

1. Se recibe un JSON con información del ticket.
2. La Lambda `validate_ticket` verifica que los datos sean válidos.
3. La Lambda `classify_ticket` asigna una severidad basada en reglas.
4. La Lambda `route_ticket` guarda el ticket en S3.
5. La Step Function evalúa el resultado y finaliza el flujo.

## Ejemplo de entrada

```json
{
  "ticket_id": "tk-001",
  "customer": "student@uag.mx",
  "priority_score": 90,
  "description": "System is down and not working"
}

## Despliegue con GitHub Actions

El despliegue se realiza automáticamente al hacer **push a la rama `main`**.

El workflow ejecuta estos pasos:

1. Descarga el código del repositorio.  
2. Se autentica en AWS usando **OIDC** (sin access keys).  
3. Instala OpenTofu.  
4. Ejecuta:
   - `tofu fmt`
   - `tofu init`
   - `tofu validate`
   - `tofu plan`
5. Ejecuta `tofu apply` para desplegar la infraestructura.

En pull requests solo se ejecuta `tofu plan`.