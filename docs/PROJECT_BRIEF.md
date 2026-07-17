# Resumen del proyecto

## Identidad

**SITAA** significa **Sistema Integral de Tutorías y Asesorías Académicas**. Es una aplicación web institucional para planear, registrar, consultar y evaluar actividades de tutoría y asesoría académica.

## Problema

Los procesos suelen depender de formularios aislados y hojas de cálculo. Esto dificulta comprobar participación y asistencia, dar seguimiento semestral y obtener reportes consistentes con acceso controlado.

## Objetivo

Centralizar el ciclo operativo, desde la planeación hasta el reporte, mediante actividades, participantes registrados, asistencia, formularios dinámicos versionados y permisos derivados de asignaciones de rol.

## Usuarios principales

- Alumnos y alumnos tutores pares, cuyas responsabilidades pueden cambiar entre periodos.
- Profesores tutores o asesores que planean y documentan actividades asignadas.
- Responsables de tutorías o asesorías que coordinan programas y formularios de su área.
- Enlaces y jefaturas que supervisan programas o divisiones dentro de su alcance.
- Secretarios técnicos con acceso exclusivamente logístico.
- Administradores técnicos responsables de configuración, sin acceso académico sensible implícito.

Una persona puede tener varias asignaciones activas o históricas. Los permisos dependen del rol, vigencia, alcance (`own`, `program`, `division`, `system`) y área de servicio (`tutoring`, `advising`, `both`, `logistics`, `technical`).

## Identidad y registro

El modelo canónico de esta materia se define en `docs/IDENTITY_AND_REGISTRATION.md`. El perfil conserva nombres, apellidos, correo, tipo de persona, identificador institucional y programa principal cuando aplique. No conserva un rol ni semestre actual.

SITAA deberá ofrecer dos flujos institucionales diferenciados:

- **Alumno:** nombre, programa y número de cuenta; Google aporta el correo verificado.
- **Profesor:** nombre, programa principal y número de trabajador; Google aporta el correo verificado.

El registro público usa Google OAuth sin restricción de dominio y sin scopes elevados. Las cuentas técnicas internas son una excepción administrativa: no usan el registro público ni requieren identificador o programa académico. Completar identidad después de Google activa una cuenta básica, pero no concede funciones académicas: el alumno no se vuelve tutor par y el profesor no se vuelve tutor o asesor sin una asignación autorizada.

## Alcance funcional

- Planeación semestral y registro de actividades.
- Participantes vinculados exclusivamente a perfiles registrados en SITAA.
- Registro/invitación de participantes separado de la confirmación de asistencia.
- Asistencia con corrección manual obligatoria y mecanismos futuros por QR, enlace directo o código corto de tres palabras.
- Formularios dinámicos similares a Google Forms, con campos configurables y versiones inmutables.
- Tablas, resúmenes y gráficas filtrables.
- Exportaciones CSV y reportes PDF.
- Paneles según asignaciones y alcance.

## Evidencia producida por SITAA

SITAA genera evidencia interna estructurada:

- registros de actividades;
- participantes registrados;
- registros de asistencia;
- respuestas de formularios dinámicos;
- resúmenes, exportaciones CSV y reportes PDF.

SITAA **no almacena ni administra evidencia documental externa**, como carteles, fotografías, oficios, materiales, carpetas de Drive o enlaces para indicadores. Esos documentos permanecen bajo responsabilidad de los actores institucionales fuera de la plataforma.

## Plataforma prevista

- Next.js con App Router y TypeScript.
- Tailwind CSS para estilos.
- Supabase Free para PostgreSQL, Auth y RLS.
- Vercel Free para despliegue.
- GitHub como control de versiones y GitKraken como cliente visual.

## Principios

- Seguridad, privacidad y mínimo privilegio desde el diseño.
- Los campos académicos obligatorios son una decisión colegiada, no de desarrollo.
- Integridad histórica mediante formularios versionados.
- Participación y asistencia basadas en identidades registradas.
- Reportes reproducibles a partir de datos estructurados.
- Alcance compatible con los límites de los planes gratuitos.

## Medidas iniciales de éxito

- Una actividad puede planearse, realizarse y reportarse dentro de SITAA.
- Cada participante y asistencia queda vinculada a un perfil institucional.
- Las respuestas permanecen asociadas a la versión exacta del formulario utilizado.
- Los usuarios autorizados pueden consultar y exportar información dentro de su alcance.
- Los indicadores coinciden con los registros fuente del sistema.
