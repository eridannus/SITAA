# Notas de seguridad y privacidad

## Datos protegidos

SITAA manejará identidad, matrícula o número de empleado, pertenencia académica, asistencia, observaciones de sesión y encuestas. Se debe recopilar únicamente lo necesario y definir responsables, finalidad, conservación y eliminación conforme a la normativa institucional aplicable.

## Controles obligatorios

### Identidad y sesión

- Usar Supabase Auth con Google OAuth para registro y login público. No restringir dominios ni usar `hd`; aceptar Gmail, Workspace y `pc.puma` con scopes básicos `openid`, `email`, `profile`.
- 0004 crea `pending_registration` para Google nuevo y sólo activa mediante un RPC autenticado que completa el propio perfil. SMTP no es requisito. El acceso correo/contraseña permanece únicamente para identidades heredadas.
- Las cuentas `technical` siguen siendo exclusivamente administrativas: sólo `app_metadata` confiable puede originarlas; el formulario público no controla tipo de cuenta, estado ni roles.
- SITAA no permite cuentas que existan sólo en Auth. Cada alta debe resolver exactamente un camino institucional o técnico y crear exactamente un perfil; metadata ausente, no soportada o ambigua aborta la transacción completa sin dejar un Auth user huérfano.
- El preflight de 0004 bloquea por separado perfiles sin Auth y Auth users sin perfil. La conciliación de estos casos se realiza con acceso privado: no se inventan nombres, programas ni identificadores y no se elimina una cuenta salvo confirmación explícita de que es sintética y desechable.
- La base limita los identificadores institucionales a 1–50 dígitos como texto, el nombre normalizado a 2–200 caracteres y el correo normalizado a 254 caracteres. El trigger de alta aplica los mismos límites antes de crear el perfil.
- Gestionar la sesión con clientes SSR y cookies seguras; validar al usuario en el servidor antes de servir rutas protegidas.
- Configurar redirecciones autorizadas y cookies seguras.
- No se recibe ni almacena PII institucional antes de Google. La selección pública guarda sólo `student` o `professor` en una cookie breve `HttpOnly` limitada al callback.
- No existe RPC anónimo para crear registros o consultar disponibilidad. El conflicto de identificador sólo se revela al usuario autenticado que completa su propio perfil.
- Desde 0005, el trigger de alta Google no confía en el valor temporal de `email_confirmed_at` durante el `INSERT`. El perfil queda pendiente, inactivo y sin permisos; la activación exige después una fila Google de `auth.identities`, correo coincidente y evidencia final de verificación.
- Las rutas públicas de registro y `startGoogleRegistration` repiten guardas de servidor: cuentas activas, pendientes, inactivas o sin perfil no pueden iniciar otra alta.
- 0004 y 0005 están aplicadas, verificadas y reconciliadas. La guarda usada durante el render de rutas públicas es de sólo lectura; la limpieza de cookies queda limitada a Server Actions y Route Handlers.
- La separación administrativa inicial entre una cuenta técnica y una cuenta académica fue específica del entorno, no transfirió historia ni se convierte en una operación general de fusión. La administración futura debe ser explícita y auditada en Fase B.
- El callback registra sólo etapa, código/mensaje sanitizados y timestamp. Nunca registra código OAuth, state, verifier, access/refresh tokens, cookies o secretos del proveedor.
- No revelar si un correo está registrado mediante mensajes de error diferenciados.
- Revocar acceso al desactivar perfiles o vencer asignaciones.
- No permitir que el usuario cambie por autoservicio tipo de cuenta/persona, identificador, programa principal, estado o roles.
- Con 0006, el autoservicio activo permite únicamente `first_names`, `paternal_surname` y `maternal_surname`; privilegios de columna y trigger impiden cambiar clasificación, identificador, programa, correo, estado o roles. `full_name` se deriva en la base y no se escribe directamente.
- La migración 0006 no divide nombres existentes. Su preflight de sólo lectura expone conteos y bloquea cualquier cuenta activa sin componentes revisados, evitando incorporar PII o correspondencias adivinadas al repositorio.
- La aplicación bloquea perfiles pendientes o inactivos. La revocación coordinada de sesiones Auth y la administración de bajas permanecen para una migración posterior de Fase B.

