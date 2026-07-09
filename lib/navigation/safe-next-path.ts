export function safeNextPath(value: FormDataEntryValue | string | string[] | undefined | null) {
  const rawValue = Array.isArray(value) ? value[0] : value;

  if (typeof rawValue !== "string") return null;

  const nextPath = rawValue.trim();

  if (!nextPath) return null;
  if (!nextPath.startsWith("/")) return null;
  if (nextPath.startsWith("//")) return null;

  try {
    const parsed = new URL(nextPath, "http://sitaa.local");

    if (parsed.origin !== "http://sitaa.local") return null;

    return parsed.pathname + parsed.search + parsed.hash;
  } catch {
    return null;
  }
}

export function loginPathWithNext(nextPath: string) {
  const params = new URLSearchParams({ error: "sesion-requerida", next: nextPath });
  return "/login?" + params.toString();
}
