# Modelo de datos

## Tablas implementadas

La integración actual utiliza cinco tablas públicas. Supabase Auth conserva la identidad de acceso; `profiles` y `role_assignments` contienen el contexto institucional.

| Tabla | Propósito | Contrato utilizado por la aplicación |
| --- | --- | --- |
| `divisions` | Divisiones académicas | `id`, `code`, `name`, `is_active` |
| `academic_programs` | Carreras o programas | `id`, `division_id`, `code`, `name`, `is_active` |
| `roles` | Catálogo estable de roles | `id`, `code`, `name`, `description`, `is_active` |
| `profiles` | Perfil institucional vinculado a Auth | `id`, `full_name`, `student_number`, `employee_number`, `institutional_email`, `primary_program_id`, `status` |
| `role_assignments` | Asignaciones múltiples, vigentes o históricas | `id`, `user_id`, `role_id`, `scope_type`, `service_area`, `division_id`, `program_id`, `starts_at`, `ends_at`, `status`, `is_active` |

Los campos de auditoría `created_at` y `updated_at` pueden estar presentes en todas las tablas. `profiles.id` corresponde al identificador del usuario de Supabase Auth.

`profiles` **no contiene `role_code` ni otro rol fijo**. Una cuenta sin fila en `profiles` existe en Auth, pero aún no está activada en SITAA.

## Asignaciones de rol

Valores controlados:

- Alcance: `own`, `program`, `division`, `system`.
- Área de servicio: `tutoring`, `advising`, `both`, `logistics`, `technical`.
- Roles: `student`, `peer_tutor`, `professor`, `program_tutoring_lead`, `program_advising_lead`, `division_tutoring_liaison`, `program_head`, `division_head`, `technical_secretary`, `technical_admin`.

Una asignación se considera activa cuando no está deshabilitada o revocada, su estado es activo y la fecha actual se encuentra entre `starts_at` y `ends_at`; los límites nulos representan vigencia abierta. Las asignaciones históricas se conservan, pero no conceden acceso actual.

Para alcance `program` se requiere `program_id`; para `division`, `division_id`. `own` no requiere referencia institucional y `system` se reserva para capacidades institucionales explícitas.

## Relaciones implementadas

- Una división contiene muchos programas.
- Un perfil puede señalar un programa académico principal.
- Un usuario puede tener cero o más asignaciones de rol activas o históricas.
- Cada asignación referencia un rol y puede acotarse a un programa o división.
- El dashboard consulta únicamente el perfil y las asignaciones del usuario autenticado; RLS debe aplicar el mismo límite.

## Reglas de integridad

- Usar UUID y marcas de tiempo con zona horaria.
- Separar Supabase Auth, perfil institucional y asignaciones de rol.
- Validar la coherencia entre `scope_type`, `program_id` y `division_id`.
- Evitar asignaciones duplicadas o vigencias equivalentes superpuestas.
- Revocar o finalizar asignaciones; no borrarlas si produjeron acciones auditables.
- No conceder permisos por `primary_program_id`; es información de perfil, no autorización.
- Mantener normalizados los campos utilizados en RLS, filtros e indicadores.

## Entidades previstas, no implementadas

Grupos, membresías, responsables operativos, tipos de sesión, planes semestrales, sesiones, asistencia, encuestas y auditoría permanecen en fase de diseño. No existen migraciones de estas entidades en la etapa actual.

## Pendientes de definición

- Matriz de otorgamiento y revocación de asignaciones.
- Reglas definitivas para solapamiento, suplencia y delegación.
- Políticas RLS y pruebas por combinación de rol, alcance y área de servicio.
- Conservación y anonimización de datos académicos futuros.