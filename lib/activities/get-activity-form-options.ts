import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { ActivityFormOptions } from "@/types/activities";
import type {
  AcademicPeriod,
  ActivityModality,
  ActivityStatus,
  ActivityType,
  AttentionCategory,
  CatalogRow,
  LocationType,
  ServiceType,
} from "@/types/catalogs";
import type { AcademicProgram } from "@/types/sitaa";

function getLabel(item: CatalogRow) {
  return item.label?.trim() || item.name?.trim() || item.code;
}

function activeCatalog<T extends CatalogRow>(rows: T[]) {
  return rows
    .filter((row) => row.is_active !== false)
    .sort((left, right) => {
      const orderDifference = (left.sort_order ?? 0) - (right.sort_order ?? 0);
      return orderDifference || getLabel(left).localeCompare(getLabel(right), "es");
    });
}

export async function getActivityFormOptions(): Promise<ActivityFormOptions> {
  const supabase = await createSupabaseServerClient();
  const results = await Promise.all([
    supabase.from("academic_periods").select("*"),
    supabase.from("academic_programs").select("*").order("name", { ascending: true }),
    supabase.from("activity_types").select("*"),
    supabase.from("service_types").select("*"),
    supabase.from("attention_categories").select("*"),
    supabase.from("activity_modalities").select("*"),
    supabase.from("activity_statuses").select("*"),
    supabase.from("location_types").select("*"),
  ]);

  if (results.some((result) => result.error)) {
    throw new Error("No fue posible cargar las opciones de actividad.");
  }

  return {
    academicPeriods: activeCatalog(results[0].data as AcademicPeriod[]),
    programs: (results[1].data as AcademicProgram[]).filter(
      (program) => program.is_active !== false,
    ),
    activityTypes: activeCatalog(results[2].data as ActivityType[]),
    serviceTypes: activeCatalog(results[3].data as ServiceType[]),
    attentionCategories: activeCatalog(results[4].data as AttentionCategory[]),
    modalities: activeCatalog(results[5].data as ActivityModality[]),
    statuses: activeCatalog(results[6].data as ActivityStatus[]),
    locationTypes: activeCatalog(results[7].data as LocationType[]),
  };
}