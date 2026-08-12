# Hoja de ruta canónica del MVP operativo

## 1. Propósito y línea base autoritativa

Este documento es el plan canónico de ejecución para poner SITAA en operación durante el próximo semestre académico. Sustituye la secuencia inmediata de `ROADMAP.md`, que se conserva únicamente como contexto histórico.

Línea base aprobada:

- [x] Migraciones `0001`–`0010` aplicadas, verificadas, reconciliadas e inmutables.
- [x] Snapshot canónico `2026-08-06T23:33:15Z` sin deriva inexplicada.
- [x] Casos 1–20 aprobados y Fase B.3a cerrada.
- [x] Rollback 0010 prohibido permanentemente.
- [x] Build de producción en Vercel aprobado.
- [x] LAB desechable pausado y conservado.
- [x] **DOC-00 — Completado y publicado:** rebase documental aprobada como fuente canónica.
- [x] **AUTH-01 — Completado:** gate de lanzamiento público satisfecho y respaldado por evidencia sanitizada.

`SEM-01` es el siguiente paquete estructural activo. Su contrato de producto fue aprobado y quedó documentado en `SEM_01_DESIGN.md`; `0011` fue aplicada en producción el 2026-08-12 y el verificador transaccional corregido aprobó los casos 1–51 con `ROLLBACK` final explícito. El arnés multisesión y la reconciliación post-0011 siguen pendientes, y `/admin/periods` todavía no existe.

## 2. Principio del MVP inmediato

SITAA debe reemplazar primero:

- listas de registro y asistencia en papel;
- Formularios de Google usados para registro o asistencia;
- hojas de cálculo de asistencia mantenidas manualmente;
- directorios informales de tutores y grupos;
- mensajes informales de alerta de riesgo.

El flujo operativo objetivo es: configurar semestre; crear y publicar actividad; prerregistrar o registrar durante check-in; confirmar asistencia; corregirla manualmente cuando exista autorización; consultar por rol, grupo, programa y semestre; exportar el padrón de asistencia en CSV o PDF. En paralelo, todo profesor activo puede emitir una alerta mínima que SITAA enruta a destinatarios académicos autorizados.

Los formularios dinámicos permanecen aceptados como arquitectura futura, pero no son gate del MVP operativo inicial.

## 3. Leyenda de estado

- `[x]` completado y sustentado por evidencia.
- `[ ]` pendiente o gate todavía no aprobado.
- **Siguiente / kickoff pendiente:** paquete estructural seleccionado cuyo diseño e implementación todavía no comienzan.
- **Activo / en curso:** paquete que recibe el trabajo local actual, todavía sin cierre ni publicación de producción.
- **Gate de lanzamiento:** condición obligatoria para el piloto, aunque pueda desarrollarse en paralelo.
- Tamaño relativo: `S` pequeño, `M` mediano, `L` grande; no representa calendario ni compromiso de fecha.

## 4. Grafo de dependencias

```text
DOC-00
  ├─ AUTH-01 ------------------------------------------┐
  ├─ SEM-01                                            │
  ├─ ATT-01                                            │
  ├─ EXP-01                                            ├─ PILOT-01
  └─ ROLE-01                                           │
       └─ GRP-01                                       │
            └─ DASH-01                                 │
                 └─ ALERT-01 --------------------------┘
```

`DOC-00` y el gate obligatorio `AUTH-01` están completados. `SEM-01` es el siguiente paquete estructural activo: diseño canónico aprobado, `0011` aplicada y verificador transaccional aprobado; multisesión y reconciliación permanecen pendientes. `PILOT-01` no puede aprobarse hasta que las ramas pendientes hayan producido evidencia suficiente.

## 5. Resumen de paquetes

