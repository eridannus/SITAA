import type { SupabaseClient } from "npm:@supabase/supabase-js@2.110.1";

// El SDK instalado documenta `ban_duration: "none"` para levantar el bloqueo.
// El comportamiento real del proyecto alojado debe comprobarse en un entorno
// desechable antes de aplicar 0010 en producción.
export const AUTH_RESTORATION_BAN_DURATION = "none" as const;
export const AUTH_SUSPENSION_BAN_DURATION = "876000h" as const;

export type StableAuthFailureCode =
  | "auth_temporarily_unavailable"
  | "auth_rate_limited"
  | "auth_user_not_found"
  | "auth_update_rejected"
  | "unsupported_auth_contract";

export type AuthAdminResult =
  | { ok: true }
  | {
      ok: false;
      result: "retryable_failure" | "terminal_failure";
      code: StableAuthFailureCode;
    };

type AuthAdminError = { status?: number };

function stableFailure(error: AuthAdminError): AuthAdminResult {
  const status = error.status ?? 0;
  if (status === 404) {
    return { ok: false, result: "terminal_failure", code: "auth_user_not_found" };
  }
  if (status === 429) {
    return { ok: false, result: "retryable_failure", code: "auth_rate_limited" };
  }
  if (status === 400 || status === 401 || status === 403 || status === 422) {
    return { ok: false, result: "terminal_failure", code: "auth_update_rejected" };
  }
  return {
    ok: false,
    result: "retryable_failure",
    code: "auth_temporarily_unavailable",
  };
}

async function updateBanDuration(
  client: SupabaseClient,
  targetAuthUserId: string,
  banDuration: string,
): Promise<AuthAdminResult> {
  const { error } = await client.auth.admin.updateUserById(targetAuthUserId, {
    ban_duration: banDuration,
  });
  return error ? stableFailure(error) : { ok: true };
}

export function suspendAuthUser(
  client: SupabaseClient,
  targetAuthUserId: string,
) {
  return updateBanDuration(client, targetAuthUserId, AUTH_SUSPENSION_BAN_DURATION);
}

export function restoreAuthUser(
  client: SupabaseClient,
  targetAuthUserId: string,
) {
  return updateBanDuration(client, targetAuthUserId, AUTH_RESTORATION_BAN_DURATION);
}

