# Plan de pruebas de la migración 0008

## Estado y alcance

`0008_operational_account_barrier_identity_correction.sql` está preparada localmente y **no aplicada**. Este plan valida la barrera operativa de cuenta activa y la corrección administrativa de identidad de Fase B.2a. No autoriza conexión ni ejecución contra Supabase.

Inventario esperado después de aplicar 0008: 18 tablas, 165 columnas, 80 restricciones, 43 índices, 10 triggers públicos, 50 funciones, 25 políticas y 51 semillas. El delta de privilegios de rutina esperado es seis entradas ACL: propietario y `authenticated` para cada una de las tres funciones nuevas; no cambia grants de tablas.

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
- informa sólo conteos agregados de dependencias potenciales;
- no expone nombres, correos, identificadores, UUID ni filas operativas.
- exige RLS activa en `profiles`, `role_assignments`, `activities`, `activity_participants` y `admin_audit_events`;
- bloquea huérfanos Auth/profile, deriva de las FK exactas y asignaciones con usuario huérfano;
- verifica por separado identidad institucional/técnica activa o inactiva, ciclo de vida, políticas propias y el RLS/ACL exacto de la auditoría.

Todos los bloqueos se repiten dentro de la migración antes del DDL.

## Verificador transaccional

El verificador usa UUID aleatorios, correos `.invalid`, tablas/funciones `pg_temp`, grants temporales mínimos y termina con `ROLLBACK`. Los cambios de rol a `authenticated` conservan la evaluación real de RLS y RPC. No usa PII operativa.

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
20. El administrador exacto B.1 mantiene acceso al directorio.
21. Una asignación técnica mal formada continúa denegada.
22. La privacidad de borradores continúa limitada al creador.
23. La privacidad del padrón de participantes continúa vigente.
24. Los flujos activos de asistencia y check-in conservan sus contratos.
25. Los catálogos de referencia conservan su lectura documentada.
26. Administrador exacto obtiene el contexto B.2a.
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
100. La mutación contiene, en orden, locks `SHARE` sobre `role_assignments`, `activities` y `activity_participants`, antes del perfil objetivo.
101. `add_activity_participant` toma primero `ROW EXCLUSIVE` sobre su tabla y después relee el perfil con `FOR SHARE`.
102. La razón normalizada se persiste sin whitespace exterior.
103. La corrección normalizada exitosa registra únicamente los nombres esperados en `changed_fields`.
104. El ACL y RLS exactos de `admin_audit_events` permanecen inalterados.
105. El dominio de hash del rollback usa `md5(btrim(regexp_replace(lower(p.prosrc), '\s+', ' ', 'g')))` para las 29 restauraciones.

El verificador también compara hashes normalizados de `prosrc` para las 29 rutinas reemplazadas, el ACL exacto de esas rutinas, las propiedades/ACL de las tres nuevas funciones, las dos políticas restrictivas y el inventario estructural sin delta no autorizado.

## Protocolo de locks y prueba manual en dos sesiones

La mutación autoriza primero y adquiere siempre `SHARE` en este orden: `role_assignments`, `activities`, `activity_participants`; después bloquea el perfil, relee el programa, evalúa dependencias, actualiza e inserta auditoría. Las escrituras normales toman `ROW EXCLUSIVE`, incompatible con `SHARE`, por lo que no atraviesan la decisión. `add_activity_participant` adelanta explícitamente su `ROW EXCLUSIVE` y relee el perfil con `FOR SHARE` antes de validar e insertar.

Prueba manual futura, no ejecutada en esta preparación:

| Caso | Sesión A | Sesión B | Resultado esperado |
|---|---|---|---|
| 1 | Corrección de tipo/programa | `INSERT` de asignación | Se serializa; o se observa y rechaza la dependencia, o el escritor espera y revalida. |
| 2 | Corrección de tipo/programa | `INSERT`/`UPDATE` de actividad | Mismo resultado serializado. |
| 3 | Corrección de tipo/programa | `add_activity_participant` | Mismo resultado; el writer relee el perfil tras esperar. |
| 4 | Escritura de dependencia inicia primero | Corrección | La corrección espera, observa la fila confirmada y rechaza si es incompatible. |
| 5 | Corrección inicia primero | Escritura de dependencia | El writer espera y valida contra la identidad ya corregida. |

No se afirmará verificación concurrente en PostgreSQL hasta ejecutar esta matriz coordinada.

## Pruebas de aplicación compatibles antes de aplicar 0008

1. `/admin/accounts` y el detalle B.1 siguen funcionando.
2. Si PostgREST reporta que el RPC de contexto no existe, se omite la acción en el detalle.
3. Acceso directo a `/admin/accounts/[id]/identity` muestra un estado español controlado de migración pendiente.
4. No se propaga texto crudo de Supabase/PostgreSQL.
5. Un administrador no exacto no obtiene controles.
6. La acción reautoriza, reconsulta contexto y usa sólo el RPC de mutación.
7. Error de campo conserva valores, muestra resumen y enfoca el primer campo inválido.
8. Éxito redirige al detalle, refresca datos y muestra `Identidad corregida`.

## Contrato de rollback

El rollback:

- exige que el contrato completo 0008 exista;
- elimina las dos políticas restrictivas y las dos RPC B.2a;
- restaura las 29 definiciones y ACL exactos post-0007;
- elimina al final el helper de cuenta activa;
- no usa borrado en cascada;
- no modifica tablas, historia operativa ni `admin_audit_events`;
- no reconstruye valores de identidad anteriores;
- conserva correcciones válidas y sus eventos append-only;
- finaliza con `COMMIT` sólo tras verificar el estado exacto post-0007.
- verifica los 29 cuerpos restaurados en el mismo dominio de hash normalizado de `prosrc` usado por el preflight post-0007, con una regresión explícita sobre `activity_attendance_deadline(uuid)`.

## Secuencia futura coordinada

1. Aprobar el preflight 0008.
2. Publicar la aplicación compatible.
3. Aplicar 0008 manualmente.
4. Ejecutar este verificador y confirmar `ROLLBACK`.
5. Ejecutar smoke tests.
6. Regenerar el snapshot completo.
7. Reconciliar 0001–0008.
8. Cerrar B.2a canónicamente.

Nada de esa secuencia remota se ejecuta en la preparación local.

