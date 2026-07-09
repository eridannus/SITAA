import type { CheckinActionState } from "@/types/check-in";

type MaybeError = { code?: string; message?: string; details?: string; hint?: string };
type CheckinRpcRow = {
  message?: unknown;
  activity_id?: unknown;
  activity_title?: unknown;
  attendance_status?: unknown;
  checked_in_at?: unknown;
};

const GENERIC_CHECKIN_ERROR = "No fue posible registrar tu asistencia.";

function normalize(value: string) {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

function firstRow(data: unknown): CheckinRpcRow | null {
  if (Array.isArray(data)) return data.length > 0 ? firstRow(data[0]) : null;
  if (data && typeof data === "object") return data as CheckinRpcRow;
  if (typeof data === "string") return { message: data };
  return null;
}

function stringOrNull(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function checkinErrorMessage(error: MaybeError) {
  const raw = normalize([error.code, error.message, error.details, error.hint].filter(Boolean).join(" "));

  if (/periodo.*registrar.*asistencia.*termin|attendance.*period|deadline|expired|expir/.test(raw)) {
    return "El periodo para registrar asistencia ya terminó.";
  }

  if (/codigo.*no existe|code.*closed|codigo.*cerrad|token.*invalid|codigo.*invalid/.test(raw)) {
    return "El código de asistencia no existe, ya fue cerrado o expiró.";
  }

  if (/no.*participante|not.*participant/.test(raw)) {
    return "No estás registrado como participante en esta actividad. Si crees que deberías aparecer en la lista, contacta al responsable de la actividad.";
  }

  return GENERIC_CHECKIN_ERROR;
}

function classifyMessage(message: string): CheckinActionState["status"] {
  const raw = normalize(message);

  if (/already|ya.*(registr|asist|check)/.test(raw)) return "already";
  if (/not.*participant|no.*participante|no.*registrad/.test(raw)) return "not-participant";
  if (/closed|invalid|expired|expir|no existe|cerrad|codigo.*inval|token.*inval/.test(raw)) return "invalid";
  if (/no fue posible|no se pudo|no pudimos/.test(raw)) return "error";

  return "success";
}

export function checkinMessageFromResult(data: unknown, error?: MaybeError | null): CheckinActionState {
  if (error) {
    const message = checkinErrorMessage(error);
    return { status: message === GENERIC_CHECKIN_ERROR ? "error" : "invalid", message };
  }

  const row = firstRow(data);

  if (!row) {
    return { status: "error", message: GENERIC_CHECKIN_ERROR };
  }

  const message = stringOrNull(row.message);
  const activityTitle = stringOrNull(row.activity_title);
  const attendanceStatus = stringOrNull(row.attendance_status);
  const checkedInAt = stringOrNull(row.checked_in_at);
  const classifiedStatus = message ? classifyMessage(message) : "error";
  const status = attendanceStatus === "attended"
    ? classifiedStatus === "already"
      ? "already"
      : "success"
    : classifiedStatus === "success"
      ? "invalid"
      : classifiedStatus;

  return {
    status,
    message: message ?? GENERIC_CHECKIN_ERROR,
    activityTitle,
    attendanceStatus,
    checkedInAt,
  };
}
