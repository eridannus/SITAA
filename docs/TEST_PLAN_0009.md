# Plan de pruebas de la migración 0009

## Estado y alcance

`0009_admin_account_lifecycle_transitions.sql` está preparada localmente y no aplicada. Este plan valida la desactivación/reactivación auditada por administradores B.1 exactos. No administra Auth, no revoca sesiones físicas, no modifica asignaciones y no implementa roles V2.

Orden manual obligatorio: ejecutar el preflight de sólo lectura, revisar sus 19 categorías bloqueantes y 7 informativas (26 filas siempre presentes, incluso cuando un bloqueo vale cero), desplegar la aplicación compatible, aplicar la migración, ejecutar el verificador transaccional, realizar smoke tests y finalmente regenerar/reconciliar el snapshot.

La revisión previa a aplicación corrigió el handler canónico del trigger de correo a `sync_sitaa_profile_email_from_auth()`, preservó exactamente los `UPDATE` de columna de `authenticated` sobre `first_names`, `paternal_surname` y `maternal_surname`, y mantuvo denegados los campos de identidad y ciclo de vida protegidos. Los contratos usan mapas/hashes exactos post-0008 para impedir sustituciones que conserven sólo los conteos. El conjunto controlado de once catálogos contiene exactamente 51 filas y usa el hash canónico `2e450238768fbe9889470864a1832486`; se comprueba en preflight independiente, preflight embebido, guarda posterior al DDL, verificador y las dos guardas del rollback.

Los cuatro artefactos abren su transacción y fijan localmente `TimeZone = UTC` y `DateStyle = ISO, MDY` antes de calcular evidencia textual. Estos valores desaparecen al terminar la transacción y sirven exclusivamente para hacer reproducibles los JSON y hashes de catálogos: no alteran la fecha institucional B.1, las fronteras de actividad en `America/Mexico_City` ni la semántica de los `timestamptz` de ciclo de vida.

### Evidencia del preflight y del primer intento de migración

La primera ejecución remota del preflight 0009 fue estrictamente de sólo lectura: devolvió sus 26 filas, terminó con `ROLLBACK` y código de salida 0, pero no fue aprobada porque `audit_action_code_incompatible`, `post_0001_0008_object_contract_drift`, `post_0008_inventory_drift` y `post_0008_privilege_drift` resultaron distintas de cero. Una transacción diagnóstica posterior también fue de sólo lectura y terminó con `ROLLBACK`; no aplicó la migración ni modificó objetos o datos.

El diagnóstico confirmó los inventarios post-0008 de 18 tablas, 165 columnas, 80 restricciones, 43 índices, 11 triggers públicos, 51 funciones, 25 políticas, 18 tablas con RLS, 132 grants de rutina, 267 de tabla, 440 ACL expandidas y 51 semillas controladas, además de los hashes canónicos de columnas, índices, firmas/cuerpos de función, políticas y semillas. Los bloqueos fueron falsos positivos del arnés: restricciones y mapa público de triggers se comparaban con el modo no pretty; los privilegios de secuencia se contaban mediante una vista que sólo reflejaba `USAGE`; el mapa de grants de `authenticated` conservaba el hash anterior a 0008; y el constraint de acciones se comparaba contra la representación no pretty.

La corrección alineó restricciones con `pg_get_constraintdef(oid, true)`, el mapa agregado de triggers con `pg_get_triggerdef(oid, true)`, las seis ACL de `system_health_id_seq` con `pg_class`/`aclexplode` y los diecinueve grants de tabla de `authenticated` con `information_schema.table_privileges`. El parser especializado del `WHEN` del trigger Auth conserva `pg_get_triggerdef(oid, false)`. La reejecución corregida devolvió las 26 filas, dejó en cero las 19 categorías bloqueantes, terminó con `ROLLBACK` y `psql` salió correctamente; el preflight independiente quedó aprobado.

La aplicación compatible B.2b se desplegó antes del intento de migración. La primera ejecución de 0009 falló mientras PostgreSQL compilaba el `DO $preflight$` embebido: una rama abría un `EXISTS` exterior para comprobar `is_b1_account_admin()` y no lo cerraba antes del siguiente `UNION ALL`. Sólo se alcanzaron `BEGIN` y los dos `SET LOCAL`; no se envió ni ejecutó el primer `CREATE FUNCTION`, no se creó ningún objeto 0009, no se alcanzaron `REVOKE`, `GRANT`, guarda post-DDL o `COMMIT`, y la transacción fallida se descartó. No fue necesario ni se ejecutó el rollback. El artefacto quedó corregido localmente y su nueva ejecución permanece pendiente.

## Contrato automatizado y transaccional

