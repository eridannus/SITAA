"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { canManageActivityScope, getActivityScopeAccess } from "@/lib/activities/activity-scope-permissions";
import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { calculatePresetEnd, getMexicoCityToday, isValidDate, isValidTime, toMexicoCityTimestamp } from "@/lib/activities/date-time";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { ActivityFormField, ActivityFormState, ActivityFormValues, DurationMode } from "@/types/activities";

const durationModes = new Set<DurationMode>(["one_hour", "two_hours", "custom"]);

type AcademicPeriodRpcResult = string | {
  id?: string | null;
  code?: string | null;
  label?: string | null;
  name?: string | null;
} | null;

function normalizeAcademicPeriodResult(data: unknown) {
  const rows = Array.isArray(data) ? data : (data ? [data] : []);
  const first = rows[0] as AcademicPeriodRpcResult | undefined;
  if (!first) return { id: null, label: null };
  if (typeof first === "string") return { id: first, label: first };
  const id = first.id?.trim() || null;
  const label = first.label?.trim() || first.name?.trim() || first.code?.trim() || id;
  return { id, label };
}

async function getAcademicPeriodForDate(targetDate: string) {
  if (!isValidDate(targetDate)) return { id: null, label: null, error: true };
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("get_academic_period_for_date", { target_date: targetDate });
  if (error) return { id: null, label: null, error: true };
  return { ...normalizeAcademicPeriodResult(data), error: false };
}

export async function resolveAcademicSemester(targetDate: string) {
  const result = await getAcademicPeriodForDate(targetDate);
  return { label: result.label, error: result.error };
}
function text(formData: FormData, field: keyof ActivityFormValues) {
  const value = formData.get(field);
  return typeof value === "string" ? value.trim() : "";
}
function valuesFrom(formData: FormData): ActivityFormValues {
  return {
    title: text(formData, "title").replace(/\s+/g, " "),
    scope_type: text(formData, "scope_type"),
    description: text(formData, "description"),
    program_id: text(formData, "program_id"),
    activity_type_code: text(formData, "activity_type_code"),
    service_type_code: text(formData, "service_type_code"),
    attention_category_code: text(formData, "attention_category_code"),
    modality_code: text(formData, "modality_code"),
    location_type_code: text(formData, "location_type_code"),
    location_detail: text(formData, "location_detail"),
    start_date: text(formData, "start_date"),
    start_time: text(formData, "start_time"),
    duration_mode: text(formData, "duration_mode"),
    end_date: text(formData, "end_date"),
    end_time: text(formData, "end_time"),
  };
}
function invalid(previous: ActivityFormState, values: ActivityFormValues, errors: ActivityFormState["errors"], message = "Revisa los campos marcados antes de continuar."): ActivityFormState {
  return { revision: previous.revision + 1, values, errors, message };
}
function validate(values: ActivityFormValues, { enforceFutureStartDate }: { enforceFutureStartDate: boolean }) {
  const errors: Partial<Record<ActivityFormField, string>> = {};
  if (!values.title) errors.title = "Escribe el título de la actividad.";
  else if (values.title.length > 200) errors.title = "El título no puede exceder 200 caracteres.";
  if (values.description.length > 5000) errors.description = "La descripción no puede exceder 5000 caracteres.";
  if (values.scope_type !== "program" && values.scope_type !== "division") errors.scope_type = "Selecciona el alcance de la actividad.";
  if (values.scope_type === "program" && !values.program_id) errors.program_id = "Selecciona un programa académico.";
  if (!values.activity_type_code) errors.activity_type_code = "Selecciona un tipo de actividad.";
  if (!values.service_type_code) errors.service_type_code = "Selecciona un tipo de servicio.";
  if (!values.attention_category_code) errors.attention_category_code = "Selecciona una categoría de atención.";
  if (!values.modality_code) errors.modality_code = "Selecciona una modalidad.";
  if (!values.location_type_code) errors.location_type_code = "Selecciona un tipo de ubicación.";
  if (!values.location_detail) errors.location_detail = "Indica el lugar, aula o enlace de la actividad.";
  else if (values.location_detail.length > 500) errors.location_detail = "El detalle no puede exceder 500 caracteres.";
  if (!isValidDate(values.start_date)) errors.start_date = "Indica una fecha de inicio válida.";
  if (!isValidTime(values.start_time)) errors.start_time = "Indica una hora válida en formato de 24 horas.";
  if (!durationModes.has(values.duration_mode as DurationMode)) errors.duration_mode = "Selecciona una duración.";
  if (enforceFutureStartDate && isValidDate(values.start_date) && values.start_date < getMexicoCityToday()) errors.start_date = "La fecha de inicio no puede ser anterior a hoy.";

  let endDate = values.end_date;
  let endTime = values.end_time;
  const durationMode = values.duration_mode as DurationMode;
  if (durationMode === "custom") {
    if (!isValidDate(endDate)) errors.end_date = "Indica una fecha de término válida.";
    if (!isValidTime(endTime)) errors.end_time = "Indica una hora válida en formato de 24 horas.";
    if (isValidDate(values.start_date) && isValidDate(endDate)) {
      if (endDate < values.start_date) errors.end_date = "La fecha de término no puede ser anterior al inicio.";
      else if (endDate === values.start_date && isValidTime(values.start_time) && isValidTime(endTime) && endTime <= values.start_time) errors.end_time = "La hora de término debe ser posterior a la hora de inicio.";
    }
  } else if (durationMode === "one_hour" || durationMode === "two_hours") {
    const calculated = calculatePresetEnd(values.start_date, values.start_time, durationMode);
    if (calculated) { endDate = calculated.endDate; endTime = calculated.endTime; }
  }
  return { errors, endDate, endTime, durationMode };
}

