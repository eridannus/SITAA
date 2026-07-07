"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { InstitutionalIdType, PersonType } from "@/types/sitaa";

const validPersonTypes = new Set<PersonType>(["student", "worker"]);
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function getText(formData: FormData, field: string) {
  const value = formData.get(field);
  return typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
}

function isValidName(value: string, required: boolean) {
  if (!value) {
    return !required;
  }

  return value.length <= 100;
}

export async function updateProfile(formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login?error=sesion-requerida");
  }

  const firstNames = getText(formData, "first_names");
  const paternalSurname = getText(formData, "paternal_surname");
  const maternalSurname = getText(formData, "maternal_surname");
  const personTypeValue = getText(formData, "person_type") as PersonType;
  const institutionalIdValue = getText(formData, "institutional_id_value");
  const primaryProgramId = getText(formData, "primary_program_id");

  if (
    !isValidName(firstNames, true) ||
    !isValidName(paternalSurname, true) ||
    !isValidName(maternalSurname, false) ||
    !validPersonTypes.has(personTypeValue) ||
    !institutionalIdValue ||
    institutionalIdValue.length > 50 ||
    (primaryProgramId && !uuidPattern.test(primaryProgramId))
  ) {
    redirect("/profile?error=datos-invalidos");
  }

  if (primaryProgramId) {
    const { data: program, error: programError } = await supabase
      .from("academic_programs")
      .select("id")
      .eq("id", primaryProgramId)
      .eq("is_active", true)
      .maybeSingle();

    if (programError || !program) {
      redirect("/profile?error=programa-invalido");
    }
  }

  const institutionalIdType: InstitutionalIdType =
    personTypeValue === "student" ? "student_account" : "worker_number";
  const fullName = [firstNames, paternalSurname, maternalSurname].filter(Boolean).join(" ");
  const { data: profile, error } = await supabase
    .from("profiles")
    .update({
      first_names: firstNames,
      paternal_surname: paternalSurname,
      maternal_surname: maternalSurname || null,
      full_name: fullName,
      person_type: personTypeValue,
      institutional_id_type: institutionalIdType,
      institutional_id_value: institutionalIdValue,
      primary_program_id: primaryProgramId || null,
    })
    .eq("id", user.id)
    .select("id")
    .maybeSingle();

  if (error) {
    redirect("/profile?error=actualizacion");
  }

  if (!profile) {
    redirect("/profile?error=perfil-inexistente");
  }

  revalidatePath("/dashboard");
  revalidatePath("/profile");
  redirect("/profile?success=actualizado");
}