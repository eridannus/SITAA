import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { ActivityParticipant, ActivityParticipantDisplay } from "@/types/participants";
import type { CatalogRow } from "@/types/catalogs";
import type { AcademicProgram, Profile } from "@/types/sitaa";

function catalogLabel(item: CatalogRow | undefined, fallback: string) {
  return item?.label?.trim() || item?.name?.trim() || fallback;
}

export async function getActivityParticipants(activityId: string): Promise<ActivityParticipantDisplay[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("activity_participants")
    .select("*")
    .eq("activity_id", activityId)
    .order("created_at", { ascending: true });

  if (error) throw new Error("No fue posible cargar participantes.");
  const rows = (data ?? []) as ActivityParticipant[];
  if (!rows.length) return [];

  const profileIds = [...new Set(rows.map((row) => row.profile_id))];
  const roleCodes = [...new Set(rows.map((row) => row.participant_role_code))];
  const [profilesResult, rolesResult] = await Promise.all([
    supabase.from("profiles").select("id, full_name, email, institutional_id_type, institutional_id_value, primary_program_id").in("id", profileIds),
    supabase.from("participant_roles").select("*").in("code", roleCodes),
  ]);
  if (profilesResult.error || rolesResult.error) throw new Error("No fue posible completar la información de participantes.");

  const profiles = (profilesResult.data ?? []) as Pick<Profile, "id" | "full_name" | "email" | "institutional_id_type" | "institutional_id_value" | "primary_program_id">[];
  const programIds = [...new Set(profiles.map((profile) => profile.primary_program_id).filter((id): id is string => Boolean(id)))];
  const programsResult = programIds.length
    ? await supabase.from("academic_programs").select("id, name").in("id", programIds)
    : { data: [] as Pick<AcademicProgram, "id" | "name">[], error: null };
  if (programsResult.error) throw new Error("No fue posible cargar los programas de participantes.");

  const profileMap = new Map(profiles.map((profile) => [profile.id, profile]));
  const programMap = new Map(((programsResult.data ?? []) as Pick<AcademicProgram, "id" | "name">[]).map((program) => [program.id, program.name]));
  const roleMap = new Map(((rolesResult.data ?? []) as CatalogRow[]).map((role) => [role.code, role]));

  return rows.map((row) => {
    const profile = profileMap.get(row.profile_id);
    return {
      ...row,
      full_name: profile?.full_name || "Perfil sin nombre",
      email: profile?.email || "Correo no disponible",
      institutional_id_type: profile?.institutional_id_type ?? "student_account",
      institutional_id_value: profile?.institutional_id_value || "No disponible",
      program_name: profile?.primary_program_id ? programMap.get(profile.primary_program_id) ?? "Programa no disponible" : "Programa no asignado",
      participant_role_label: catalogLabel(roleMap.get(row.participant_role_code), row.participant_role_code),
    };
  });
}