| ID | Paquete | Estado | Criticidad | Tamaño | Dependencias directas |
| --- | --- | --- | --- | --- | --- |
| `DOC-00` | Rebase documental | Completado | Bloqueante | S | Ninguna |
| `AUTH-01` | Publicación de Google OAuth | Completado | Gate satisfecho | M | `DOC-00` |
| `SEM-01` | Administración mínima de semestres | `0011` aplicada y verificador aprobado; multisesión y reconciliación pendientes | Crítica | M | `DOC-00` |
| `ATT-01` | Registro y asistencia atómicos | Pendiente | Crítica | L | `DOC-00` |
| `EXP-01` | Exportaciones CSV y PDF | Pendiente | Crítica | M | `DOC-00` |
| `ROLE-01` | Autoridad y roles mínimos del piloto | Pendiente | Crítica | L | `DOC-00` |
| `GRP-01` | Grupos, membresías y tutores | Pendiente | Crítica | L | `ROLE-01` |
| `DASH-01` | Paneles adaptativos y filtros autorizados | Pendiente | Alta | L | `GRP-01` |
| `ALERT-01` | Alertas de riesgo e inbox | Pendiente | Alta | L | `DASH-01` |
| `PILOT-01` | Preparación y decisión go/no-go | Pendiente | Gate final | L | Todos los paquetes anteriores |

## 6. DOC-00 — Rebase documental

**Objetivo:** fijar alcance, orden, dependencias, decisiones bloqueadas y backlog antes de diseñar el primer cambio estructural.

- [x] Registrar la línea base post‑0010 y el cierre B.3a.
- [x] Definir IDs estables para los paquetes operativos.
- [x] Sustituir la secuencia inmediata anterior sin borrar su historia.
- [x] Registrar decisiones de producto, seguridad y autoridad.
- [x] Revisar, aprobar y publicar el cambio documental.
- [x] Cerrar `AUTH-01` con evidencia sanitizada y seleccionar `SEM-01` como el primer paquete estructural.

**Salida:** documentación canónica coherente y autorización explícita para diseñar el siguiente paquete, sin reservar todavía una migración.

## 7. AUTH-01 — Publicación de Google OAuth

**Objetivo:** habilitar el acceso público real con identidad básica y sin scopes elevados.

- [x] Auditar manualmente Audience, Branding, Data Access y OAuth Clients: audiencia **External**, estado **In production** y un cliente web de producción sin URI local, Preview o LAB.
- [x] Confirmar únicamente `openid`, `userinfo.email` y `userinfo.profile`, con cero scopes sensibles y cero restringidos.
- [x] Revisar la separación de producción y pruebas del cliente OAuth.
- [x] Desplegar y verificar manualmente `/acerca-de` y `/privacidad` en producción.
- [x] Verificar la propiedad de `sitaa.net` mediante Search Console y conservar el registro DNS correspondiente.
- [x] Completar y verificar la marca, incluido el logotipo mostrado a las personas usuarias.
- [x] Decidir que no se requiere página de términos para el lanzamiento inicial.
- [x] Completar un recorrido de producción con una identidad que nunca fue usuario de prueba y confirmar que el perfil resultante no recibió autoridad elevada automáticamente, conforme a DEC-065.
- [x] Revalidar los requisitos vigentes de Google al cerrar el paquete.
- [x] Registrar la evidencia sanitizada en `docs/AUTH_01_PUBLIC_OAUTH_EVIDENCE.md`.

**No incluye:** Gmail, Drive, Calendar ni otros scopes o APIs de Google.

**Estado:** completado; gate de lanzamiento público satisfecho. Las variaciones de Gmail de consumidor, `pc.puma` / UNAM y organizaciones Workspace adicionales permanecen como regresiones de `PILOT-01`.

## 8. SEM-01 — Administración mínima de semestres

**Objetivo:** permitir que sólo una autoridad técnica exacta administre los semestres oficiales requeridos para la operación, sin restringir las lecturas de referencia ya autorizadas.

