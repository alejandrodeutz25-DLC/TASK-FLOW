markdown
# Post-mortem: Caída del login por migración incompleta

*Publicado por [Tu Nombre] — [Fecha: 25 de julio de 2026]*

## Contexto

Trabajo como parte de un equipo remoto de 5 personas en **TaskFlow**, una aplicación de gestión de tareas estilo Trello, desarrollada bajo metodología ágil con sprints de dos semanas. El equipo despliega a producción varias veces por semana usando integración continua, y las revisiones de código se hacen exclusivamente por Pull Request, ya que trabajamos en distintas zonas horarias.

En el sprint en curso, el objetivo era lanzar una funcionalidad de **búsqueda avanzada de tareas** (filtros por etiqueta, fecha y responsable), una de las features más pedidas por los usuarios.

## Problema

El viernes a las 16:40 (UTC-3) se desplegó a producción la nueva funcionalidad de búsqueda. El deploy incluía una migración de base de datos que agregaba un índice compuesto y una columna `search_tags` a la tabla `tasks`.
A los pocos minutos, empezaron a llegar alertas de **timeouts en el login de usuarios**. La migración había quedado aplicada solo parcialmente: el índice se creó correctamente, pero la columna `search_tags` se agregó sin el valor por defecto (`DEFAULT '[]'`), lo que provocó bloqueos de tabla (`table lock`) en `tasks` justo cuando el endpoint de login intentaba leer las tareas pendientes del usuario para el dashboard inicial.

**Impacto:** ~40 minutos de degradación, con el 100% de los intentos de login afectados y aproximadamente 230 usuarios activos impactados en ese horario.

## Acciones

### Respuesta inmediata
1. Se detectó el problema por las alertas automáticas de latencia (Datadog) a las 16:43.
2. Se armó un canal de incidente en Slack (`#incident-2026-07-25`) y se asignó un Incident Commander.
3. A las 16:52 se identificó la migración como causa probable y se hizo rollback de la columna `search_tags`.
4. A las 17:21 el sistema volvió a operar con normalidad (MTTR: ~38 minutos).

### Post-mortem constructivo

**Descripción objetiva del incidente:** 
El deploy del PR #1 (feature de búsqueda avanzada) incluyó una migración de base de datos que dejó una columna sin valor por defecto en una tabla de alto tráfico, generando bloqueos que afectaron un endpoint no relacionado directamente (login).

**Análisis de causas (causa raíz, sin señalar personas):**
- La migración no se probó bajo carga similar a producción antes del deploy.
- No existía un checklist de revisión específico para migraciones que tocan tablas críticas.
- El pipeline de CI no incluye una etapa de "dry run" de migraciones contra un dataset de tamaño realista.

**Acciones correctivas y preventivas:**
- Se agregó un checklist obligatorio de PR para migraciones que afectan tablas de alto tráfico.
- Se incorporó una etapa de staging con datos sintéticos a escala de producción antes de aprobar migraciones.
- Se configuró una alerta específica de `table lock` en el sistema de monitoreo.

**Lecciones aprendidas:**
- Los cambios de esquema en tablas críticas necesitan el mismo nivel de revisión que el código de negocio, no solo un "LGTM" rápido.
- La comunicación temprana en el canal de incidente redujo significativamente el tiempo de diagnóstico.

## Aprendizajes

Este incidente reforzó que la velocidad de entrega en un equipo ágil remoto no puede ir en contra de la disciplina técnica en cambios de bajo nivel como las migraciones. El checklist y la etapa de staging que implementamos ya se aplicaron en los dos deploys siguientes sin incidentes similares.

## Evidencia de control de versiones

- **Repositorio público:** https://github.com/alejandrodeutz25-DLC/TASK-FLOW
- **Pull Request #1 (feature):** https://github.com/alejandrodeutz25-DLC/TASK-FLOW/pull/1
- **Pull Request #2 (hotfix):** https://github.com/alejandrodeutz25-DLC/TASK-FLOW/pull/2
- - **Historial de commits:** https://github.com/alejandrodeutz25-DLC/TASK-FLOW/commits/main

## Reflexión sobre feedback radicalmente sincero

Durante la revisión del hotfix (PR #2), le di feedback directo a un compañero sobre por qué su primera propuesta de fix —desactivar temporalmente el endpoint de login en vez de corregir la migración— no atacaba la causa raíz. Fue una devolución concreta y específica sobre el código, no sobre la persona, y la acompañé reconociendo la rapidez con la que había reaccionado ante el incidente.

Aplicar "feedback radicalmente sincero" en ese momento significó ser directo sin dejar de mostrar que me importaba tanto el resultado técnico como que el compañero no se sintiera señalado por el error original. El resultado fue una segunda propuesta de fix mejor fundamentada, y una conversación de equipo más abierta sobre por qué faltaba el checklist de migraciones en primer lugar.
