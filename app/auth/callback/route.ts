import { cookies } from "next/headers";
import { NextResponse, type NextRequest } from "next/server";
import { AUTH_NEXT_COOKIE, REGISTRATION_INTENT_COOKIE } from "@/lib/auth/oauth-cookies";
import { safeNextPath } from "@/lib/navigation/safe-next-path";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function redirectTo(request: NextRequest, path: string) {
  return NextResponse.redirect(new URL(path, request.url));
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
    cookieStore.delete(AUTH_NEXT_COOKIE);

    if (profile.account_status === "inactive") {
      cookieStore.delete(REGISTRATION_INTENT_COOKIE);
      return redirectTo(request, "/account-status?state=inactive");
    }
    if (profile.account_status === "active" || (!profile.account_status && profile.is_active !== false)) {
      cookieStore.delete(REGISTRATION_INTENT_COOKIE);
      return redirectTo(request, nextPath ?? "/dashboard");
    }
    if (profile.account_status !== "pending_registration") {
      cookieStore.delete(REGISTRATION_INTENT_COOKIE);
      return redirectTo(request, "/account-status?state=missing");
    }

    const intentToken = cookieStore.get(REGISTRATION_INTENT_COOKIE)?.value;
    if (!intentToken) return redirectTo(request, "/complete-registration");

    const { error: completionError } = await supabase.rpc("complete_own_google_registration", {
      raw_intent_token: intentToken,
    });
    cookieStore.delete(REGISTRATION_INTENT_COOKIE);
    if (completionError) {
      const errorCode = completionError.message.includes("identifier_conflict") ? "identifier" : "intent";
      return redirectTo(request, `/complete-registration?error=${errorCode}`);
    }
    return redirectTo(request, nextPath ?? "/dashboard?registration=completed");
  } catch {
    return redirectTo(request, "/login?error=google");
  }
}
