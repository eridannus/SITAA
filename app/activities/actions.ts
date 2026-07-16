"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { canManageActivityScope, getActivityScopeAccess } from "@/lib/activities/activity-scope-permissions";
import {
  getPublicationScheduleRejectionErrors,
  PUBLICATION_SCHEDULE_MESSAGE,
  validateActivityForm,
} from "@/lib/activities/activity-form-validation";
import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { isValidDate, isValidTime, toMexicoCityTimestamp } from "@/lib/activities/date-time";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { ActivityFormField, ActivityFormState, ActivityFormValues } from "@/types/activities";

const ONLINE_MODALITY_CODE = "online";
const ONLINE_LOCATION_TYPE_CODE = "online_space";

type AcademicPeriodRpcResult = string | {
  id?: string | null;
  code?: string | null;
  label?: string | null;
  name?: string | null;
} | null;

type PublicationErrorCode = "permission" | "semester" | "schedule" | "validation" | "generic";

const publicationMessages: Record<PublicationErrorCode, string> = {
  permission: "No tienes permiso para publicar esta actividad.",
  semester: "No fue posible publicar la actividad porque no hay un semestre válido para la fecha de inicio.",
  schedule: PUBLICATION_SCHEDULE_MESSAGE,
  validation: "La actividad permanece como borrador. Revisa que todos los datos requeridos estén completos y sean válidos.",
  generic: "No fue posible publicar la actividad. El borrador se conservó para que puedas revisarlo.",
};

function publicationError(error: { code?: string; message?: string } | null) {
  const message = error?.message?.toLocaleLowerCase("es-MX") ?? "";
  let code: PublicationErrorCode = "generic";
  if (error?.code === "42501" || message.includes("sólo el creador") || message.includes("permiso")) {
    code = "permission";
  } else if (message.includes("semestre") || message.includes("academic_period")) {
    code = "semester";
  } else if (message.includes("posteriores a la hora actual")) {
    code = "schedule";
  } else if (error?.code === "23514" || message.includes("selecciona") || message.includes("indica")) {
    code = "validation";
  }
  return { code, message: publicationMessages[code] };
}

