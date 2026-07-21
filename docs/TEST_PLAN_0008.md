# Plan de pruebas de la migración 0008

## Estado y alcance

El preflight corregido de `0008_operational_account_barrier_identity_correction.sql` fue aprobado, la aplicación compatible se publicó y la migración terminó con `COMMIT`; 0008 está aplicada y es inmutable. La primera ejecución del verificador aprobó sus controles estáticos, creó fixtures transaccionales y después abortó al invocar directamente `is_b1_account_admin()` bajo `authenticated`, cuyo ACL owner-only rechazó correctamente la llamada con SQLSTATE `42501`. La transacción se descartó completa: no persistieron fixtures, grants temporales, eventos de auditoría ni cambios operativos. La corrección del verificador es local; su reejecución, los smoke tests y la reconciliación contra un snapshot post-0008 permanecen pendientes. Este plan no autoriza conexión ni ejecución contra Supabase.

Inventario contractual post-0008, pendiente de confirmación mediante snapshot: 18 tablas, 165 columnas, 80 restricciones, 43 índices, 11 triggers públicos, 51 funciones, 25 políticas y 51 semillas. Las tres RPC/helper B.2a nuevas conservan propietario y `authenticated`; el nuevo trigger de integridad de escritores es owner-only. `authenticated` conserva `SELECT` sobre `activity_participants`, pero sus escrituras directas se retiran porque la aplicación ya usa los RPC autorizados. La clausura distingue el ACL de tabla, el ACL explícito por columna en `pg_attribute.attacl`, la proyección table-derived de `information_schema.column_privileges` y el acceso efectivo de `has_column_privilege`: no puede sobrevivir ningún `attacl` y ningún acceso de columna puede exceder el ACL exacto de tabla.

Partiendo de los snapshots de privilegios post-0007 (125 grants de rutina, 270 de tabla, 6 de secuencia y 436 ACL expandidas), el contrato exacto post-0008 es 132/267/6/440. Las cuatro funciones añaden siete entradas de rutina —owner + `authenticated` para tres, sólo owner para el trigger— y la tabla de participantes pierde tres grants de `authenticated`; el delta ACL neto es +4.

## Matriz completa de superficie funcional

La evidencia post-0007 contiene 47 firmas públicas. Veintinueve se reemplazan sin cambiar firma ni ACL y dieciocho se exentan expresamente.

