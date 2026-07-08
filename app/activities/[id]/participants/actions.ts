"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { canManageActivityScope } from "@/lib/activities/activity-scope-permissions";
import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Activity, ActivityFormValues } from "@/types/activities";
import type { ParticipantSearchState, ParticipationProfileSearchResult } from "@/types/participants";
import type { InstitutionalIdType } from "@/types/sitaa";

function activityValues(activity: Activity): ActivityFormValues {
  return {
    title: activity.title, scope_type: activity.scope_type, description: activity.description ?? "",
    program_id: activity.program_id ?? "", activity_type_code: activity.activity_type_code,
    service_type_code: activity.service_type_code, attention_category_code: activity.attention_category_code ?? "",
    modality_code: activity.modality_code, location_type_code: activity.location_type_code ?? "",
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
  const options = await getActivityFormOptions();
  if (!canManageActivityScope(context, activityValues(activity), options.programs, activity.division_id)) return null;
  return { context, supabase };
}

type SearchRow = {
  profile_id?: string;
  id?: string;
  full_name?: string | null;
  email?: string | null;
  institutional_id_type?: InstitutionalIdType | null;
  institutional_id_value?: string | null;
  primary_program_id?: string | null;
  program_name?: string | null;
};

export async function searchParticipationProfiles(
  activityId: string,
  _previous: ParticipantSearchState,
  formData: FormData,
): Promise<ParticipantSearchState> {
  const queryValue = formData.get("search_text");
  const query = typeof queryValue === "string" ? queryValue.trim() : "";
  if (query.length < 2) return { query, results: [], error: "Escribe al menos dos caracteres para buscar." };

  const editor = await requireEditor(activityId);
  if (!editor) return { query, results: [], error: "No tienes permiso para agregar participantes." };

  const { data, error } = await editor.supabase.rpc("search_profiles_for_participation", { search_text: query });
  if (error) return { query, results: [], error: "No fue posible buscar perfiles. Intenta nuevamente." };

  const rows = (data ?? []) as SearchRow[];
  const programIds = [...new Set(rows.map((row) => row.primary_program_id).filter((id): id is string => Boolean(id)))];
  const programsResult = programIds.length
    ? await editor.supabase.from("academic_programs").select("id, name").in("id", programIds)
    : { data: [] as { id: string; name: string }[], error: null };
  const programMap = new Map((programsResult.data ?? []).map((program) => [program.id, program.name]));

  const results: ParticipationProfileSearchResult[] = rows
    .map((row) => ({
      profile_id: row.profile_id ?? row.id ?? "",
      full_name: row.full_name?.trim() || "Perfil sin nombre",
      email: row.email?.trim() || "Correo no disponible",
      institutional_id_type: row.institutional_id_type ?? "student_account",
      institutional_id_value: row.institutional_id_value?.trim() || "No disponible",
      primary_program_id: row.primary_program_id ?? null,
      program_name: row.program_name?.trim() || (row.primary_program_id ? programMap.get(row.primary_program_id) ?? "Programa no disponible" : "Programa no asignado"),
    }))
    .filter((row) => Boolean(row.profile_id));

  return { query, results, error: null };
}

export async function addActivityParticipant(activityId: string, formData: FormData) {
  const profileId = formData.get("profile_id");
  const roleCode = formData.get("participant_role_code");
  if (typeof profileId !== "string" || !profileId || typeof roleCode !== "string" || !roleCode) {
    redirect(`/activities/${activityId}?participant=invalid`);
  }

  const editor = await requireEditor(activityId);
  if (!editor) redirect(`/activities/${activityId}?participant=forbidden`);

  const [{ data: existing, error: duplicateError }, { data: role, error: roleError }] = await Promise.all([
    editor.supabase.from("activity_participants").select("id").eq("activity_id", activityId).eq("profile_id", profileId).maybeSingle(),
    editor.supabase.from("participant_roles").select("code, is_active").eq("code", roleCode).maybeSingle(),
  ]);
  if (duplicateError || roleError) redirect(`/activities/${activityId}?participant=error`);
  if (existing) redirect(`/activities/${activityId}?participant=duplicate`);
  if (!role || role.is_active === false) redirect(`/activities/${activityId}?participant=invalid`);

  const { error } = await editor.supabase.from("activity_participants").insert({
    activity_id: activityId,
    profile_id: profileId,
    participant_role_code: roleCode,
    created_by: editor.context.user.id,
  });
  if (error?.code === "23505") redirect(`/activities/${activityId}?participant=duplicate`);
  if (error) redirect(`/activities/${activityId}?participant=error`);

  revalidatePath("/activities");
  revalidatePath(`/activities/${activityId}`);
  redirect(`/activities/${activityId}?participant=added`);
}

export async function removeActivityParticipant(activityId: string, participantId: string, formData: FormData) {
  if (formData.get("confirmation") !== "confirmed") redirect(`/activities/${activityId}?participant=remove-error`);
  const editor = await requireEditor(activityId);
  if (!editor) redirect(`/activities/${activityId}?participant=forbidden`);

  const { data, error } = await editor.supabase
    .from("activity_participants")
    .delete()
    .eq("id", participantId)
    .eq("activity_id", activityId)
    .select("id")
    .maybeSingle();
  if (error || !data) redirect(`/activities/${activityId}?participant=remove-error`);

  revalidatePath("/activities");
  revalidatePath(`/activities/${activityId}`);
  redirect(`/activities/${activityId}?participant=removed`);
}
