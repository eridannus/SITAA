# Administración de cuentas de usuario

**Estado funcional:** aprobado.

**Alcance:** panel interno para `technical_admin` y delegación limitada de roles académicos. No implementa código ni introduce una llave administrativa en el cliente.

## Objetivos

- localizar cuentas sin exponer directorios completos a usuarios no autorizados;
- corregir identidad principal bajo validación estricta;
- activar o desactivar acceso sin borrar historia;
- administrar asignaciones vigentes e históricas;
- administrar de forma segura acceso heredado y vinculación de proveedores sin ver credenciales;
- mantener auditoría de toda acción crítica.

## Búsqueda y filtros del panel

El panel debe buscar por:

- nombre;
- correo;
- número de cuenta o de trabajador;
- programa;
- tipo de cuenta (`institutional`, `technical`);
- tipo de persona (`student`, `professor`);
- estado (`pending_registration`, `active`, `inactive`);
- rol asignado;
- servicio;
- alcance.

Los resultados deben paginarse, minimizar identificadores visibles y exigir autorización del servidor antes de consultar. No se descarga el padrón completo al navegador para filtrarlo localmente.

## Vista de cuenta

La ficha administrativa muestra:

- resumen de Auth: correo y estado de confirmación, sin tokens;
- identidad SITAA y programa principal;
- estado operativo;
- asignaciones activas, futuras, vencidas y revocadas;
- actividades futuras que podrían requerir cambio de responsable;
- historial administrativo sanitizado.

## Acciones

Sólo `technical_admin` puede, durante la fase actual:

- activar o desactivar una cuenta;
- corregir alumno/profesor;
- corregir programa principal;
- corregir tipo o valor del identificador con unicidad del par `(tipo, valor)`;
- crear y administrar cuentas técnicas internas;
- iniciar recuperación de contraseña;
- asignar o revocar roles críticos conforme a la matriz V2;
- consultar el historial administrativo.

Los leads de tutoría y asesoría sólo ven la operación necesaria para delegar los roles académicos permitidos en su programa. No obtienen corrección de identidad, activación, Auth admin ni acceso a cuentas de otros programas.

## Contraseñas y correo

- Los administradores nunca ven contraseñas.
- Los administradores nunca establecen directamente una contraseña.
- «Restablecer contraseña» significa enviar un enlace seguro de recuperación de Supabase Auth.
- «Reenviar confirmación» inicia el flujo de confirmación; no marca el correo como verificado manualmente.
- Las respuestas no revelan si un correo existe y deben aplicar límites de frecuencia.
- Los enlaces usan únicamente redirects internos permitidos bajo el dominio canónico.

## Desactivación y reactivación

Desactivar una cuenta:

1. impide nuevas sesiones y operación;
2. hace que RLS/RPC consideren al perfil no habilitado;
3. conserva perfil, autoría, actividades, participación y asistencia;
4. conserva filas de asignación, pero su autorización efectiva queda suspendida por el estado de cuenta;
5. identifica actividades futuras cuyo responsable deba reasignarse;
6. registra actor, fecha y motivo.

La desactivación no elimina ni revoca automáticamente cada asignación. Al reactivar, vuelven a ser efectivas sólo las asignaciones no revocadas y todavía vigentes. Una revocación explícita nunca se deshace por reactivación.

## Ejecución técnica confiable

La versión instalada de `@supabase/supabase-js` ofrece operaciones públicas y administrativas distintas:

| Operación | Cliente público/SSR con clave anon | Backend confiable o Edge Function |
| --- | --- | --- |
| Registro institucional propio | Google OAuth + intents/RPC | Configuración del proveedor; no usa `service_role` en la aplicación |
| Vinculación Google propia | Flujo Supabase Auth | Se conserva `auth.users.id`; no se sobrescribe identidad SITAA |
| Recuperación propia | `auth.resetPasswordForEmail` | Panel administrativo debe envolverla para autorización y auditoría |
| Leer/editar perfil propio no crítico | Cliente SSR bajo RLS | No requerido |
| Listar usuarios Auth | No | `auth.admin.listUsers` |
| Crear cuenta técnica | No | `auth.admin.createUser` o invitación administrativa |
| Activar/desactivar Auth | No | `auth.admin.updateUserById` y política SITAA coordinada |
| Generar invitación/recuperación administrativa | No | `auth.admin.generateLink` o `inviteUserByEmail`, según el flujo aprobado |
| Corregir identidad principal | No | RPC o servicio confiable con auditoría |
| Asignar/revocar roles | No | RPC privilegiada con matriz y auditoría |

La llave `service_role` nunca se envía al navegador, no se guarda en tablas y no se añade a variables `NEXT_PUBLIC_*`. Las operaciones Auth admin deben ejecutarse en un entorno servidor confiable o Edge Function con sesión del operador, autorización explícita, validación y logs sanitizados.

## Auditoría administrativa

Se requiere un registro inmutable o append-only con, como mínimo:

- `event_id`;
- actor;
- cuenta afectada;
- tipo de acción;
- fecha/hora;
- motivo o nota administrativa;
- resultado;
- referencia a asignación cuando aplique;
- metadatos mínimos no sensibles.

Eventos mínimos: creación técnica, activación, desactivación, corrección de identidad/programa, vinculación de proveedor cuando se administre, inicio de recuperación, asignación, revocación y transferencia de `technical_admin`.

No deben registrarse contraseñas, tokens, enlaces completos, cookies ni identificadores completos si basta una referencia interna o versión enmascarada.

## Flujo de asignación

1. El operador busca y abre la cuenta.
2. El servidor carga su identidad y autoridad efectiva.
3. La interfaz ofrece sólo roles permitidos por la matriz.
4. El servidor valida nuevamente actor distinto del beneficiario, elegibilidad, servicio, alcance, programa y vigencia.
5. Se crea una nueva asignación o se revoca la existente; nunca se sobrescribe la historia.
6. Se registra el evento y se actualiza la vista.

## Transferencia técnica

El modelo permite crear una nueva cuenta técnica interna, verificarla, asignarle `technical_admin` mediante un operador distinto y después revocar/desactivar la cuenta anterior. La transferencia debe probar que no depende de la cuenta institucional de la persona desarrolladora.

## Criterios de aceptación

- Ningún control administrativo funciona sólo por ocultamiento visual.
- Una cuenta inactiva no puede iniciar sesión ni usar RPC académicas.
- Los identificadores duplicados se rechazan antes de guardar.
- No existe autoasignación.
- Toda revocación conserva historia.
- El panel no expone claves, tokens ni contraseñas.
- Las acciones de Auth admin sólo ocurren en ejecución confiable.