| # | Firma | Modificada | Tratamiento |
|---:|---|:---:|---|
| 1 | `activity_attendance_deadline(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 2 | `activity_attendance_open_at(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 3 | `activity_has_ended(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 4 | `add_activity_participant(uuid,uuid,text)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 5 | `admin_audit_metadata_is_safe(jsonb)` | No | Validador privado de metadata de auditoría. |
| 6 | `can_create_activity(text,uuid,uuid,text)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 7 | `can_create_activity(uuid,text)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 8 | `can_delete_activity(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 9 | `can_edit_activity(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 10 | `can_manage_activity(text,uuid,uuid,text)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 11 | `can_manage_activity(uuid,text)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 12 | `can_read_activity(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 13 | `can_update_activity_base(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 14 | `check_in_activity(text)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 15 | `close_activity_attendance_checkin(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 16 | `complete_own_google_registration(text,text,text,text,text,uuid)` | No | Finalización Google de una cuenta pendiente; debe funcionar antes de la activación. |
| 17 | `complete_own_google_registration(text,text,text,uuid)` | No | Sobrecarga heredada sin EXECUTE de cliente; compatibilidad post-0007. |
| 18 | `enforce_sitaa_profile_identity()` | No | Trigger de integridad de perfiles. |
| 19 | `finalize_expired_attendance()` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 20 | `generate_three_word_code()` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 21 | `get_academic_period_for_date(date)` | No | Consulta pura de catálogo de semestres. |
| 22 | `get_active_activity_attendance_checkin(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 23 | `get_activity_attendance_checkin_state(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 24 | `get_activity_participants(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 25 | `get_admin_account_assignments_b1(uuid)` | No | RPC B.1 con autoridad exacta de administrador activo. |
| 26 | `get_admin_account_audit_history_b1(uuid,integer,integer)` | No | RPC B.1 con autoridad exacta de administrador activo. |
| 27 | `get_admin_account_detail_b1(uuid)` | No | RPC B.1 con autoridad exacta de administrador activo. |
| 28 | `get_visible_activity_cards()` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 29 | `guard_activity_participant_pending_deadline()` | No | Trigger de integridad de asistencia. |
| 30 | `handle_sitaa_auth_user_created()` | No | Trigger Auth/bootstrap. |
| 31 | `has_active_role(text)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 32 | `has_any_active_role(text[])` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 33 | `is_activity_participant(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 34 | `is_b1_account_admin()` | No | Helper privado de autoridad B.1 activa. |
| 35 | `normalize_sitaa_profile_names()` | No | Trigger de normalización de nombres. |
| 36 | `open_activity_attendance_checkin(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 37 | `prevent_admin_audit_event_mutation()` | No | Trigger append-only de auditoría. |
| 38 | `publish_activity(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 39 | `remove_activity_participant(uuid)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 40 | `search_admin_accounts_b1(text,uuid,text,text,text,text,text,text,integer,integer)` | No | RPC B.1 con autoridad exacta de administrador activo. |
| 41 | `search_profiles_for_participation(uuid,text)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 42 | `set_updated_at()` | No | Trigger técnico de timestamps. |
| 43 | `sitaa_current_mexico_date()` | No | Helper puro privado de fecha institucional. |
| 44 | `sync_sitaa_profile_email_from_auth()` | No | Trigger de sincronización Auth/profile. |
| 45 | `update_activity_participant_attendance(uuid,text,text)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 46 | `update_activity_participants_attendance_bulk(uuid,uuid[],text,text)` | Sí | Barrera explícita; conserva ACL `postgres`, `authenticated`, `service_role`. |
| 47 | `validate_activity_scheduled_state()` | No | Trigger de integridad de publicación. |

Semántica uniforme:

- helpers booleanos: `false`;
- helpers escalares de tiempo/estado: `NULL`;
- lecturas que devuelven conjuntos: cero filas o el rechazo controlado ya establecido;
- mutaciones PL/pgSQL: `42501` con `sitaa_operational_account_inactive` antes de leer o escribir.

## Preflight independiente

El preflight:

- inicia una transacción de sólo lectura y termina con `ROLLBACK`;
- emite únicamente `category`, `classification` y `aggregate_count`;
- bloquea por deriva de inventario, firmas, definiciones, ACL, políticas, grants directos, identidad/lifecycle, programas, catálogos, auditoría B.1 o conflictos 0008;
- cuenta por separado el `attacl` explícito, las filas de `information_schema.column_privileges` no explicadas por grants directos de tabla y cualquier diferencia entre `has_column_privilege` y `has_table_privilege`; acepta las filas legítimas que PostgreSQL proyecta por cada columna desde `SELECT`/`INSERT`/`UPDATE`/`REFERENCES` de tabla;
- bloquea incompatibilidades de participantes únicamente en dependencias abiertas: borrador o actividad aún no terminada mediante fecha/hora de Ciudad de México;
- informa como agregado no bloqueante las incompatibilidades históricas terminadas, sin PII;
- informa sólo conteos agregados de dependencias potenciales;
- no expone nombres, correos, identificadores, UUID ni filas operativas.
- exige RLS activa en `profiles`, `role_assignments`, `activities`, `activity_participants` y `admin_audit_events`;
- bloquea huérfanos Auth/profile, deriva de las FK exactas y asignaciones con usuario huérfano;
- verifica por separado identidad institucional/técnica activa o inactiva, ciclo de vida, políticas propias y el RLS/ACL exacto de la auditoría.

Todos los bloqueos se repiten dentro de la migración antes del DDL.

La comparación de la proyección replica la semántica estable de PostgreSQL para `is_grantable`: el propietario aparece con `YES` por su condición de owner aunque su entrada ACL directa no lleve grant option; los demás receptores sólo aparecen con `YES` si el ítem ACL lo concede. La prohibición de grant option se comprueba sobre `relacl`/`attacl`, no confundiendo esa representación del propietario con deriva.

### Contrato canónico de triggers Auth

La primera ejecución remota del preflight fue de sólo lectura, terminó con `ROLLBACK` y código de salida 0, y devolvió cero en todas las categorías bloqueantes salvo `registration_trigger_drift = 1`. El resultado fue un falso positivo local: el SQL buscaba los nombres ajenos al contrato SITAA `on_auth_user_created` y `on_auth_user_updated`. No se aplicó la migración ni se modificó ningún objeto.

La categoría corregida valida de forma independiente y agregada los dos triggers canónicos:

- `on_sitaa_auth_user_created`: exactamente uno, no interno, habilitado normalmente, `AFTER INSERT FOR EACH ROW` sobre `auth.users`, sin lista de columnas ni `WHEN`, conectado por OID exacto a `public.handle_sitaa_auth_user_created()`;
- `on_sitaa_auth_user_email_changed`: exactamente uno, no interno, habilitado normalmente, `AFTER UPDATE OF email FOR EACH ROW` sobre `auth.users`, con una sola columna `email`, condición semántica `OLD.email IS DISTINCT FROM NEW.email` y OID exacto de `public.sync_sitaa_profile_email_from_auth()`.

El control rechaza ausencia, duplicados, deshabilitación, tabla/evento/timing/función incorrectos y cualquier trigger no interno adicional que invoque alguno de esos handlers. El preflight embebido repite el mismo contrato antes del DDL; la guarda post-DDL y el verificador vuelven a comprobar cada trigger por separado. 0008 no crea, reemplaza, renombra ni elimina triggers de `auth.users`.

La segunda ejecución remota inició una transacción de sólo lectura, pero falló durante la evaluación del contrato antes de producir las 40 categorías con `expression contains variables of more than one relation`. El arnés intentaba decompilar `tgqual` mediante `pg_get_expr`, aunque el `WHEN` contiene referencias separadas a `OLD` y `NEW`. `ON_ERROR_STOP=1` detuvo `psql`; la transacción abortada se descartó al cerrar la conexión y no dejó cambios ni objetos de migración.

La tercera ejecución remota terminó normalmente, devolvió las 40 categorías y finalizó con `ROLLBACK`. Todos los bloqueos fueron cero salvo `registration_trigger_drift = 1`; los conteos informativos permanecieron no bloqueantes en dos perfiles institucionales potencialmente bloqueados por dependencias y una responsabilidad abierta. Un diagnóstico de catálogos también de sólo lectura confirmó exactamente uno de cada trigger canónico, ambos sobre `auth.users`, habilitados con `O`, `tgtype` 5/17, handlers correctos, lista `email` exacta y cero triggers inesperados. Por tanto, no existe deriva viva.

El tercer falso positivo procedía únicamente de los casts `::text` que `pg_get_triggerdef` añade al reconstruir `WHEN (((old.email)::text IS DISTINCT FROM (new.email)::text))`. La corrección aísla el texto entre ` when ` y ` execute function `, normaliza minúsculas, whitespace y paréntesis, elimina sólo el token literal `::text` y compara por igualdad con `old.emailisdistinctfromnew.email`. No elimina otros casts ni usa `LIKE`.

La cuarta ejecución remota del preflight corregido devolvió las 40 categorías y terminó con `ROLLBACK`: sus 35 categorías bloqueantes fueron cero y los conteos informativos de dependencias permanecieron no bloqueantes. Después se publicó la aplicación compatible y la migración 0008 terminó con `COMMIT`.

## Verificador transaccional

El verificador usa UUID aleatorios, correos `.invalid`, tablas/funciones `pg_temp`, grants temporales mínimos y termina con `ROLLBACK`. Los cambios de rol a `authenticated` conservan la evaluación real de RLS y RPC. No usa PII operativa. Su primera ejecución post-aplicación superó los controles estáticos y llegó a las fixtures, pero abortó en la línea 1670 de la versión ejecutada con `permission denied for function is_b1_account_admin`: el bloque evaluaba directamente el helper B.1 privado bajo `authenticated`. PostgreSQL devolvió el `42501` esperado por el ACL; el defecto pertenecía al arnés, no al esquema aplicado.

Su contrato estático comprueba por separado nombre, unicidad, relación, condición no interna, habilitación ordinaria, función por OID, evento/timing, granularidad por fila, ausencia de columnas/`WHEN` en el alta, lista exacta `email` y predicado semántico en la sincronización. Para el `WHEN` con `OLD` y `NEW` usa `pg_get_triggerdef`, no `pg_get_expr`. Una regresión sintética acepta la forma canónica con `::text` y rechaza operandos invertidos, igualdad, un término `AND true` y otra columna, sin tocar triggers persistentes. También rechaza triggers adicionales que invoquen cualquiera de los dos handlers. No usa una sola existencia agrupada mediante `IN (...)` para aceptar ambos objetos.

La autoridad B.1 se prueba en tres planos separados: (1) semántica del helper privado bajo el owner legítimo, donde `admin_exact` debe producir `true` y `admin_bad_scope`, `false`; (2) ACL cliente, donde una invocación directa bajo `authenticated` debe fallar exactamente con SQLSTATE `42501`; y (3) contratos públicos, donde las RPC B.1/B.2a `SECURITY DEFINER` deben autorizar o rechazar según la decisión del helper interno. El contrato estático exige propietario `postgres`, una única entrada `EXECUTE` owner sin grant option y ausencia de privilegio efectivo para `authenticated`, `anon` y `service_role`. La comprobación estática local busca cada bloque entre `SET LOCAL ROLE authenticated` y `RESET ROLE` y permite una sola llamada directa, protegida por la expectativa explícita de `42501`; no concede `EXECUTE` al cliente.

Los identificadores válidos se asignan con un allocator `pg_temp`: cada etiqueta obtiene una cadena decimal con cero inicial, se comprueba contra asignaciones previas del arnés y contra ambos tipos de identificador de `profiles`, y cualquier colisión hace avanzar el contador hasta encontrar un valor libre. No quedan literales válidos `0008...`. La identidad Google usa una clave de proveedor derivada del marcador de ejecución. Cada actividad sintética tiene UUID explícito en el contexto temporal y títulos legibles derivados del mismo marcador; ninguna fila se localiza por título.

La actividad programada ya no depende de `hoy + 1`: cada ejecución crea un semestre sintético único, activo y futuro, cuyo inicio queda después del mayor `ends_on` conocido más un margen seguro. La fecha fixture pertenece a ese rango y se resuelve por ID contra `get_academic_period_for_date`. Esto hace al arnés independiente de que la fecha real caiga dentro de un semestre o en un intersemestre; todo desaparece con el `ROLLBACK`.

Cobertura mínima numerada:

1. Usuario institucional activo conserva su acceso autorizado a actividades.
2. Administrador técnico activo conserva temporalmente A-02.
3. Cuenta inactiva con asignación vigente obtiene cero actividades por SELECT directo.
4. La misma cuenta obtiene cero participantes por SELECT directo.
5. La cuenta inactiva no inserta actividades.
6. La cuenta inactiva no actualiza ni elimina actividades.
7. La cuenta inactiva no inserta participantes.
8. La cuenta inactiva no actualiza ni elimina participantes.
9. Las lecturas RPC operativas de una cuenta inactiva no devuelven filas.
10. Los helpers booleanos devuelven false para cuenta inactiva.
11. Los helpers escalares temporales devuelven NULL para cuenta inactiva.
12. Una mutación RPC inactiva falla con 42501 y sitaa_operational_account_inactive.
13. Una cuenta pendiente recibe la misma barrera operativa.
14. Cambiar el fixture de activo a inactivo revoca acceso sin cambiar claims JWT.
15. Restaurar el fixture a activo recupera sólo su autorización preexistente.
16. La barrera no modifica asignaciones de rol.
17. La lectura mínima del perfil propio sigue disponible.
18. La lectura propia de asignaciones sigue disponible como estado/historia.
19. La finalización Google pendiente conserva su contrato.
20. El administrador exacto produce `true` en el helper privado como owner, recibe `42501` al invocarlo directamente como cliente y mantiene acceso al directorio mediante la RPC pública B.1.
21. Una asignación técnica mal formada produce `false` en el helper privado como owner y continúa denegada por los contratos públicos.
22. La privacidad de borradores continúa limitada al creador.
23. La privacidad del padrón de participantes continúa vigente.
24. Los flujos activos de asistencia y check-in conservan sus contratos.
25. Los catálogos de referencia conservan su lectura documentada.
26. Administrador exacto obtiene exactamente una fila de contexto B.2a para el objetivo solicitado, con `target_profile_id` correcto y `can_correct = true`.
27. Alumno/profesor ordinario recibe 42501 en contexto.
28. Administrador técnico mal formado recibe 42501.
29. Administrador inactivo recibe 42501.
30. Objetivo existente e inexistente son indistinguibles para actor no autorizado.
31. El propio administrador obtiene can_correct = false.
32. Objetivo pendiente obtiene can_correct = false.
33. Objetivo institucional activo puede ser elegible.
34. Objetivo institucional inactivo puede ser elegible.
35. Objetivo técnico activo o inactivo puede ser elegible.
36. Los conteos de dependencias son agregados y sin PII.
37. Administrador exacto corrige nombres institucionales estructurados.
38. Administrador exacto corrige identificador institucional.
39. Cambio de programa sin bloqueador tiene éxito.
40. Cambio de tipo de persona sin bloqueador tiene éxito.
41. Cuenta técnica admite sólo nombres.
42. Objetivo inactivo se corrige y permanece inactivo.
43. UUID, email, kind, estado, timestamps y vínculo Auth permanecen.
44. Las asignaciones permanecen byte por byte.
45. Actividades, participantes y asistencia permanecen.
46. full_name se deriva mediante el trigger existente.
47. Se preservan ceros iniciales del identificador.
48. Identificador duplicado se rechaza atómicamente.
49. Programa inválido o inactivo se rechaza atómicamente.
50. Nombres inválidos se rechazan atómicamente.
51. Identificador inválido se rechaza atómicamente.
52. Campos institucionales en solicitud técnica se rechazan.
53. Solicitud institucional incompleta se rechaza.
54. Autocorrección se rechaza.
55. Objetivo pendiente se rechaza.
56. Corrección sin cambios se rechaza.
57. Razón nula, vacía, corta o larga se rechaza.
58. Usuario ordinario no invoca la mutación.
59. Administrador mal formado no invoca la mutación.
60. Objetivo inexistente produce resultado genérico.
61. Cambio de persona se bloquea por asignación vigente.
62. Cambio de persona se bloquea por asignación futura.
63. Asignación histórica vencida/inactiva no bloquea.
64. Cambio a alumno se bloquea por responsabilidad abierta.
65. Cambio de programa se bloquea por asignación de otro programa.
66. Cambio de programa se bloquea por asignación de otra división.
67. Cambio de programa se bloquea por responsabilidad abierta incompatible.
68. Cambio de programa se bloquea por participación abierta incompatible.
69. Responsabilidad/participación histórica finalizada no bloquea.
70. Cambio sólo de nombre no queda bloqueado por dependencias.
71. Cambio sólo de identificador no queda bloqueado por dependencias.
72. Cada corrección exitosa crea exactamente un evento.
73. El evento usa account_identity_corrected.
74. El outcome es success.
75. La razón se normaliza sin truncarse.
76. Actor y objetivo son exactos.
77. role_assignment_id queda NULL.
78. Metadata contiene sólo changed_fields ordenado.
79. Metadata no contiene valores, email, roles ni actividad.
80. Un rechazo no crea auditoría.
81. La proyección B.1 muestra la acción sin metadata cruda.
82. El evento sigue siendo append-only.
83. Autoservicio de perfil continúa limitado a nombres estructurados.
84. Firmas y ACL B.1 permanecen.
85. Registro Google y sincronización de email permanecen.
86. Triggers Auth existentes permanecen.
87. Contratos acumulados 0002–0007 permanecen.
88. No aparece campo/código de Fase C.
89. No aparece auth.admin ni cliente service-role en aplicación.
90. El ROLLBACK elimina fixtures y grants temporales.
91. `requested_person_type = NULL` en una cuenta institucional produce `sitaa_identity_invalid_person_type` sin cambios ni auditoría.
92. Un nombre técnico derivado de un solo carácter produce `sitaa_identity_invalid_name` antes del `UPDATE`.
93. Nombres y razón colapsan tabs, saltos de línea y espacios repetidos antes de recortar extremos y convertir vacío en `NULL`.
94. Un cambio aparente que sólo agrega whitespace exterior es `sitaa_identity_no_changes`.
95. Ningún rechazo de validación filtra nombres de restricciones `CHECK` ni crea auditoría.
96. El semestre sintético se resuelve por su ID y la actividad programada conserva ese mismo ID y fecha.
97. RLS está activa en las cinco tablas requeridas.
98. Las tres funciones nuevas conservan nombres, tipos y orden exactos de entradas y salidas para PostgREST.
99. Cada función nueva tiene exactamente dos entradas `EXECUTE` no delegables: owner y `authenticated`.
100. La mutación captura `auth.uid()` una sola vez, autoriza de forma optimista, rechaza autocorrección y contiene en orden locks `SHARE` sobre `role_assignments`, `activities` y `activity_participants`.
101. `add_activity_participant` toma primero `ROW EXCLUSIVE` sobre su tabla y después relee el perfil con `FOR SHARE`.
102. La razón normalizada se persiste sin whitespace exterior.
103. La corrección normalizada exitosa registra únicamente los nombres esperados en `changed_fields`.
104. El ACL y RLS exactos de `admin_audit_events` permanecen inalterados.
105. El dominio de hash del rollback usa `md5(btrim(regexp_replace(lower(p.prosrc), '\s+', ' ', 'g')))` para las 29 restauraciones.
106. `get_activity_participants(uuid)` para cuenta inactiva falla exactamente con `42501` y `sitaa_operational_account_inactive` fuera de cualquier expresión booleana.
107. El mismo RPC para el alumno activo participante falla exactamente con `42501` y el mensaje estable de privacidad del padrón.
108. Todos los identificadores válidos de registro o mutación provienen del allocator libre de colisiones y preservan cero inicial.
109. La identidad Google y todas las actividades fixture están namespaced por ejecución; no existe lookup por título fijo.
110. El `INSERT` directo de participante queda denegado, la adición RPC incompatible se rechaza y la compatible tiene éxito.
111. Una escritura directa de actividad no puede sustituir creador/responsable y un cambio de alcance no puede dejar participantes incompatibles.
112. El trigger de escritor relee perfiles participantes con `FOR SHARE`; `add_activity_participant` mantiene su lock/relectura y la corrección conserva el orden fijo de locks.
113. El guard predestructivo del rollback verifica inventario, políticas, firmas/salidas, hashes y ACL de las 29 rutinas, trigger de escritor, barrera activa y contrato físico/ACL de auditoría antes de cambiar objeto alguno.
114. Con actor activo, `activity_has_ended` devuelve false para borrador, true para actividad terminada y NULL para UUID inexistente.
115. Con actor inactivo, `activity_has_ended` devuelve false tanto para UUID existente como inexistente y no filtra existencia.
116. Una actividad histórica compatible admite que su participante y responsable primario cambien de programa/tipo mediante la corrección auditada.
117. La incompatibilidad histórica resultante no satisface el predicado abierto ni convierte el preflight en bloqueo.
118. Un `UPDATE` autenticado que mueve esa actividad histórica al futuro falla exactamente con `23514` y `sitaa_activity_reopen_forbidden`.
119. El rechazo anterior deja todos los campos de actividad e identidad intactos y no agrega auditoría.
120. Una actividad compatible todavía abierta puede actualizar campos permitidos de horario.
121. Un cambio abierto de alcance/programa con participante incompatible se rechaza.
122. El cuerpo del trigger inspecciona `status_code`, fechas/horas separadas y `starts_at`/`ends_at`, y revalida participantes más responsabilidad primaria en cualquier reapertura confiable.
123. La responsabilidad primaria no exige universalmente profesor; el requisito permanece sólo en el rol participante `responsible`.
124. Los cuatro cuerpos nuevos coinciden exactamente con `md5(regexp_replace(prosrc,'\s+','','g'))` en migración, verificador y rollback.
125. El inventario final es exactamente 51 funciones, 11 triggers y 25 políticas, sin modificar tablas, columnas, restricciones, índices o semillas.
126. `authenticated` tiene sólo `SELECT` directo sobre `activity_participants`; owner y `service_role` conservan sus ocho privilegios, `attacl` está vacío, cada fila de `column_privileges` deriva de los grants de tabla admitidos, no hay grant option y los totales exactos son 132/267/6/440.
127. La aplicación compatible conserva tipos completos, carga opcional de contexto, autoridad B.1 independiente, NULL reales para identidad técnica, errores controlados y un formulario accesible sin PII en URL o `localStorage`.
128. El verificador concede temporalmente `UPDATE(attendance_notes)` a `authenticated`, demuestra que aparece en `attacl`, que la fila `UPDATE` de `column_privileges` no está explicada por el ACL de tabla y que el privilegio efectivo excede al de tabla; después lo revoca y confirma la proyección legítima antes de crear fixtures.
129. Actor y objetivo se bloquean juntos mediante `ORDER BY profile.id FOR UPDATE`; la segunda comprobación exacta B.1 ocurre después de todos los locks y antes de cargar, validar o modificar el objetivo.

El verificador también compara hashes normalizados de `prosrc` para las 29 rutinas reemplazadas y, en un dominio exacto independiente y uniforme, para las cuatro funciones nuevas; conserva el ACL exacto de esas rutinas, las dos políticas restrictivas y el inventario estructural y de privilegios sin delta no autorizado.

## Protocolo de locks y prueba manual en dos sesiones

La mutación captura al actor una sola vez y lo autoriza primero. Rechaza autocorrección antes de locks amplios; adquiere siempre `SHARE` en este orden: `role_assignments`, `activities`, `activity_participants`; luego bloquea actor y objetivo en una sola consulta ordenada por UUID. Sólo entonces repite la autoridad B.1 exacta, carga el objetivo, relee el programa, evalúa dependencias, actualiza e inserta auditoría. Las escrituras normales toman `ROW EXCLUSIVE`, incompatible con `SHARE`, por lo que no atraviesan la decisión. `add_activity_participant` adelanta explícitamente su `ROW EXCLUSIVE` y relee el perfil con `FOR SHARE` antes de validar e insertar.

### Matriz completa de escritores de dependencias

| Tabla | Privilegios directos | Políticas DML | Escritores soportados | Invariantes y revalidación |
|---|---|---|---|---|
| `role_assignments` | `authenticated`: sólo `SELECT`; `postgres`/`service_role` conservan ACL post-0007 | No hay `INSERT/UPDATE/DELETE` para cliente | Ningún writer de aplicación en B.2a; Fase C queda pendiente | La corrección toma `SHARE`. Todo writer futuro de Fase C deberá tomar el lock incompatible y revalidar perfil, alcance, vigencia y autoridad después de esperar. |
| `activities` | `authenticated`: `SELECT/INSERT/UPDATE/DELETE` | Políticas permisivas existentes más barrera restrictiva de cuenta activa | Server Actions de crear, editar y eliminar; trigger de publicación; roles privilegiados heredados | El trigger B.2a exige creador/responsable propios al insertar, los hace inmutables, revalida `can_create_activity` si cambia alcance/servicio, relee con `FOR SHARE` los perfiles participantes al cambiar alcance abierto y rechaza toda transición autenticada de histórica a abierta. Un writer confiable que reabra debe revalidar participantes y responsabilidad primaria. |
| `activity_participants` | `authenticated`: sólo `SELECT`; DML directo revocado en tabla y `attacl` vacío | Las políticas heredadas permanecen, pero ya no conceden por sí solas capacidad de escritura | `add_activity_participant`, `remove_activity_participant`, actualización manual/masiva y check-in; triggers de asistencia | `add_activity_participant` bloquea la tabla en `ROW EXCLUSIVE` y relee el perfil `FOR SHARE`; los demás RPC sólo alteran asistencia o eliminan filas. Preflight y guardas exactas aceptan la proyección por columna derivada de la tabla, pero rechazan `attacl`, grantees inesperados, grant option o acceso efectivo que exceda el ACL de tabla. |

No existe cliente `service_role` en la aplicación. Los privilegios persistentes de `postgres`/`service_role` son superficies confiables fuera del flujo cliente; no se declaran escritores administrativos nuevos. El diseño de Fase C deberá adoptar el mismo protocolo antes de habilitar mutaciones de roles.

Prueba manual futura, no ejecutada en esta preparación:

| Caso | Sesión A | Sesión B | Resultado esperado |
|---|---|---|---|
| 1 | Corrección de tipo/programa | `INSERT` de asignación | Se serializa; o se observa y rechaza la dependencia, o el escritor espera y revalida. |
| 2 | Corrección de tipo/programa | `INSERT`/`UPDATE` de actividad | Mismo resultado serializado. |
| 3 | Corrección de tipo/programa | `add_activity_participant` | Mismo resultado; el writer relee el perfil tras esperar. |
| 4 | Escritura de dependencia inicia primero | Corrección | La corrección espera, observa la fila confirmada y rechaza si es incompatible. |
| 5 | Corrección inicia primero | Escritura de dependencia | El writer espera y valida contra la identidad ya corregida. |

No se afirmará verificación concurrente en PostgreSQL hasta ejecutar esta matriz coordinada.

### Autoridad administrativa: cuatro pruebas manuales de dos sesiones

Estas pruebas siguen pendientes. Deben ejecutarse exclusivamente en una base PostgreSQL local desechable, una rama/proyecto Supabase desechable u otro clon aislado que se restaure o descarte por completo al terminar. Nunca se ejecutan en producción. Cada escenario usa perfiles, asignaciones y objetivos sintéticos, y parte de un administrador B.1 exacto activo, un objetivo distinto y cero eventos `account_identity_corrected` para ese objetivo.

1. **La revocación de rol inicia primero.** Sesión A abre transacción, revoca la asignación sintética `technical_admin/system/technical` del actor y pausa antes de confirmar. Sesión B abre transacción e invoca la corrección; debe esperar en `role_assignments IN SHARE MODE`. Sesión A confirma primero. Sesión B continúa, bloquea ambos perfiles y falla en la segunda autorización con `42501 / sitaa_admin_access_denied`; después revierte. El perfil objetivo queda idéntico y el conteo de auditoría permanece en cero.

2. **La corrección inicia antes que la revocación.** Sesión A abre transacción, invoca la corrección y pausa antes de confirmar, conservando sus locks. Sesión B intenta revocar la asignación y debe esperar. Sesión A confirma primero: el objetivo contiene la identidad corregida y existe exactamente un evento. Sesión B continúa y confirma la revocación después.

3. **La desactivación del actor inicia primero.** Sesión A abre transacción, cambia el perfil sintético del actor a inactivo y pausa reteniendo su row lock. Sesión B invoca la corrección: puede adquirir los locks de dependencias, pero debe esperar al bloquear conjuntamente actor y objetivo. Sesión A confirma primero. Sesión B continúa y falla en la segunda autorización con `42501 / sitaa_admin_access_denied`; después revierte. El objetivo no cambia y no aparece auditoría.

4. **La corrección inicia antes que la desactivación.** Sesión A invoca la corrección dentro de una transacción y pausa antes de confirmar, reteniendo el lock del actor. Sesión B intenta desactivar al actor y debe esperar. Sesión A confirma primero bajo autoridad todavía válida: el perfil objetivo cambia y se crea exactamente un evento. Sesión B continúa y confirma la desactivación.

La limpieza de los escenarios confirmados consiste únicamente en descartar o restaurar el entorno desechable completo. Está prohibido borrar eventos append-only, deshabilitar sus triggers, usar `session_replication_role`, retirar FK/restricciones o eliminar perfiles actor/objetivo referenciados. Los casos rechazados pueden revertir su transacción, pero su preparación confirmada también se mantiene aislada salvo que exista una ruta de limpieza íntegra y documentada. Los smoke tests de producción usan cuentas ya controladas y no crean correcciones desechables para medir locks. Si no existe un entorno desechable, estas pruebas se registran como **no ejecutadas** y no se afirma verificación concurrente en PostgreSQL.

Dos administradores que intenten corregirse mutuamente bloquean los mismos dos UUID mediante una sola consulta `ORDER BY profile.id FOR UPDATE`; uno espera al otro, pero no se forma un ciclo de locks por adquirir primero “su propia” fila. Este resultado también permanece pendiente de ejecución manual en PostgreSQL.

## Evidencia de aplicación compatible

La inspección local coordinada con la aplicación de 0008 confirmó, sin modificar archivos correctos:

- `types/admin.ts`: contexto, entrada, resultado y unión completa de errores de corrección;
- detalle de cuenta: contexto opcional, acción sólo cuando `can_correct` y alerta de éxito;
- página de identidad: autenticación, autoridad B.1 exacta, bloqueos de autocorrección/pendiente y valores iniciales;
- Server Action: autenticación y autorización independientes, recarga de contexto, NULL SQL reales para persona/identificador/programa técnico, RPC, revalidación y redirect;
- formulario: confirmación de fuente, ayuda/límites de razón, conservación de valores rechazados, resumen accesible y foco del primer campo inválido;
- cliente de corrección: argumentos RPC nominales y mapeo de errores controlados;
- ausencia de PII en URL y `localStorage`.

## Estado de la aplicación compatible y pruebas pendientes

La aplicación compatible fue publicada antes de aplicar 0008. La aceptación operativa de B.2a todavía requiere reejecutar el verificador corregido y completar los smoke tests siguientes:

1. `/admin/accounts` y el detalle B.1 siguen funcionando.
2. El detalle carga el contexto B.2a sin exponer errores crudos.
3. Acceso autorizado a `/admin/accounts/[id]/identity` respeta elegibilidad, autocorrección y estado de cuenta.
4. No se propaga texto crudo de Supabase/PostgreSQL.
5. Un administrador no exacto no obtiene controles.
6. La acción reautoriza, reconsulta contexto y usa sólo el RPC de mutación.
7. Error de campo conserva valores, muestra resumen y enfoca el primer campo inválido.
8. Éxito redirige al detalle, refresca datos y muestra `Identidad corregida`.

## Contrato de rollback

El rollback:

- exige el contrato completo 0008 antes de su primera operación destructiva, incluidos el ACL exacto de tabla, `attacl` vacío, la proyección table-derived exacta y el acceso efectivo correspondiente, los 29 hashes operativos, los cuatro hashes nuevos, el protocolo de doble autorización de la corrección, el trigger de escritores, los totales de privilegios y `admin_audit_events`;
- no crea, elimina, renombra ni reemplaza los triggers Auth `on_sitaa_auth_user_created` y `on_sitaa_auth_user_email_changed`; el rollback de 0008 no tiene lógica destructiva sobre `auth.users`;
- elimina las dos políticas restrictivas, las dos RPC B.2a y el trigger/helper de escritores;
- restaura `INSERT/UPDATE/DELETE` de `authenticated` sobre `activity_participants` exactamente como en post-0007 y comprueba que no introdujo ACL de columna;
- restaura las 29 definiciones y ACL exactos post-0007;
- elimina al final el helper de cuenta activa;
- no usa borrado en cascada;
- no modifica tablas, historia operativa ni `admin_audit_events`;
- no reconstruye valores de identidad anteriores;
- conserva correcciones válidas y sus eventos append-only;
- finaliza con `COMMIT` sólo tras verificar el estado exacto post-0007.
- verifica los 29 cuerpos restaurados en el mismo dominio de hash normalizado de `prosrc` usado por el preflight post-0007, con una regresión explícita sobre `activity_attendance_deadline(uuid)`.

## Estado de la secuencia coordinada

1. Preflight 0008: aprobado, con `ROLLBACK` y 35 bloqueos en cero.
2. Aplicación compatible: publicada.
3. Migración 0008: aplicada con `COMMIT`; artefacto inmutable.
4. Primera ejecución del verificador: abortada y descartada por la llamada cliente inválida al helper owner-only.
5. Reejecutar el verificador corregido y confirmar su `ROLLBACK`: pendiente.
6. Ejecutar smoke tests: pendiente.
7. Regenerar el snapshot completo: pendiente.
8. Reconciliar 0001–0008 y cerrar B.2a canónicamente: pendiente.

Esta corrección local no reejecuta el verificador ni realiza ninguna operación remota.

