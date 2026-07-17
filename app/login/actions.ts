"use server";

import { revalidatePath } from "next/cache";
import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { AUTH_NEXT_COOKIE, oauthCookieOptions } from "@/lib/auth/oauth-cookies";
import { getSiteOrigin } from "@/lib/auth/site-url";
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

export async function loginWithGoogle(formData: FormData) {
  const nextPath = safeNextPath(formData.get("next"));
  let supabase;
  try {
    supabase = await createSupabaseServerClient();
  } catch {
    redirect(loginErrorPath("configuracion", nextPath));
  }

  const requestHeaders = await headers();
  const origin = getSiteOrigin(
    requestHeaders.get("origin"),
    requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host"),
    requestHeaders.get("x-forwarded-proto"),
  );
  const cookieStore = await cookies();
  if (nextPath) cookieStore.set(AUTH_NEXT_COOKIE, nextPath, oauthCookieOptions());
  else cookieStore.delete(AUTH_NEXT_COOKIE);

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: { redirectTo: new URL("/auth/callback", origin).toString() },
  });
  if (error || !data.url) {
    cookieStore.delete(AUTH_NEXT_COOKIE);
    redirect(loginErrorPath("google", nextPath));
  }
  redirect(data.url);
}
