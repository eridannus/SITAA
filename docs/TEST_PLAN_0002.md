# Plan de pruebas de la migración 0002

## Propósito y alcance

Validar `0002_database_security_and_integrity.sql` antes de su aplicación manual en la base viva. Las pruebas cubren privacidad de borradores, publicación transaccional, asistencia vencida y privilegios mínimos. No validan una restricción de `technical_admin`, porque esa decisión permanece diferida intencionalmente.

## Requisitos previos

- Usar un proyecto Supabase de prueba restaurado desde la baseline reconciliada y datos ficticios.
- No usar perfiles, correos, identificadores ni actividades reales.
- Preparar cuentas independientes para: profesor A, profesor B, alumno, responsable de programa y `technical_admin`.
- Asignar profesor A y profesor B al mismo programa para comprobar que el alcance institucional no rompe la privacidad del borrador.
- Preparar una actividad futura, una actividad dentro de la ventana normal, una vencida y participantes ficticios.
- Conservar un respaldo y una copia de los resultados del preflight.

## Secuencia de ejecución

1. Ejecutar el preflight incluido al inicio de 0002 en el entorno de prueba.
2. Si reporta actividades programadas incompatibles, detenerse y revisar; no corregirlas automáticamente.
3. Aplicar 0002 completa.
4. Ejecutar `supabase/reconciliation/0002_database_security_and_integrity_verify.sql` con un rol administrativo de revisión.
5. Ejecutar las pruebas manuales siguientes.
6. Registrar actor, hora, resultado esperado, resultado observado y evidencia sin datos personales.
7. Probar el rollback sólo en un entorno desechable y coordinado con una versión de la aplicación anterior a 0002.

## Pruebas anónimas

### Salud pública

1. Sin sesión, consultar el endpoint o pantalla de salud.
2. Consultar `system_health` mediante la API anónima.
3. Confirmar que sólo la lectura funciona.

**Esperado:** la señal de salud continúa disponible; insertar, actualizar, eliminar o usar la secuencia es rechazado.

### Datos sensibles y RPC

1. Sin sesión, intentar SELECT sobre `profiles`, `role_assignments`, `activities`, `activity_participants` y `activity_checkin_tokens`.
2. Intentar leer cada catálogo y `academic_periods`.
3. Intentar invocar RPC de consulta y mutación, incluidas `publish_activity`, participantes, asistencia, check-in y finalización.

**Esperado:** no existe acceso directo a tablas sensibles, catálogos, semestres ni funciones SITAA. No se filtran detalles internos.

## Profesor autenticado

### Sesión, perfil y catálogos

1. Iniciar sesión como profesor A.
2. Abrir panel, perfil y catálogos.
3. Actualizar un campo permitido del propio perfil.
4. Intentar insertar o eliminar un perfil y escribir en catálogos o asignaciones.

**Esperado:** login, panel, lectura/actualización propia y catálogos funcionan; las escrituras no autorizadas fallan.

### Borrador incompleto propio

1. Guardar una actividad con título y programa, dejando incompletos campos operativos permitidos para borrador.
2. Abrir `/activities`, el detalle y la API directa como profesor A.
3. Editar y volver a guardar el borrador.

**Esperado:** el borrador se crea con `status_code = draft`, `created_by` igual al usuario autenticado, aparece sólo para profesor A y admite campos operativos incompletos.

### Privacidad frente a otro usuario

1. Iniciar sesión como profesor B, responsable de programa, enlace divisional y `technical_admin`, uno por vez.
2. Buscar el borrador de profesor A en lista, detalle y llamada directa a `activities`.
3. Intentar leer participantes o invocar helpers/RPC con el id del borrador.

**Esperado:** ningún actor distinto del creador puede leer ni modificar el borrador, aunque sea responsable asignado, gestor, participante o `technical_admin`.

### Publicación completa

1. Como profesor A, completar tipo, servicio, categoría, modalidad, ubicación, fecha/hora futuras y duración.
2. Probar modalidad `online` con `online_space` y una URL completa.
3. Usar la confirmación en página y publicar.
4. Consultar la fila y la tarjeta.

**Esperado:** la aplicación guarda primero el borrador, llama `publish_activity`, asigna el semestre mediante la fecha —incluido un intersemestre— y cambia atómicamente a `scheduled`. La tarjeta conserva etiqueta, URL, DD/MM/YYYY, 24 horas y badge Programada.

### Publicación incompleta o inválida

1. Intentar publicar un borrador sin cada campo obligatorio, uno por vez.
2. Probar programa/división inconsistentes, modalidad en línea con ubicación presencial, ubicación en línea con modalidad no en línea, fin no posterior e intervalos de una/dos horas inconsistentes.
3. Probar una fecha sin semestre activo anterior y una fecha/hora de inicio pasada.
4. Intentar actualizar o insertar una fila `scheduled` incompleta directamente por PostgREST.

**Esperado:** cada intento falla sin dejar una fila programada incompleta. El registro permanece como borrador del creador y la interfaz muestra sólo mensajes españoles sanitizados.

### Publicación y bloqueo posterior