async function saveActivity(activityId: string | null, previous: ActivityFormState, formData: FormData): Promise<ActivityFormState> {
  const values = valuesFrom(formData);
  const context = await getAuthenticatedUserContext();
  if (!context) redirect("/login?error=sesion-requerida");
  if (context.error || !context.profile) return invalid(previous, values, {}, "Tu cuenta necesita un perfil institucional activo.");

  let options;
  try { options = await getActivityFormOptions(); }
  catch { return invalid(previous, values, {}, "No fue posible validar los catálogos operativos."); }

  const supabase = await createSupabaseServerClient();
  const existingResult = activityId
    ? await supabase
        .from("activities")
        .select("id, scope_type, division_id, created_by")
        .eq("id", activityId)
        .maybeSingle()
    : { data: null, error: null };
  if (existingResult.error) {
    return invalid(previous, values, {}, "No fue posible validar la actividad existente.");
  }
  const existingActivity = existingResult.data;
  const isTechnicalAdmin = context.activeRoleAssignments.some(
    (item) => item.role_code === "technical_admin",
  );
  const legacyCleanup = Boolean(
    existingActivity?.scope_type === "division" &&
      (isTechnicalAdmin || existingActivity.created_by === context.user.id),
  );


  let access = getActivityScopeAccess(context, options.programs, options.divisions);
  if (legacyCleanup && existingActivity) {
    access = {
      ...access,
      allowedPrograms: options.programs.filter(
        (program) => program.division_id === existingActivity.division_id,
      ),
    };
  }
  if (!access.allowedPrograms.length) {
    return invalid(previous, values, { scope_type: "Tus asignaciones no permiten crear actividades." }, "No tienes permiso para crear o modificar actividades.");
  }

  values.scope_type = "program";
  if (access.allowedPrograms.length === 1) values.program_id = access.allowedPrograms[0].id;

  const result = validate(values, { enforceFutureStartDate: !activityId });
  if (Object.keys(result.errors).length) return invalid(previous, values, result.errors);

  const selectedProgram = options.programs.find((item) => item.id === values.program_id);
  const divisionId = selectedProgram?.division_id ?? null;
  if (!divisionId) {
    return invalid(previous, values, { program_id: "Selecciona un programa académico válido." }, "Revisa el programa seleccionado.");
  }
  if (!legacyCleanup && !canManageActivityScope(context, values, options.programs, divisionId)) {
    return invalid(previous, values, { scope_type: "Tus asignaciones no permiten este alcance y tipo de servicio." }, "No tienes permiso para guardar la actividad con esta combinación.");
  }

  const checks: Array<[ActivityFormField, boolean]> = [
    ["activity_type_code", options.activityTypes.some((item) => item.code === values.activity_type_code)],
    ["service_type_code", options.serviceTypes.some((item) => item.code === values.service_type_code)],
    ["attention_category_code", options.attentionCategories.some((item) => item.code === values.attention_category_code)],
    ["modality_code", options.modalities.some((item) => item.code === values.modality_code)],
    ["location_type_code", options.locationTypes.some((item) => item.code === values.location_type_code)],
  ];
  checks.push(["program_id", Boolean(selectedProgram)]);
  for (const [field, valid] of checks) if (!valid) result.errors[field] = "La opción seleccionada ya no está disponible.";
  if (Object.keys(result.errors).length) return invalid(previous, values, result.errors);

  const semester = await getAcademicPeriodForDate(values.start_date);
  if (semester.error) {
    return invalid(previous, values, { academic_period_id: "No fue posible asignar el semestre." }, "No fue posible validar el semestre de la actividad.");
  }
  const academicPeriodId = semester.id;

  const payload = {
    title: values.title,
    description: values.description || null,
    academic_period_id: academicPeriodId,
    scope_type: "program",
    division_id: divisionId,
    program_id: values.program_id,
    activity_type_code: values.activity_type_code,
    service_type_code: values.service_type_code,
    attention_category_code: values.attention_category_code,
    modality_code: values.modality_code,
    location_type_code: values.location_type_code,
    location_detail: values.location_detail,
    start_date: values.start_date,
    start_time: values.start_time,
    end_date: result.endDate,
    end_time: result.endTime,
    duration_mode: result.durationMode,
    starts_at: toMexicoCityTimestamp(values.start_date, values.start_time),
    ends_at: toMexicoCityTimestamp(result.endDate, result.endTime),
  };
  if (activityId) {
    const { data: canUpdateBase, error: canUpdateBaseError } = await supabase.rpc("can_update_activity_base", { target_activity_id: activityId });
    if (canUpdateBaseError || canUpdateBase !== true) {
      return invalid(previous, values, {}, "Los datos base de esta actividad est?n bloqueados. Puedes actualizar participantes y asistencia.");
    }
    const { data, error } = await supabase.from("activities").update(payload).eq("id", activityId).select("id").maybeSingle();
    if (error || !data) return invalid(previous, values, {}, "No fue posible actualizar la actividad. Verifica tus permisos e intenta nuevamente.");
    revalidatePath("/activities"); revalidatePath(`/activities/${activityId}`); redirect(`/activities/${activityId}?updated=1`);
  }
  const { error } = await supabase.from("activities").insert({ ...payload, responsible_profile_id: context.profile.id, created_by: context.user.id, status_code: "scheduled" });
  if (error) return invalid(previous, values, {}, "No fue posible crear la actividad. Verifica tus permisos e intenta nuevamente.");
  revalidatePath("/activities"); redirect("/activities?created=1");
}

export async function createActivity(previous: ActivityFormState, formData: FormData) { return saveActivity(null, previous, formData); }
export async function updateActivity(activityId: string, previous: ActivityFormState, formData: FormData) { return saveActivity(activityId, previous, formData); }
export async function deleteActivity(activityId: string, formData: FormData) {
  if (formData.get("confirmation") !== "confirmed") redirect(`/activities/${activityId}?error=delete`);
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?error=sesion-requerida");
  const { data: canDelete, error: canDeleteError } = await supabase.rpc("can_delete_activity", { target_activity_id: activityId });
  if (canDeleteError || canDelete !== true) redirect(`/activities/${activityId}?error=delete`);
  const { data, error } = await supabase.from("activities").delete().eq("id", activityId).select("id").maybeSingle();
  if (error || !data) redirect(`/activities/${activityId}?error=delete`);
  revalidatePath("/activities"); redirect("/activities?deleted=1");
}

