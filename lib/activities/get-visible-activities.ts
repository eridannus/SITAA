import { getActivityFormOptions } from "@/lib/activities/get-activity-form-options";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Activity, ActivityListItem } from "@/types/activities";
import type { CatalogRow } from "@/types/catalogs";
import type { Profile } from "@/types/sitaa";

function getLabel(item: CatalogRow | undefined, fallback: string) {
  return item?.label?.trim() || item?.name?.trim() || fallback;
}

export async function getVisibleActivities(): Promise<ActivityListItem[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.from("activities").select("*");

  if (error) {
    throw new Error("No fue posible consultar las actividades.");
  }

  const activities = data as Activity[];
  const responsibleIds = [
    ...new Set(activities.map((activity) => activity.responsible_profile_id)),
  ];
  const [options, profilesResult] = await Promise.all([
    getActivityFormOptions(),
    responsibleIds.length
      ? supabase.from("profiles").select("id, full_name").in("id", responsibleIds)
      : Promise.resolve({ data: [] as Pick<Profile, "id" | "full_name">[], error: null }),
  ]);

  if (profilesResult.error) {
    throw new Error("No fue posible consultar las personas responsables.");
  }

  const programs = new Map(options.programs.map((item) => [item.id, item]));
  const periods = new Map(options.academicPeriods.map((item) => [item.id, item]));
  const activityTypes = new Map(options.activityTypes.map((item) => [item.code, item]));
  const serviceTypes = new Map(options.serviceTypes.map((item) => [item.code, item]));
  const categories = new Map(options.attentionCategories.map((item) => [item.code, item]));
  const modalities = new Map(options.modalities.map((item) => [item.code, item]));
  const statuses = new Map(options.statuses.map((item) => [item.code, item]));
  const locationTypes = new Map(options.locationTypes.map((item) => [item.code, item]));
  const profiles = new Map(
    (profilesResult.data as Pick<Profile, "id" | "full_name">[]).map((item) => [item.id, item]),
  );

  return activities
    .map((activity) => ({
      ...activity,
      academicPeriodLabel: activity.academic_period_id
        ? getLabel(periods.get(activity.academic_period_id), activity.academic_period_id)
        : null,
      programName: activity.scope_type === "division"
        ? "Ambos programas"
        : activity.program_id
          ? programs.get(activity.program_id)?.name ?? activity.program_id
          : "Programa no asignado",
      activityTypeLabel: getLabel(
        activityTypes.get(activity.activity_type_code),
        activity.activity_type_code,
      ),
      serviceTypeLabel: getLabel(
        serviceTypes.get(activity.service_type_code),
        activity.service_type_code,
      ),
      attentionCategoryLabel: activity.attention_category_code
        ? getLabel(
            categories.get(activity.attention_category_code),
            activity.attention_category_code,
          )
        : null,
      modalityLabel: getLabel(modalities.get(activity.modality_code), activity.modality_code),
      statusLabel: getLabel(statuses.get(activity.status_code), activity.status_code),
      locationTypeLabel: activity.location_type_code
        ? getLabel(locationTypes.get(activity.location_type_code), activity.location_type_code)
        : null,
      responsibleName:
        profiles.get(activity.responsible_profile_id)?.full_name || "Responsable sin nombre",
    }))
    .sort((left, right) => {
      const leftDate = left.start_date ?? left.starts_at ?? left.created_at ?? "";
      const rightDate = right.start_date ?? right.starts_at ?? right.created_at ?? "";
      return rightDate.localeCompare(leftDate);
    });
}