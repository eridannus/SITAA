function validHttpOrigin(value: string | null | undefined) {
  if (!value) return null;

  try {
    const url = new URL(value);
    return url.protocol === "https:" || url.protocol === "http:" ? url.origin : null;
  } catch {
    return null;
  }
}

export function getSiteOrigin(
  requestOrigin?: string | null,
  requestHost?: string | null,
  forwardedProto?: string | null,
) {
  const configured = validHttpOrigin(process.env.NEXT_PUBLIC_SITE_URL);
  if (configured) return configured;

  const normalizedHost = requestHost?.split(",")[0]?.trim();
  const candidateOrigin = validHttpOrigin(requestOrigin);
  if (candidateOrigin && normalizedHost) {
    const candidate = new URL(candidateOrigin);
    if (candidate.host === normalizedHost) return candidate.origin;
  }

  if (normalizedHost && /^[a-z0-9.-]+(?::[0-9]+)?$/i.test(normalizedHost)) {
    const protocol = forwardedProto?.split(",")[0]?.trim() === "http" ? "http" : "https";
    return `${protocol}://${normalizedHost}`;
  }

  return "https://www.sitaa.net";
}