1. Preflight termina en `ROLLBACK`.
2. Migración termina en `COMMIT`.
3. Verificador termina en `ROLLBACK`.
4. Rollback termina en `COMMIT`.
5. El estado previo contiene 18 tablas.
6. El estado previo contiene 165 columnas.
7. El estado previo contiene 80 restricciones.
8. El estado previo contiene 43 índices.
9. El estado previo contiene 11 triggers públicos.
10. El estado previo contiene 51 funciones públicas.
11. El estado previo contiene 25 políticas.
12. RLS está habilitado en 18 tablas.
13. Existen 132 grants de rutina antes de 0009.
14. Existen 267 grants de tabla antes de 0009.
15. Existen 6 grants de secuencia antes de 0009.
16. Existen 440 entradas ACL expandidas antes de 0009.
17. Los tres objetos 0009 no existen en el preflight.
18. Existe la autoridad B.1 canónica.
19. Existe la frontera temporal canónica de actividades.
20. El constraint de `action_code` admite los dos códigos nuevos.
21. Sólo se crean tres funciones.
22. No se crea ni altera ninguna tabla.
23. No se crea ni altera ninguna columna.
24. No se crea ni altera ninguna política RLS.
25. El helper exacto devuelve `boolean`.
26. El helper exacto es `STABLE SECURITY DEFINER`.
27. El contexto tiene la firma y orden de columnas aprobados.
28. El contexto es `STABLE SECURITY DEFINER`.
29. La mutación tiene la firma y nombres de parámetros aprobados.
30. La mutación es `VOLATILE SECURITY DEFINER`.
31. Las tres funciones fijan `search_path = pg_catalog, public`.
32. `PUBLIC` no ejecuta ninguna función 0009.
33. `anon` no ejecuta ninguna función 0009.
34. `service_role` no ejecuta ninguna función 0009.
35. `authenticated` no ejecuta el helper privado.
36. `authenticated` ejecuta sólo contexto y mutación.
37. Ningún grant delegado usa `WITH GRANT OPTION`.
38. El inventario posterior contiene 54 funciones.
39. El inventario posterior contiene 137 grants de rutina.
40. El inventario posterior contiene 445 entradas ACL expandidas.
41. Un usuario ordinario no consulta el contexto.
42. Un usuario ordinario no ejecuta la mutación.
43. Un administrador B.1 exacto consulta el contexto.
44. Un alcance B.1 no exacto no autoriza.
45. Un perfil administrativo inactivo no autoriza.
46. Un objetivo inexistente produce cero filas en contexto.
47. Un objetivo propio recibe `self_forbidden`.
48. Un objetivo pendiente recibe `pending_target`.
49. Un objetivo activo válido sólo puede desactivarse.
50. Un objetivo inactivo válido sólo puede reactivarse.
51. Una identidad inactiva inválida recibe `invalid_identity`.
52. Un Auth no confirmado recibe `auth_unconfirmed`.
53. Los duplicados de asignación B.1 cuentan un solo perfil.
54. La guarda de conteo del último administrador se conserva como defensa en profundidad; bajo autoridad canónica, una cuenta distinta autorizada implica al menos dos administradores exactos activos y el caso de una sola cuenta se intercepta antes como transición propia.
55. El conteo de asignaciones incluye vigentes y futuras no vencidas.
56. El conteo de responsabilidades usa la frontera 0008.
57. El conteo de participaciones usa la frontera 0008.
58. Las dependencias son advertencias y no bloquean desactivación.
59. Sólo se aceptan `deactivate` y `reactivate`.
60. El motivo colapsa todo whitespace y se recorta.
61. Un motivo menor de 10 caracteres se rechaza.
62. Un motivo mayor de 1000 caracteres se rechaza.
63. La mutación propia se rechaza antes de consultar el objetivo.
64. La mutación toma el advisory lock `(1397310529, 9002)`.
65. La mutación bloquea `role_assignments` en `SHARE`.
66. La fila `auth.users` objetivo se bloquea antes de perfiles.
67. Actor, objetivo y candidatos B.1 se bloquean juntos por UUID.
68. La autoridad B.1 se revalida después de todos los locks.
69. Desactivar cambia exactamente estado, bandera y `deactivated_at`; devuelve el UUID exacto y el `updated_at` persistido.
70. Desactivar conserva `activated_at` byte por byte y establece `deactivated_at`.
71. Reactivar cambia exactamente estado, bandera y `deactivated_at`; devuelve el UUID exacto y el `updated_at` persistido.
72. Reactivar conserva `activated_at` byte por byte y limpia `deactivated_at`.
73. Reactivar exige identidad coherente y programa institucional activo.
74. Reactivar exige correspondencia Auth/profile y correo confirmado.
75. Una transición exitosa conserva asignaciones y datos operativos.
76. Una transición exitosa inserta exactamente un evento append-only.
77. El evento usa `account_deactivated` o `account_reactivated`.
78. El evento usa motivo normalizado y `role_assignment_id = NULL`.
79. La metadata contiene exclusivamente `changed_fields` en orden aprobado.
80. Un rechazo no inserta auditoría.
81. El detalle B.1 muestra los eventos sin exponer metadata.
82. El rollback elimina sólo las tres funciones y conserva datos/eventos.
83. El rollback recupera exactamente el contrato post-0008.
84. Cada intervalo `SET LOCAL ROLE authenticated` tiene su `RESET ROLE`; en esas fases sólo se usan RPC públicas, objetos `pg_temp` concedidos y pruebas negativas protegidas.
85. Las lecturas crudas de perfiles, Auth, asignaciones, actividades, participantes y auditoría se ejecutan exclusivamente como owner.
86. La única llamada cliente al helper exacto privado es una prueba protegida que exige SQLSTATE `42501`; `authenticated` no recibe `EXECUTE`.
87. Antes de crear fixtures se captura el conjunto y conteo de administradores B.1 exactos activos vivos, sin mostrarlos ni modificarlos.
88. Los conteos sintéticos son relativos: línea base + 2, línea base + 1 tras desactivar B y línea base + 2 tras restaurarlo.
89. Cada fixture institucional obtiene un identificador numérico con cero inicial mediante un allocator `pg_temp`, con reuso determinista y comprobación contra fixtures previos y ambos tipos de identificador vivos.
90. La reactivación institucional bloquea el programa con `FOR SHARE`, exige que exista y permanezca activo y reutiliza ese resultado en la validación autoritativa.
91. La secuencia de locks es advisory de ciclo, `role_assignments` en `SHARE`, Auth objetivo, perfiles ordenados por UUID, segunda autorización, programa institucional en `FOR SHARE`, validación, actualización y auditoría.
92. Los diagnósticos informativos de dependencias abiertas usan directamente la frontera temporal pura 0008, sin depender de JWT ni de `activity_has_ended(uuid)`.
93. Las seis superficies SQL exigen los cardinales exactos de los once catálogos, 51 filas totales y el hash canónico; 0009 introduce delta cero de semillas.
94. El cuerpo normalizado de la mutación usa MD5 `7f940968051ff1b844443f6c76b561c3`; el mapa agregado de 54 funciones posteriores usa `71f9763d702e95e4eede51a4a4611694`.
95. Migración, preflight, verificador y rollback fijan `UTC` y `ISO, MDY` con `SET LOCAL` inmediatamente después de abrir su transacción y antes del primer hash de semillas.
96. Las tres funciones nuevas deben pertenecer exactamente a `postgres`; una ejecución bajo otro owner aborta la migración antes de `COMMIT`, sin reparación automática.
97. Ninguna entrada ACL de las tres funciones puede usar grant option, incluida la entrada del owner.
98. El helper privado tiene exactamente una entrada `EXECUTE` para su owner; contexto y mutación tienen exactamente dos, para owner y `authenticated`.
99. La guarda post-DDL, el verificador y la guarda predestructiva del rollback aplican el mismo contrato exacto de owner, grantees, cardinalidad y ausencia de grant option.
100. Los seis mapas completos de restricciones usan la representación pretty canónica y conservan el hash `64f099164063d0cf500478dda3b5d25c`.
101. Los seis mapas agregados de triggers públicos usan representación pretty y conservan `67ee47bcd43c0594129facf3d7729bad`; los seis parsers especializados Auth siguen usando el modo no pretty controlado.
102. Las ACL de secuencia coinciden bidireccionalmente con las seis filas canónicas de `system_health_id_seq`, sin otra secuencia, rol, privilegio, concedente ni grant option.
103. Los grants de tabla de `authenticated` coinciden con diecinueve filas y el hash `edbb0931514cafe989d3d345c4ea61d6`; `activity_participants` conserva sólo `SELECT` y `profiles` no tiene `UPDATE` de tabla.
104. Los tres `UPDATE` de nombres estructurados permanecen exclusivamente en ACL de columna.
105. `admin_audit_events_action_code_check` existe una sola vez, está validada, pertenece a `action_code`, usa la definición pretty canónica y acepta los dos códigos B.2b.
106. El checker extrae y valida individualmente los 5 cuerpos dollar-quoted de la migración, los 35 del verificador y los 2 del rollback, además del balance léxico global del preflight independiente.
107. La regresión negativa reproduce un `$preflight$` con el `EXISTS` exterior sin cerrar y debe ser rechazada; la regresión positiva con el cierre correcto debe aprobar.
108. La auditoría por cuerpo verifica paréntesis, corchetes, literales, comentarios y delimitadores sin interpretar como estructura los caracteres contenidos en strings SQL.

