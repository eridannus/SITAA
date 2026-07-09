import type { CheckinActionState } from "@/types/check-in";

type MaybeError = { code?: string; message?: string; details?: string; hint?: string };

function normalize(value: string) {
  return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

export function checkinMessageFromResult(data: unknown, error?: MaybeError | null): CheckinActionState {
  const raw = normalize([
    error?.code,
    error?.message,
    error?.details,
    error?.hint,
    typeof data === "string" ? data : JSON.stringify(data ?? ""),
  ].filter(Boolean).join(" "));

  if (!error) {
    if (/already|ya.*(registr|asist|check)/.test(raw)) {
      return { status: "already", message: "Tu asistencia ya estaba registrada." };
    }
    return { status: "success", message: "Asistencia registrada correctamente." };
  }

  if (/already|ya.*(registr|asist|check)/.test(raw)) {
    return { status: "already", message: "Tu asistencia ya estaba registrada." };
  }
  if (/not.*participant|no.*participante|no.*registrad/.test(raw)) {
    return { status: "not-participant", message: "No estás registrado como participante en esta actividad." };
  }
  if (/closed|invalid|expired|no existe|cerrad|codigo.*inval|token.*inval/.test(raw)) {
    return { status: "invalid", message: "El código de asistencia no existe o ya fue cerrado." };
  }
  return { status: "error", message: "No fue posible registrar la asistencia." };
}
