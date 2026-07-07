# Resumen del proyecto

## Identidad

**SITAA** significa **Sistema Integral de Tutorías y Asesorías Académicas**. Será una aplicación web institucional para planear, registrar, consultar y evaluar tutorías y asesorías académicas.

## Problema

Los procesos suelen depender de formularios aislados, hojas de cálculo y evidencias dispersas. Esto dificulta comprobar asistencia, dar seguimiento semestral, controlar quién puede consultar información y obtener reportes consistentes.

## Objetivo

Centralizar el ciclo operativo de tutorías y asesorías, desde la planeación hasta el reporte, con registros configurables, trazabilidad, acceso por rol y controles de privacidad.

## Usuarios principales

- Estudiantes que consultan actividades, registran asistencia y responden encuestas.
- Tutores o asesores que planean y documentan sesiones.
- Coordinadores que administran periodos, supervisan operación y generan reportes.
- Administradores que configuran catálogos, usuarios, roles y parámetros institucionales.

## Capacidades previstas

- Planeación por semestre.
- Registro configurable de sesiones de tutoría o asesoría.
- Asistencia mediante código QR.
- Encuestas de satisfacción.
- Paneles según rol.
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
- Configuración institucional sin sacrificar integridad de datos.
- Experiencia sencilla en móvil para asistencia y encuestas.
- Alcance compatible con los límites de los planes gratuitos.
- Reportes reproducibles a partir de datos estructurados.

## Medidas iniciales de éxito

- Una sesión puede planearse, realizarse y cerrarse sin recurrir a archivos externos.
- La asistencia queda asociada a estudiante, sesión, hora y método de registro.
- Cada rol solo accede a los datos necesarios para su función.
- Coordinación puede exportar resultados de un periodo en CSV.
- Los indicadores básicos coinciden con los registros fuente.
