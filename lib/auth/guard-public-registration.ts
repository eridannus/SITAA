import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import {
  AUTH_NEXT_COOKIE,
  clearCallbackCookie,
  REGISTRATION_TYPE_COOKIE,
} from "@/lib/auth/oauth-cookies";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function guardPublicRegistrationEntry(
  pendingDestination = "/complete-registration",
) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return;

  const cookieStore = await cookies();
  clearCallbackCookie(cookieStore, REGISTRATION_TYPE_COOKIE);
  clearCallbackCookie(cookieStore, AUTH_NEXT_COOKIE);

  const { data: profile, error } = await supabase
    .from("profiles")
    .select("account_status,is_active")
    .eq("id", user.id)
    .maybeSingle();

  if (error || !profile) redirect("/account-status?state=missing");
  if (profile.account_status === "inactive") {
    redirect("/account-status?state=inactive");
  }
  if (profile.account_status === "pending_registration") {
    redirect(pendingDestination);
  }
  if (profile.account_status === "active" || (!profile.account_status && profile.is_active)) {
    redirect("/dashboard");
  }
  redirect("/account-status?state=missing");
}
