# Plan de pruebas de la migración 0003

## Propósito

Validar que las fechas y horas de un borrador sean provisionales y nunca activen bloqueo temporal. Las pruebas deben ejecutarse en un entorno desechable con identidades y actividades ficticias. La publicación completa, la privacidad de borradores y el comportamiento de contenido publicado deben conservar las reglas de 0002.

## Preparación

- Aplicar 0001 y 0002, y después 0003, en un proyecto de prueba.
- Preparar cuentas ficticias para un profesor creador, otro profesor, un responsable de programa, un alumno y `technical_admin`.
- Ejecutar `0003_fix_draft_temporal_lifecycle_verify.sql` y conservar el resultado sin datos personales.
- Probar el rollback sólo en un entorno desechable; éste restaura deliberadamente el defecto conocido.

## Integridad de la fixture automatizada

El verificador crea dentro de una sola transacción usuarios Auth ficticios, perfiles, una división, un programa, un semestre, asignaciones de rol y actividades aisladas. Los códigos de roles y catálogos operativos se toman de las semillas estables y se validan antes de insertar actividades. `session_replication_role = replica` se limita al bootstrap de usuarios Auth; todas las filas de `public` se insertan después de restaurar `origin`, con FK, checks y triggers activos.

Antes de probar permisos o temporalidad, el verificador confirma que programas, divisiones, semestres, creadores, responsables, perfiles, roles y catálogos referenciados existan. La ejecución anterior falló porque el `program_id` sintético de las actividades no tenía una fila correspondiente en `academic_programs`; fue una fixture FK incompleta y no un defecto de la migración 0003.

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

## Retroalimentación por campo al publicar

Estas comprobaciones se realizan desde un borrador existente y deben conservar todos los valores capturados. La confirmación dentro de la página sólo aparece cuando la validación completa termina sin errores.

| Caso | Resultado esperado |
| --- | --- |
| Ayer y cualquier hora | Sólo **Fecha de inicio** queda inválida con “La fecha de inicio no puede ser anterior a hoy.” |
| Hoy y una hora pasada | Sólo **Hora de inicio** queda inválida con “La hora de inicio debe ser posterior a la hora actual.” |
| Hoy y el minuto actual exacto | **Hora de inicio** queda inválida; la igualdad no se acepta. |
| Hoy y una hora futura | Fecha y hora no presentan error de calendario. |
| Mañana y una hora válida | Fecha y hora no presentan error de calendario. |
| Fecha ausente | **Fecha de inicio** queda inválida con “Indica una fecha de inicio válida.” |
| Hora ausente | **Hora de inicio** queda inválida con “Indica una hora válida en formato de 24 horas.” |
| Término personalizado inválido | El error aparece bajo fecha u hora de término; una duración ausente o inválida se marca en **Duración**. |
| La RPC rechaza el horario después de la prevalidación | Se reconstruye el error específico desde fecha y hora; si no puede determinarse, ambos campos muestran el mensaje general. El borrador y sus valores permanecen intactos. |

En cada error, verificar borde rojo, `aria-invalid`, relación mediante `aria-describedby`, desplazamiento suave y foco en el primer campo inválido. Al corregir un campo debe desaparecer sólo su error o los errores temporales directamente relacionados. **Guardar cambios** debe continuar aceptando como borrador fechas pasadas y datos operativos incompletos, sin abrir la confirmación de publicación.

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

- La aserción `fixture_foreign_keys_valid` pasa antes de las pruebas funcionales.
- El verificador transaccional devuelve los nueve resultados booleanos esperados, termina sin excepciones y ejecuta `ROLLBACK`.
- Las diez pruebas manuales pasan.
- 0001, 0002 y `0003_fix_draft_temporal_lifecycle.sql` permanecen sin cambios.
- La verificación corregida confirma la migración 0003 ya aplicada sin persistir fixtures.
