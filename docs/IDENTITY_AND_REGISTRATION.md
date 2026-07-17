# Identidad y registro

**Estado funcional:** Fase A implementada en código y migración 0004; migración pendiente de aplicación.

**Documento canónico:** esta especificación sustituye las reglas de identidad y registro incompatibles o incompletas de documentos anteriores. No crea SQL ni habilita todavía el registro público.

## Principio central

La identidad responde «¿quién es la persona o cuenta?». La autorización responde «¿qué puede hacer, para qué servicio y dentro de qué alcance?». `profiles` describe identidad; `role_assignments` describe permisos. Cambiar una responsabilidad nunca cambia la identidad base.

## Categorías de cuenta

| `account_kind` | Registro | `person_type` | Identificador institucional | Programa principal |
| --- | --- | --- | --- | --- |
| `institutional` | Público, con verificación de correo | `student` o `professor`, exclusivos | Obligatorio | Obligatorio |
| `technical` | Sólo administrativo | No aplica | No aplica | No aplica |

Una cuenta institucional normal no puede ser simultáneamente alumno y profesor. Una cuenta técnica interna no debe fingir ser alumno o profesor ni recibir identificador o programa ficticios.

## Dos flujos públicos separados

SITAA ofrecerá dos rutas principales; no se usará un selector alumno/profesor como experiencia principal:

### `/register/student`

- nombre completo;
- correo electrónico;
- número de cuenta UNAM;
- programa académico;
- contraseña y confirmación según las reglas de Supabase Auth.

El perfil se crea como `account_kind = institutional`, `person_type = student` e `institutional_id_type = student_account`. El alta básica no concede `peer_tutor`.

### `/register/professor`

- nombre completo;
- correo electrónico;
- número de trabajador UNAM;
- programa académico principal;
- contraseña y confirmación según las reglas de Supabase Auth.

El perfil se crea como `account_kind = institutional`, `person_type = professor` e `institutional_id_type = worker_number`. El alta básica no concede tutoría, asesoría, coordinación ni jefatura.

Los formularios pueden capturar nombres y apellidos por separado para derivar `full_name`, pero la experiencia debe explicar claramente el nombre completo esperado.

## Identificadores institucionales

- Se almacenan como texto y sólo admiten dígitos ASCII (`0–9`).
- Nunca se convierten a número; deben conservar ceros iniciales.
- El valor normalizado elimina espacios exteriores, pero no modifica los dígitos.
- `student` exige `student_account`; `professor` exige `worker_number`.
- El número de trabajador permanece asociado a la persona aunque cambie su responsabilidad o adscripción institucional.
- La unicidad se aplica al par (`institutional_id_type`, `institutional_id_value`). Un número de cuenta y un número de trabajador pueden compartir la misma cadena de dígitos; dos identificadores del mismo tipo no pueden repetirla.
- Corregir tipo o valor requiere validación de unicidad y una acción auditada de `technical_admin`.
- Desactivar una cuenta no libera el identificador para otra persona.

La aplicación no ofrece un endpoint público para comprobar disponibilidad. Los conflictos se resuelven durante el alta y se presentan con un mensaje sanitizado.

## Programa principal

- El alumno pertenece a un programa académico.
- El profesor tiene una afiliación principal o predeterminada.
- `primary_program_id` sirve para identidad, valores predeterminados y presentación; por sí solo no concede gestión académica.
- Una asignación autorizada puede tener un programa distinto del principal cuando la matriz de permisos lo permita explícitamente.
- La cuenta técnica interna no requiere programa.

## Verificación y activación

1. El usuario completa uno de los dos formularios.
2. Supabase Auth crea la identidad con correo sin confirmar.
3. SITAA conserva un perfil pendiente sin roles elevados.
4. El usuario confirma el correo mediante el enlace seguro.
5. La cuenta institucional pasa automáticamente a `active`; no requiere aprobación administrativa para acceso básico.
6. El acceso básico se deriva de `person_type`; las responsabilidades adicionales se asignan después.

Estados implementados por 0004:

