export const REGISTRATION_TYPE_COOKIE = "sitaa_registration_type";
export const AUTH_NEXT_COOKIE = "sitaa_auth_next";
export const OAUTH_COOKIE_MAX_AGE = 15 * 60;

export function oauthCallbackCookieOptions() {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax" as const,
    maxAge: OAUTH_COOKIE_MAX_AGE,
    path: "/auth/callback",
  };
}

export function clearCallbackCookie(
  cookieStore: {
    set(name: string, value: string, options: ReturnType<typeof oauthCallbackCookieOptions>): unknown;
  },
  name: string,
) {
  cookieStore.set(name, "", { ...oauthCallbackCookieOptions(), maxAge: 0 });
}
