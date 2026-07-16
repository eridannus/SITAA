# Plan de pruebas de la migración 0003

## Propósito

Validar que las fechas y horas de un borrador sean provisionales y nunca activen bloqueo temporal. Las pruebas deben ejecutarse en un entorno desechable con identidades y actividades ficticias. La publicación completa, la privacidad de borradores y el comportamiento de contenido publicado deben conservar las reglas de 0002.

## Preparación

- Aplicar 0001 y 0002, y después 0003, en un proyecto de prueba.
- Preparar cuentas ficticias para un profesor creador, otro profesor, un responsable de programa, un alumno y `technical_admin`.
- Ejecutar `0003_fix_draft_temporal_lifecycle_verify.sql` y conservar el resultado sin datos personales.
- Probar el rollback sólo en un entorno desechable; éste restaura deliberadamente el defecto conocido.

## Matriz temporal de borradores

### 1. Borrador sin fecha ni hora

Guardar un borrador con título y programa, sin `start_date`, `start_time`, fecha de término ni hora de término.

**Esperado:** conserva badge Borrador, muestra campos incompletos sin afirmar que ocurrió y el creador puede abrirlo, editarlo y eliminarlo.

### 2. Borrador con fecha pasada y sin hora

Guardar un borrador con `start_date` pasada y `start_time = null`.

**Esperado:** sigue editable y eliminable; no aparece “Esta actividad ya ocurrió” ni un modo de corrección administrativa.

### 3. Borrador con fecha y hora pasadas completas

Guardar un borrador con inicio y término pasados.

**Esperado:** la temporalidad continúa siendo provisional; no se bloquean los datos base.

### 4. Borrador con fecha futura

Guardar y volver a editar un borrador con fecha futura, primero sin hora y después con hora.

**Esperado:** ambos guardados funcionan y el borrador permanece privado al creador.

## Publicación

### 5. Intento con fecha y hora pasadas

Completar los campos operativos de un borrador con un inicio pasado e invocar `publish_activity(uuid)` desde la interfaz.

**Esperado:** la publicación se rechaza; `status_code` permanece `draft` y el creador puede continuar editando o eliminar el registro.

### 6. Publicación futura completa

Corregir el mismo borrador con catálogo, alcance, ubicación, semestre, duración e inicio futuro válidos y publicar.

**Esperado:** cambia transaccionalmente a `scheduled`, asigna el semestre correcto y deja de usar las reglas temporales de borrador.

### 7. Actividad publicada ya ocurrida

Abrir una actividad publicada cuyo término sea anterior a la hora actual de Ciudad de México.

**Esperado:** `activity_has_ended` devuelve true; un responsable regular ve los datos base bloqueados y los usuarios de gestión conservan la corrección administrativa prevista.

## Privacidad y recuperación

### 8. Creador del borrador

Consultar, actualizar y eliminar borradores propios de cada variante temporal.

**Esperado:** las tres operaciones están disponibles sin depender de fecha u hora provisional.

### 9. Otros actores

Como otro profesor, responsable de programa, alumno y `technical_admin`, intentar listar, consultar, actualizar y eliminar el borrador ajeno.

**Esperado:** ninguno puede acceder. La amplitud temporalmente aceptada de `technical_admin` sigue limitada al contenido publicado.

### 10. Borrador atrapado existente

Antes de 0003, conservar un borrador propio con fecha pasada que aparezca bloqueado. Aplicar 0003 sin modificar la fila y recargar detalle y lista.

**Esperado:** el registro existente vuelve a ser editable y eliminable automáticamente; no requiere reescritura, cambio de fecha ni corrección manual de datos.

## Regresiones obligatorias

- Borradores visibles sólo para `created_by`.
- Publicación incompleta, pasada o con semestre inválido rechazada.
- `created_by` inmutable y transición publicada irreversible.
- Pendiente vencido rechazado por RPC y `UPDATE` directo.
- Participantes, asistencia manual, reapertura QR/código y semestres sin cambios para actividades publicadas.
- Fechas DD/MM/YYYY, horas de 24 horas y texto UTF-8 correcto.

## Criterios de salida

- El verificador transaccional termina sin excepciones y ejecuta `ROLLBACK`.
- Las diez pruebas manuales pasan.
- 0001 y 0002 permanecen sin cambios.
- 0003 continúa marcada como creada/no aplicada hasta contar con evidencia de ejecución controlada.
