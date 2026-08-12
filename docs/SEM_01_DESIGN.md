# Diseño canónico de SEM-01

## Estado y alcance

**Estado:** contrato de producto aprobado. La migración `0011` fue aplicada en producción el 2026-08-12 y su verificador transaccional corregido aprobó los casos 1–51. El arnés multisesión y la reconciliación post-0011 permanecen pendientes; la interfaz `/admin/periods` no está implementada y SEM-01 no está cerrado.

Este documento define la administración mínima de semestres oficiales y la resolución automática de `academic_period_id` para `SEM-01`. Complementa DEC-022, DEC-024 y DEC-056. No autoriza código, DDL, migraciones, despliegues ni operaciones remotas.

## Contrato de producto aprobado

- La superficie administrativa futura será `/admin/periods`. `/catalogs` seguirá siendo una referencia de sólo lectura; `SEM-01` no lo convierte en editor genérico ni habilita administración general de catálogos.
- Sólo una autoridad técnica exacta y actualmente efectiva podrá listar con diagnóstico administrativo, crear, corregir, activar o desactivar periodos.
- Los usuarios operativos nunca seleccionan ni sustituyen manualmente `academic_period_id`. La fecha de inicio de la actividad es la fuente autoritativa.
- Pueden coexistir varios periodos activos. `is_active` significa «elegible para resolución automática y referencia operativa ordinaria», no «semestre único actual».
- Los periodos ordinarios tienen fechas completas, rango válido y ausencia de traslapes activos garantizada en PostgreSQL incluso bajo concurrencia.
- Los borradores pueden conservar `academic_period_id = NULL`; publicar exige resolver el periodo de nuevo y dentro de la misma transacción.
- Toda mutación que altere el calendario efectivo exige diagnóstico transaccional. No puede cambiar ni eliminar una atribución almacenada ni modificar la resolución de una actividad no borrador. Se permite únicamente que un borrador con `academic_period_id = NULL`, antes no resoluble, pase a ser resoluble bajo el calendario propuesto; la mutación del periodo no actualiza la actividad y la publicación posterior vuelve a resolverla transaccionalmente. El producto no ofrece eliminación de periodos; el ciclo operativo es desactivar y preservar.
- Toda mutación administrativa, salvo la creación, requiere motivo; toda mutación exitosa produce auditoría append-only propia del recurso.

## Línea base física actual

El snapshot canónico post-0010 registra `public.academic_periods` con estas columnas reales:

| Columna | Contrato físico actual |
| --- | --- |
| `id` | `uuid`, llave primaria, default `gen_random_uuid()` |
| `code` | `text`, obligatorio y único |
| `name` | `text`, obligatorio; etiqueta visible almacenada |
| `starts_on` | `date`, actualmente admite `NULL` |
| `ends_on` | `date`, actualmente admite `NULL` |
| `is_active` | `boolean`, obligatorio, default `true` |
| `sort_order` | `integer`, obligatorio, default `0` |
| `created_at` | `timestamptz`, obligatorio, default `now()` |
| `updated_at` | `timestamptz`, obligatorio, default `now()` |

No existen columnas `label` ni `description`. La tabla tiene PK y unicidad de `code`, pero la línea base no garantiza todavía por restricción propia fechas ordinarias completas, rango válido, no traslape ni actualización automática de `updated_at`. `activities.academic_period_id` referencia `academic_periods.id` con comportamiento restrictivo predeterminado; esa referencia y las etiquetas históricas se preservan.

La fila inactiva `pilot`, con fechas nulas, es una excepción histórica controlada. No se elimina ni normaliza en `SEM-01`. Las filas ordinarias vivas usan códigos como `2026-1`, `2026-2`, `2027-1` y `2027-2`.

La tabla tiene RLS habilitado y lectura `SELECT` para `authenticated`. No existe hoy una ruta, acción o RPC de administración de periodos. `get_academic_period_for_date(date)` elige el periodo activo con mayor `starts_on <= target_date`; por ello extiende de hecho el último periodo indefinidamente. `publish_activity(uuid)` vuelve a invocar ese resolver al publicar y el trigger basado en `validate_activity_scheduled_state()` exige correspondencia para el estado programado. Esta conducta del resolver es línea base a reemplazar, no el contrato aprobado.

