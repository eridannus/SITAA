"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function normalizedName(formData: FormData) {
  const value = formData.get("full_name");
  return typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
}

export async function updateProfile(formData: FormData) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?error=sesion-requerida");

  const fullName = normalizedName(formData);
  if (fullName.length < 2 || fullName.length > 200) {
    redirect("/profile?error=nombre-invalido");
  }

  const { data: profile, error } = await supabase
    .from("profiles")
    .update({ full_name: fullName })
    .eq("id", user.id)
    .select("id")
    .maybeSingle();

  if (error) redirect("/profile?error=actualizacion");
  if (!profile) redirect("/profile?error=perfil-inexistente");

  revalidatePath("/dashboard");
  revalidatePath("/profile");
  redirect("/profile?success=actualizado");
}
