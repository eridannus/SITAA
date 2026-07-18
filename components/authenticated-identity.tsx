import type { User } from "@supabase/supabase-js";
import { Avatar } from "@/components/avatar";
import { getDisplayName, getInitials, getSafeGoogleAvatarUrl } from "@/lib/auth/user-display";

export function AuthenticatedIdentity({ user, compact = false }: { user: User; compact?: boolean }) {
  const displayName = getDisplayName(null, user);
  return (
    <div className={`flex min-w-0 items-center gap-3 rounded-2xl border border-blue-950/10 bg-[var(--sitaa-blue-light)] ${compact ? "p-3" : "p-4"}`}>
      <Avatar imageUrl={getSafeGoogleAvatarUrl(user)} initials={getInitials(displayName)} alt={`Foto de la cuenta de ${displayName}`} />
      <div className="min-w-0">
        <p className="text-sm font-bold text-[var(--sitaa-blue-dark)]">Cuenta de Google autenticada</p>
        <p className="sitaa-wrap-anywhere mt-0.5 text-sm text-[var(--sitaa-text-secondary)]">{user.email}</p>
      </div>
    </div>
  );
}
