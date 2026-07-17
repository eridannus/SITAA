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

type CallbackStage =
  | "provider_error"
  | "missing_authorization_code"
  | "code_exchange_failed"
  | "authenticated_user_missing"
  | "profile_query_failed"
  | "profile_missing"
  | "unexpected_callback_failure";

function redirectTo(request: NextRequest, path: string) {
  return NextResponse.redirect(new URL(path, request.url));
}

function validatedRegistrationType(value?: string): RegistrationPersonType | null {
  return value === "student" || value === "professor" ? value : null;
}

function sanitizeDiagnostic(value: unknown) {
  if (typeof value !== "string") return undefined;
  return value
    .replace(/https?:\/\/\S+/gi, "[url]")
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, "[email]")
    .replace(/\b[0-9]{6,50}\b/g, "[identifier]")
    .replace(/[A-Za-z0-9_-]{32,}/g, "[redacted]")
    .replace(/[^\p{L}\p{N}\s._:()\-]/gu, "")
    .trim()
    .slice(0, 180) || undefined;
}

function logCallbackFailure(stage: CallbackStage, code?: unknown, message?: unknown) {
  console.error("SITAA OAuth callback", {
    stage,
    code: sanitizeDiagnostic(code),
    message: sanitizeDiagnostic(message),
    timestamp: new Date().toISOString(),
  });
}

async function clearCallbackState() {
  const cookieStore = await cookies();
  clearCallbackCookie(cookieStore, AUTH_NEXT_COOKIE);
  clearCallbackCookie(cookieStore, REGISTRATION_TYPE_COOKIE);
}

export async function GET(request: NextRequest) {
  const providerError = request.nextUrl.searchParams.get("error");
  if (providerError) {
    const providerCode = request.nextUrl.searchParams.get("error_code");
    const providerDescription = request.nextUrl.searchParams.get("error_description");
    logCallbackFailure("provider_error", providerCode ?? providerError, providerDescription);
    await clearCallbackState();
    const canceled = providerError === "access_denied" || providerCode === "access_denied";
    return redirectTo(request, canceled ? "/login?error=google-cancelado" : "/login?error=google-cuenta");
  }

  const code = request.nextUrl.searchParams.get("code");
  if (!code) {
    logCallbackFailure("missing_authorization_code");
    await clearCallbackState();
    return redirectTo(request, "/login?error=google-codigo");
  }

  try {
    const supabase = await createSupabaseServerClient();
    const { error: exchangeError } = await supabase.auth.exchangeCodeForSession(code);
    if (exchangeError) {
      logCallbackFailure("code_exchange_failed", exchangeError.code, exchangeError.message);
      await clearCallbackState();
      return redirectTo(request, "/login?error=google-intercambio");
    }

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      logCallbackFailure("authenticated_user_missing", userError?.code, userError?.message);
      await clearCallbackState();
      return redirectTo(request, "/login?error=google-sesion");
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles").select("*").eq("id", user.id).maybeSingle();
    if (profileError) {
      logCallbackFailure("profile_query_failed", profileError.code, profileError.message);
      await clearCallbackState();
      return redirectTo(request, "/login?error=google-temporal");
    }
    if (!profile) {
      logCallbackFailure("profile_missing");
      await clearCallbackState();
      return redirectTo(request, "/account-status?state=missing");
    }

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
    return redirectTo(
      request,
      registrationType ? `/complete-registration/${registrationType}` : "/complete-registration",
    );
  } catch (error) {
    logCallbackFailure(
      "unexpected_callback_failure",
      undefined,
      error instanceof Error ? error.message : undefined,
    );
    await clearCallbackState();
    return redirectTo(request, "/login?error=google-temporal");
  }
}
