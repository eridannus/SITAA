import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function getPublicRegistrationRedirect(
  pendingDestination = "/complete-registration",
) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: profile, error } = await supabase
    .from("profiles")
    .select("account_status,is_active")
    .eq("id", user.id)
    .maybeSingle();

  if (error || !profile) return "/account-status?state=missing";
  if (profile.account_status === "inactive") {
    return "/account-status?state=inactive";
  }
  if (profile.account_status === "pending_registration") {
    return pendingDestination;
  }
  if (profile.account_status === "active" || (!profile.account_status && profile.is_active)) {
    return "/dashboard";
  }
  return "/account-status?state=missing";
}

export async function guardPublicRegistrationEntry(
  pendingDestination = "/complete-registration",
) {
  const destination = await getPublicRegistrationRedirect(pendingDestination);
  if (destination) redirect(destination);
}
