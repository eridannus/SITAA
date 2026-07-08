import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { ActivityParticipantDisplay } from "@/types/participants";
import type { InstitutionalIdType } from "@/types/sitaa";

type ParticipantRpcRow = {
  id?: string;
  participant_id?: string;
  activity_id?: string;
  profile_id?: string;
  participant_role_code?: string;
  role_code?: string;
  full_name?: string | null;
  email?: string | null;
  institutional_id_type?: InstitutionalIdType | null;
  institutional_id_value?: string | null;
  program_name?: string | null;
  academic_program_name?: string | null;
  participant_role_label?: string | null;
  role_label?: string | null;
  created_by?: string | null;
  created_at?: string;
};

export async function getActivityParticipants(activityId: string): Promise<ActivityParticipantDisplay[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("get_activity_participants", {
    target_activity_id: activityId,
  });
  if (error) throw new Error("No fue posible cargar participantes.");

  return ((data ?? []) as ParticipantRpcRow[]).map((row) => {
    const roleCode = row.participant_role_code ?? row.role_code ?? "participant";
    return {
      id: row.participant_id ?? row.id ?? "",
      activity_id: row.activity_id ?? activityId,
      profile_id: row.profile_id ?? "",
      participant_role_code: roleCode,
      created_by: row.created_by ?? null,
      created_at: row.created_at,
      full_name: row.full_name?.trim() || "Perfil sin nombre",
      email: row.email?.trim() || "Correo no disponible",
      institutional_id_type: row.institutional_id_type ?? "student_account",
      institutional_id_value: row.institutional_id_value?.trim() || "No disponible",
      program_name: row.program_name?.trim() || row.academic_program_name?.trim() || "Programa no asignado",
      participant_role_label: row.participant_role_label?.trim() || row.role_label?.trim() || roleCode,
    };
  }).filter((row) => Boolean(row.id && row.profile_id));
}
