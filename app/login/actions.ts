"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function login(formData: FormData) {
  const email = formData.get("email");
  const password = formData.get("password");

  if (typeof email !== "string" || typeof password !== "string") {
    redirect("/login?error=datos-incompletos");
  }

  const normalizedEmail = email.trim();

  if (!normalizedEmail || !password) {
    redirect("/login?error=datos-incompletos");
  }

  let supabase;

  try {
    supabase = await createSupabaseServerClient();
  } catch {
    redirect("/login?error=configuracion");
  }

  const { error } = await supabase.auth.signInWithPassword({
    email: normalizedEmail,
    password,
  });

  if (error) {
    redirect("/login?error=credenciales");
  }

  revalidatePath("/", "layout");
  redirect("/dashboard");
}