El verificador automatiza los contratos estructurales, ACL, autorizaciones, fixtures principales, transiciones, auditoría, preservación y rechazos deterministas. Alterna fases cliente bajo `authenticated` con fases owner después de `RESET ROLE`: la primera sólo invoca RPC/proyecciones públicas o denegaciones expresas y la segunda inspecciona estado crudo. Prueba el helper privado como owner para autoridad exacta, asignación malformada y cuenta inactiva, y confirma `42501` en su única invocación directa como `authenticated`. Captura y conserva byte por byte los administradores exactos preexistentes, mientras las expectativas de A/B se calculan desde esa línea base. También exige cardinalidad de contexto 0/1, objetivo inexistente sin filas, `auth_unconfirmed`, timestamps persistidos y monótonos, UUID exactos, actor/objetivo/acción/motivo/metadata exactos de auditoría y la presentación vigente/futura/vencida/inactiva/suspendida de asignaciones. Como `set_updated_at()` usa `now()`, que es estable dentro de una transacción PostgreSQL, el verificador transaccional prueba igualdad exacta entre la marca devuelta y la persistida, pero no exige valores de reloj distintos entre dos transiciones de la misma transacción; esa diferencia se comprueba en transacciones separadas durante la verificación manual posterior a la aplicación.

La seguridad de última autoridad usa una secuencia real con dos administradores: A desactiva a B; B pierde autoridad y su intento recíproco contra A falla con `42501/sitaa_admin_access_denied`; A no puede actuar sobre sí mismo; finalmente A restaura a B por la RPC pública. No se fabrica un estado imposible para forzar `last_admin`. Los casos de bloqueo entre sesiones se ejecutan aparte porque una sola transacción no puede probar esperas reales.

