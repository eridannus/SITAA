import { createSupabaseServerClient } from "@/lib/supabase/server";
import type {
  AcademicPeriod,
  ActivityModality,
  ActivityStatus,
  ActivityType,
  AttentionCategory,
  CatalogRow,
  LocationType,
  OperationalCatalogs,
  ParticipantRole,
  ServiceType,
} from "@/types/catalogs";

function getLabel(item: CatalogRow) {
  return item.label?.trim() || item.name?.trim() || item.code;
}

function sortCatalog<T extends CatalogRow>(items: T[]) {
  return [...items].sort((left, right) => {
    const orderDifference = (left.sort_order ?? 0) - (right.sort_order ?? 0);

    if (orderDifference !== 0) {
      return orderDifference;
    }

    return getLabel(left).localeCompare(getLabel(right), "es");
  });
}

export async function getActiveCatalogs(): Promise<OperationalCatalogs> {
  const supabase = await createSupabaseServerClient();
  const results = await Promise.all([
    supabase.from("academic_periods").select("*").eq("is_active", true),
    supabase.from("activity_types").select("*").eq("is_active", true),
    supabase.from("service_types").select("*").eq("is_active", true),
    supabase.from("attention_categories").select("*").eq("is_active", true),
    supabase.from("activity_modalities").select("*").eq("is_active", true),
    supabase.from("activity_statuses").select("*").eq("is_active", true),
    supabase.from("location_types").select("*").eq("is_active", true),
    supabase.from("participant_roles").select("*").eq("is_active", true),
  ]);

  const failedCatalog = results.find((result) => result.error);

  if (failedCatalog?.error) {
    throw new Error("No fue posible consultar los catálogos operativos.");
  }

  return {
    academicPeriods: sortCatalog(results[0].data as AcademicPeriod[]),
    activityTypes: sortCatalog(results[1].data as ActivityType[]),
    serviceTypes: sortCatalog(results[2].data as ServiceType[]),
    attentionCategories: sortCatalog(results[3].data as AttentionCategory[]),
    activityModalities: sortCatalog(results[4].data as ActivityModality[]),
    activityStatuses: sortCatalog(results[5].data as ActivityStatus[]),
    locationTypes: sortCatalog(results[6].data as LocationType[]),
    participantRoles: sortCatalog(results[7].data as ParticipantRole[]),
  };
}