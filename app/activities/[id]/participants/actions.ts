"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { canManageActivityScope } from "@/lib/activities/activity-scope-permissions";
import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Activity, ActivityFormValues } from "@/types/activities";
import type { AttendanceStatus, ParticipantMutationState, ParticipantSearchState, ParticipationProfileSearchResult } from "@/types/participants";
import type { InstitutionalIdType } from "@/types/sitaa";

const attendanceStatuses = new Set<AttendanceStatus>(["pending", "attended", "absent", "justified"]);

function activityValues(activity: Activity): ActivityFormValues {
  return {
    title: activity.title, scope_type: activity.scope_type, description: activity.description ?? "",
    program_id: activity.program_id ?? "", activity_type_code: activity.activity_type_code ?? "",
    service_type_code: activity.service_type_code ?? "", attention_category_code: activity.attention_category_code ?? "",
    modality_code: activity.modality_code ?? "", location_type_code: activity.location_type_code ?? "",
    location_detail: activity.location_detail ?? "", start_date: activity.start_date ?? "",
    start_time: activity.start_time ?? "", duration_mode: activity.duration_mode ?? "custom",
    end_date: activity.end_date ?? "", end_time: activity.end_time ?? "",
  };
}

async function requireEditor(activityId: string) {
  const context = await getAuthenticatedUserContext();
  if (!context) redirect("/login?error=sesion-requerida");
  if (context.error || !context.profile) return null;
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.from("activities").select("*").eq("id", activityId).maybeSingle();
  if (error || !data) return null;
  const activity = data as Activity;
  if (activity.scope_type !== "program" || !activity.program_id) return null;
  const options = await getActivityFormOptions();
  if (!canManageActivityScope(context, activityValues(activity), options.programs, activity.division_id)) return null;
  return { supabase, activity };
}

type SearchRow = {
  profile_id?: string; id?: string; full_name?: string | null; email?: string | null;
  institutional_id_type?: InstitutionalIdType | null; institutional_id_value?: string | null;
  primary_program_id?: string | null; program_id?: string | null;
  program_name?: string | null; academic_program_name?: string | null;
};

export async function searchParticipationProfiles(activityId: string, _previous: ParticipantSearchState, formData: FormData): Promise<ParticipantSearchState> {
  const queryValue = formData.get("search_text");
  const query = typeof queryValue === "string" ? queryValue.trim() : "";
  if (query.length < 2) return { query, results: [], error: "Escribe al menos dos caracteres para buscar." };
  const editor = await requireEditor(activityId);
  if (!editor) return { query, results: [], error: "No tienes permiso para buscar participantes en esta actividad." };

  const { data, error } = await editor.supabase.rpc("search_profiles_for_participation", {
    target_activity_id: activityId,
    search_text: query,
  });
  if (error) {
    const rawError = [error.code, error.message, error.details, error.hint].filter(Boolean).join(" ");
    const normalizedError = rawError.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();

    if (error.code === "42501" || /permission|not authorized|row-level|rls|permiso|autorizad/.test(normalizedError)) {
      return { query, results: [], error: "No tienes permiso para buscar participantes en esta actividad." };
    }

    if (/actividad.*no tiene.*programa|sin programa|programa academico asignado/.test(normalizedError)) {
      return { query, results: [], error: "La actividad no tiene programa académico asignado." };
    }

    return { query, results: [], error: "No fue posible realizar la búsqueda de participantes." };
  }

  const rows = (data ?? []) as SearchRow[];
  const programIds = [...new Set(rows.map((row) => row.primary_program_id ?? row.program_id).filter((id): id is string => Boolean(id)))];
  const programsResult = programIds.length ? await editor.supabase.from("academic_programs").select("id, name").in("id", programIds) : { data: [] as { id: string; name: string }[], error: null };
  const programMap = new Map((programsResult.data ?? []).map((program) => [program.id, program.name]));
  const results: ParticipationProfileSearchResult[] = rows.map((row) => ({
    profile_id: row.profile_id ?? row.id ?? "",
    full_name: row.full_name?.trim() || "Perfil sin nombre",
    email: row.email?.trim() || "Correo no disponible",
    institutional_id_type: row.institutional_id_type ?? "student_account",
    institutional_id_value: row.institutional_id_value?.trim() || "No disponible",
    primary_program_id: row.primary_program_id ?? null,
    program_name: row.program_name?.trim() || (row.primary_program_id ? programMap.get(row.primary_program_id) ?? "Programa no disponible" : "Programa no asignado"),
  })).filter((row) => Boolean(row.profile_id));
  return { query, results, error: null };
}

function addErrorMessage(error: { code?: string; message?: string; details?: string; hint?: string }) {
  const text = [error.code, error.message, error.details, error.hint].filter(Boolean).join(" ").toLowerCase();
  const normalizedText = text.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  if (/otro programa academico/.test(normalizedText)) return "La persona seleccionada pertenece a otro programa académico.";
  if (error.code === "23505" || /duplicate|already|ya (está|esta)|registrad/.test(text)) return "Esta persona ya está registrada en la actividad.";
  if (error.code === "42501" || /permission|not authorized|row-level|rls|permiso|autorizad/.test(text)) return "No tienes permiso para agregar participantes a esta actividad.";
  return "No fue posible agregar a la persona. Intenta nuevamente.";
}

