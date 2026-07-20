# SITAA

Sistema Integral de Tutorías y Asesorías Académicas.

## Requisitos

- Node.js compatible con la versión de Next.js indicada en `package.json`.
- npm.

## Comandos

```bash
npm install
npm run dev
```

La aplicación estará disponible en [http://localhost:3000](http://localhost:3000).

Otros comandos útiles:

```bash
npm run lint   # Revisa la calidad del código
npm run check:ui # Detecta patrones visuales prohibidos
npm run build  # Genera la compilación de producción
npm run start  # Inicia la compilación de producción
```

## Rutas iniciales

- `/`: puerta compacta de autenticación con identidad visual azul y oro.
- `/health`: comprobación básica del servicio; muestra `SITAA OK`.
- `/supabase-test`: verifica la configuración y consulta `public.system_health`.
- `/login`: Google como acceso principal y correo/contraseña heredado como opción secundaria.
- `/register`: elección de registro de alumno o profesor.
- `/register/student` y `/register/professor`: inicio Google sin capturar PII institucional.
- `/auth/callback`: intercambio PKCE y selección de la ruta de finalización.
- `/complete-registration`: selector para perfiles Google con registro pendiente.
- `/complete-registration/student` y `/complete-registration/professor`: identidad institucional autenticada de tipo fijo.
- `/dashboard`: panel protegido con perfil institucional y asignaciones de rol activas.
- `/catalogs`: visor protegido de catálogos operativos activos.
- `/profile`: edición protegida de nombre(s) y apellidos estructurados.
- `/activities`: listado protegido de actividades visibles.
- `/activities/new`: alta protegida de una actividad básica.
- `/admin/accounts`: directorio administrativo protegido y de sólo lectura, preparado para B.1.
- `/admin/accounts/[id]`: detalle administrativo de cuenta, asignaciones V1 e historial sanitizado.

## Configuración de Supabase

Copia `.env.example` como `.env.local` y completa las variables públicas del proyecto:

```env
NEXT_PUBLIC_SUPABASE_URL=https://tu-proyecto.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_clave_anon_publica
```

La clave `anon` es pública y está sujeta a las políticas RLS. No agregues claves `service_role` ni secretos al repositorio.

## Autenticación

El acceso público usa Google OAuth con cookies SSR; correo/contraseña permanece sólo para cuentas heredadas. El registro no restringe dominios ni requiere SMTP. Google, 0004 y 0005 están configurados, aplicados y verificados. El callback autorizado de producción es `https://www.sitaa.net/auth/callback`.

El registro autentica primero con Google y sólo después solicita identidad institucional. No existe escritura anónima ni consulta de disponibilidad de identificadores; tampoco asigna tutoría, asesoría, tutoría par o administración. Las cuentas técnicas no usan formularios públicos.

Después de configurar `.env.local`, inicia la aplicación y abre `/login`. Los usuarios no autenticados que intenten visitar `/dashboard`, `/catalogs`, `/profile` o `/activities` serán enviados al inicio de sesión.

La Fase A de identidad y Google OAuth está operativa. El snapshot `2026-07-18T04:05:40Z` quedó reconciliado contra 0001–0006 sin deriva inexplicada. 0006 está aplicada y verificada: los nombres personales estructurados son autoritativos y `full_name` se conserva como compatibilidad derivada. La migración 0007 del directorio B.1 está aplicada y la aplicación compatible está publicada. Su primera verificación se detuvo antes de crear fixtures por un defecto del arnés ya corregido localmente; la reejecución, los smoke tests y la reconciliación post-0007 permanecen pendientes.

La navegación autenticada usa avatar Google validado o iniciales, menú de cuenta accesible y estados seleccionados de alto contraste. El acceso público emplea una tarjeta única que cabe en el viewport; el fondo canvas es decorativo, pausa en pestañas ocultas y respeta movimiento reducido.

El sistema visual canónico está en `docs/DESIGN_SYSTEM.md`. Toda interfaz usa la identidad azul y oro y reserva el verde exclusivamente para estados semánticos de éxito. Antes de entregar cambios visuales es obligatorio ejecutar `npm run check:ui`.

## Alcance actual

Esta etapa incluye autenticación, perfiles, asignaciones de rol, catálogos, actividades, participantes y asistencia manual o por QR/enlace/código. El dashboard aún no aplica paneles especializados por rol y los formularios dinámicos, reportes y exportaciones permanecen pendientes. La definición del producto se encuentra en `docs/`.
