"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function namePart(formData: FormData, field: string) {
  const value = formData.get(field);
  return typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
}

export async function updateProfile(formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?error=sesion-requerida");

  const { data: currentProfile, error: currentProfileError } = await supabase
    .from("profiles").select("id, account_kind").eq("id", user.id).maybeSingle();
  if (currentProfileError) redirect("/profile?error=actualizacion");
  if (!currentProfile) redirect("/profile?error=perfil-inexistente");

  const firstNames = namePart(formData, "first_names");
  const paternalSurname = namePart(formData, "paternal_surname");
  const maternalSurname = namePart(formData, "maternal_surname");
  if (!firstNames || firstNames.length > 150) redirect("/profile?error=nombres-invalidos");
  if ((currentProfile.account_kind !== "technical" && !paternalSurname) || paternalSurname.length > 150) redirect("/profile?error=apellido-paterno-invalido");
  if (maternalSurname.length > 150) redirect("/profile?error=apellido-materno-invalido");
  if ([firstNames, paternalSurname, maternalSurname].filter(Boolean).join(" ").length > 200) redirect("/profile?error=nombre-combinado-invalido");

  const { data: profile, error } = await supabase
    .from("profiles")
    .update({ first_names: firstNames, paternal_surname: paternalSurname || null, maternal_surname: maternalSurname || null })
    .eq("id", user.id)
    .select("id")
    .maybeSingle();

  if (error) redirect("/profile?error=actualizacion");
  if (!profile) redirect("/profile?error=perfil-inexistente");
  revalidatePath("/", "layout");
  revalidatePath("/dashboard");
  revalidatePath("/profile");
  redirect("/profile?success=actualizado");
}
