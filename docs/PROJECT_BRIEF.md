# Resumen del proyecto

## Identidad

**SITAA** significa **Sistema Integral de Tutorías y Asesorías Académicas**. Será una aplicación web institucional para planear, registrar, consultar y evaluar tutorías y asesorías académicas.

## Problema

Los procesos suelen depender de formularios aislados, hojas de cálculo y evidencias dispersas. Esto dificulta comprobar asistencia, dar seguimiento semestral, controlar quién puede consultar información y obtener reportes consistentes.

## Objetivo

Centralizar el ciclo operativo de tutorías y asesorías, desde la planeación hasta el reporte, con registros configurables, trazabilidad y acceso determinado por asignaciones de rol temporales, alcance institucional y área de servicio.

## Usuarios principales

- Alumnos y alumnos tutores pares, cuyas responsabilidades pueden cambiar entre periodos.
- Profesores tutores o asesores que planean y documentan actividades asignadas.
- Responsables de tutorías o asesorías de carrera que coordinan su programa y configuran formularios de su área.
- Enlaces y jefaturas que supervisan programas o divisiones dentro de su alcance.
- Secretarios técnicos con acceso exclusivamente logístico.
- Administradores técnicos responsables de configuración, sin acceso académico sensible implícito.

Una persona puede tener varias asignaciones activas o históricas. Los permisos no forman parte fija del perfil: dependen del rol asignado, su vigencia, alcance (`own`, `program`, `division`, `system`) y área de servicio (`tutoring`, `advising`, `both`, `logistics`, `technical`).

## Capacidades previstas

- Planeación por semestre.
- Registro configurable de sesiones de tutoría o asesoría.
- Asistencia mediante código QR.
- Encuestas de satisfacción.
- Paneles según asignaciones y alcance.
- Exportación CSV y reportes institucionales básicos.
- Formularios configurables en una fase posterior.

## Plataforma prevista

- Next.js con App Router y TypeScript.
- Tailwind CSS para estilos.
- Supabase Free para PostgreSQL, Auth, Storage y RLS.
- Vercel Free para despliegue.
- GitHub como control de versiones y GitKraken como cliente visual.

## Principios

- Seguridad y privacidad desde el diseño.
- Mínimo privilegio según vigencia, alcance y área de servicio.
- Configuración institucional sin sacrificar integridad de datos.
- Experiencia sencilla en móvil para asistencia y encuestas.
- Alcance compatible con los límites de los planes gratuitos.
- Reportes reproducibles a partir de datos estructurados.

## Medidas iniciales de éxito

- Una sesión puede planearse, realizarse y cerrarse sin recurrir a archivos externos.
- La asistencia queda asociada a estudiante, sesión, hora y método de registro.
- Cada usuario accede solo a lo permitido por sus asignaciones vigentes.
- El vencimiento de una asignación elimina sus permisos sin borrar su historial.
- Coordinación puede exportar resultados dentro de su alcance autorizado.
- Los indicadores básicos coinciden con los registros fuente.