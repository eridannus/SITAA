import type { User } from "@supabase/supabase-js";

export interface StructuredDisplayName {
  first_names?: string | null;
  paternal_surname?: string | null;
  maternal_surname?: string | null;
  full_name?: string | null;
}

function clean(value: unknown) {
  return typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
}

export function getDisplayName(profile: StructuredDisplayName | null | undefined, user?: User | null) {
  const structured = [
    clean(profile?.first_names),
    clean(profile?.paternal_surname),
    clean(profile?.maternal_surname),
  ].filter(Boolean).join(" ");

  return structured
    || clean(profile?.full_name)
    || clean(user?.user_metadata?.full_name)
    || clean(user?.user_metadata?.name)
    || clean(user?.email?.split("@")[0])
    || "Usuario de SITAA";
}

export function getInitials(name: string) {
  const words = name.trim().split(/\s+/).filter(Boolean);
  if (!words.length) return "ST";
  const selected = words.length === 1
    ? [words[0]!]
    : [words[0]!, words[words.length - 1]!];
  return selected.map((word) => Array.from(word)[0]?.toLocaleUpperCase("es-MX") ?? "").join("").slice(0, 2);
}

export function getSafeGoogleAvatarUrl(user: User | null | undefined) {
  const candidate = clean(user?.user_metadata?.avatar_url) || clean(user?.user_metadata?.picture);
  if (!candidate) return null;
  try {
    const url = new URL(candidate);
    const host = url.hostname.toLowerCase();
    if (url.protocol !== "https:" || url.username || url.password) return null;
    if (host !== "googleusercontent.com" && !host.endsWith(".googleusercontent.com")) return null;
    return url.toString();
  } catch {
    return null;
  }
}
