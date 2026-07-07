import type {
  AcademicPeriod,
  ActivityModality,
  ActivityStatus,
  ActivityType,
  AttentionCategory,
  LocationType,
  ServiceType,
} from "@/types/catalogs";
import type { AcademicProgram } from "@/types/sitaa";

export interface Activity {
  id: string;
  title: string;
  description: string | null;
  academic_period_id: string | null;
  program_id: string;
  activity_type_code: string;
  service_type_code: string;
  attention_category_code: string | null;
  modality_code: string;
  location_type_code: string | null;
  location_detail: string | null;
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
  activityTypes: ActivityType[];
  serviceTypes: ServiceType[];
  attentionCategories: AttentionCategory[];
  modalities: ActivityModality[];
  statuses: ActivityStatus[];
  locationTypes: LocationType[];
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
}