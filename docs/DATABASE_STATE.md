# Estado conocido de base de datos

**Estado:** pendiente de reconciliar contra Supabase vivo.

Este documento resume los módulos de base de datos conocidos por la aplicación y la documentación de SITAA. No sustituye una migración SQL baseline ni debe tratarse como definición exacta del esquema.

## Módulos conocidos

### Health check

Existe una verificación básica de conexión con Supabase mediante una tabla pública de salud del sistema.

### Roles y asignaciones de rol

SITAA usa un catálogo de roles y asignaciones múltiples en el tiempo. Los perfiles no almacenan un rol fijo. Las asignaciones consideran vigencia, alcance, área de servicio y relación con programa, división o sistema.

### Perfiles

Los perfiles representan identidad institucional estable: nombres, apellidos, nombre completo, correo, tipo de persona, identificador institucional y programa académico principal. El semestre no pertenece al perfil.

### Divisiones y programas académicos

El modelo distingue divisiones y programas académicos. En el MVP, las actividades operativas pertenecen a un programa específico, principalmente Diseño Gráfico o Arquitectura.

### Periodos académicos / semestres

`academic_periods` representa semestres oficiales. SITAA asigna el semestre automáticamente desde la fecha de inicio de la actividad usando rangos registrados y reglas institucionales.

### Catálogos operativos

SITAA usa catálogos controlados para tipos de actividad, tipos de servicio, categorías de atención, modalidades, estados, tipos de ubicación y roles de participante.

### Actividades

`activities` es el núcleo operativo. Registra planeación, programa, división, responsable, fechas, horarios, duración, estado y campos relacionados con el semestre.

### Participantes de actividad

`activity_participants` vincula actividades con perfiles SITAA registrados y un rol de participante. No se admiten participantes libres de texto como flujo normal.

### Asistencia manual

La asistencia puede actualizarse manualmente por responsables o editores autorizados. Los estados conocidos son `pending`, `attended`, `absent` y `justified`; `pending` es temporal.

### Tokens de asistencia por QR/código

SITAA usa tokens de check-in para confirmar asistencia mediante QR, enlace directo o código de tres palabras. Estos mecanismos sólo aplican a participantes ya registrados.

### Expiración y reapertura de asistencia

La asistencia normal puede abrirse desde 15 minutos antes del inicio de la actividad y cerrar 15 minutos después del término. Después del cierre normal, usuarios autorizados pueden reabrir asistencia por ventanas extraordinarias de 15 minutos. La expiración convierte pendientes vencidos en `absent` con fuente `system` conforme a funciones de Supabase.

## Reconciliación pendiente

La baseline debe verificar contra Supabase vivo al menos:

- Tablas y columnas reales.
- Claves primarias, foráneas, índices y restricciones.
- Triggers y funciones RPC.
- Políticas RLS.
- Catálogos mínimos requeridos.
- Permisos de ejecución de funciones.
- Diferencias entre prototipo y documentación actual.

Cualquier discrepancia debe resolverse antes de declarar al repositorio como fuente de verdad completa para la base de datos.
