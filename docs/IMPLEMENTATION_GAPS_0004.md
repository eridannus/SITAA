# Brechas de implementación para 0004 y fases posteriores

**Fecha de análisis:** 2026-07-16.

**Base observada:** cadena reconciliada `0001 + 0002 + 0003`.

**Estado:** la Fase A está implementada en aplicación y en 0004; la migración todavía no fue aplicada a Supabase.

## Resumen

SITAA ya tiene Auth SSR, login, perfil, asignaciones múltiples, RLS de actividades, participantes y asistencia. No tiene registro público, cuenta técnica explícita, administración de usuarios, autoridad de roles ni filtros reutilizables. El esquema actual puede evolucionar, pero necesita cambios condicionales y backfill antes de aplicar el modelo canónico.

## Inventario actual

- `profiles`: 13 columnas; `person_type` admite `student|worker`; identidad y programa pueden ser nulos; `is_active` es booleano; no existe `account_kind` ni unicidad institucional.
- `roles`: 10 códigos, sin `is_active`; `professor` combina tutor/asesor, `program_head` y `technical_secretary` no coinciden con V2.
- `role_assignments`: ya tiene usuario, rol, alcance, servicio, programa/división, vigencia, activo, `assigned_by`, `created_at` y `updated_at`; no tiene revocador, fecha de revocación ni nota.
- Auth: login con contraseña y cookies SSR; no hay `signUp`, rutas de registro, callback de activación, recuperación ni administración.
- Perfil: el usuario puede editar `person_type`, identificador y programa principal; el objetivo reserva esas correcciones a administración técnica.
- Contexto: carga perfil/asignaciones y filtra vigencia en TypeScript; no bloquea de forma central una cuenta inactiva.
- Permisos: helpers de actividades usan códigos actuales y conservan acceso académico transitorio de `technical_admin`.
- Pantallas: no existe panel de usuarios, auditoría administrativa ni filtro reusable de actividades/reportes.

## Matriz de brechas

| Clasificación | Capacidad actual | Objetivo | Brecha exacta | Impacto de base | Impacto de aplicación | Seguridad/backfill |
| --- | --- | --- | --- | --- | --- | --- |
| Registro | Sólo login; registro público deshabilitado | Dos rutas alumno/profesor con verificación | No hay formularios, acciones, callback ni estado pendiente | `account_kind`, estado y constraints condicionales; creación idempotente de perfil | `/register/student`, `/register/professor`, confirmación y mensajes no enumerables | Validar metadata; auditar perfiles existentes antes de `NOT NULL`/checks |
| Registro | `worker` representa trabajador/profesor | Clasificación exclusiva `student|professor` | Semántica y tipos no coinciden | Migrar `worker → professor`; actualizar check | Tipos TypeScript, formularios, etiquetas y contexto | Preflight de valores inesperados |
| Registro | Sin unicidad institucional | Texto de dígitos, ceros preservados, único por `(tipo, valor)` | Duplicados posibles dentro del mismo tipo | Índice único parcial por par y check de dígitos | Validación servidor y mensajes sanitizados | Auditar duplicados por par y valores no numéricos antes de crear constraint |
| Registro | Programa opcional | Obligatorio sólo para cuenta institucional | Falta regla condicional por tipo de cuenta | Check `account_kind`/programa/identificador | Formularios y corrección administrativa | Backfill de perfiles institucionales incompletos |
| Administración básica | `profiles.is_active` no gobierna todo el acceso | Desactivación bloquea Auth, RLS y RPC | Falta estado coordinado y gate central | Estado de cuenta y helpers que lo comprueben | Contexto, middleware y panel | Evitar borrar historia; decidir tratamiento de sesiones existentes |
| Administración básica | Sin cuenta técnica explícita | `technical` sin identidad institucional | Hoy requeriría datos ficticios | `account_kind` y checks condicionales | Flujo admin de creación y presentación | Sólo backend confiable; sin registro público |
| Administración básica | Sin historial administrativo | Auditoría append-only | No hay tabla/eventos | Nueva entidad de auditoría y políticas | Vista de historial y motivos | Minimizar PII; impedir edición/borrado cliente |
| Administración básica | Sin Auth admin | Activar, desactivar, reenviar, recuperar | Cliente anon no puede listar/administrar Auth | Ninguno o RPC de coordinación; Auth vive fuera de `public` | Server actions/Edge Function confiables | `service_role` sólo servidor; rate limit y auditoría |
| Roles académicos | `professor` combina tutor/asesor | Roles separados | No se puede delegar por servicio sin ambigüedad | Nuevos códigos y backfill | Helpers, formularios y paneles | No elevar profesores existentes automáticamente |
| Roles académicos | Faltan coordinator/secretary/auxiliary V2 | Responsabilidades separadas | Códigos actuales no expresan el modelo | Insertar nuevos códigos; mapear `program_head` y `technical_secretary` | Etiquetas, navegación, permisos | Auditar asignaciones antes de migrar o desactivar códigos antiguos |
| Roles académicos | Asignaciones se pueden desactivar, no revocar completamente | Historia de asignación/revocación | Faltan `assigned_at`, `revoked_by`, `revoked_at`, nota | Añadir columnas y validaciones; prohibir borrado operativo | Panel y RPC de asignación/revocación | Backfill `assigned_at = created_at`; preservar filas |
| Roles académicos | Sin matriz ejecutable de autoridad | Leads delegan roles limitados; admin roles críticos | No existen RPC/políticas para administrar roles | RPC `SECURITY DEFINER`, checks de elegibilidad y alcance | UI consciente de autoridad | Sin autoasignación; doble validación; auditoría |
| Retiro A-02 | `technical_admin` gestiona contenido publicado | Administración técnica sin acceso académico implícito | Helpers mezclan soporte y gestión académica | Redefinir helpers/RLS en fase E | Separar cuenta técnica/institucional y pruebas | No retirar hasta que panel/roles estén estabilizados |
| Filtros | Listados casi sin estado reusable | Filtros posteriores a autorización | Falta contrato común y consultas parametrizadas | RPC/vistas sólo si aportan paginación segura | Estado URL, componentes y paneles | Nunca descargar filas prohibidas; conteos autorizados |
| Mejora posterior | Check-in sólo para preinscritos | Check-in abierto opcional y transaccional | No existe bandera, elegibilidad ni RPC | Campo/configuración y operación atómica futura | Resultado normal de check-in | Después de identidad/roles; no forma parte de 0004 inicial |

