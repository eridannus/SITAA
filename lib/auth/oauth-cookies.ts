export const REGISTRATION_INTENT_COOKIE = "sitaa_registration_intent";
export const AUTH_NEXT_COOKIE = "sitaa_auth_next";
export const OAUTH_COOKIE_MAX_AGE = 15 * 60;

export function oauthCookieOptions() {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax" as const,
    maxAge: OAUTH_COOKIE_MAX_AGE,
    path: "/",
  };
}
