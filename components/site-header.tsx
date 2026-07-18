import Link from "next/link";
import type { User } from "@supabase/supabase-js";
import { AccountMenu } from "@/components/account-menu";
import { AuthenticatedNavigation } from "@/components/authenticated-navigation";
import { getDisplayName, getInitials, getSafeGoogleAvatarUrl } from "@/lib/auth/user-display";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { Profile } from "@/types/sitaa";

export async function SiteHeader() {
  let user: User | null = null;
  let profile: Profile | null = null;
  try {
    const supabase = await createSupabaseServerClient();
    const result = await supabase.auth.getUser();
    user = result.data.user;
    if (user) {
      const profileResult = await supabase.from("profiles").select("*").eq("id", user.id).maybeSingle();
      profile = profileResult.data as Profile | null;
    }
  } catch {
    user = null;
  }

  const displayName = getDisplayName(profile, user);
  return (
    <header className="relative z-40 border-b border-blue-950/10 bg-white/95 backdrop-blur">
      <div className="mx-auto flex min-h-[4.5rem] max-w-7xl items-center justify-between gap-4 px-4 sm:px-6 lg:px-8">
        <Link href={user ? "/dashboard" : "/"} className="flex min-w-0 cursor-pointer items-center gap-3 rounded-lg" aria-label="Ir al inicio de SITAA">
          <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-[var(--sitaa-blue)] text-sm font-black tracking-wide text-white shadow-sm">ST</span>
          <span className="min-w-0">
            <span className="block text-lg font-black tracking-[0.12em] text-[var(--sitaa-blue-dark)]">SITAA</span>
            <span className="hidden truncate text-xs text-[var(--sitaa-text-secondary)] sm:block">Tutorías y asesorías académicas</span>
          </span>
        </Link>
        {user ? (
          <div className="flex items-center gap-2 sm:gap-4">
            <AuthenticatedNavigation />
            <AccountMenu displayName={displayName} email={user.email ?? ""} imageUrl={getSafeGoogleAvatarUrl(user)} initials={getInitials(displayName)} />
          </div>
        ) : <Link href="/login" className="sitaa-secondary-action hidden sm:inline-flex">Iniciar sesión</Link>}
      </div>
    </header>
  );
}
