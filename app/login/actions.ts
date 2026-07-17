"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { safeNextPath } from "@/lib/navigation/safe-next-path";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function loginErrorPath(error: string, nextPath: string | null) {
  const params = new URLSearchParams({ error });

  if (nextPath) params.set("next", nextPath);

  return "/login?" + params.toString();
}

export async function login(formData: FormData) {
  const email = formData.get("email");
  const password = formData.get("password");
  const nextPath = safeNextPath(formData.get("next"));

  if (typeof email !== "string" || typeof password !== "string") {
    redirect(loginErrorPath("datos-incompletos", nextPath));
  }

  const normalizedEmail = email.trim();

  if (!normalizedEmail || !password) {
    redirect(loginErrorPath("datos-incompletos", nextPath));
  }

  let supabase;

  try {
    supabase = await createSupabaseServerClient();
  } catch {
    redirect(loginErrorPath("configuracion", nextPath));
  }

  const { error } = await supabase.auth.signInWithPassword({
    email: normalizedEmail,
    password,
  });

  if (error) {
    if (error.message.toLowerCase().includes("email not confirmed")) {
      redirect(loginErrorPath("verificacion-pendiente", nextPath));
    }
    redirect(loginErrorPath("credenciales", nextPath));
  }

  revalidatePath("/", "layout");
  redirect(nextPath ?? "/dashboard");
}
