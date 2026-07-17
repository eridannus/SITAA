# Roles y permisos V2

**Estado funcional:** aprobado.

**Documento canónico:** sustituye el catálogo funcional, la autoridad de asignación y los pendientes equivalentes de `ROLES_AND_PERMISSIONS.md`. Las reglas ya implementadas de actividades, borradores y asistencia del documento anterior siguen vigentes hasta su migración explícita.

## Modelo

- `student` y `professor` son tipos de persona, no responsabilidades elevadas.
- Los roles son aditivos, acotados, vigentes e independientemente revocables.
- No existe un rol combinado de profesor tutor y asesor.
- La autorización efectiva combina rol, alcance, programa/división, servicio, vigencia, estado de cuenta y RLS.
- `primary_program_id` no concede permisos de gestión.
- Nadie puede asignarse o revocarse roles a sí mismo.

## Acceso básico por identidad

| Identidad | Capacidades básicas |
| --- | --- |
| Alumno | Ver actividades propias o donde participa, confirmar su asistencia y filtrar ese conjunto. No crea actividades sin `peer_tutor`. |
| Profesor | Ver actividades propias o donde participa y filtrar ese conjunto. No crea tutorías o asesorías sin la asignación correspondiente. |
| Cuenta técnica interna | Sin capacidad académica por identidad. Opera sólo mediante asignaciones técnicas explícitas. |

## Catálogo funcional canónico

| Código propuesto | Elegibilidad | Alcance/servicio normal | Capacidades |
| --- | --- | --- | --- |
| `peer_tutor` | Sólo alumno | Programa, `tutoring` | Crear y gestionar tutorías propias; participantes y asistencia de esas actividades. |
| `professor_tutor` | Sólo profesor | Programa, `tutoring` | Crear y gestionar tutorías propias en el programa asignado. |
| `professor_advisor` | Sólo profesor | Programa, `advising` | Crear y gestionar asesorías propias en el programa asignado. |
| `program_tutoring_lead` | Profesor | Programa, `tutoring` | Control completo de tutorías, reportes y delegación de tutores/profesores pares en su programa. |
| `program_advising_lead` | Profesor | Programa, `advising` | Control completo de asesorías, reportes, alertas de riesgo pertinentes y delegación de profesores asesores. |
| `program_coordinator` | Profesor o autoridad institucional | Programa, `both` | Leer actividades y reportes del programa; sin modificación ordinaria de actividades ajenas. |
| `program_technical_secretary` | Profesor autorizado | Programa, `both` | Leer actividades del programa y crear actividades propias de tutoría/asesoría; sin modificación indiscriminada de actividades ajenas. |
| `division_head` | Autoridad institucional | División, `both` | Leer actividades, indicadores y reportes de ambos programas; sin modificación ordinaria. |
| `division_tutoring_liaison` | Autoridad institucional | División, `both` | Leer y modificar tutoría/asesoría de ambos programas, reportes divisionales y flujos académicos transversales. |
| `division_auxiliary_secretary` | Autoridad institucional | División, `both` | Inicialmente el mismo paquete funcional que el enlace divisional, con código independiente para permitir divergencia futura. |
| `technical_admin` | Cuenta técnica interna; excepción transitoria permitida | Sistema, `technical` | Cuentas, identidad, roles críticos, configuración, semestres y diagnóstico. En el modelo final no obtiene acceso académico implícito. |

Un profesor puede tener simultáneamente `professor_tutor` y `professor_advisor`; cada asignación conserva servicio y alcance propios. Un alumno puede tener `peer_tutor` y volver después a acceso básico sin cambiar su perfil.

## Contrato de `role_assignments`

Cada asignación debe conservar:

- cuenta/perfil (`user_id` o nombre futuro equivalente);
- `role_code`;
- `scope_type`: `own`, `program`, `division` o `system`;
- `program_id` y/o `division_id` coherentes con el alcance;
- `service_area`: `tutoring`, `advising`, `both`, `logistics` o `technical`;
- estado activo/inactivo;
- vigencia desde y hasta opcional;
- quién asignó y cuándo;
- quién revocó y cuándo;
- nota administrativa opcional.

Las asignaciones se revocan o desactivan; nunca se eliminan en la operación normal. Una cuenta inactiva tiene autorización efectiva cero aunque sus filas históricas permanezcan. Al reactivarla, sólo recupera asignaciones que no fueron revocadas y cuya vigencia siga activa.

## Validaciones de elegibilidad