## Matriz manual de concurrencia (entorno desechable)

1. Dos últimos administradores intentan desactivarse entre sí: una transición puede confirmar; el actor que espera debe fallar la segunda autorización y siempre queda una autoridad exacta activa.
2. Dos administradores desactivan el mismo objetivo: sólo uno confirma, el otro recibe conflicto de estado y existe un solo evento.
3. Una desactivación comienza antes que la reactivación del mismo objetivo: la segunda espera y el orden confirmado determina el estado final, con un evento por éxito.
4. Una reactivación comienza antes que la desactivación del mismo objetivo: se aplica el mismo contrato serializado.
5. Una revocación de rol comienza antes que la transición: la transición espera el `SHARE` y falla la segunda autorización si el actor perdió autoridad.
6. Una transición comienza antes que la revocación: la revocación espera y la transición puede confirmar bajo autoridad todavía válida.
7. Un cambio de email Auth comienza antes que la reactivación: ésta espera el lock Auth y evalúa el estado ya confirmado.
8. La reactivación comienza antes que el cambio de email Auth: el cambio espera y el trigger sincroniza después del commit de la reactivación.
9. La sesión A desactiva el programa institucional y se pausa antes de `COMMIT`; la sesión B intenta reactivar una cuenta de ese programa y espera su fila. Si A confirma, B rechaza con `sitaa_account_lifecycle_invalid_identity`; si A revierte, B puede continuar. Nunca debe confirmar un perfil activo ligado a un programa inactivo.

Cada escenario debe ejecutarse en una rama Supabase, base local o clon desechable que pueda descartarse por completo. No se limpia producción borrando eventos append-only. Ningún escenario de concurrencia ni verificación PostgreSQL de 0009 se ha ejecutado todavía.

## Aplicación compatible y smoke tests

- Antes de aplicar 0009, el detalle B.1/B.2a sigue disponible y los controles B.2b permanecen ocultos.
- Después de aplicar, una cuenta activa elegible muestra `Desactivar cuenta`; una inactiva elegible muestra `Reactivar cuenta`.
- El formulario preserva motivo y confirmación ante errores, enfoca el primer error y nunca envía PII a URLs o almacenamiento local.
- Una transición exitosa redirige al detalle con mensaje de éxito y refresca lista, detalle e historial.
- Una cuenta inactiva continúa siendo desviada por las guardas operativas existentes; no se afirma revocación física de sesiones.

## Criterio de cierre

B.2b no se considera aplicada, verificada ni reconciliada hasta completar la ejecución corregida de la migración, el verificador, smoke tests, snapshot post-0009 e informe de reconciliación. A la fecha, el preflight independiente está aprobado y la aplicación compatible está desplegada, pero el primer intento de migración falló de forma segura antes del DDL y 0009 permanece no aplicada. No se afirma ejecución del verificador/rollback, smoke tests, snapshot ni reconciliación de B.2b. B.3 y Fase C continúan pendientes.