## Frontera exacta de autoridad

La autoridad `SEM-01` exige simultáneamente:

- perfil con `account_status = active`;
- `profiles.is_active = true`;
- asignación de rol activa;
- `role_code = technical_admin`;
- `scope_type = system`;
- `service_area = technical`;
- `program_id IS NULL`;
- `division_id IS NULL`;
- vigencia evaluada con la fecha calendario de `America/Mexico_City`;
- extremos `starts_at` y `ends_at` inclusivos.

La ruta, cada Server Action y cada RPC privilegiada deben comprobar este contrato de manera independiente y fallar de forma cerrada. Ocultar navegación no es autorización. `hasActiveRole(context, "technical_admin")` valida sólo una parte y no puede ser la guarda autoritativa.

La aplicación futura debe usar una guarda de dominio específica que delegue en las mismas semánticas exactas de la frontera confiable B.1. No se concederá `EXECUTE` directo sobre helpers privados de autoridad sólo para reutilizarlos. Después de adquirir los locks de una mutación, la RPC volverá a validar toda la autoridad antes de diagnosticar impacto, auditar o escribir.

## Identidad y ciclo de vida del periodo

### Código

Los nuevos periodos ordinarios usan exclusivamente `YYYY-1` o `YYYY-2`, por ejemplo `2028-1` y `2028-2`. El código es único, normalizado, estable e inmutable después de crear la fila. No admite espacios, minúsculas, sufijos adicionales, formatos alternativos, corrección silenciosa ni reutilización. `pilot` es la única excepción heredada controlada.

### Nombre visible

`name` sigue siendo la etiqueta visible almacenada. Al crear un periodo se inicializa con el mismo valor que `code`; no se añade una segunda columna de etiqueta. Una corrección posterior de `name` sólo se permite por la mutación autorizada y auditada. Nunca cambia la resolución del periodo ni la atribución de actividades.

### Orden

`sort_order` es un campo interno/de compatibilidad y no será editable por el operador. Las interfaces administrativas y de referencia ordenarán periodos ordinarios por `starts_on` y, como clave secundaria estable, `code`. Este diseño no prescribe reescribir valores actuales. Cualquier mantenimiento automático futuro de `sort_order` requerirá una decisión separada y nunca lo convertirá en campo operativo.

### Activación y preservación

La lista administrativa incluye periodos activos e inactivos. Puede haber periodos activos históricos, actuales y futuros al mismo tiempo; no se creará una unicidad de «periodo activo».

Desactivar sólo es válido si el diagnóstico transaccional prueba que ninguna actividad pierde o cambia su periodo resuelto. Reactivar vuelve a validar, después de los locks, autoridad exacta, código, fechas completas, rango, no traslape e impacto de atribución. Un periodo con historia operativa normalmente seguirá activo cuando desactivarlo alteraría esa historia.

El producto no expone botón, Server Action, RPC ni privilegio cliente ordinario de `DELETE`, incluso para filas todavía no referenciadas. Los periodos se desactivan y preservan.

## Integridad de fechas

Todo nuevo semestre ordinario exige `starts_on`, `ends_on` y `starts_on <= ends_on`. Los rangos de periodos ordinarios activos no pueden traslaparse y dos periodos activos no pueden compartir una frontera `starts_on`. PostgreSQL debe impedir las carreras entre `INSERT` y `UPDATE`; la validación de aplicación por sí sola no satisface el contrato. No se exige que exista un único periodo activo.

La integridad pura del rango usa valores `date`. Cualquier decisión dependiente de «hoy», vigencia de asignación o fecha administrativa efectiva usa `America/Mexico_City` y no depende de la zona horaria de la sesión PostgreSQL.

## Resolución automática e intersemestre

La fecha `start_date` de la actividad determina automáticamente el semestre. Para cada periodo activo configurado, el intervalo efectivo comienza en `starts_on` y:

