"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function getText(formData: FormData, field: string) {
  const value = formData.get(field);
  return typeof value === "string" ? value.trim() : "";
}

export async function createActivity(formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login?error=sesion-requerida");
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("id")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError || !profile) {
    redirect("/activities/new?error=perfil-requerido");
  }

  const title = getText(formData, "title").replace(/\s+/g, " ");
  const description = getText(formData, "description");
  const academicPeriodId = getText(formData, "academic_period_id");
  const programId = getText(formData, "program_id");
  const activityTypeCode = getText(formData, "activity_type_code");
  const serviceTypeCode = getText(formData, "service_type_code");
  const attentionCategoryCode = getText(formData, "attention_category_code");
  const modalityCode = getText(formData, "modality_code");
  const locationTypeCode = getText(formData, "location_type_code");
  const locationDetail = getText(formData, "location_detail");
  const startsAt = getText(formData, "starts_at");
  const endsAt = getText(formData, "ends_at");

  if (!title || !programId || !activityTypeCode || !serviceTypeCode || !modalityCode) {
    redirect("/activities/new?error=campos-requeridos");
  }

  if (
    title.length > 200 ||
    description.length > 5000 ||
    locationDetail.length > 500 ||
    (startsAt && Number.isNaN(Date.parse(startsAt))) ||
    (endsAt && Number.isNaN(Date.parse(endsAt))) ||
    (endsAt && !startsAt) ||
    (startsAt && endsAt && Date.parse(endsAt) < Date.parse(startsAt))
  ) {
    redirect("/activities/new?error=datos-invalidos");
  }

  async function isAvailable(table: string, column: string, value: string) {
    if (!value) {
      return true;
    }

    const { data, error } = await supabase
      .from(table)
      .select("*")
      .eq(column, value)
      .maybeSingle();

    return !error && Boolean(data) && data?.is_active !== false;
  }

  const checks = await Promise.all([
    isAvailable("academic_programs", "id", programId),
    isAvailable("activity_types", "code", activityTypeCode),
    isAvailable("service_types", "code", serviceTypeCode),
    isAvailable("activity_modalities", "code", modalityCode),
    isAvailable("academic_periods", "id", academicPeriodId),
    isAvailable("attention_categories", "code", attentionCategoryCode),
    isAvailable("location_types", "code", locationTypeCode),
  ]);

  if (checks.some((isValid) => !isValid)) {
    redirect("/activities/new?error=catalogo-invalido");
  }

  const { error } = await supabase.from("activities").insert({
    title,
    description: description || null,
    academic_period_id: academicPeriodId || null,
    program_id: programId,
    activity_type_code: activityTypeCode,
    service_type_code: serviceTypeCode,
    attention_category_code: attentionCategoryCode || null,
    modality_code: modalityCode,
    location_type_code: locationTypeCode || null,
    location_detail: locationDetail || null,
    starts_at: startsAt || null,
    ends_at: endsAt || null,
    responsible_profile_id: profile.id,
    created_by: user.id,
    status_code: startsAt ? "scheduled" : "draft",
  });

  if (error) {
    redirect("/activities/new?error=creacion");
  }

  revalidatePath("/activities");
  redirect("/activities?created=1");
}