import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { ActivityAttendanceCheckinState, ActivityCheckinToken } from "@/types/check-in";

type RpcError = { code?: string; message?: string; details?: string; hint?: string };

type CheckinRow = Partial<ActivityCheckinToken> & {
  token?: string | null;
  direct_token?: string | null;
  code?: string | null;
  word_code?: string | null;
  short_code?: string | null;
  code_words?: string | string[] | null;
};

type CheckinStateRow = {
  can_open_now?: unknown;
  window_status?: unknown;
  opens_at?: unknown;
  ordinary_closes_at?: unknown;
  active_expires_at?: unknown;
  message?: unknown;
};

function firstRow<T>(data: unknown): T | null {
  if (Array.isArray(data)) return (data[0] as T | undefined) ?? null;
  return (data as T | null) ?? null;
}

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function textOrNull(value: unknown) {
  const text = cleanText(value);
  return text || null;
}

function cleanCodeWords(value: unknown) {
  if (Array.isArray(value)) return value.map((item) => cleanText(item)).filter(Boolean).join("-");
  return cleanText(value);
}

function sanitizedDetail(error: RpcError) {
  const text = [error.message, error.details, error.hint]
    .filter(Boolean)
    .join(" ")
    .replace(/[\r\n\t]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (!text) return "No fue posible consultar el código activo.";
  return text.replace(/eyJ[a-zA-Z0-9._-]+/g, "[valor oculto]").slice(0, 240);
}

export function normalizeCheckinToken(data: unknown, activityId: string): ActivityCheckinToken | null {
  const row = firstRow<CheckinRow>(data);
  if (!row) return null;
  const secretToken = cleanText(row.secret_token) || cleanText(row.token) || cleanText(row.direct_token);
  const threeWordCode =
    cleanText(row.three_word_code) ||
    cleanCodeWords(row.code_words) ||
    cleanText(row.word_code) ||
    cleanText(row.short_code) ||
    cleanText(row.code);
  if (!secretToken || !threeWordCode) return null;
  return {
    id: cleanText(row.id) || secretToken,
    activity_id: cleanText(row.activity_id) || activityId,
    secret_token: secretToken,
    three_word_code: threeWordCode,
    is_active: row.is_active ?? true,
    opened_at: row.opened_at ?? null,
    expires_at: row.expires_at ?? null,
    closed_at: row.closed_at ?? null,
  };
}

export function normalizeCheckinState(data: unknown): ActivityAttendanceCheckinState | null {
  const row = firstRow<CheckinStateRow>(data);
  if (!row) return null;

  return {
    canOpenNow: row.can_open_now === true,
    windowStatus: textOrNull(row.window_status),
    opensAt: textOrNull(row.opens_at),
    ordinaryClosesAt: textOrNull(row.ordinary_closes_at),
    activeExpiresAt: textOrNull(row.active_expires_at),
    message: textOrNull(row.message),
  };
}

export async function getActiveActivityAttendanceCheckin(activityId: string): Promise<{ token: ActivityCheckinToken | null; error: string | null }> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("get_active_activity_attendance_checkin", {
    target_activity_id: activityId,
  });
  if (error) return { token: null, error: sanitizedDetail(error) };
  return { token: normalizeCheckinToken(data, activityId), error: null };
}

export async function getActivityAttendanceCheckinState(activityId: string): Promise<{ state: ActivityAttendanceCheckinState | null; error: string | null }> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("get_activity_attendance_checkin_state", {
    target_activity_id: activityId,
  });
  if (error) return { state: null, error: sanitizedDetail(error) };
  return { state: normalizeCheckinState(data), error: null };
}