1. Publicar por `publish_activity(uuid)` un borrador completo de un creador que todavía conserva el rol y alcance requeridos.
2. Crear otro borrador, retirar o inactivar la asignación que autorizaba su alcance e intentar `draft → scheduled` directamente por PostgREST.
3. Intentar el mismo cambio directo con una sesión sin autenticar y con un creador distinto.
4. Intentar cambiar `created_by` de un borrador por `UPDATE` directo.
5. Intentar devolver una actividad `scheduled` a `draft` por `UPDATE` directo.
6. Intentar publicar el mismo id por segunda vez y publicar por RPC el borrador de otro usuario.
7. Como profesor A, abrir la actividad publicada y tratar de modificar o eliminar datos base.
8. Gestionar participantes y asistencia.

**Esperado:** el RPC publica al creador elegible. La transición directa exige sesión, creador y permiso vigente; perder el rol impide publicar. `created_by` es inmutable para clientes y una actividad no borrador no vuelve a `draft`. Una segunda publicación falla; los datos base publicados quedan bloqueados para el responsable regular, mientras participantes y asistencia siguen operativos. `postgres` y `service_role` conservan su vía administrativa de confianza.

### Asistencia manual vencida

1. En una actividad antes del plazo natural, marcar individualmente y en lote como Pendiente.
2. Probar la frontera exacta con una fixture controlada donde `activity_attendance_deadline(id) = now()` dentro de la transacción; invocar los RPC individual y masivo con `pending`.
3. Mover el reloj del entorno de prueba o usar una actividad cuyo plazo natural ya venció.
4. Ejecutar `finalize_expired_attendance()` y recargar.
5. Intentar volver a Pendiente individualmente y en lote mediante los RPC.
6. Como editor permitido por RLS, intentar `UPDATE activity_participants SET attendance_status = 'pending'` directamente.
7. Corregir individualmente y en lote a Asistió, No asistió y Justificada.
8. Reabrir asistencia extraordinaria y confirmar que ésta permite el check-in previsto, pero no vuelve a habilitar `pending` manual.

**Esperado:** Pendiente funciona sólo antes del plazo natural; en la frontera exacta y después se rechaza atómicamente con “La ventana de asistencia ya terminó; el estado Pendiente ya no está disponible.” El trigger bloquea también el `UPDATE` directo. Los pendientes vencidos quedan No asistió/Sistema; Asistió, No asistió y Justificada siguen corregibles, y la reapertura extraordinaria conserva el check-in autorizado.

### QR, enlace y código

1. Abrir y cerrar asistencia dentro de la ventana normal.
2. Confirmar por QR, enlace y código de tres palabras con participantes registrados.
3. Después del plazo natural, reabrir varias veces durante 15 minutos.
4. Verificar que una ausencia generada por sistema puede convertirse en Asistió.
5. Verificar que Justificada y No asistió/Manual no son sobrescritas.

**Esperado:** el retiro de grants anónimos no rompe los flujos autenticados; apertura, cierre, regeneración, reapertura y check-in conservan su autorización interna.

## Alumno

1. Asignar al alumno a una actividad publicada y a ningún borrador.
2. Abrir `/activities` y el resumen asignado.
3. Intentar listar borradores y consultar directamente el id de un borrador conocido.
4. Intentar abrir el roster completo o controles de gestión.
5. Confirmar asistencia por QR, enlace y código durante una ventana válida.
6. Verificar Pendiente, Asistió, No asistió y Justificada en sus tarjetas.

**Esperado:** ve sólo actividades publicadas asignadas y su propia participación; no ve borradores, roster ni controles. El check-in autenticado funciona y respeta ausencias manuales/justificadas y expiración.

## Technical admin

1. Confirmar que no puede leer el borrador ajeno del profesor A.
2. Crear y publicar un borrador propio dentro de cualquiera de los programas permitidos por su alcance amplio vigente.
3. Abrir y corregir una actividad publicada dentro del alcance amplio de prueba existente.
4. Gestionar participantes, asistencia y limpieza de una actividad divisional heredada.

**Esperado:** 0002 no introduce una restricción nueva de `technical_admin` sobre creación o contenido publicado. La excepción no se extiende a borradores privados ajenos y las reglas generales de inmutabilidad y ciclo de estado se aplican a la sesión cliente.

## Regresión funcional y visual

- Semestre automático e intersemestre asignados a la frontera más reciente.
- Modalidad `online` y ubicación `online_space` coherentes.
- URLs y correos largos envuelven sin desbordar.
- Fechas DD/MM/YYYY y horas de 24 horas.
- Texto UTF-8: acentos, eñes, signos y convención “sólo”.
- Badges Borrador y Programada.
- Contadores Registrados, Asistieron y Faltaron.
- Tarjetas detalladas y Pase de lista.
- Copia PNG y descarga SVG del QR.
- Compatibilidad de `starts_at`/`ends_at` y actividades divisionales heredadas.

## Criterios de salida

- El script de verificación no reporta desviaciones.
- Todas las pruebas críticas de RLS, publicación, asistencia y grants pasan.
- No hay pérdida ni reescritura silenciosa de datos.
- Los hallazgos se documentan antes de aplicar manualmente 0002 en Supabase.
- La migración se registra como “creada/no aplicada” hasta contar con evidencia de ejecución viva.
