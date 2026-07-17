import type { EmailOtpType } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const allowedOtpTypes = new Set<EmailOtpType>([
  "signup",
  "email",
  "email_change",
  "magiclink",
  "recovery",
]);

export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const tokenHash = url.searchParams.get("token_hash");
  const rawType = url.searchParams.get("type");

  try {
    const supabase = await createSupabaseServerClient();
    let error = null;

    if (code) {
      ({ error } = await supabase.auth.exchangeCodeForSession(code));
    } else if (tokenHash && rawType && allowedOtpTypes.has(rawType as EmailOtpType)) {
      ({ error } = await supabase.auth.verifyOtp({
        token_hash: tokenHash,
        type: rawType as EmailOtpType,
      }));
    } else {
      return NextResponse.redirect(new URL("/login?error=enlace-heredado", url.origin));
    }

    if (error) {
      return NextResponse.redirect(new URL("/login?error=enlace-heredado", url.origin));
    }

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return NextResponse.redirect(new URL("/login?error=credenciales", url.origin));
    const { data: profile } = await supabase.from("profiles").select("*").eq("id", user.id).maybeSingle();
    if (profile?.account_status === "inactive") {
      return NextResponse.redirect(new URL("/account-status?state=inactive", url.origin));
    }
    if (profile?.account_status === "pending_registration") {
      return NextResponse.redirect(new URL("/complete-registration", url.origin));
    }
    return NextResponse.redirect(new URL("/dashboard", url.origin));
  } catch {
    return NextResponse.redirect(new URL("/login?error=enlace-heredado", url.origin));
  }
}