1. cubre su rango oficial hasta `ends_on`;
2. si ya existe un periodo activo sucesor, continúa durante el intersemestre hasta el día calendario inmediatamente anterior al `starts_on` de ese sucesor;
3. si es el último periodo activo configurado, termina en su propio `ends_on` y no se extiende indefinidamente.

En consecuencia:

- antes del primer periodo resoluble, el resultado es `NULL`;
- dentro del semestre, se devuelve ese periodo;
- después de `ends_on` y antes del inicio de un sucesor ya configurado, se conserva el periodo anterior;
- después de `ends_on` del último periodo configurado, el resultado vuelve a ser `NULL` hasta que exista sucesor;
- tras configurar el sucesor, el intersemestre anterior queda cubierto hasta el día previo a su inicio;
- traslapes o fronteras iniciales iguales se rechazan, no se desempatan de forma inestable.

Ésta es una regla intencional de intersemestre, no una consulta convencional de rangos cerrados. El resolver futuro debe ser determinista y aplicar la misma semántica en vistas previas, guardado compatible y publicación, sin confiar en un valor aportado por el cliente.

## Borradores y publicación

Un borrador puede tener fecha incompleta y `academic_period_id = NULL`. No poder resolver un semestre no impide guardarlo, no expone la llave foránea interna y no produce un mensaje para contactar a administración técnica.

Configurar posteriormente el semestre correspondiente puede hacer que ese borrador pase de no resoluble a resoluble. Esa habilitación es intencional: la mutación del calendario no escribe `activities`, no asigna `academic_period_id` y no publica la actividad. La publicación posterior vuelve a resolver desde `start_date` y persiste la atribución dentro de su propia transacción.

Para una fecha claramente fuera de un horizonte operativo razonable, la validación de campo aprobada es:

> Revisa la fecha de la actividad. Selecciona una fecha dentro de un periodo académico razonable.

El umbral numérico o basado en periodos configurados todavía no está aprobado. Es un parámetro futuro de aplicación, no una restricción de integridad de `academic_periods`, y no se inventa en este documento.

Publicar exige volver a resolver el periodo transaccionalmente desde `start_date`, sin aceptar una vista previa o valor cliente obsoleto. Cuando no exista periodo resoluble, se bloquea la publicación con lenguaje neutral:

> La fecha seleccionada no corresponde a un semestre disponible en SITAA. Revisa la fecha o conserva la actividad como borrador.

La persona puede corregir la fecha o conservar el borrador; nunca elegir otro semestre manualmente. DEC-024 conserva las demás validaciones y la transición atómica de borrador a programada.

## Diagnóstico transaccional de impacto

Toda mutación que cambie el calendario efectivo —incluida la creación de un periodo ordinario bajo sus fechas y estado activo propuestos, la corrección de `starts_on` o `ends_on`, la activación y la desactivación— compara de forma autoritativa la resolución actual y propuesta bajo locks. El diagnóstico inspecciona borradores, actividades programadas, canceladas y finalizadas o históricas, y distingue para cada fila:

- atribución almacenada: `activities.academic_period_id`;
- resolución actual: periodo resuelto desde `start_date` bajo el calendario efectivo actual;
- resolución propuesta: periodo resuelto desde `start_date` bajo el calendario efectivo propuesto.

La única clasificación no bloqueante de cambio lógico es la habilitación benigna de un borrador que cumple simultáneamente:

- `status_code = draft`;
- `academic_period_id IS NULL`;
- resolución actual `NULL`;
- resolución propuesta distinta de `NULL` y correspondiente a un periodo válido.

En esa clasificación no existe atribución almacenada que remapear. La mutación del periodo ejecuta cero DML sobre la fila de actividad: no cambia `academic_period_id`, estado, timestamps, creador, perfil responsable ni ningún otro campo. La actividad permanece borrador y sólo una publicación posterior vuelve a resolver desde `start_date` y persiste el periodo dentro de la transacción de publicación.

Todos los demás efectos bloquean la mutación. Se rechaza cuando:

1. una actividad con `academic_period_id IS NOT NULL` resolvería a `NULL` o a un ID distinto del almacenado;
2. una actividad no borrador con `academic_period_id IS NULL` adquiriría, perdería o cambiaría una resolución;
3. un borrador sin atribución almacenada que ya resuelve bajo el calendario actual perdería esa resolución o cambiaría a otro periodo;
4. cualquier actividad requeriría actualización automática o reescritura masiva de `activities.academic_period_id`;
5. se alteraría de cualquier otra forma una atribución histórica persistida.

`SEM-01` no remapea actividades automáticamente. Una reparación histórica excepcional, si alguna vez resulta necesaria, será otra operación explícita, auditada y diseñada en un paquete independiente.

Una mutación cuyo único efecto sea habilitación benigna de borradores puede confirmarse. Crear continúa sin exigir un motivo administrativo separado.

Una corrección exclusiva de `name` no altera la atribución, pero sigue necesitando autoridad, motivo y auditoría con valores anterior/nuevo únicamente de ese campo.

## Motivo administrativo y auditoría

Crear un periodo no exige motivo separado. Corregir `name`, corregir fechas, activar o desactivar exige un motivo normalizado de 10 a 1000 caracteres. No debe contener contraseñas, tokens, cookies, secretos, encabezados de autorización, credenciales, material de sesión ni datos personales innecesarios.

`admin_audit_events` está acoplada estructuralmente a un perfil objetivo y no debe reutilizarse fingiendo que un periodo es una cuenta. La alternativa de menor acoplamiento es un recurso append-only para configuración administrativa o periodos, o una generalización explícitamente aprobada del modelo de auditoría por recurso. El nombre físico se decidirá en el ticket de implementación.

Eventos mínimos:

- periodo académico creado;
- periodo académico actualizado;
- periodo académico activado;
- periodo académico desactivado.

Cada evento contiene actor, identificador del periodo, código estable, acción, timestamp, motivo cuando aplique, campos cambiados y sólo los valores anterior/nuevo de esos campos, con metadata acotada y sanitizada. No contiene SQL crudo, dumps, respuestas de proveedor, tokens, cookies, sesión ni filas completas no relacionadas. Cada mutación exitosa produce exactamente un evento; una operación rechazada o revertida no produce ninguno. `UPDATE`, `DELETE` y `TRUNCATE` sobre el recurso de auditoría deben quedar bloqueados con la misma disciplina append-only vigente.

## Ruta administrativa futura

`/admin/periods` ofrecerá:

- lista completa activa e inactiva;
- código, nombre, fechas y estado;
- creación de semestres ordinarios;
- corrección de campos permitidos;
- activación o desactivación;
- conflictos e impacto expresados con mensajes claros;
- ningún control de eliminación.

La navegación se ocultará sin autoridad, pero la ruta, acciones y RPC fallarán cerradas de forma independiente. `/catalogs` permanecerá de sólo lectura.

## Superficies de lectura

Los periodos son configuración de referencia, no datos personales. Se preservan las lecturas ya autorizadas en actividades, tarjetas y detalles, filtros, exportaciones, etiquetas históricas y reportes autorizados. Una RPC administrativa futura podrá devolver una proyección acotada más rica con filas inactivas, referencias y diagnóstico de editabilidad.

Leer periodos no concede capacidad de mutación, no amplía el universo de actividades visible y no justifica DML directo de clientes autenticados. Cada selector operativo ordinario podrá limitar su proyección a los periodos que requiera su flujo aprobado, sin convertir esa selección en autoridad administrativa.

## Límite del paquete de implementación

El paquete asignado a `0011` abarca las capas A–D, F y G descritas a continuación. La migración está aplicada y su verificador transaccional aprobado; la capa E de aplicación permanece fuera de este ticket y se implementará sólo después de aprobar el arnés multisesión y reconciliar la base.

### A. Integridad de base

- fortalecer `academic_periods` para código ordinario normalizado, fechas completas, rangos válidos y no traslape concurrente;
- definir `updated_at` confiable;
- preservar `pilot`, la FK de actividades y etiquetas históricas.

### B. Resolver

- sustituir o endurecer el resolver actual;
- implementar intersemestre, cierre del último periodo y determinismo;
- conservar borradores con `NULL` y asignación automática al publicar.