- [x] Aprobar el contrato de producto y documentarlo canónicamente en `SEM_01_DESIGN.md`.
- [x] Asignar `0011` y preparar localmente el preflight, migración, verificador, rollback, checker y plan de pruebas de base de datos.
- [x] Revisar el paquete, aplicar `0011` y aprobar el verificador transaccional corregido de casos 1–51.
- [ ] Crear, revisar y ejecutar el arnés multisesión real.
- [ ] Regenerar el snapshot vivo y reconciliar post-0011.
- [ ] Implementar `/admin/periods` como superficie dedicada, sin convertir `/catalogs` en editor genérico.
- [ ] Aplicar la autoridad exacta `technical_admin/system/technical`, activa, vigente y sin programa o división en ruta, acciones y RPC independientes.
- [ ] Preservar las lecturas de referencia autorizadas sin conceder administración ni ampliar universos visibles.
- [ ] Implementar resolución automática intersemestral desde la fecha, con cierre del último periodo en `ends_on` y sin selección manual.
- [ ] Preservar borradores con `academic_period_id = NULL` y exigir re-resolución transaccional al publicar.
- [ ] Garantizar código ordinario estable, fechas completas y no traslape activo bajo concurrencia, conservando la excepción histórica `pilot`.
- [ ] Implementar diagnóstico transaccional de impacto sin remapeo silencioso y sin ruta de eliminación.
- [ ] Añadir auditoría append-only sanitizada y desacoplada de perfiles.
- [ ] Conservar aprobados checker y verificador transaccional y completar el arnés multisesión de concurrencia y pérdida de autoridad.
- [ ] Revisar un rollback fail-closed que preserve historia, referencias y auditoría.
- [ ] Completar las pruebas pendientes, capturar snapshot y reconciliar antes de implementar la aplicación.

La administración general de catálogos permanece diferida.

## 9. ATT-01 — Registro y asistencia atómicos

**Objetivo:** sustituir registro y pase de lista en papel o Formularios de Google con un único contrato transaccional.

- [ ] Añadir a cada actividad una opción explícita de autorregistro durante check-in, deshabilitada por defecto.
- [ ] Exigir perfil SITAA estudiantil completo, activo y elegible.
- [ ] Conservar prerregistro de participantes por responsables autorizados.
- [ ] Hacer que QR, enlace directo y código de tres palabras usen el mismo contrato.
- [ ] Insertar participante y confirmar asistencia en una sola transacción.
- [ ] Garantizar idempotencia en check-ins repetidos.
- [ ] Conservar corrección manual de asistencia por autoridades existentes.
- [ ] Mantener fuera participantes anónimos, libres o provisionales.
- [ ] Probar expiración, reapertura, concurrencia, programa, RLS y privacidad.

## 10. EXP-01 — Exportaciones CSV y PDF

**Objetivo:** entregar padrones operativos desde el mismo universo autorizado que la lista visible.

- [ ] Definir una fuente de datos única para vista, CSV y PDF.
- [ ] Aplicar autorización antes de filtros y generación.
- [ ] Generar CSV UTF-8 con encabezados en español.
- [ ] Neutralizar fórmulas y valores peligrosos en CSV.
- [ ] Generar PDF institucional imprimible con metadata de actividad y totales de asistencia.
- [ ] Excluir UUID internos, tokens e identificadores técnicos.
- [ ] Verificar nombres largos, caracteres españoles, paginación y consistencia de totales.

CSV y PDF son salidas centrales del MVP operativo, no reportes avanzados.

## 11. ROLE-01 — Autoridad y roles mínimos del piloto

**Objetivo:** implementar sólo la autoridad necesaria para operar el piloto sin abrir todavía toda Fase C.

Subconjunto inicial: `technical_admin`, `professor_tutor`, `professor_advisor`, `peer_tutor`, `program_tutoring_lead`, `program_advising_lead`, `program_coordinator`, `division_tutoring_liaison` y únicamente otros roles institucionales comprobados como necesarios.

- [ ] Permitir a `technical_admin` asignar roles institucionales iniciales de alto nivel.
- [ ] Permitir a `program_tutoring_lead` asignar/revocar `professor_tutor` y `peer_tutor` sólo en su programa.
- [ ] Permitir a `program_advising_lead` asignar/revocar `professor_advisor` sólo en su programa.
- [ ] Revalidar cuenta, elegibilidad, alcance, vigencia y programa bajo locks.
- [ ] Conservar historial y auditoría; revocar en vez de borrar.
- [ ] Impedir autoasignación y escalamiento por parámetros del cliente.

Administración completa, transferencia de `technical_admin` y delegación general permanecen diferidas.

