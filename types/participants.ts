import type { InstitutionalIdType } from "@/types/sitaa";

export type AttendanceStatus = "pending" | "attended" | "absent" | "justified";
export type AttendanceSource = "system" | "manual" | "qr" | "code";

export interface ActivityParticipant {
  id: string;
  activity_id: string;
  profile_id: string;
  participant_role_code: string;
  attendance_status: AttendanceStatus | null;
  attendance_source: AttendanceSource | null;
  checked_in_at: string | null;
  attendance_updated_by: string | null;
  attendance_updated_at: string | null;
  attendance_notes: string | null;
  created_by?: string | null;
  created_at?: string;
}

export interface ActivityParticipantDisplay extends ActivityParticipant {
  full_name: string;
  email: string;
  institutional_id_type: InstitutionalIdType;
  institutional_id_value: string;
  program_name: string;
  participant_role_label: string;
}

export interface ParticipationProfileSearchResult {
  profile_id: string;
  full_name: string;
  email: string;
  institutional_id_type: InstitutionalIdType;
  institutional_id_value: string;
  primary_program_id: string | null;
  program_name: string;
}

export interface ParticipantMutationState {
  error: string | null;
}

export interface ParticipantSearchState {
  query: string;
  results: ParticipationProfileSearchResult[];
  error: string | null;
}
