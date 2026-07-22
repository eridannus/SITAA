# Plan de pruebas de la migración 0009

## Estado y alcance

`0009_admin_account_lifecycle_transitions.sql` está preparada localmente y no aplicada. Este plan valida la desactivación/reactivación auditada por administradores B.1 exactos. No administra Auth, no revoca sesiones físicas, no modifica asignaciones y no implementa roles V2.

Orden manual obligatorio: ejecutar el preflight de sólo lectura, revisar sus 19 categorías bloqueantes y 7 informativas (26 filas siempre presentes, incluso cuando un bloqueo vale cero), desplegar la aplicación compatible, aplicar la migración, ejecutar el verificador transaccional, realizar smoke tests y finalmente regenerar/reconciliar el snapshot.

La revisión previa a aplicación corrigió el handler canónico del trigger de correo a `sync_sitaa_profile_email_from_auth()`, preservó exactamente los `UPDATE` de columna de `authenticated` sobre `first_names`, `paternal_surname` y `maternal_surname`, y mantuvo denegados los campos de identidad y ciclo de vida protegidos. Los contratos usan mapas/hashes exactos post-0008 para impedir sustituciones que conserven sólo los conteos.

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

El verificador automatiza los contratos estructurales, ACL, autorizaciones, fixtures principales, transiciones, auditoría, preservación y rechazos deterministas. Prueba el helper privado como owner para autoridad exacta, asignación malformada y cuenta inactiva, y confirma `42501` al invocarlo como `authenticated`. También exige cardinalidad de contexto 0/1, objetivo inexistente sin filas, `auth_unconfirmed`, timestamps persistidos y monótonos, UUID exactos, actor/objetivo/acción/motivo/metadata exactos de auditoría y la presentación vigente/futura/vencida/inactiva/suspendida de asignaciones. Como `set_updated_at()` usa `now()`, que es estable dentro de una transacción PostgreSQL, el verificador transaccional prueba igualdad exacta entre la marca devuelta y la persistida, pero no exige valores de reloj distintos entre dos transiciones de la misma transacción; esa diferencia se comprueba en transacciones separadas durante la verificación manual posterior a la aplicación.

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

Cada escenario debe ejecutarse en una rama Supabase, base local o clon desechable que pueda descartarse por completo. No se limpia producción borrando eventos append-only.

## Aplicación compatible y smoke tests

- Antes de aplicar 0009, el detalle B.1/B.2a sigue disponible y los controles B.2b permanecen ocultos.
- Después de aplicar, una cuenta activa elegible muestra `Desactivar cuenta`; una inactiva elegible muestra `Reactivar cuenta`.
- El formulario preserva motivo y confirmación ante errores, enfoca el primer error y nunca envía PII a URLs o almacenamiento local.
- Una transición exitosa redirige al detalle con mensaje de éxito y refresca lista, detalle e historial.
- Una cuenta inactiva continúa siendo desviada por las guardas operativas existentes; no se afirma revocación física de sesiones.

## Criterio de cierre

B.2b no se considera aplicada, verificada ni reconciliada hasta completar ejecución remota controlada, smoke tests, snapshot post-0009 e informe de reconciliación. A la fecha, 0009 permanece local y no aplicada; no se afirma ejecución PostgreSQL, smoke tests, snapshot ni reconciliación de B.2b. B.3 y Fase C continúan pendientes.