### Administración de cuentas y roles

- Ejecutar `auth.admin`, correcciones de identidad y administración de roles sólo en backend confiable o Edge Function; nunca exponer `service_role` al navegador.
- Los administradores no ven ni establecen contraseñas; inician enlaces seguros de recuperación.
- Validar elegibilidad, alcance, servicio, programa, vigencia y actor distinto del beneficiario antes de asignar un rol.
- Revocar asignaciones sin borrar historia y registrar actor, fecha y motivo.
- Desactivar una cuenta en Auth y en la autorización SITAA sin eliminar perfil, autoría, actividades o asistencia.
- Mantener un log administrativo append-only y sanitizado para cambios críticos.

#### Fase B.1 implementada, verificada y reconciliada mediante 0007

- El directorio administrativo es de sólo lectura y exige perfil `active` más una asignación actual `technical_admin/system/technical`, sin programa ni división. Una asignación mal formada no concede acceso.
- La vigencia B.1 usa la fecha calendario de `America/Mexico_City`, con `starts_at` y `ends_at` inclusivos. La aplicación y las RPC 0007 comparten ese contrato; la autorización en base no depende de la zona horaria de la sesión PostgreSQL.
- La guarda de interfaz se repite dentro de cada RPC `SECURITY DEFINER`; una invocación directa no autorizada falla con `42501`.
- No se crean políticas transversales de `profiles` ni `role_assignments`; las políticas propias existentes permanecen intactas.
- La lista minimiza datos y enmascara el identificador salvo sus últimos cuatro caracteres como máximo. El valor completo sólo aparece en la ficha individual autorizada.
- Auth se resume únicamente como correo confirmado o no confirmado: el booleano acepta `email_confirmed_at` o una identidad Google verificada cuyo correo normalizado coincide. No se devuelven contraseñas, tokens, cookies, metadata, identidades OAuth ni enlaces de recuperación.
- `admin_audit_events` está aplicada como bitácora append-only, con RLS sin políticas de cliente y triggers contra `UPDATE`, `DELETE` y `TRUNCATE`. `PUBLIC`, `anon` y `authenticated` no tienen acceso directo; `service_role`, cuya propiedad `rolbypassrls=true` fue precondición bloqueante, recibe explícitamente sólo `SELECT` e `INSERT` sobre la tabla y `EXECUTE` sobre `admin_audit_metadata_is_safe(jsonb)`. Ningún privilegio depende de defaults ambientales y la aplicación no crea un cliente `service_role`.
- 0007 normaliza explícitamente el ACL de cada función para los cuatro roles del proyecto y lo verifica antes del `COMMIT`: las RPC públicas sólo conceden `EXECUTE` no delegable a `authenticated`; fecha institucional, autoridad y bloqueo append-only son owner-only; únicamente el validador de metadata concede `EXECUTE` no delegable a `service_role`.
- El rollback de 0007 usa `READ COMMITTED` y retiene `ACCESS EXCLUSIVE NOWAIT` sobre `admin_audit_events` antes de consultar si está vacía. Esto cierra la carrera entre el control de vacío y el retiro de la tabla: cualquier actividad concurrente aborta el intento y exige aquietar la auditoría y reintentar, sin quitar `NOWAIT`, debilitar el lock, omitir el control o forzar la pérdida de historia.
- La metadata debe ser un objeto JSON de hasta 16 384 bytes. Sus llaves superiores se normalizan a minúsculas y sin separadores antes de rechazar términos sensibles como `password`, `token`, `cookie`, `secret`, `authorization`, `credential`, `recovery`, `session`, `bearer` o `apikey`.
- El verificador 0007 no se limita a comprobar nombres de objetos: valida columnas y defaults, PK/FK/CHECK, índices, triggers, firmas RPC, propiedades de helpers y ACL de tabla, columna y función contra los catálogos PostgreSQL. Esto impide aceptar una forma física o un privilegio más amplio que el contrato B.1.
- Su primera ejecución se detuvo antes de crear fixtures porque el arnés normalizaba `pg_proc.prosrc` en un orden incorrecto. El diagnóstico de sólo lectura confirmó las definiciones y ACL persistentes; la corrección sólo cambió el verificador y no debilitó ni alteró la migración aplicada. La reejecución terminó con `ROLLBACK`, los smoke tests aprobaron y la reconciliación post-0007 no encontró deriva inexplicada.
- La aplicación no utiliza `service_role` ni escribe auditoría en B.1. Las mutaciones de cuenta quedan en B.2/B.3 y las de rol en Fase C.
- No incorporar nombres, correos ni identificadores personales a semillas SQL.