### C. Frontera de mutación autorizada

- lista administrativa acotada, creación, corrección permitida, activación y desactivación;
- clasificación transaccional de impacto para creación y toda mutación posterior que altere el calendario efectivo: sólo la habilitación benigna de borradores no asignados es no bloqueante; toda alteración persistida u operativa permanece bloqueada;
- reautorización exacta después de locks;
- cero DML cliente directo y cero eliminación.

### D. Auditoría

- recurso append-only de periodos/configuración con metadata sanitizada;
- exactamente un evento por éxito y ninguno por rechazo o rollback.

### E. Aplicación

- `/admin/periods`, guarda exacta, lista, formularios y mensajes neutrales;
- ningún selector manual de periodo ni acción de eliminación.

### F. Verificación

- preflight independiente, checker SQL estático y verificador transaccional con `ROLLBACK`;
- arnés multisesión real para carreras de traslape y pérdida de autoridad;
- pruebas de aplicación, snapshot post-aplicación y reconciliación.

### G. Rollback

- reversión conservadora y fail-closed que restaure definiciones y ACL post-0010 exactos sólo cuando sea seguro;
- preservación de actividades, referencias y auditoría;
- locks explícitos y rechazo ante mutación concurrente.

Los artefactos de base, preflight, verificador, rollback, checker y plan de pruebas fueron preparados. `0011` fue aplicada en producción el 2026-08-12 y el verificador corregido aprobó los casos 1–51 con su propio `ROLLBACK`; el rollback de la migración no fue ejecutado. El arnés multisesión y la reconciliación post-0011 permanecen pendientes.

## Preflight obligatorio antes de aplicar

El preflight será de sólo lectura, fallará de forma cerrada y terminará sin mutar producción. Como mínimo inspeccionará:

1. forma física exacta de `academic_periods`;
2. filas actuales y excepciones heredadas controladas;
3. códigos duplicados o no normalizados;
4. fechas nulas o parciales;
5. rangos inválidos;
6. traslapes activos existentes;
7. límites `starts_on` activos iguales;
8. referencias de actividades por estado de ciclo de vida;
9. definición del resolver vigente;
10. función de publicación vigente;
11. trigger de validación del estado programado;
12. estado RLS;
13. políticas;
14. privilegios de tabla, columna, rutina y ACL;
15. rutas DML directas existentes;
16. autoridades técnicas exactas presentes, sólo como conteos sanitizados;
17. auditoría existente y su acoplamiento a perfiles;
18. nombres de objetos en conflicto;
19. triggers o funciones inesperados;
20. cualquier artefacto de migración o reconciliación llamado `0011`;
21. identidad de Git y del snapshot base;
22. privilegios predeterminados relevantes para nuevas tablas y funciones.

## Verificador y concurrencia posteriores a la aplicación

El verificador transaccional y las pruebas complementarias cubrirán, como mínimo:

1. forma y ACL exactos de línea base antes de mutar;
2. creación válida;
3. rechazo de código duplicado;
4. rechazo de formato de código inválido;
5. rechazo de código vacío o en blanco;
6. rechazo de fechas ordinarias ausentes o parciales;
7. rechazo de `starts_on > ends_on`;
8. traslape en `INSERT`;
9. traslape en `UPDATE`;
10. inserts traslapados concurrentes desde sesiones distintas;
11. actualización concurrente contra creación;
12. límites adyacentes no traslapados;
13. múltiples periodos futuros activos válidos;
14. preservación de `pilot` inactivo con fechas nulas;
15. éxito del administrador técnico exacto;
16. denegación a `anon`;
17. denegación a usuarios autenticados ordinarios;
18. denegación a asignación técnica malformada;
19. denegación a administrador inactivo, futuro, expirado, con alcance o servicio incorrecto, o ligado a programa/división;
20. pérdida de autoridad mientras espera locks;
21. lista administrativa sólo por la frontera aprobada;
22. lecturas de referencia ordinarias sin mutación;
23. borrador con `academic_period_id = NULL`;
24. publicación dentro de semestre;
25. publicación en intersemestre;
26. publicación antes del primer periodo;
27. publicación después de `ends_on` del último periodo;
28. publicación después de configurar sucesor;
29. re-resolución al publicar, sin confiar en cliente;
30. ausencia de override manual;
31. corrección de nombre sin cambio de atribución;
32. corrección de fecha con cero actividades afectadas;
33. bloqueo de corrección cuando cambia cualquier atribución;
34. bloqueo de desactivación cuando una actividad pierde o cambia periodo;
35. rechazo de traslape al reactivar;
36. ausencia de DELETE de producto;
37. ausencia de DML directo de `authenticated`;
38. exactamente un evento sanitizado por mutación exitosa;
39. ningún evento por mutación rechazada o revertida;
40. protección append-only;
41. seguridad y límites de metadata;
42. comportamiento de fechas independiente de zona de sesión;
43. corrección de `updated_at`;
44. `ROLLBACK` final que restaure fixtures;
45. postcondiciones exactas de esquema, políticas, ACL, filas y ausencia de residuos.
46. creación exitosa cuando su único efecto de resolución es habilitar una fila `draft` con `academic_period_id IS NULL` que antes no resolvía a ningún periodo;
47. prueba de que la mutación exitosa del periodo no actualiza esa fila de borrador, incluidos `academic_period_id`, estado, timestamps, creador, perfil responsable y los demás campos de actividad;
48. publicación posterior exitosa de ese borrador, con nueva resolución transaccional y persistencia del periodo académico correcto;
49. rechazo de una creación u otra mutación del calendario cuando una actividad no borrador adquiere, pierde o cambia su periodo resuelto;
50. rechazo cuando cualquier actividad con `academic_period_id` almacenado no nulo resolvería a `NULL` o a un periodo diferente;
51. rechazo cuando un borrador no asignado que ya resuelve bajo el calendario actual perdería esa resolución o cambiaría a otro periodo.

El verificador SQL no sustituye el arnés multisesión: las carreras de solapamiento, espera de locks y pérdida de autoridad requieren conexiones reales independientes y evidencia sanitizada.

## Rollback conservador preparado

El rollback preparado sólo restaurará objetos introducidos o reemplazados por la migración `0011` y preservará contratos post-0010 no sustituidos. Debe:

- negarse si la auditoría de periodos contiene evidencia operativa, salvo procedimiento irreversible aprobado;
- negarse si nuevos periodos o semánticas ya usadas no pueden revertirse sin eliminar o reatribuir historia;
- no borrar actividades, referencias de periodo ni eventos;
- restaurar exactamente definiciones anteriores del resolver y ACL;
- adquirir locks explícitos y fallar ante uso concurrente;
- incluir una guarda predestructiva y una ruta de verificación transaccional separada;
- no declararse automáticamente seguro sólo porque la migración aún no hubiera llegado a producción.

## Elementos explícitamente diferidos

Quedan fuera de `SEM-01`: administración genérica de catálogos, elección manual del semestre, remapeo masivo, eliminación de periodos, grupos, asignaciones de tutores, exportaciones de asistencia, dashboards, alertas, B.3b, OAuth, cambios a 0001–0010, limpieza de `pilot` y formularios dinámicos.

## Parámetro de implementación pendiente

Falta aprobar la definición numérica —o dependiente de periodos configurados— del horizonte de fecha de actividad «razonable». Debe resolverse antes de programar esa validación de aplicación. No se adopta aquí un límite de años y no se convierte en restricción de la tabla.

## Estado de aceptación

- Contrato de producto: **aprobado**.
- Documentación canónica: **creada**.
- Revisión del paquete de implementación: **aprobada para la aplicación ejecutada**.
- Implementación de base de datos: **aplicada en producción el 2026-08-12; verificador transaccional aprobado**.
- Migración: **`0011` asignada a SEM-01**.
- Verificador productivo: **casos 1–51 aprobados; primer intento rechazado conservado como historia**.
- Rollback de la migración: **no ejecutado**.
- Arnés multisesión, snapshot/reconciliación post-0011 y smoke tests: **pendientes**.
- Interfaz `/admin/periods`: **no implementada**.
