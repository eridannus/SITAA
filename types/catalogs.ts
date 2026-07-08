export interface CatalogRow {
  id: string;
  code: string;
  label?: string | null;
  name?: string | null;
  description?: string | null;
  is_active: boolean;
  sort_order?: number | null;
  created_at?: string;
  updated_at?: string;
}

export interface AcademicPeriod extends CatalogRow {
  start_date?: string | null;
  end_date?: string | null;
  starts_on?: string | null;
  ends_on?: string | null;
}

export type ActivityType = CatalogRow;

export type ServiceType = CatalogRow;

export type AttentionCategory = CatalogRow;

export type ActivityModality = CatalogRow;

export type ActivityStatus = CatalogRow;

export type LocationType = CatalogRow;

export type ParticipantRole = CatalogRow;

export interface OperationalCatalogs {
  academicPeriods: AcademicPeriod[];
  activityTypes: ActivityType[];
  serviceTypes: ServiceType[];
  attentionCategories: AttentionCategory[];
  activityModalities: ActivityModality[];
  activityStatuses: ActivityStatus[];
  locationTypes: LocationType[];
  participantRoles: ParticipantRole[];
}