#### Fase B.2a aplicada mediante 0008; verificación pendiente

El preflight 0008 fue aprobado, la aplicación compatible se publicó y la migración terminó con `COMMIT`. 0008 está aplicada y es inmutable, pero la reejecución del verificador corregido, los smoke tests y la reconciliación post-0008 siguen pendientes.

- Una cuenta pendiente, inactiva, sin perfil o con estado incompatible no puede leer ni mutar actividades, participantes, asistencia o check-in, aunque conserve un JWT o asignaciones vigentes.
- La frontera se aplica en RLS restrictiva y dentro de las RPC operativas `SECURITY DEFINER`; ocultar botones no constituye autorización.
- Se mantiene el acceso mínimo al perfil propio y a su historial de asignaciones para `/account-status`. La finalización Google pendiente continúa disponible bajo su contrato específico.
- Sólo un administrador B.1 exacto, activo y vigente puede corregir la identidad de otra cuenta activa o inactiva. La RPC hace una comprobación optimista y otra autoritativa después de esperar todos los locks; ninguna identidad del objetivo se carga o valida de forma distinguible antes de la segunda decisión. El cambio más su evento se confirman o revierten juntos.
- La decisión se serializa con locks `SHARE` en orden fijo: `role_assignments`, `activities`, `activity_participants`; después actor y objetivo se bloquean juntos por UUID con `ORDER BY ... FOR UPDATE`. Así, una revocación de rol o desactivación del actor iniciada primero hace fallar la segunda autorización, mientras que una corrección iniciada primero puede confirmar bajo autoridad todavía válida. El orden común evita deadlock en correcciones cruzadas. Estas pruebas de dos sesiones siguen pendientes y sólo podrán ejecutarse en una base, rama o clon desechable que se descarte/restaure por completo; nunca en producción ni mediante borrado de auditoría append-only o perfiles referenciados.
- La aplicación no necesita DML directo sobre `activity_participants`: 0008 conserva sólo `SELECT` para `authenticated` y elimina su DML de tabla. `pg_attribute.attacl`/`aclexplode` es la autoridad para exigir cero grants explícitos de columna; `information_schema.column_privileges` conserva legítimamente filas por columna derivadas de `SELECT`/`INSERT`/`UPDATE`/`REFERENCES` de tabla; y `has_column_privilege` se compara con `has_table_privilege` para impedir acceso efectivo adicional. Preflight, post-DDL, verificador y rollback aplican esas tres semánticas y rechazan grantees inesperados o grant option. Las escrituras directas de `activities` se conservan para el flujo actual, pero un trigger impide sustituir creador/responsable, revalida cambios de alcance y bloquea cambios que dejarían participantes incompatibles.
- La frontera temporal canónica considera abierta una actividad si es borrador o aún no terminó mediante `end_date`/`start_date` y `end_time`/`start_time` en `America/Mexico_City`. Las dependencias históricas no borrador ya terminadas no bloquean correcciones; un cliente autenticado tampoco puede moverlas de nuevo a estado abierto (`sitaa_activity_reopen_forbidden`). Un writer confiable sólo podría hacerlo tras revalidar todos los perfiles dependientes.
- El rol de participante `responsible` conserva su requisito de profesor. Esa regla no se extiende a `responsible_profile_id`, porque la responsabilidad primaria puede corresponder a un tutor par; para éste se revalida alcance de programa/división, no un tipo universal de persona.
- `role_assignments` no tiene mutaciones directas de `authenticated` ni writer de aplicación en B.2a. Cualquier writer futuro de Fase C deberá repetir el protocolo de lock y revalidación después de esperar; la existencia de privilegios confiables de `postgres`/`service_role` no equivale a una ruta de aplicación soportada.
- La normalización colapsa todo whitespace a un espacio, recorta extremos y convierte vacío en `NULL`. `person_type = NULL` institucional y nombres derivados menores de dos caracteres se rechazan con errores controlados antes de tocar el perfil.
- El evento guarda actor, objetivo, acción, resultado, motivo normalizado y sólo los nombres de campos modificados; nunca almacena valores anteriores/nuevos, correo, identificadores, Auth, roles ni actividad.
- Las tres funciones B.2a invocables tienen sólo owner + `authenticated`; el trigger es owner-only. Junto con la revocación de tres grants de tabla, el estado previsto pasa de 125/270/6/436 a 132/267/6/440 para rutina/tabla/secuencia/ACL expandida.
- `public.is_b1_account_admin()` sigue siendo un helper privado owner-only: `PUBLIC`, `anon`, `authenticated` y `service_role` no tienen `EXECUTE`. Las RPC públicas B.1/B.2a son `SECURITY DEFINER` y lo invocan internamente bajo la autoridad de su propietario después de que el cliente entra por la firma autorizada. La invocación directa como `authenticated` debe fallar con SQLSTATE `42501`; no se concede privilegio adicional para probar su semántica.
- No se añade `auth.admin`, clave `service_role` ni cliente privilegiado a la aplicación.
- 0008 preserva sin DDL los dos triggers Auth de Fase A. Sus guardas exigen exactamente `on_sitaa_auth_user_created` para `AFTER INSERT` y `on_sitaa_auth_user_email_changed` para `AFTER UPDATE OF email` con `OLD.email IS DISTINCT FROM NEW.email`, ambos por fila, habilitados normalmente y conectados por OID a su handler canónico. También bloquean duplicados o handlers reutilizados por otro trigger no interno. Tras falsos positivos del arnés por nombres, decompilación `OLD`/`NEW` y el cast `::text` del deparser, el preflight corregido aprobó sus 35 bloqueos y terminó con `ROLLBACK`.
- La primera ejecución del verificador post-aplicación abortó dentro de su propia transacción porque intentó evaluar directamente el helper owner-only bajo `authenticated`. La denegación fue correcta; no persistieron fixtures, grants temporales, eventos de auditoría ni cambios operativos. El verificador corregido prueba por separado semántica owner, denegación ACL cliente y autorización mediante las RPC públicas, sin cambiar ningún privilegio persistente.

