import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Activity, ActivityListItem, ActivityScopeType, DurationMode } from "@/types/activities";
import type { AttendanceSource, AttendanceStatus } from "@/types/participants";
import type { CatalogRow } from "@/types/catalogs";

type VisibleActivityCardRow = Partial<Activity> & {
  activity_id?: string;
  activity_program_id?: string | null;
  academic_program_id?: string | null;
  program_name?: string | null;
  program_label?: string | null;
  academic_program_name?: string | null;
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
  viewer_can_edit?: boolean | null;
  is_participant?: boolean | null;
  viewer_is_participant?: boolean | null;
  participant_role_label?: string | null;
  viewer_attendance_status?: AttendanceStatus | null;
  viewer_attendance_source?: AttendanceSource | null;
  viewer_checked_in_at?: string | null;
};

type ActivityProgramFallback = Pick<Activity, "id" | "scope_type" | "division_id" | "program_id">;

function label(item: CatalogRow | undefined, fallback: string) {
  return item?.label?.trim() || item?.name?.trim() || fallback;
}

function firstText(...values: Array<string | null | undefined>) {
  return values.map((value) => value?.trim()).find((value): value is string => Boolean(value)) ?? null;
}

export async function getVisibleActivities(): Promise<ActivityListItem[]> {
  const supabase = await createSupabaseServerClient();
  const [{ data, error }, options] = await Promise.all([
    supabase.rpc("get_visible_activity_cards"),
    getActivityFormOptions(),
  ]);
  if (error) throw new Error("No fue posible consultar las actividades.");

  const rows = (data ?? []) as VisibleActivityCardRow[];
  const activityIds = rows.map((row) => row.id ?? row.activity_id).filter((id): id is string => Boolean(id));
  const { data: fallbackRows } = activityIds.length
    ? await supabase
        .from("activities")
        .select("id, scope_type, division_id, program_id")
        .in("id", activityIds)
    : { data: [] as ActivityProgramFallback[] };
  const activityFallbacks = new Map(
    ((fallbackRows ?? []) as ActivityProgramFallback[]).map((activity) => [activity.id, activity]),
  );

  const periods = new Map(options.academicPeriods.map((item) => [item.id, item]));
  const programs = new Map(options.programs.map((item) => [item.id, item]));
  const activityTypes = new Map(options.activityTypes.map((item) => [item.code, item]));
  const serviceTypes = new Map(options.serviceTypes.map((item) => [item.code, item]));
  const categories = new Map(options.attentionCategories.map((item) => [item.code, item]));
  const modalities = new Map(options.modalities.map((item) => [item.code, item]));
  const statuses = new Map(options.statuses.map((item) => [item.code, item]));
  const locations = new Map(options.locationTypes.map((item) => [item.code, item]));

  return rows.map((row) => {
    const id = row.id ?? row.activity_id ?? "";
    const fallback = activityFallbacks.get(id);
    const scopeType = (row.scope_type ?? fallback?.scope_type ?? "program") as ActivityScopeType;
    const programId = row.program_id ?? row.activity_program_id ?? row.academic_program_id ?? fallback?.program_id ?? null;
    const divisionId = row.division_id ?? fallback?.division_id ?? "";
    const activityTypeCode = row.activity_type_code ?? "";
    const serviceTypeCode = row.service_type_code ?? "";
    const modalityCode = row.modality_code ?? "";
    const statusCode = row.status_code ?? "";
    const categoryCode = row.attention_category_code ?? null;
    const locationCode = row.location_type_code ?? null;
    const programLabel = firstText(
      row.program_name,
      row.program_label,
      row.academic_program_name,
      programId ? programs.get(programId)?.name : null,
    );

    return {
      id,
      title: row.title ?? "Actividad sin título",
      description: row.description ?? null,
      academic_period_id: row.academic_period_id ?? null,
      scope_type: scopeType,
      division_id: divisionId,
      program_id: programId,
      activity_type_code: activityTypeCode,
      service_type_code: serviceTypeCode,
      attention_category_code: categoryCode,
      modality_code: modalityCode,
      location_type_code: locationCode,
      location_detail: row.location_detail ?? null,
      start_date: row.start_date ?? null,
      start_time: row.start_time ?? null,
      end_date: row.end_date ?? null,
      end_time: row.end_time ?? null,
      duration_mode: (row.duration_mode ?? null) as DurationMode | null,
      starts_at: row.starts_at ?? null,
      ends_at: row.ends_at ?? null,
      responsible_profile_id: row.responsible_profile_id ?? "",
      created_by: row.created_by ?? "",
      status_code: statusCode,
      created_at: row.created_at,
      updated_at: row.updated_at,
      academicPeriodLabel: row.academic_period_label?.trim() || (row.academic_period_id ? label(periods.get(row.academic_period_id), row.academic_period_id) : null),
      programName: programLabel || (scopeType === "division" ? "Ambos programas" : "Programa no disponible"),
      activityTypeLabel: row.activity_type_label?.trim() || label(activityTypes.get(activityTypeCode), activityTypeCode),
      serviceTypeLabel: row.service_type_label?.trim() || label(serviceTypes.get(serviceTypeCode), serviceTypeCode),
      attentionCategoryLabel: row.attention_category_label?.trim() || (categoryCode ? label(categories.get(categoryCode), categoryCode) : null),
      modalityLabel: row.modality_label?.trim() || label(modalities.get(modalityCode), modalityCode),
      statusLabel: row.status_label?.trim() || label(statuses.get(statusCode), statusCode),
      locationTypeLabel: row.location_type_label?.trim() || (locationCode ? label(locations.get(locationCode), locationCode) : null),
      responsibleName: row.responsible_full_name?.trim() || row.responsible_name?.trim() || "Responsable no disponible",
      canEdit: row.viewer_can_edit === true || row.can_edit === true,
      isParticipant: row.viewer_is_participant === true || row.is_participant === true,
      ownParticipantRoleLabel: row.participant_role_label?.trim() || null,
      viewerAttendanceStatus: row.viewer_attendance_status ?? null,
      viewerAttendanceSource: row.viewer_attendance_source ?? null,
      viewerCheckedInAt: row.viewer_checked_in_at ?? null,
    };
  }).filter((activity) => Boolean(activity.id)).sort((left, right) =>
    (right.start_date ?? right.starts_at ?? right.created_at ?? "").localeCompare(left.start_date ?? left.starts_at ?? left.created_at ?? ""),
  );
}