## 12. GRP-01 — Grupos, membresías y tutores

**Objetivo:** sustituir directorios informales con grupos acotados por programa y semestre, conservando historia.

**Autoridad**

- [ ] Permitir que un `program_tutoring_lead` activo administre grupos únicamente dentro de su mismo programa académico.
- [ ] Mantener el bootstrap institucional de roles por `technical_admin` separado de la autoridad académica del `program_tutoring_lead`; el rol técnico no la sustituye por sí solo.
- [ ] Revalidar en la base de datos programa, rol, estado de cuenta y vigencia en cada mutación.

**Ciclo de vida del grupo**

- [ ] Modelar grupo separado de `profiles` y acotado por programa y periodo.
- [ ] Incluir código, turno, semestre nominal, cohorte/generación, etiqueta y estado.
- [ ] Permitir reutilizar código en otro periodo.
- [ ] Crear grupos dentro del programa autorizado.
- [ ] Editar sus atributos administrativos.
- [ ] Cerrar un grupo sin borrar su historia.
- [ ] Listar grupos actuales e históricos por programa y periodo autorizados.

**Membresías**

- [ ] Agregar manualmente a un estudiante SITAA existente.
- [ ] Mover a un estudiante entre grupos del mismo programa y periodo.
- [ ] Finalizar una membresía sin borrarla.
- [ ] Limitar a cada alumno a un grupo actual por programa y periodo.
- [ ] Rechazar un segundo grupo actual para el mismo estudiante, programa y periodo.
- [ ] Importar membresías por CSV contra perfiles estudiantiles SITAA existentes.
- [ ] Mostrar una vista previa de filas no vinculadas y reportar identificadores no encontrados sin crear perfiles provisionales.

**Tutoría de grupos**

- [ ] Mantener un tutor primario actual por grupo y permitir varios grupos por tutor.
- [ ] Asignar un tutor primario sólo mediante una asignación vigente `professor_tutor` del mismo programa.
- [ ] Referenciar en la asignación de tutor la fila concreta de rol habilitante.
- [ ] Transferir el grupo a otro tutor elegible.
- [ ] Cerrar una asignación de tutor sin borrarla.
- [ ] Bloquear revocación del rol mientras existan grupos activos dependientes.
- [ ] Transferir o cerrar grupos antes de revocar el rol.
- [ ] Cerrar/revocar membresías y asignaciones; nunca borrar historia operativa.

**Búsqueda, filtros y operación masiva**

- [ ] Buscar por código de grupo, estudiante y tutor.
- [ ] Filtrar por periodo académico, turno, semestre nominal y cohorte/generación.
- [ ] Detectar grupos sin tutor.
- [ ] Seleccionar explícitamente las filas de grupo filtradas y asignar o transferir un tutor elegible a esa selección.
- [ ] Materializar cada asignación sobre filas explícitas; la operación masiva no crea una regla dinámica permanente.

**Resultados para estudiantes y tutores**

- [ ] Permitir que cada estudiante consulte su grupo de tutoría actual, periodo académico, tutor asignado y los datos institucionales de contacto de ese tutor que estén expresamente permitidos.
- [ ] Permitir que cada tutor consulte sus grupos asignados, el número de estudiantes y el padrón autorizado de cada grupo, con búsqueda y filtros.
- [ ] Limitar ambas vistas al universo actual o histórico autorizado para el perfil que consulta.

El semestre nominal describe al grupo y no afirma que cada alumno curse exclusivamente materias de ese semestre.

## 13. DASH-01 — Paneles adaptativos y filtros autorizados

**Objetivo:** componer una sola experiencia adaptable desde capacidades efectivas.

Contextos iniciales: alumno; profesor ordinario; tutor o asesor; lead de tutoría/asesoría; coordinación de programa; enlace divisional; administración técnica.

- [ ] Construir primero el universo visible mediante RLS/RPC autorizadas.
- [ ] Aplicar después filtros, conteos, orden y paginación.
- [ ] Incorporar semestre, programa, servicio, responsable, grupo, tutor, estado, tipo, categoría y rango de fechas.
- [ ] Impedir que query params amplíen acceso o revelen opciones fuera del universo autorizado.
- [ ] Mantener privacidad de participantes, borradores y alertas por capacidad.
- [ ] Verificar móvil, teclado, contraste, rendimiento y paginación acotada.