- `peer_tutor` exige `person_type = student`.
- `professor_tutor`, `professor_advisor` y responsabilidades académicas de programa exigen `person_type = professor` salvo una excepción institucional documentada.
- `technical_admin` se asigna normalmente a `account_kind = technical`.
- El alcance de programa exige `program_id`; el de división exige `division_id`; el de sistema no usa programa.
- El servicio fijo de cada rol no puede sustituirse con un valor más amplio enviado por el cliente.
- Una asignación no puede ser creada por su propio beneficiario.
- RLS y RPC privilegiadas vuelven a validar autoridad, elegibilidad, alcance y vigencia.

## Autoridad para asignar o revocar

| Rol que se administra | Quién puede asignar o revocar | Límites |
| --- | --- | --- |
| `division_head` | Sólo `technical_admin` | Sin autoasignación. |
| `division_tutoring_liaison` | Sólo `technical_admin` | Código distinto del auxiliar. |
| `division_auxiliary_secretary` | Sólo `technical_admin` | Código distinto del enlace aunque hoy compartan paquete. |
| `program_coordinator` | Sólo `technical_admin` | Programa explícito. |
| `program_technical_secretary` | Sólo `technical_admin` | Programa explícito. |
| `program_tutoring_lead` | Sólo `technical_admin` | Programa y servicio de tutoría. |
| `program_advising_lead` | Sólo `technical_admin` | Programa y servicio de asesoría. |
| `technical_admin` | Sólo otro `technical_admin` | Transferencia auditada; nunca autoasignación. |
| `professor_tutor` | `program_tutoring_lead` | Sólo profesores y sólo su programa. |
| `peer_tutor` | `program_tutoring_lead` | Sólo alumnos y sólo su programa. |
| `professor_advisor` | `program_advising_lead` | Sólo profesores y sólo su programa. |

Coordinadores y secretarías técnicas no asignan roles en esta etapa. El enlace y el auxiliar divisional sólo delegarán roles cuando una matriz futura lo autorice expresamente; la matriz actual no les concede esa capacidad.

El bootstrap o transferencia de la última cuenta técnica requiere un procedimiento operativo revisado fuera del autoservicio, con evidencia de quién autorizó el cambio. No se resuelve mediante autoasignación.

## Administración técnica transitoria

Durante desarrollo, el helper actual permite a `technical_admin` acceso académico amplio a contenido publicado. Esta excepción A-02 se conserva temporalmente para pruebas. No amplía la privacidad de borradores y debe eliminarse en una fase posterior, después de implementar administración de cuentas, roles y permisos y probar por separado la cuenta institucional y la cuenta técnica.

## Mapeo organizacional para planeación

> Ejemplos no ejecutables. Esta lista no es semilla, no asigna permisos y no debe copiarse a SQL. Las personas deben registrarse normalmente cuando aplique y recibir roles manualmente dentro de SITAA.

| Responsabilidad prevista | Referencia de planeación |
| --- | --- |
| Jefatura de división | Elizabeth Cordero |
| Enlace divisional de tutorías y asesorías | Mariana Caballero |
| Secretaría auxiliar de división | Alejandra Guzmán |
| Coordinación de Diseño Gráfico | Ana Cárdenas |
| Secretaría técnica de Diseño Gráfico | Kenia Bonifacio |
| Encargado de asesorías de Diseño Gráfico | José Luis Caballero |
| Encargada de tutorías de Diseño Gráfico | Laura Espinoza |
| Coordinación de Arquitectura | Inés Otmara |
| Secretaría técnica de Arquitectura | Rodrigo |
| Encargado de tutorías de Arquitectura | Salvador |
| Encargado de asesorías de Arquitectura | Pendiente de confirmación; puede asignarse independientemente a Salvador si se confirma |
| Cuenta institucional del desarrollador | Profesor ordinario, sin permiso de comité por desarrollo |
| Cuenta personal del desarrollador | Cuenta técnica interna con `technical_admin` |

Mariana y Alejandra tienen códigos distintos aunque sus permisos iniciales sean iguales.

## Compatibilidad con códigos actuales

| Código actual | Tratamiento futuro recomendado |
| --- | --- |
| `student` | Dejar de usarlo como rol de autorización base; derivar acceso básico de `person_type = student`. |
| `professor` | Separar identidad `professor` de `professor_tutor` y `professor_advisor`; no elevar automáticamente. |
| `program_head` | Migrar semánticamente a `program_coordinator` después de auditar asignaciones. |
| `technical_secretary` | Sustituir por `program_technical_secretary` con programa explícito. |
| `division_tutoring_liaison` | Conservar como código del enlace divisional. |
| `peer_tutor`, leads, `division_head`, `technical_admin` | Conservar, ajustando elegibilidad y autoridad. |

No se debe renombrar ni borrar códigos vivos sin migración, backfill y compatibilidad revisada. Las brechas exactas se documentan en `IMPLEMENTATION_GAPS_0004.md`.
