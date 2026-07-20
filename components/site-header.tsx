import Image from "next/image";
import Link from "next/link";
import { AccountMenu } from "@/components/account-menu";
import { AuthenticatedNavigation } from "@/components/authenticated-navigation";
import {
  getAuthenticatedUserContext,
  hasActiveRole,
  type AuthenticatedUserContext,
} from "@/lib/auth/get-authenticated-user-context";
import { getDisplayName, getInitials, getSafeGoogleAvatarUrl } from "@/lib/auth/user-display";
import { canAccessAccountAdministration } from "@/lib/admin/authorization";

export async function SiteHeader() {
  let context: AuthenticatedUserContext | null = null;
  try {
    context = await getAuthenticatedUserContext();
  } catch {
    context = null;
  }

  const user = context?.user ?? null;
  const profile = context?.profile ?? null;
  const canViewCatalogs = hasActiveRole(context, "technical_admin");
  const canAdministerAccounts = canAccessAccountAdministration(context);
  const displayName = getDisplayName(profile, user);
  return (
    <header className="relative z-40 border-b border-blue-950/10 bg-white/95 backdrop-blur">
      <div className="mx-auto flex min-h-[4.5rem] max-w-7xl items-center justify-between gap-4 px-4 sm:px-6 lg:px-8">
        <Link href={user ? "/dashboard" : "/"} className="flex min-w-0 cursor-pointer items-center gap-3 rounded-lg" aria-label="Ir al inicio de SITAA">
          <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-[var(--sitaa-blue)] shadow-sm" aria-hidden="true">
            <Image
              src="/brand/sitaa-mark.svg"
              alt=""
              width={28}
              height={28}
              className="size-7 object-contain brightness-0 invert"
              priority
            />
          </span>
          <span className="min-w-0">
            <span className="block text-lg font-black tracking-[0.12em] text-[var(--sitaa-blue-dark)]">SITAA</span>
            <span className="hidden truncate text-xs text-[var(--sitaa-text-secondary)] sm:block">Tutorías y asesorías académicas</span>
          </span>
        </Link>
        {user ? (
          <div className="flex items-center gap-2 sm:gap-4">
            <AuthenticatedNavigation
              canViewCatalogs={canViewCatalogs}
              canAdministerAccounts={canAdministerAccounts}
            />
            <AccountMenu
              displayName={displayName}
              email={user.email ?? ""}
              imageUrl={getSafeGoogleAvatarUrl(user)}
              initials={getInitials(displayName)}
              canViewCatalogs={canViewCatalogs}
              canAdministerAccounts={canAdministerAccounts}
            />
          </div>
        ) : <Link href="/login" className="sitaa-secondary-action hidden sm:inline-flex">Iniciar sesión</Link>}
      </div>
    </header>
  );
}