- `pending_verification`: Auth aún no confirma el correo; no puede operar.
- `active`: correo confirmado, perfil completo y cuenta habilitada.
- `inactive`: cuenta desactivada administrativamente; no puede iniciar sesión ni operar.

La transición de verificación debe ser idempotente. No debe crear duplicados de perfil o asignaciones.

## Cuenta técnica interna

La cuenta `technical`:

- se crea mediante un proceso administrativo confiable;
- usa un correo verificable, pero no registro público;
- no tiene número de cuenta, número de trabajador ni programa;
- puede recibir `technical_admin` mediante asignación auditada;
- puede activarse, desactivarse y transferirse a otra persona sin reutilizar identidades;
- no obtiene acceso académico implícito en el modelo final.

Durante desarrollo, `technical_admin` conserva temporalmente el acceso académico amplio documentado en A-02. Es una excepción de transición, no el objetivo de seguridad.

Bootstrap controlado pendiente de operación: una persona autorizada crea el usuario Auth mediante una herramienta administrativa confiable, fija `app_metadata.sitaa_account_kind = technical`, verifica que el perfil resultante no tenga identidad institucional y asigna `technical_admin` mediante el procedimiento auditado de la fase correspondiente. Nunca se ejecuta desde un formulario público, nunca se autoasigna y 0004 no incorpora ninguna cuenta concreta.

## Separación de cuentas del desarrollador

El modelo admite dos cuentas independientes para una misma persona responsable del desarrollo:

- cuenta institucional: `institutional + professor`, correo institucional, número de trabajador, programa principal y acceso básico de profesor;
- cuenta personal técnica: `technical`, sin identidad institucional ni programa, con asignación `technical_admin`.

La cuenta institucional no recibe permisos de comité por el hecho de desarrollar SITAA. La cuenta técnica no debe presentarse como profesor.

## Corrección de identidad

En la fase administrativa inicial, sólo `technical_admin` puede corregir:

- clasificación alumno/profesor;
- identificador y tipo institucional;
- programa principal;
- estado activo/inactivo.

El usuario puede mantener datos personales no críticos que se definan posteriormente, pero no debe cambiar por autoservicio su clasificación, identificador principal, programa o roles. Toda corrección conserva auditoría de actor, fecha, motivo y valores de control; los logs no deben copiar innecesariamente el identificador completo.

## Reglas de privacidad

- Los identificadores no aparecen en URLs, QR ni listas generales de actividades.
- Sólo gestores autorizados del padrón pueden ver nombres e identificadores de participantes.
- Los mensajes de registro, recuperación y reenvío no deben revelar si un correo o identificador ya existe.
- Ningún nombre, correo o identificador personal se incorpora a semillas SQL.
- Auth y perfil deben permanecer sincronizados sin exponer llaves administrativas al navegador.

Supabase Auth puede resumir un fallo de trigger como error genérico de alta. La aplicación reconoce causas específicas cuando el SDK las conserva y, en caso contrario, muestra un fallo sanitizado. No se añade una consulta anónima de disponibilidad porque permitiría enumerar identificadores; la confirmación definitiva de unicidad siempre ocurre en la transacción de registro.

## Implementación de Fase A

`0004_identity_registration_foundation.sql` reutiliza `person_type`, `institutional_id_type`, `institutional_id_value` y `primary_program_id`; transforma determinísticamente `worker` en `professor` y añade `account_kind`, `account_status`, `activated_at` y `deactivated_at`. La migración está creada pero no aplicada.

El alta usa metadata de registro limitada y un trigger auditado sobre `auth.users`. El trigger deriva `account_kind`, tipo de identificador y estado, valida programa activo, no crea roles y falla la transacción Auth ante identidad inválida. Las cuentas técnicas sólo pueden originarse mediante `app_metadata` de un proceso administrativo confiable; 0004 no crea ninguna.

Antes de aplicar 0004 es obligatorio ejecutar el preflight. Identificadores de prototipo no numéricos, duplicados, perfiles incompletos o inconsistencias Auth/profile detienen la migración y requieren remediación humana.
