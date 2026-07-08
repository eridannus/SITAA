import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Activity, ActivityListItem, ActivityScopeType, DurationMode } from "@/types/activities";
import type { CatalogRow } from "@/types/catalogs";

type VisibleActivityCardRow = Partial<Activity> & {
  activity_id?: string;
  program_name?: string | null;
  academic_period_label?: string | null;
  activity_type_label?: string | null;
  service_type_label?: string | null;
  attention_category_label?: string | null;
  modality_label?: string | null;
  status_label?: string | null;
  location_type_label?: string | null;
  responsible_full_name?: string | null;
  responsible_name?: string | null;
  can_edit?: boolean | null;
  is_participant?: boolean | null;
  participant_role_label?: string | null;
};

function label(item: CatalogRow | undefined, fallback: string) {
  return item?.label?.trim() || item?.name?.trim() || fallback;
}

export async function getVisibleActivities(): Promise<ActivityListItem[]> {
  const supabase = await createSupabaseServerClient();
  const [{ data, error }, options] = await Promise.all([
    supabase.rpc("get_visible_activity_cards"),
    getActivityFormOptions(),
  ]);
  if (error) throw new Error("No fue posible consultar las actividades.");

  const periods = new Map(options.academicPeriods.map((item) => [item.id, item]));
  const programs = new Map(options.programs.map((item) => [item.id, item]));
  const activityTypes = new Map(options.activityTypes.map((item) => [item.code, item]));
  const serviceTypes = new Map(options.serviceTypes.map((item) => [item.code, item]));
  const categories = new Map(options.attentionCategories.map((item) => [item.code, item]));
  const modalities = new Map(options.modalities.map((item) => [item.code, item]));
  const statuses = new Map(options.statuses.map((item) => [item.code, item]));
  const locations = new Map(options.locationTypes.map((item) => [item.code, item]));

  return ((data ?? []) as VisibleActivityCardRow[]).map((row) => {
    const id = row.id ?? row.activity_id ?? "";
    const scopeType = (row.scope_type ?? "program") as ActivityScopeType;
    const programId = row.program_id ?? null;
    const activityTypeCode = row.activity_type_code ?? "";
    const serviceTypeCode = row.service_type_code ?? "";
    const modalityCode = row.modality_code ?? "";
    const statusCode = row.status_code ?? "";
    const categoryCode = row.attention_category_code ?? null;
    const locationCode = row.location_type_code ?? null;
    return {
      id, title: row.title ?? "Actividad sin título", description: row.description ?? null,
      academic_period_id: row.academic_period_id ?? null, scope_type: scopeType,
      division_id: row.division_id ?? "", program_id: programId,
      activity_type_code: activityTypeCode, service_type_code: serviceTypeCode,
      attention_category_code: categoryCode, modality_code: modalityCode,
      location_type_code: locationCode, location_detail: row.location_detail ?? null,
      start_date: row.start_date ?? null, start_time: row.start_time ?? null,
      end_date: row.end_date ?? null, end_time: row.end_time ?? null,
      duration_mode: (row.duration_mode ?? null) as DurationMode | null,
      starts_at: row.starts_at ?? null, ends_at: row.ends_at ?? null,
      responsible_profile_id: row.responsible_profile_id ?? "", created_by: row.created_by ?? "",
      status_code: statusCode, created_at: row.created_at, updated_at: row.updated_at,
      academicPeriodLabel: row.academic_period_label?.trim() || (row.academic_period_id ? label(periods.get(row.academic_period_id), row.academic_period_id) : null),
      programName: row.program_name?.trim() || (scopeType === "division" ? "Alcance divisional reservado" : programId ? programs.get(programId)?.name ?? "Programa no disponible" : "Programa no asignado"),
      activityTypeLabel: row.activity_type_label?.trim() || label(activityTypes.get(activityTypeCode), activityTypeCode),
      serviceTypeLabel: row.service_type_label?.trim() || label(serviceTypes.get(serviceTypeCode), serviceTypeCode),
      attentionCategoryLabel: row.attention_category_label?.trim() || (categoryCode ? label(categories.get(categoryCode), categoryCode) : null),
      modalityLabel: row.modality_label?.trim() || label(modalities.get(modalityCode), modalityCode),
      statusLabel: row.status_label?.trim() || label(statuses.get(statusCode), statusCode),
      locationTypeLabel: row.location_type_label?.trim() || (locationCode ? label(locations.get(locationCode), locationCode) : null),
      responsibleName: row.responsible_full_name?.trim() || row.responsible_name?.trim() || "Responsable no disponible",
      canEdit: row.can_edit === true, isParticipant: row.is_participant === true,
      ownParticipantRoleLabel: row.participant_role_label?.trim() || null,
    };
  }).filter((activity) => Boolean(activity.id)).sort((left, right) =>
    (right.start_date ?? right.starts_at ?? right.created_at ?? "").localeCompare(left.start_date ?? left.starts_at ?? left.created_at ?? ""),
  );
}