async function publishDraft(
  supabase: Awaited<ReturnType<typeof createSupabaseServerClient>>,
  activityId: string,
) {
  const { data, error } = await supabase.rpc("publish_activity", {
    target_activity_id: activityId,
  });
  if (error) return publicationError(error);
  const first = Array.isArray(data) ? data[0] : data;
  const returnedStatus = first && typeof first === "object" && "status_code" in first ? first.status_code : null;
  if (returnedStatus !== "scheduled") {
    return publicationError(null);
  }
  return null;
}

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
function activityIntent(formData: FormData) {
  const value = formData.get("activity_intent");
  return value === "draft" || value === "publish" || value === "validate_publish" ? value : "save";
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
  return { revision: previous.revision + 1, values, errors, message, confirmPublish: false };
}
async function saveActivity(activityId: string | null, previous: ActivityFormState, formData: FormData): Promise<ActivityFormState> {
  const values = valuesFrom(formData);
  const intent = activityIntent(formData);
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
        .select("id, scope_type, division_id, created_by, status_code")
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
  if (values.modality_code === ONLINE_MODALITY_CODE) values.location_type_code = ONLINE_LOCATION_TYPE_CODE;
  else if (values.location_type_code === ONLINE_LOCATION_TYPE_CODE) values.location_type_code = "";

  const willPublish = intent === "publish" || intent === "validate_publish";
  if (willPublish && existingActivity && (existingActivity.status_code !== "draft" || existingActivity.created_by !== context.user.id)) {
    return invalid(previous, values, {}, "Sólo el creador puede publicar una actividad que permanezca en borrador.");
  }
  const willRemainDraft = !willPublish && (activityId ? existingActivity?.status_code === "draft" : true);
  const requireOperationalFields = !willRemainDraft;
  const result = validateActivityForm(values, {
    enforceFutureStartDate: willPublish,
    requireOperationalFields,
  });
  if (Object.keys(result.errors).length) return invalid(previous, values, result.errors);

  const selectedProgram = options.programs.find((item) => item.id === values.program_id);
  const divisionId = selectedProgram?.division_id ?? null;
  if (!divisionId) {
    return invalid(previous, values, { program_id: "Selecciona un programa académico válido." }, "Revisa el programa seleccionado.");
  }
  if (!legacyCleanup && requireOperationalFields && !canManageActivityScope(context, values, options.programs, divisionId)) {
    return invalid(previous, values, { scope_type: "Tus asignaciones no permiten este alcance y tipo de servicio." }, "No tienes permiso para guardar la actividad con esta combinación.");
  }
  if (!legacyCleanup && !requireOperationalFields && !access.allowedPrograms.some((program) => program.id === values.program_id)) {
    return invalid(previous, values, { program_id: "Tus asignaciones no permiten este programa." }, "No tienes permiso para guardar el borrador en este programa.");
  }

  const checks: Array<[ActivityFormField, boolean]> = [["program_id", Boolean(selectedProgram)]];
  if (values.activity_type_code || requireOperationalFields) checks.push(["activity_type_code", options.activityTypes.some((item) => item.code === values.activity_type_code)]);
  if (values.service_type_code || requireOperationalFields) checks.push(["service_type_code", options.serviceTypes.some((item) => item.code === values.service_type_code)]);
  if (values.attention_category_code || requireOperationalFields) checks.push(["attention_category_code", options.attentionCategories.some((item) => item.code === values.attention_category_code)]);
  if (values.modality_code || requireOperationalFields) checks.push(["modality_code", options.modalities.some((item) => item.code === values.modality_code)]);
  if (values.location_type_code || requireOperationalFields) checks.push(["location_type_code", options.locationTypes.some((item) => item.code === values.location_type_code)]);
  for (const [field, valid] of checks) if (!valid) result.errors[field] = "La opción seleccionada ya no está disponible.";
  if (values.modality_code !== ONLINE_MODALITY_CODE && values.location_type_code === ONLINE_LOCATION_TYPE_CODE) {
    result.errors.location_type_code = "Selecciona un tipo de ubicación presencial o híbrido.";
  }
  if (Object.keys(result.errors).length) return invalid(previous, values, result.errors);

  const semester = values.start_date ? await getAcademicPeriodForDate(values.start_date) : { id: null, label: null, error: false };
  if (semester.error) {
    return invalid(previous, values, { academic_period_id: "No fue posible asignar el semestre." }, "No fue posible validar el semestre de la actividad.");
  }
  const academicPeriodId = semester.id;

  if (intent === "validate_publish") {
    return { revision: previous.revision + 1, values, errors: {}, message: null, confirmPublish: true };
  }

  // Toda alta se guarda primero como borrador. La única transición a scheduled
  // ocurre después mediante publish_activity, dentro de una transacción de base.
  const nextStatusCode = activityId ? existingActivity?.status_code ?? "draft" : "draft";

  const payload = {
    status_code: nextStatusCode,
    title: values.title,
    description: values.description || null,
    academic_period_id: academicPeriodId,
    scope_type: "program",
    division_id: divisionId,
    program_id: values.program_id,
    activity_type_code: values.activity_type_code || null,
    service_type_code: values.service_type_code || null,
    attention_category_code: values.attention_category_code || null,
    modality_code: values.modality_code || null,
    location_type_code: values.location_type_code || null,
    location_detail: values.location_detail || null,
    start_date: values.start_date || null,
    start_time: values.start_time || null,
    end_date: result.endDate || null,
    end_time: result.endTime || null,
    duration_mode: result.durationMode,
    starts_at: isValidDate(values.start_date) && isValidTime(values.start_time) ? toMexicoCityTimestamp(values.start_date, values.start_time) : null,
    ends_at: isValidDate(result.endDate) && isValidTime(result.endTime) ? toMexicoCityTimestamp(result.endDate, result.endTime) : null,
  };
  if (activityId) {
    const { data: canUpdateBase, error: canUpdateBaseError } = await supabase.rpc("can_update_activity_base", { target_activity_id: activityId });
    if (canUpdateBaseError || canUpdateBase !== true) {
      return invalid(previous, values, {}, "Los datos base de esta actividad están bloqueados. Puedes actualizar participantes y asistencia.");
    }
    const { data, error } = await supabase.from("activities").update(payload).eq("id", activityId).select("id").maybeSingle();
    if (error || !data) return invalid(previous, values, {}, "No fue posible actualizar la actividad. Verifica tus permisos e intenta nuevamente.");
    if (intent === "publish") {
      const errorResult = await publishDraft(supabase, activityId);
      if (errorResult) {
        const fieldErrors = errorResult.code === "schedule"
          ? getPublicationScheduleRejectionErrors(values)
          : {};
        return invalid(previous, values, fieldErrors, errorResult.message);
      }
      revalidatePath("/activities");
      revalidatePath(`/activities/${activityId}`);
      revalidatePath(`/activities/${activityId}`, "page");
      redirect(`/activities/${activityId}?published=1`);
    }
    revalidatePath("/activities"); revalidatePath(`/activities/${activityId}`); revalidatePath(`/activities/${activityId}`, "page"); redirect(`/activities/${activityId}?updated=1#attendance-checkin`);
  }
  const { data: inserted, error } = await supabase
    .from("activities")
    .insert({ ...payload, responsible_profile_id: context.profile.id, created_by: context.user.id })
    .select("id")
    .maybeSingle();
  if (error || !inserted) return invalid(previous, values, {}, "No fue posible crear la actividad. Verifica tus permisos e intenta nuevamente.");
  if (intent === "publish") {
    const errorResult = await publishDraft(supabase, inserted.id);
    if (errorResult) {
      revalidatePath("/activities");
      revalidatePath(`/activities/${inserted.id}`);
      redirect(`/activities/${inserted.id}?publication_error=${errorResult.code}`);
    }
  }
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