## 14. ALERT-01 — Alertas de riesgo e inbox

**Objetivo:** registrar y enrutar una señal académica mínima sin convertir SITAA en expediente o sistema clínico.

- [ ] Permitir crear alertas a todo perfil activo con `person_type = professor`.
- [ ] Capturar nombre del alumno, programa, materia, categoría, grupo opcional, identificador opcional y vínculo opcional a perfil SITAA.
- [ ] Limitar categorías a `absences`, `missing_work` y `socioemotional_attention`.
- [ ] Enrutar ausencias/trabajos a leads de tutoría y asesoría y coordinación del programa.
- [ ] Enrutar atención socioemocional al enlace divisional y coordinación del programa.
- [ ] Fijar destinatarios al crear la alerta para que cambios de roles no reescriban historia.
- [ ] Usar estados técnicos de routing `registered`, `routing_pending`, `routed` y `routing_failed`.
- [ ] Representar por separado la interacción de cada destinatario mediante los conceptos `delivered_at`, `read_at` y `archived_at`.
- [ ] Implementar inbox interno con contadores como fuente de verdad.
- [ ] Restringir `technical_admin` a diagnósticos sanitizados de entrega, sin contenido de alerta.
- [ ] Probar contenido sólo con perfiles académicos ficticios y LAB para escenarios destructivos.

`read_at` significa únicamente que el destinatario abrió el elemento; `archived_at`, únicamente que lo organizó o retiró del inbox activo. Ninguna de esas marcas prueba atención al estudiante, activación de un protocolo, investigación, resolución, descarte o seguimiento. SITAA no almacena el resultado de la situación subyacente: sólo registra la alerta y el routing técnico realizado por el sistema. No diagnostica, gestiona casos, almacena notas clínicas ni sustituye protocolos institucionales. Un correo futuro sería secundario y sólo avisaría genéricamente que existe una alerta nueva.

Antes de desplegar `ALERT-01` se debe revisar y actualizar el aviso público de privacidad para incorporar, de forma expresa y minimizada, la nueva categoría de datos.

## 15. PILOT-01 — Preparación y decisión go/no-go

**Objetivo:** demostrar que el flujo completo puede operar con seguridad, soporte y procedimientos claros.

- [x] Conservar como línea base el gate `AUTH-01` aprobado para audiencia **External** y estado **In production**.
- [ ] Probar una cuenta Gmail de consumidor.
- [ ] Probar una cuenta Google `pc.puma` / UNAM.
- [ ] Probar otra organización institucional de Workspace cuando esté disponible.
- [ ] Probar la cancelación del consentimiento.
- [ ] Probar el rechazo por política organizacional y el retorno posterior.
- [ ] Probar el inicio de sesión repetido después de completar un registro existente.
- [ ] Configurar un semestre real.
- [ ] Asignar roles iniciales y grupos del piloto.
- [ ] Completar asignaciones de tutores con sus roles habilitantes.
- [ ] Aprobar check-in atómico y corrección manual.
- [ ] Aprobar exportaciones CSV/PDF.
- [ ] Aprobar paneles, filtros y routing de alertas.
- [ ] Ejecutar revisión de privacidad y minimización.
- [ ] Ejecutar pruebas móviles, RLS, accesibilidad, rendimiento y recuperación.
- [ ] Preparar guías de operación, soporte e incidentes.
- [ ] Registrar decisión go/no-go con evidencia y pendientes aceptados.

## 16. Gates de entrega

1. **Gate documental:** `DOC-00` aprobado y publicado.
2. **Gate de identidad pública:** `AUTH-01` aprobado mediante al menos una identidad de Google que nunca fue usuario de prueba, conforme a `DEC-065`.
3. **Gate de configuración:** semestre real válido y administrable.
4. **Gate de autoridad:** roles mínimos, tutores y grupos consistentes.
5. **Gate de operación:** actividad publicada, registro/check-in atómico y corrección manual.
6. **Gate de salida:** CSV/PDF coinciden con el padrón autorizado.
7. **Gate de consulta:** paneles y filtros no amplían el universo visible.
8. **Gate de alertas:** routing, inbox, privacidad y separación técnica aprobados.
9. **Gate final:** pruebas y guías completas; decisión go/no-go registrada.

