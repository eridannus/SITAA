# Plan de prueba de 0006: nombres personales estructurados

## Estado y alcance

`0006_structured_person_names.sql` está creada y no aplicada. Este plan valida únicamente nombres estructurados, compatibilidad de `full_name` y la interfaz coordinada. No modifica roles, ciclo de cuenta, OAuth, actividades ni permisos académicos.

## Precondiciones

1. Confirmar que 0001–0005 siguen aplicadas y sin cambios locales.
2. Ejecutar `supabase/reconciliation/0006_structured_person_names_preflight.sql` con un rol de revisión.
3. Comprobar que todos los conteos incompatibles sean cero. `nombres_compatibilidad_por_sincronizar` puede ser mayor que cero porque su corrección es determinista.
4. Si faltan componentes en una cuenta activa o inactiva, revisar la correspondencia de manera privada. No guardar PII ni mapeos reales en Git.
5. Respaldar y coordinar la aplicación de SQL con el despliegue de la versión que invoca la nueva firma RPC.

## Aplicación manual

1. Aplicar `supabase/migrations/0006_structured_person_names.sql` en una transacción revisada.
2. No ejecutar el rollback salvo decisión de emergencia.
3. Ejecutar `supabase/reconciliation/0006_structured_person_names_verify.sql`; debe terminar con `ROLLBACK`.
4. Regenerar el snapshot sólo después de aprobar pruebas funcionales.

## Casos de base de datos

| Caso | Resultado esperado |
| --- | --- |
| Nombre con espacios repetidos | Los componentes quedan normalizados y `full_name` se deriva con un espacio |
| Nombre con acentos | Los acentos y Unicode se conservan |
| Apellido materno vacío | Se almacena `NULL` y no agrega espacio final a `full_name` |
| Nombre(s) vacío | La finalización se rechaza sin activar parcialmente |
| Apellido paterno vacío en cuenta institucional | La finalización se rechaza |
| Cuenta técnica con nombre(s) y sin apellidos | Se crea activa con `full_name` derivado |
| Edición propia de componentes | Actualiza sólo componentes y sincroniza `full_name` |
| Edición propia de identificador, programa, persona, correo, estado o rol | Se rechaza por privilegio o trigger |
| RPC post-0005 | `authenticated` ya no tiene `EXECUTE` |
| RPC estructurado 0006 | Sólo `authenticated` tiene `EXECUTE` entre roles públicos |
| Registro de alumno o profesor | No crea `role_assignments` |
| Consulta de claves de orden | Devuelve apellido paterno, apellido materno y nombre(s) por separado |

## Casos de aplicación

1. Completar registro de alumno con los tres componentes y confirmar el nombre visible derivado.
2. Completar registro de profesor sin apellido materno.
3. Provocar un error de identificador y comprobar que cada campo de nombre conserva su valor y el foco llega al primer inválido.
4. Editar nombres desde `/profile`; verificar dashboard, encabezado y menú de cuenta.
5. Confirmar que cuenta, persona, identificador, programa, correo, estado y roles siguen sin controles editables.
6. Comprobar avatar Google con URL válida y fallback de iniciales sin imagen.

## Accesibilidad y presentación

- Probar `/`, `/login`, `/register`, ambas finalizaciones, `/dashboard`, `/profile` y navegación de actividades a 320, 375, 768 y 1440 píxeles.
- Verificar que el acceso público cerrado no requiera desplazamiento vertical normal ni produzca desplazamiento horizontal.
- Probar zoom de navegador al 200 %, recorrido completo por teclado, foco visible, Escape y clic exterior del menú.
- Confirmar blancos sobre azul en acciones primarias y texto legible en estados seleccionados.
- Activar `prefers-reduced-motion`: el canvas debe dibujar una vista estática sin animación continua.
- Ocultar la pestaña: `requestAnimationFrame` debe pausarse hasta recuperar visibilidad.
- Probar correo largo y comprobar `overflow-wrap:anywhere` sin colisión.

## Rollback

`0006_structured_person_names_rollback.sql` restaura funciones, constraint y grants post-0005 sin `CASCADE`, sin borrar perfiles y sin eliminar las columnas históricas. Los componentes estructurados capturados después de 0006 permanecen en la tabla; antes de volver a la aplicación post-0005 se requiere revisión operacional porque esa versión sólo edita `full_name`.

## Criterios de salida

- Preflight compatible, migración y verificador aprobados.
- `npm run check:text`, `npm run lint` y `npm run build` aprobados.
- Sin cambios en 0001–0005, snapshots ni Supabase antes de la aplicación manual autorizada.
- Sin secretos, PII real, mojibake, scroll horizontal ni regresiones de OAuth o roles.
