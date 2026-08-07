# Roles y permisos V2

**Estado funcional:** diseño aprobado para Fase C; no implementado. La Fase A de identidad está cerrada y no asigna roles automáticamente.

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

## Subconjunto operativo del piloto

La hoja `MVP_OPERATIONAL_ROADMAP.md` acota la primera implementación de Fase C al paquete `ROLE-01`. No sustituye el catálogo V2: define únicamente la autoridad necesaria para iniciar el piloto.

### Roles necesarios ahora

- `technical_admin`;
- `professor_tutor`;
- `professor_advisor`;
- `peer_tutor`;
- `program_tutoring_lead`;
- `program_advising_lead`;
- `program_coordinator`;
- `division_tutoring_liaison`;
- sólo roles institucionales adicionales que una necesidad concreta del piloto justifique.

### Bootstrap y delegación mínima

- Un `technical_admin` exacto y activo asigna los roles institucionales iniciales de alto nivel, con alcance explícito, vigencia y auditoría.
- `program_tutoring_lead` puede asignar o revocar `professor_tutor` y `peer_tutor` sólo en su mismo programa.
- `program_advising_lead` puede asignar o revocar `professor_advisor` sólo en su mismo programa.
- La autoridad se revalida en la base de datos; una opción visible o un parámetro enviado por el cliente no concede rol.
- Autoasignación, transferencia completa de `technical_admin` y delegación general siguen fuera del paquete mínimo.

### Regla rol primero, grupo después

Un profesor sólo puede recibir un grupo de tutoría después de tener una asignación vigente `professor_tutor` para el mismo programa. La asignación de tutor al grupo referencia la fila concreta de `role_assignments` que la habilita, no sólo el perfil.

No se puede revocar ese rol mientras existan asignaciones activas de grupo dependientes. Primero deben transferirse o concluirse los grupos. Membresías, tutorías y roles conservan historia mediante cierre o revocación, nunca mediante borrado operativo.

### Autoridad operativa de grupos

- `program_tutoring_lead` es la autoridad operativa para crear, editar y cerrar grupos de tutoría exclusivamente dentro de su propio programa.
- Dentro de ese programa administra membresías actuales y asigna o transfiere tutores.
- Toda asignación de grupo exige una fila habilitante `professor_tutor` preexistente, vigente y del mismo programa; la asignación o transferencia referencia esa fila exacta.
- Una búsqueda, un filtro o un control visible nunca concede autoridad; cada mutación debe revalidarse en la base de datos.
- `program_coordinator`, `program_advising_lead` y profesores ordinarios no adquieren autoridad de gestión de grupos por su sola identidad.
- `technical_admin` realiza bootstrap institucional y soporte técnico, pero su rol técnico no constituye la autoridad académica final sobre el contenido de los grupos.
- La excepción transitoria A-02 no define un contrato permanente de gestión de grupos.

### Capacidad básica de alertas

Todo perfil activo con `person_type = professor` puede crear una alerta académica mínima sin ser tutor o asesor. La recepción depende de asignaciones académicas vigentes:

- `absences` y `missing_work`: leads de tutoría y asesoría y coordinación del programa;
- `socioemotional_attention`: enlace divisional de tutorías y coordinación del programa.

Los destinatarios se fijan al crear la alerta. `technical_admin` no obtiene contenido de alertas por su rol técnico; sólo puede consultar diagnósticos sanitizados de creación y entrega. El acceso técnico amplio transitorio A-02 no debe interpretarse como autoridad sobre contenido de alertas.

Fase C completa conserva administración de todos los roles, transferencia, delegación general y retiro de A-02. Estas capacidades permanecen diferidas y no se infieren del subconjunto del piloto.

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

B.2a no introduce semántica V2 ni repara dependencias automáticamente: una corrección incompatible se rechaza y no revoca, mueve ni reescribe asignaciones. La creación, revocación, transferencia y delegación de roles permanece íntegramente en Fase C.