### Autorización y base de datos

- Habilitar RLS en todas las tablas accesibles desde la API.
- Basar políticas en `auth.uid()` más relaciones de asignación verificables.
- Probar políticas con cada rol y con usuarios fuera del alcance autorizado.
- Reservar `service_role` para procesos de servidor estrictamente controlados.
- Validar datos y transiciones de estado en servidor o base de datos, no solo en formularios.
- Aplicar filtros sólo después de construir mediante RLS/RPC el conjunto visible; ningún query param o selector puede ampliar acceso.

### QR y asistencia

- El QR debe contener un token aleatorio, de un solo propósito y vigencia corta; nunca datos personales.
- Guardar la huella criptográfica del token, no el token reutilizable.
- Requerir sesión autenticada y comprobar pertenencia del estudiante al grupo.
- Aplicar unicidad por sesión y estudiante, límites de intentos y registro de invalidaciones.
- No prometer validación de presencia física solo con QR; ubicación o dispositivo requerirían evaluación adicional de privacidad.

### Encuestas, exportaciones y archivos

- Separar respuestas de satisfacción de vistas que identifiquen al estudiante cuando el objetivo sea anonimato.
- Aplicar un umbral antes de presentar agregados de grupos pequeños.
- Escapar celdas peligrosas en CSV para evitar inyección de fórmulas.
- Registrar quién exporta, qué filtros usa y cuándo lo hace.
- Usar buckets privados de Supabase Storage, rutas no predecibles y URLs firmadas de corta duración.
- Restringir tipo, tamaño y extensión de archivos; analizar la necesidad real antes de permitir adjuntos.

