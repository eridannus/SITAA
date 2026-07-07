# Roles y permisos

Los permisos se aplicarán con RLS en Supabase y se reflejarán en la interfaz. El acceso efectivo combina rol, periodo, programa, grupo y asignaciones vigentes.

## Roles iniciales

- **Estudiante:** participa en sesiones y consulta únicamente su información.
- **Tutor/asesor:** planea y registra actividades de los grupos asignados.
- **Coordinación:** supervisa programas o periodos bajo su responsabilidad.
- **Administración:** configura la plataforma y gestiona accesos institucionales.

## Matriz resumida

| Recurso o acción | Estudiante | Tutor/asesor | Coordinación | Administración |
| --- | --- | --- | --- | --- |
| Ver perfil | Propio | Propio | Dentro de su alcance | Institucional |
| Editar perfil | Datos propios permitidos | Datos propios permitidos | Datos propios permitidos | Campos administrativos |
| Ver grupos | Propios | Asignados | De su alcance | Todos |
| Crear/editar plan | No | Propio y asignado | Revisar/aprobar | Configuración excepcional |
| Crear/editar sesión | No | Propia y asignada | Supervisar/corregir con auditoría | Excepcional con auditoría |
| Registrar asistencia | Solo la propia, con QR válido | Captura o valida en sus sesiones | Consulta y corrección auditada | Corrección auditada |
| Ver asistencias | Propias | De sus sesiones | Agregadas y detalladas en su alcance | Todas según necesidad operativa |
| Responder encuesta | Propia, una vez | No | No | No |
| Ver resultados de encuesta | No individualizados | Agregados de sus sesiones | Agregados de su alcance | Agregados institucionales |
| Exportar CSV | No en MVP | Sus sesiones, si se habilita | Su alcance | Institucional |
| Gestionar usuarios/roles | No | No | No por defecto | Sí |
| Gestionar catálogos/periodos | No | No | Consulta | Sí |

## Reglas transversales

- Denegar por defecto: toda tabla expuesta debe tener RLS y políticas explícitas.
- Los permisos elevados no deben depender de valores editables por el propio usuario.
- Un usuario con varios roles obtiene la unión de permisos, limitada por sus asignaciones vigentes.
- Las acciones administrativas o correcciones posteriores al cierre deben quedar auditadas.
- Las encuestas se muestran agregadas cuando exista riesgo de identificar al participante.
- Las cuentas de servicio y la clave `service_role` nunca se utilizarán en el navegador.

## Decisiones pendientes

- Umbral mínimo de respuestas para mostrar resultados agregados.
- Capacidad de coordinación para editar frente a solo supervisar.
- Exportación CSV para tutores y nivel de detalle permitido.
- Procedimiento de suplencia temporal de un tutor o coordinador.