function attendanceErrorMessage(error: { code?: string; message?: string; details?: string; hint?: string }) {
  const text = [error.code, error.message, error.details, error.hint].filter(Boolean).join(" ").toLowerCase();
  const normalizedText = text.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  if (error.code === "42501" || /permission|not authorized|row-level|rls|permiso|autorizad/.test(normalizedText)) {
    return "No tienes permiso para modificar la asistencia de esta actividad.";
  }
  return "No fue posible actualizar la asistencia.";
}

export async function addActivityParticipant(
  activityId: string,
  _previous: ParticipantMutationState,
  formData: FormData,
): Promise<ParticipantMutationState> {
  const profileId = formData.get("profile_id");
  const roleCode = formData.get("participant_role_code");
  const participantProgramId = formData.get("participant_primary_program_id");
  if (typeof profileId !== "string" || !profileId || typeof roleCode !== "string" || !roleCode) {
    return { error: "Selecciona un perfil registrado y un rol de participante." };
  }

  const editor = await requireEditor(activityId);
  if (!editor) return { error: "No tienes permiso para agregar participantes a esta actividad." };

  if (typeof participantProgramId === "string" && participantProgramId && editor.activity.program_id && participantProgramId !== editor.activity.program_id) {
    return { error: "La persona seleccionada pertenece a otro programa académico." };
  }

  const { error } = await editor.supabase.rpc("add_activity_participant", {
    target_activity_id: activityId,
    target_profile_id: profileId,
    target_participant_role_code: roleCode,
  });
  if (error) return { error: addErrorMessage(error) };

  revalidatePath("/activities");
  revalidatePath(`/activities/${activityId}`);
  redirect(`/activities/${activityId}?participant=added#participants`);
}

export async function updateParticipantAttendance(
  activityId: string,
  participantId: string,
  _previous: ParticipantMutationState,
  formData: FormData,
): Promise<ParticipantMutationState> {
  const status = formData.get("attendance_status");
  const notesValue = formData.get("attendance_notes");
  const notes = typeof notesValue === "string" ? notesValue.trim() : "";

  if (typeof status !== "string" || !attendanceStatuses.has(status as AttendanceStatus)) {
    return { error: "Selecciona un estado de asistencia válido." };
  }
  if (notes.length > 1000) return { error: "Las notas no pueden exceder 1000 caracteres." };

  const editor = await requireEditor(activityId);
  if (!editor) return { error: "No tienes permiso para modificar la asistencia de esta actividad." };

  const { error } = await editor.supabase.rpc("update_activity_participant_attendance", {
    target_participant_id: participantId,
    new_attendance_status: status,
    new_attendance_notes: notes || null,
  });
  if (error) return { error: attendanceErrorMessage(error) };

  revalidatePath("/activities");
  revalidatePath(`/activities/${activityId}`);
  redirect(`/activities/${activityId}?participant=attendance-updated#participants`);
}


export async function updateParticipantsAttendanceBulk(
  activityId: string,
  _previous: ParticipantMutationState,
  formData: FormData,
): Promise<ParticipantMutationState> {
  const participantIds = formData
    .getAll("participant_ids")
    .filter((value): value is string => typeof value === "string" && Boolean(value));
  const status = formData.get("attendance_status");

  if (!participantIds.length) return { error: "Selecciona al menos un participante." };
  if (typeof status !== "string" || !attendanceStatuses.has(status as AttendanceStatus)) {
    return { error: "Selecciona un estado de asistencia válido." };
  }

  const editor = await requireEditor(activityId);
  if (!editor) return { error: "No tienes permiso para modificar la asistencia de esta actividad." };

  const { error } = await editor.supabase.rpc("update_activity_participants_attendance_bulk", {
    target_activity_id: activityId,
    target_participant_ids: participantIds,
    new_attendance_status: status,
    new_attendance_notes: null,
  });
  if (error) return { error: attendanceErrorMessage(error) };

  revalidatePath("/activities");
  revalidatePath(`/activities/${activityId}`);
  redirect(`/activities/${activityId}?participant=attendance-updated#participants`);
}
export async function removeActivityParticipant(activityId: string, participantId: string, formData: FormData) {
  if (formData.get("confirmation") !== "confirmed") redirect(`/activities/${activityId}?participant=remove-error#participants`);
  const editor = await requireEditor(activityId);
  if (!editor) redirect(`/activities/${activityId}?participant=remove-forbidden#participants`);

  const { error } = await editor.supabase.rpc("remove_activity_participant", {
    target_participant_id: participantId,
  });
  if (error) {
    const text = [error.code, error.message, error.details].filter(Boolean).join(" ").toLowerCase();
    const code = /permission|not authorized|row-level|rls|permiso|autorizad/.test(text) ? "remove-forbidden" : "remove-error";
    redirect(`/activities/${activityId}?participant=${code}#participants`);
  }

  revalidatePath("/activities");
  revalidatePath(`/activities/${activityId}`);
  redirect(`/activities/${activityId}?participant=removed#participants`);
}