## Cambios incluidos en 0004

La migración creada se limita a la base de identidad necesaria para la Fase A:

1. introducir `account_kind` y un estado de cuenta explícito;
2. migrar semánticamente `worker` a `professor`;
3. definir checks condicionales para cuentas institucionales y técnicas;
4. proteger la unicidad del par (`institutional_id_type`, `institutional_id_value`) y conservar ceros iniciales;
5. preparar creación idempotente de perfil tras `signUp`/confirmación;
6. documentar/backfillear perfiles existentes incompatibles antes de hacer obligatorias las reglas;
7. incluir verificación y rollback revisados.

La migración no asigna nombres reales, no eleva profesores, no crea cuentas técnicas reales, no cambia roles y no retira A-02. La administración y auditoría continúan en fases posteriores.

## Secuencia recomendada

### Fase A — identidad y registro (implementada; 0004 no aplicada)

- modelo canónico de cuenta;
- dos formularios públicos;
- validación/unicidad;
- verificación de correo y activación automática;
- impedir autoservicio de identidad principal después del alta.

### Fase B — administración básica

- panel técnico de cuentas;
- activación/desactivación coordinada;
- correcciones de identidad/programa;
- recuperación/confirmación segura;
- auditoría administrativa.

### Fase C — administración de roles

- nuevos códigos y backfill;
- revocación histórica;
- delegación de tutor, asesor y tutor par;
- roles críticos sólo por `technical_admin`;
- pruebas negativas de autoasignación y alcance.

### Fase D — paneles y filtros

- visibilidad consciente de permisos;
- filtros reutilizables y paginación;
- vistas de programa/división;
- base para reportes.

### Fase E — retirar excepción técnica

- eliminar acceso académico implícito de `technical_admin`;
- probar por separado cuenta institucional ordinaria y cuenta técnica interna;
- verificar transferencia de responsabilidad técnica.

### Fase F — check-in abierto

- cada actividad lo habilita expresamente;
- un usuario SITAA autenticado puede presentarse sin inscripción previa;
- una operación transaccional crea `activity_participants` si falta y marca `attended`;
- el usuario recibe el mismo mensaje normal de éxito;
- participantes registrados que no asisten siguen convirtiéndose a `absent` normalmente;
- la operación valida cuenta activa, programa y elegibilidad;
- no se exponen identificadores en enlace, QR o código.

## Preguntas técnicas abiertas

| Pregunta | Por qué importa / objeto | Predeterminado recomendado | ¿Bloquea 0004? |
| --- | --- | --- | --- |
| ¿Cuál es la longitud institucional exacta de cada identificador? | `profiles`, validación de formularios e índice | Aceptar sólo dígitos como texto dentro del límite actual; endurecer longitud cuando exista norma oficial | No, si 0004 evita inventar una longitud |
| ¿La desactivación Auth usará bloqueo temporal indefinido o una marca coordinada adicional? | Auth admin, `profiles`, middleware y sesiones activas | Bloqueo administrativo de Auth más estado SITAA y checks RLS/RPC | Bloquea fase B, no la base de registro de 0004 |
| ¿Cómo se autoriza el bootstrap si queda un solo `technical_admin`? | Transferencia de rol crítico y continuidad operativa | Procedimiento externo revisado y auditable; nunca autoasignación | No para 0004; sí antes de producción del panel de roles |
| ¿Los códigos antiguos se conservan como compatibilidad o se migran y desactivan? | `roles`, `role_assignments`, helpers | Backfill verificado y periodo corto de compatibilidad; no borrar historia | Bloquea la parte de roles si se incluye en 0004 |
| ¿Qué campos personales no críticos seguirá editando el propio usuario? | `/profile`, RLS de `profiles` | Permitir nombre; reservar tipo, identificador, programa, correo y estado a flujos controlados | No para la migración; sí para cerrar la UI de fase A |

No existe una pregunta funcional que invalide el modelo aprobado. Antes de aplicar 0004 sí es obligatorio auditar valores nulos, `worker`, duplicados institucionales y perfiles sin programa; el resultado determina el backfill seguro.

## Verificación de Fase A y fases futuras

- registro alumno/profesor y confirmación de correo;
- rechazo de duplicados dentro del mismo tipo y aceptación del mismo valor entre tipos diferentes;
- cuenta técnica sin identificador/programa y sin registro público;
- cuenta inactiva sin acceso aunque conserve asignaciones;
- profesor nuevo sin tutoría/asesoría;
- alumno nuevo sin `peer_tutor`;
- elegibilidad y no autoasignación;
- revocación histórica y auditoría;
- filtros incapaces de ampliar RLS;
- ausencia de nombres/identificadores reales en migraciones y semillas.