## Secretos y despliegue

- Mantener secretos solo en variables de entorno locales y de Vercel/Supabase.
- Exponer al navegador únicamente valores públicos previstos, como la clave `anon`.
- Excluir archivos `.env*` con secretos y usar datos ficticios en desarrollo.
- Separar, si los límites lo permiten, proyectos de desarrollo y producción.
- Revisar encabezados de seguridad, dependencias y alertas antes de cada entrega.

### Contrato de dominio de producción

- Origen canónico: `https://www.sitaa.net`.
- El dominio raíz `https://sitaa.net` redirige al origen canónico.
- `https://sitaa.vercel.app` es respaldo técnico y no la URL pública canónica.
- Vercel Production configura `NEXT_PUBLIC_SITE_URL=https://www.sitaa.net`. Es configuración pública, no un secreto; Preview no debe recibir ese valor automáticamente salvo decisión explícita.
- Supabase Authentication configura Site URL en `https://www.sitaa.net` y permite actualmente `https://www.sitaa.net/**` y `https://sitaa.vercel.app/**` como Redirect URLs.
- Los enlaces QR y directos de asistencia derivan de `NEXT_PUBLIC_SITE_URL`; se verificó manualmente que usan `https://www.sitaa.net/check-in/...`.
- Cloudflare administra DNS. Los registros CNAME dirigidos a Vercel deben permanecer en modo **DNS only**, sin proxy de Cloudflare.
- El archivo de ejemplo puede documentar `NEXT_PUBLIC_SITE_URL=https://www.sitaa.net` porque es un origen público, no un secreto; los valores efectivos se controlan por entorno en Vercel.

## Auditoría y operación

- Auditar cambios de rol, correcciones de asistencia, cierres, exportaciones y acciones administrativas.
- No guardar tokens, secretos, respuestas completas ni datos sensibles innecesarios en logs.
- Definir respaldo, restauración, retención y respuesta a incidentes antes del piloto.
- Verificar periódicamente límites, copias disponibles y condiciones de los planes gratuitos; no asumir que equivalen a un SLA institucional.

### Límites de lectura administrativa B.2a

- `authenticated` consulta estado de otras cuentas únicamente mediante RPC `SECURITY DEFINER` autorizadas y con proyecciones sanitizadas; no recibe lectura directa de perfiles ajenos.
- `authenticated` no tiene acceso directo a `admin_audit_events`. La historia pública B.1 excluye metadata cruda y se valida como superficie cliente mediante su RPC autorizada.
- En el verificador 0008, las RPC, denegaciones y DML cliente se ejecutan bajo `authenticated`; las postcondiciones crudas de perfil, Auth y auditoría se inspeccionan sólo como owner después de `RESET ROLE`.
- Las dos ejecuciones fallidas del verificador fueron transacciones descartadas y no justifican ampliar RLS ni ACL: la primera llamó un helper owner-only como cliente y la segunda intentó leer postcondiciones owner-only bajo el rol cliente.

## Validaciones previas al piloto

- Revisión de privacidad y aviso correspondiente.
- Pruebas negativas de RLS entre roles, grupos y periodos.
- Revisión del flujo QR frente a reuso, captura y concurrencia.
- Prueba de exportaciones con caracteres especiales y fórmulas.
- Procedimiento documentado para baja de usuarios e incidentes.
