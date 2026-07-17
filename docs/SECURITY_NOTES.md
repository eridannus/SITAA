# Notas de seguridad y privacidad

## Datos protegidos

SITAA manejará identidad, matrícula o número de empleado, pertenencia académica, asistencia, observaciones de sesión y encuestas. Se debe recopilar únicamente lo necesario y definir responsables, finalidad, conservación y eliminación conforme a la normativa institucional aplicable.

## Controles obligatorios

### Identidad y sesión

- Usar Supabase Auth y exigir correo institucional cuando sea viable.
- 0004 implementa registro separado de alumnos y profesores con verificación obligatoria de correo y activación básica automática. No habilitarlo en producción hasta aplicar/verificar la migración, aprobar el preflight y configurar redirects.
- Las cuentas `technical` siguen siendo exclusivamente administrativas: sólo `app_metadata` confiable puede originarlas; el formulario público no controla tipo de cuenta, estado ni roles.
- Gestionar la sesión con clientes SSR y cookies seguras; validar al usuario en el servidor antes de servir rutas protegidas.
- Configurar redirecciones autorizadas y cookies seguras.
- No revelar si un correo está registrado mediante mensajes de error diferenciados.
- Revocar acceso al desactivar perfiles o vencer asignaciones.
- No permitir que el usuario cambie por autoservicio tipo de cuenta/persona, identificador, programa principal, estado o roles.
- El autoservicio de Fase A permite únicamente `profiles.full_name`; el correo cambia por Supabase Auth y nueva verificación.
- La aplicación bloquea perfiles pendientes o inactivos. La revocación coordinada de sesiones Auth y la administración de bajas se completan en Fase B/0005.

### Administración de cuentas y roles

- Ejecutar `auth.admin`, correcciones de identidad y administración de roles sólo en backend confiable o Edge Function; nunca exponer `service_role` al navegador.
- Los administradores no ven ni establecen contraseñas; inician enlaces seguros de recuperación.
- Validar elegibilidad, alcance, servicio, programa, vigencia y actor distinto del beneficiario antes de asignar un rol.
- Revocar asignaciones sin borrar historia y registrar actor, fecha y motivo.
- Desactivar una cuenta en Auth y en la autorización SITAA sin eliminar perfil, autoría, actividades o asistencia.
- Mantener un log administrativo append-only y sanitizado para cambios críticos.
- No incorporar nombres, correos ni identificadores personales a semillas SQL.

### Autorización y base de datos

- Habilitar RLS en todas las tablas accesibles desde la API.
- Basar políticas en `auth.uid()` más relaciones de asignación verificables.
- Probar políticas con cada rol y con usuarios fuera del alcance autorizado.
- Reservar `service_role` para procesos de servidor estrictamente controlados.
- Validar datos y transiciones de estado en servidor o base de datos, no solo en formularios.
- Aplicar filtros sólo después de construir mediante RLS/RPC el conjunto visible; ningún query param o selector puede ampliar acceso.

### QR y asistencia

- El QR debe contener un token aleatorio, de un solo propósito y vigencia corta; nunca datos personales.
- Guardar la huella criptográfica del token, no el token reutilizable.
- Requerir sesión autenticada y comprobar pertenencia del estudiante al grupo.
- Aplicar unicidad por sesión y estudiante, límites de intentos y registro de invalidaciones.
- No prometer validación de presencia física solo con QR; ubicación o dispositivo requerirían evaluación adicional de privacidad.

### Encuestas, exportaciones y archivos

- Separar respuestas de satisfacción de vistas que identifiquen al estudiante cuando el objetivo sea anonimato.
- Aplicar un umbral antes de presentar agregados de grupos pequeños.
- Escapar celdas peligrosas en CSV para evitar inyección de fórmulas.
- Registrar quién exporta, qué filtros usa y cuándo lo hace.
- Usar buckets privados de Supabase Storage, rutas no predecibles y URLs firmadas de corta duración.
- Restringir tipo, tamaño y extensión de archivos; analizar la necesidad real antes de permitir adjuntos.

## Secretos y despliegue

- Mantener secretos solo en variables de entorno locales y de Vercel/Supabase.
- Exponer al navegador únicamente valores públicos previstos, como la clave `anon`.
- Excluir archivos `.env*` con secretos y usar datos ficticios en desarrollo.
- Separar, si los límites lo permiten, proyectos de desarrollo y producción.
- Revisar encabezados de seguridad, dependencias y alertas antes de cada entrega.

### Contrato de dominio de producción

- Origen canónico: `https://www.sitaa.net`.
- El dominio raíz `https://sitaa.net` redirige al origen canónico.
- `https://sitaa.vercel.app` es respaldo técnico y no la URL pública canónica.
- Vercel Production configura `NEXT_PUBLIC_SITE_URL=https://www.sitaa.net`. Es configuración pública, no un secreto; Preview no debe recibir ese valor automáticamente salvo decisión explícita.
- Supabase Authentication configura Site URL en `https://www.sitaa.net` y permite actualmente `https://www.sitaa.net/**` y `https://sitaa.vercel.app/**` como Redirect URLs.
- Los enlaces QR y directos de asistencia derivan de `NEXT_PUBLIC_SITE_URL`; se verificó manualmente que usan `https://www.sitaa.net/check-in/...`.
- Cloudflare administra DNS. Los registros CNAME dirigidos a Vercel deben permanecer en modo **DNS only**, sin proxy de Cloudflare.
- El archivo de ejemplo puede documentar `NEXT_PUBLIC_SITE_URL=https://www.sitaa.net` porque es un origen público, no un secreto; los valores efectivos se controlan por entorno en Vercel.

## Auditoría y operación

- Auditar cambios de rol, correcciones de asistencia, cierres, exportaciones y acciones administrativas.
- No guardar tokens, secretos, respuestas completas ni datos sensibles innecesarios en logs.
- Definir respaldo, restauración, retención y respuesta a incidentes antes del piloto.
- Verificar periódicamente límites, copias disponibles y condiciones de los planes gratuitos; no asumir que equivalen a un SLA institucional.

## Validaciones previas al piloto

- Revisión de privacidad y aviso correspondiente.
- Pruebas negativas de RLS entre roles, grupos y periodos.
- Revisión del flujo QR frente a reuso, captura y concurrencia.
- Prueba de exportaciones con caracteres especiales y fórmulas.
- Procedimiento documentado para baja de usuarios e incidentes.
