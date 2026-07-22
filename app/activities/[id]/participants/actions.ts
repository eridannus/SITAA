"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { getActivityAttendanceDeadline } from "@/lib/activities/get-attendance-checkin";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Activity } from "@/types/activities";
import type { AttendanceStatus, ParticipantMutationState, ParticipantSearchState, ParticipationProfileSearchResult } from "@/types/participants";
import type { InstitutionalIdType, PersonType } from "@/types/sitaa";

const attendanceStatuses = new Set<AttendanceStatus>(["pending", "attended", "absent", "justified"]);
const personTypes = new Set<PersonType>(["student", "professor"]);
const institutionalIdTypes = new Set<InstitutionalIdType>(["student_account", "worker_number"]);

function normalizePersonType(value: unknown): PersonType | null {
  return typeof value === "string" && personTypes.has(value as PersonType) ? value as PersonType : null;
}

function normalizeInstitutionalIdType(value: unknown): InstitutionalIdType | null {
  return typeof value === "string" && institutionalIdTypes.has(value as InstitutionalIdType) ? value as InstitutionalIdType : null;
}

async function isAttendanceWindowExpired(activityId: string) {
  const deadline = await getActivityAttendanceDeadline(activityId);
  return deadline.hasPassed;
}

function pendingAfterExpirationError() {
  return "La ventana de asistencia ya terminó. No es posible dejar registros en Pendiente.";
}

async function requireEditor(activityId: string) {
  const context = await getAuthenticatedUserContext();
  if (!context) redirect("/login?error=sesion-requerida");
  if (context.error || !context.profile) return null;
  const supabase = await createSupabaseServerClient();
  const [activityResult, editPermission] = await Promise.all([
    supabase.from("activities").select("*").eq("id", activityId).maybeSingle(),
    supabase.rpc("can_edit_activity", { target_activity_id: activityId }),
  ]);
  if (
    activityResult.error ||
    !activityResult.data ||
    editPermission.error ||
    editPermission.data !== true
  ) return null;
  const activity = activityResult.data as Activity;
  if (activity.status_code === "draft") return null;
  return { supabase, activity };
}

type SearchRow = {
  profile_id?: string; id?: string; full_name?: string | null; email?: string | null;
  person_type?: string | null;
  institutional_id_type?: string | null; institutional_id_value?: string | null;
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
  const results: ParticipationProfileSearchResult[] = rows.flatMap((row) => {
    const personType = normalizePersonType(row.person_type);
    const institutionalIdType = normalizeInstitutionalIdType(row.institutional_id_type);
    const profileId = row.profile_id ?? row.id ?? "";

    // El RPC sólo debe devolver perfiles institucionales válidos. Si una fila
    // heredada llega incompleta, no se infiere que sea alumno ni se ofrecen
    // controles de participación con identidad inventada.
    if (!profileId || !personType || !institutionalIdType) {
      return [];
    }

    return [{
      profile_id: profileId,
      full_name: row.full_name?.trim() || "Perfil sin nombre",
      email: row.email?.trim() || "Correo no disponible",
      person_type: personType,
      institutional_id_type: institutionalIdType,
      institutional_id_value: row.institutional_id_value?.trim() || "No disponible",
      primary_program_id: row.primary_program_id ?? null,
      program_name: row.program_name?.trim() || (row.primary_program_id ? programMap.get(row.primary_program_id) ?? "Programa no disponible" : "Programa no asignado"),
    }];
  });
  return { query, results, error: null };
}

function addErrorMessage(error: { code?: string; message?: string; details?: string; hint?: string }) {
  const text = [error.code, error.message, error.details, error.hint].filter(Boolean).join(" ").toLowerCase();
  const normalizedText = text.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  if (/solo un (trabajador|profesor) puede registrarse como responsable|(trabajador|profesor).*responsable/.test(normalizedText)) return "Sólo un profesor puede registrarse como responsable de la actividad.";
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
  if (status === "pending" && await isAttendanceWindowExpired(activityId)) return { error: pendingAfterExpirationError() };

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
  if (status === "pending" && await isAttendanceWindowExpired(activityId)) return { error: pendingAfterExpirationError() };

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