## 17. Decisiones bloqueadas

1. El MVP inmediato reemplaza papel y Formularios de Google para registro y asistencia; formularios dinámicos no son gate.
2. Google OAuth público con scopes básicos es gate de lanzamiento.
3. Sólo `technical_admin` exacto administra semestres en esta etapa.
4. Autorregistro y asistencia se confirman atómicamente para perfiles estudiantiles SITAA activos; la opción inicia deshabilitada.
5. CSV y PDF forman parte del núcleo operativo y comparten el dataset autorizado de la vista.
6. El piloto usa un subconjunto mínimo de roles y delegación acotada por programa.
7. El rol `professor_tutor` vigente y del mismo programa precede a toda asignación de grupo y queda referenciado por ella.
8. Los grupos pertenecen a programa y periodo, no a `profiles`; membresías y tutores conservan historia.
9. Un dashboard adaptable se compone desde capacidades; autorización precede a cualquier filtro.
10. Las alertas son señales enrutadas, no expedientes, diagnósticos o gestión de casos.
11. `technical_admin` no ve contenido de alertas por su rol técnico; sólo diagnósticos sanitizados.
12. El inbox interno es la entrega primaria; cualquier email posterior será genérico y secundario.

## 18. Detalles deliberadamente diferidos hasta el kickoff

- nombres exactos de tablas, columnas, RPC, políticas, índices y migración de cada paquete;
- diseño visual y navegación detallada de pantallas nuevas;
- biblioteca y plantilla exactas del PDF;
- contrato CSV de importación/exportación y límites de archivo;
- taxonomía final de errores, auditoría y retención por paquete;
- volumen, paginación y metas de rendimiento basadas en datos del piloto;
- roles institucionales adicionales que el piloto demuestre necesarios;
- mecanismo secundario de email y su proveedor;
- plan de retiro de A-02 y alcance completo de Fase C.

Estos detalles requieren diseño, amenaza, preflight y revisión propios. No se inventan en DOC-00.

## 19. Backlog posterior al MVP

- [ ] Constructor de formularios dinámicos y respuestas versionadas.
- [ ] B.3b completa y administración de cuentas técnicas adicionales.
- [ ] Transferencia/delegación completa de roles y retiro de A-02.
- [ ] Paneles avanzados, gráficas y constructor configurable de reportes.
- [ ] Constancias, notificaciones generales e integraciones institucionales.
- [ ] Evidencia externa y almacenamiento documental.
- [ ] Participantes anónimos, registro abierto sin asistencia y perfiles provisionales desde padrones.
- [ ] Reglas dinámicas de grupo y administración general de catálogos.
- [ ] Analítica predictiva, recomendaciones o IA.

## 20. Disciplina de desarrollo y migraciones

- Cada paquete inicia con revisión de fuentes canónicas, amenazas, permisos y datos sensibles.
- La documentación y la decisión preceden al código o DDL.
- DEC-067 asigna `0011` a `SEM-01`. La migración y el verificador transaccional ya fueron aprobados; concurrencia multisesión, snapshot, reconciliación y aplicación web conservan gates separados.
- Las migraciones aplicadas permanecen inmutables y todo cambio nuevo es incremental, no destructivo y reconciliable.
- RLS/RPC construyen el universo autorizado; la interfaz nunca sustituye autorización de base.
- Todo cambio estructural exige preflight, aplicación coordinada, verificador transaccional, rollback revisado, pruebas, snapshot y reconciliación según riesgo.
- Producción usa datos claramente ficticios para smoke tests; LAB se reserva para pruebas sintéticas destructivas.
- No se versionan secretos, datos personales reales, respuestas crudas, tokens ni evidencia local sensible.
- Cada paquete se cierra sólo con criterios verificables, documentación actualizada y decisión explícita de avance.
