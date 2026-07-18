# Plan de prueba de 0006: nombres personales estructurados

## Estado y alcance

`0006_structured_person_names.sql` está creada y no aplicada. Este plan valida el contrato post‑0005 de entrada, la migración de nombres estructurados, su interfaz coordinada y el rollback exacto. No modifica roles, OAuth, ciclo de cuenta, actividades ni permisos académicos.

## Orden obligatorio

1. Confirmar que 0001–0005 conservan sus hashes aprobados.
2. Ejecutar `0006_structured_person_names_preflight.sql` con acceso de revisión y confirmar que todas las filas `blocking` tengan `affected_rows = 0`.
3. Revisar el único conteo `informational`, `full_name_requires_resynchronization`; la migración lo corrige de forma determinista sin dividir `full_name`.
4. Aplicar 0006 sólo en una ventana manual autorizada y coordinada con la aplicación compatible.
5. Ejecutar `0006_structured_person_names_verify.sql`; debe finalizar con `ROLLBACK`.
6. Conservar `0006_structured_person_names_rollback.sql` sólo para una decisión de emergencia revisada.

La salida normal del preflight contiene categorías y conteos, nunca nombres, correos ni identificadores. Cualquier correspondencia histórica necesaria se revisa de forma privada y no se guarda en Git.

## Matriz del preflight

| Categoría | Clasificación | Condición esperada |
| --- | --- | --- |
| `missing_structured_name_column` | Bloqueante | Las tres columnas existen y son `text` |
| `active_or_inactive_without_first_names` | Bloqueante | Cero |
| `institutional_without_paternal_surname` | Bloqueante | Cero |
| `pending_with_partial_structured_identity` | Bloqueante | Cero |
| `structured_component_too_long` | Bloqueante | Cero |
| `derived_full_name_too_long` | Bloqueante | Cero |
| `full_name_requires_resynchronization` | Informativa | Puede ser mayor que cero |
| Funciones, triggers y definiciones post‑0005 | Bloqueante | Sin faltantes ni desviaciones semánticas |
| Privilegios de finalización y `profiles` | Bloqueante | Contrato post‑0005 exacto |

La seguridad invocadora de `enforce_sitaa_profile_identity()` se comprueba con `pg_proc.prosecdef = false`; no se depende de que `pg_get_functiondef()` imprima la frase opcional `SECURITY INVOKER`.

El preflight embebido repite todas las condiciones bloqueantes y aborta la transacción con categorías y conteos agregados.

## Verificación transaccional automatizada

### Nombres

- `first_names` y `paternal_surname`: acepta longitudes 1 y 150; rechaza 151 y blancos.
- `maternal_surname`: acepta `NULL` y longitud 150; rechaza 151.
- Rechaza un `full_name` derivado mayor que 200.
- Normaliza espacios exteriores y repetidos.
- Conserva acentos, apóstrofes y Unicode.
- Deriva `full_name` exactamente, sin espacios dobles ni finales.
- Una escritura confiable con `full_name` incorrecto se resincroniza por trigger.
- Un perfil pendiente conserva su nombre provisional hasta completarse y luego lo reemplaza por los componentes definitivos.

### Identificadores y programas

- Acepta identificadores de 1 y 50 dígitos y conserva ceros iniciales.
- Rechaza 51 caracteres, letras, espacios y puntuación.
- Rechaza duplicados dentro de `student_account` y dentro de `worker_number`.
- Permite los mismos dígitos entre tipos institucionales diferentes.
- Acepta un programa activo; rechaza uno inactivo o inexistente.
- Todo rechazo conserva sin cambios el perfil pendiente.

### Identidad Google y ciclo de cuenta

- Rechaza identidad ausente, identidad perteneciente a otro usuario y desacuerdos entre correo de identidad, Auth y perfil.
- Rechaza identidad no verificada cuando `email_confirmed_at` es `NULL`.
- Acepta identidad verificada o el `email_confirmed_at` final admitido desde 0005.
- Completa un perfil pendiente actualizando exactamente una fila existente.
- Rechaza nueva finalización de cuentas activas, inactivas o técnicas.
- No crea `role_assignments`.
- La cuenta técnica sigue admitiendo apellidos nulos.

### Edición propia y privilegios

- `authenticated` puede actualizar sólo `first_names`, `paternal_surname` y `maternal_surname`.
- Rechaza escritura directa de `full_name`, identificador y demás campos administrativos.
- Rechaza componentes obligatorios en blanco.
- Verifica `EXECUTE` de las firmas anterior y nueva para `authenticated`, `anon` y `PUBLIC`.
- Verifica que roles y perfil permanezcan separados.
- Comprueba funciones, triggers y políticas esenciales introducidos por 0002–0005.

Todas las fixtures usan UUID y dominios `.invalid`, viven dentro de una transacción explícita y se eliminan con el `ROLLBACK` final. El rol `authenticated` recibe únicamente `SELECT` sobre `pg_temp.sitaa_0006_cases` y `EXECUTE` sobre `pg_temp.case_id(text)` y `pg_temp.case_email(text)` para resolver las fixtures durante las pruebas de privilegios; no recibe acceso a `sitaa_0006_context` ni a objetos persistentes adicionales.

## Pruebas de aplicación coordinada

1. Completar registro de alumno con los tres componentes y confirmar el nombre derivado.
2. Completar registro de profesor sin apellido materno.
3. Provocar errores de nombre, identificador y programa; confirmar persistencia de campos y foco en el primer error.
4. Editar nombres desde `/profile`; comprobar dashboard, encabezado y menú.
5. Confirmar que identificador, programa, correo, estado y roles no son editables.
6. Verificar que una cuenta técnica no exige apellidos.

## Contrato de rollback

El rollback:

- revoca explícitamente permisos 0006 antes de restaurar grants;
- elimina la firma estructurada y devuelve `EXECUTE` sólo a `authenticated` en la firma post‑0005;
- restaura la edición exclusiva de `full_name`;
- restaura funciones, restricciones y triggers post‑0005;
- elimina función, trigger y constraints propios de 0006;
- conserva columnas y valores estructurados, sin `CASCADE`, borrados ni reconstrucciones destructivas;
- se autoverifica antes de `COMMIT`.

## Validación local previa

- `npm run check:text`
- `npm run lint`
- `npm run build`
- revisión estática de delimitadores SQL, firmas, grants y ausencia de `CASCADE` o borrados;
- escaneo de secretos, PII y mojibake;
- confirmación de que 0001–0005, snapshots y la aplicación no cambiaron;
- confirmación de que no existe 0007 y no hubo conexión remota.

## Criterios de salida

- Preflight sin categorías bloqueantes.
- Migración y verificador aprobados en un entorno controlado.
- Rollback revisado y no ejecutado salvo autorización.
- Validaciones locales aprobadas.
- Sin secretos, PII real, cambios remotos ni desviaciones de alcance.
