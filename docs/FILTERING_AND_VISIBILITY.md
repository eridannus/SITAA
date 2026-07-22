# Filtrado y visibilidad

**Estado funcional:** reglas generales aprobadas; B.1 implementada y reconciliada mediante 0007; barrera operativa B.2a aplicada y reconciliada mediante 0008.

## Regla central

> La autorización determina el conjunto visible. El filtrado sólo organiza o reduce ese conjunto. Un filtro nunca concede acceso adicional.

RLS, helpers y RPC autorizadas construyen el universo visible. Después se aplican filtros validados en servidor/base. Nunca se descargan registros no autorizados para ocultarlos sólo en el cliente.

El estado de cuenta es una frontera previa a cualquier conjunto operativo. Si el perfil no está activo y compatible, el conjunto visible de actividades y participantes es vacío antes de aplicar rol, alcance o filtros; las RPC `SECURITY DEFINER` aplican la misma barrera para no depender sólo de RLS o de la vigencia del JWT.

## Secuencia de consulta

1. autenticar la sesión;
2. comprobar cuenta activa;
3. resolver identidad y asignaciones vigentes;
4. aplicar RLS o una RPC que calcule visibilidad;
5. validar filtros permitidos para esa vista;
6. filtrar, ordenar y paginar el conjunto ya autorizado;
7. devolver sólo campos necesarios.

Ocultar un selector porque tiene una sola opción es una decisión de UX. La ausencia del selector no reemplaza la restricción del servidor.

## Conjuntos visibles

| Actor | Universo antes de filtrar |
| --- | --- |
| Alumno | Actividades creadas/propias permitidas y aquellas donde está registrado o participa; nunca padrones ajenos. |
| Profesor ordinario | Actividades propias o donde participa; no adquiere tutoría/asesoría por programa principal. |
| Tutor par | Conjunto básico más sus tutorías del programa asignado. |
| Profesor tutor/asesor | Conjunto básico más sus actividades del servicio y programa asignados. |
| Lead de programa | Actividades del servicio y programa de su asignación. |
| Coordinación de programa | Lectura de actividades/reportes del programa. |
| Secretaría técnica de programa | Lectura del programa y actividades propias autorizadas. |
| Roles divisionales | Actividades autorizadas de Diseño Gráfico y Arquitectura. |
| `technical_admin` | Excepción amplia transitoria sobre contenido publicado; se retirará en la fase E. |

Los borradores siguen siendo exclusivos de su creador, incluso para roles de programa, división o administración técnica.

## Filtros reutilizables

- semestre;
- servicio de tutoría/asesoría;
- estado de actividad;
- tipo de actividad;
- fecha inicial/final;
- relación: `created_by_me`, `organized_by_me`, `participating`;
- programa, sólo si el conjunto visible puede incluir más de uno;
- responsable, sólo si el usuario ya puede ver esas actividades;
- búsqueda de participante, sólo dentro de un padrón que el usuario puede administrar.

El texto de búsqueda de participantes no forma parte de tarjetas públicas ni amplía visibilidad de perfiles.

## Comportamiento por contexto

- Alumnos filtran sus actividades visibles por semestre, servicio, estado y fecha.
- Profesores ordinarios usan los mismos filtros sobre su conjunto propio.
- Roles de programa pueden añadir responsable, tipo, categoría y dimensiones relevantes del programa.
- Roles de división reciben una opción de programa con **Todos** (`all`), **Diseño Gráfico** (`graphic_design`) y **Arquitectura** (`architecture`).
- Si sólo existe un programa permitido, se muestra como información o se omite el selector; el servidor fija el valor autorizado.
- Los reportes reutilizan el mismo estado de filtros, pero cada reporte define sus campos y agregaciones permitidos.

## Estado de filtros propuesto

Modelo conceptual, no código ejecutable:

```text
ActivityFilterState
  semesterIds: string[]
  serviceCodes: (tutoring | advising)[]
  statusCodes: string[]
  activityTypeCodes: string[]
  startDate: YYYY-MM-DD | null
  endDate: YYYY-MM-DD | null
  relationships: (created_by_me | organized_by_me | participating)[]
  programIds: string[]
  responsibleProfileId: string | null
  query: string
  sort: start_date_asc | start_date_desc | created_at_desc
  page: positive integer
  pageSize: bounded integer
```

Reglas:

- estado serializable en query string para paneles y reportes;
- valores vacíos significan «sin restricción adicional», nunca «sin autorización»;
- códigos desconocidos se rechazan o ignoran de forma explícita;
- fechas usan valores ISO en transporte y DD/MM/YYYY en interfaz;
- `programIds` se intersecta con programas autorizados;
- `responsibleProfileId` se acepta sólo en contextos con lectura multiusuario;
- `pageSize` tiene un máximo del servidor;
- el servidor construye consultas parametrizadas y no interpola texto en SQL.

## Participantes e identidad

- El alumno nunca recibe una lista para buscar a otros participantes.
- Un responsable autorizado busca sólo perfiles elegibles para el programa/actividad.
- Identificador institucional y correo sólo se devuelven cuando son necesarios para seleccionar o administrar el padrón.
- Los filtros generales de actividades no incluyen identificadores personales.

## RLS y RPC

- Las consultas directas permanecen sujetas a RLS.
- Una RPC `SECURITY DEFINER` debe validar al llamador antes de construir el conjunto visible.
- Los filtros de programa, servicio o rol no sustituyen `auth.uid()`, asignación, vigencia ni alcance.
- La paginación y los conteos deben ejecutarse después de autorización para no filtrar existencia de registros ajenos.
- Los errores no deben revelar que existe una actividad, perfil o asignación fuera de alcance.

## Criterios de prueba

- Manipular query params no amplía resultados.
- `all` en programa sólo funciona para un rol con más de un programa visible.
- Un profesor sin rol académico no obtiene actividades del programa por seleccionar su programa principal.
- Un alumno no puede filtrar por otro responsable para descubrir actividades ajenas.
- La búsqueda de participantes falla sin permiso de roster.
- Conteos, exportaciones y reportes coinciden con el mismo universo autorizado.
- El servidor no envía filas prohibidas aunque el cliente oculte controles.

## Directorio administrativo B.1

**Estado:** implementado, verificado y operativo.

El conjunto se construye sólo después de verificar perfil activo y asignación actual exacta `technical_admin/system/technical` sin programa/división. La interfaz y todas las RPC repiten el control; los filtros nunca son autoridad. La vigencia usa fechas calendario inclusivas de `America/Mexico_City`, tanto en Next.js como en 0007, sin depender de la zona horaria de la sesión PostgreSQL.

Secuencia específica:

1. verificar autoridad B.1;
2. normalizar y validar texto/filtros;
3. devolver cero filas si no existe ningún criterio;
4. aplicar consulta acento-insensible de 2 a 200 caracteres sobre nombre, correo o identificador, escapando `\`, `%` y `_` como literales;
5. aplicar programa, cuenta, estado y persona;
6. aplicar rol, servicio y alcance sobre la misma fila actual de `role_assignments`;
7. ordenar por apellido paterno, apellido materno, nombres y UUID;
8. paginar en base de datos con 20 filas por defecto y máximo 50;
9. devolver sólo la proyección minimizada y el identificador enmascarado.

Los valores desconocidos se rechazan explícitamente. La paginación conserva los filtros en la URL. Una cuenta inactiva puede tener una fila de asignación actual para clasificación histórica, pero esa fila no se describe como autorización efectiva.
