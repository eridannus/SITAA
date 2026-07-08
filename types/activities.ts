import type {
  AcademicPeriod, ActivityModality, ActivityStatus, ActivityType,
  AttentionCategory, LocationType, ServiceType,
} from "@/types/catalogs";
import type { AcademicProgram, Division } from "@/types/sitaa";

export type DurationMode = "one_hour" | "two_hours" | "custom";
export type ActivityScopeType = "program" | "division";

export interface Activity {
  id: string;
  title: string;
  description: string | null;
  academic_period_id: string | null;
  scope_type: ActivityScopeType;
  division_id: string;
  program_id: string | null;
  activity_type_code: string;
  service_type_code: string;
  attention_category_code: string | null;
  modality_code: string;
  location_type_code: string | null;
  location_detail: string | null;
  start_date: string | null;
  start_time: string | null;
  end_date: string | null;
  end_time: string | null;
  duration_mode: DurationMode | null;
  starts_at: string | null;
  ends_at: string | null;
  responsible_profile_id: string;
  created_by: string;
  status_code: string;
  created_at?: string;
  updated_at?: string;
}

export interface ActivityFormOptions {
  academicPeriods: AcademicPeriod[];
  programs: AcademicProgram[];
  divisions: Division[];
  activityTypes: ActivityType[];
  serviceTypes: ServiceType[];
  attentionCategories: AttentionCategory[];
  modalities: ActivityModality[];
  statuses: ActivityStatus[];
  locationTypes: LocationType[];
}

export interface ActivityScopeAccess {
  allowedPrograms: AcademicProgram[];
  canUseDivisionScope: boolean;
  divisionScopeId: string | null;
}

export interface ActivityFormValues {
  title: string;
  scope_type: string;
  description: string;
  program_id: string;
  activity_type_code: string;
  service_type_code: string;
  attention_category_code: string;
  modality_code: string;
  location_type_code: string;
  location_detail: string;
  start_date: string;
  start_time: string;
  duration_mode: string;
  end_date: string;
  end_time: string;
}

export type ActivityFormField = keyof ActivityFormValues | "academic_period_id" | "division_id";
export interface ActivityFormState {
  revision: number;
  values: ActivityFormValues;
  errors: Partial<Record<ActivityFormField, string>>;
  message: string | null;
}

export interface ActivityListItem extends Activity {
  academicPeriodLabel: string | null;
  programName: string;
  activityTypeLabel: string;
  serviceTypeLabel: string;
  attentionCategoryLabel: string | null;
  modalityLabel: string;
  statusLabel: string;
  locationTypeLabel: string | null;
  responsibleName: string;
  canEdit: boolean;
  isParticipant: boolean;
  ownParticipantRoleLabel: string | null;
}

