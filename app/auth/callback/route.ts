import { cookies } from "next/headers";
import { NextResponse, type NextRequest } from "next/server";
import {
  AUTH_NEXT_COOKIE,
  clearCallbackCookie,
  REGISTRATION_TYPE_COOKIE,
} from "@/lib/auth/oauth-cookies";
import { safeNextPath } from "@/lib/navigation/safe-next-path";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { RegistrationPersonType } from "@/types/registration";

function redirectTo(request: NextRequest, path: string) {
  return NextResponse.redirect(new URL(path, request.url));
}

function validatedRegistrationType(value?: string): RegistrationPersonType | null {
  return value === "student" || value === "professor" ? value : null;
}

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  if (!code) return redirectTo(request, "/login?error=google");

  try {
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (error) return redirectTo(request, "/login?error=google");

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return redirectTo(request, "/login?error=google");

    const { data: profile, error: profileError } = await supabase
      .from("profiles").select("*").eq("id", user.id).maybeSingle();
    if (profileError || !profile) return redirectTo(request, "/account-status?state=missing");

    const cookieStore = await cookies();
    const nextPath = safeNextPath(cookieStore.get(AUTH_NEXT_COOKIE)?.value);
    const registrationType = validatedRegistrationType(
      cookieStore.get(REGISTRATION_TYPE_COOKIE)?.value,
    );
    clearCallbackCookie(cookieStore, AUTH_NEXT_COOKIE);
    clearCallbackCookie(cookieStore, REGISTRATION_TYPE_COOKIE);

    if (profile.account_status === "inactive") {
      return redirectTo(request, "/account-status?state=inactive");
    }
    if (profile.account_status === "active" || (!profile.account_status && profile.is_active !== false)) {
      return redirectTo(request, nextPath ?? "/dashboard");
    }
    if (profile.account_status !== "pending_registration") {
      return redirectTo(request, "/account-status?state=missing");
    }

    if (registrationType) {
      return redirectTo(request, `/complete-registration/${registrationType}`);
    }
    return redirectTo(request, "/complete-registration");
  } catch {
    return redirectTo(request, "/login?error=google");
  }
}
