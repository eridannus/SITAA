import type { CheckinActionState } from "@/types/check-in";

type MaybeError = { code?: string; message?: string; details?: string; hint?: string };
type CheckinRpcResult = {
  message?: unknown;
  attendance_status?: unknown;
};

function normalize(value: string) {
  return value.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

function resultObject(data: unknown): CheckinRpcResult | null {
  if (Array.isArray(data)) return resultObject(data[0]);
  if (data && typeof data === "object") return data as CheckinRpcResult;
  if (typeof data === "string") return { message: data };
  return null;
}

function classifyMessage(message: string): CheckinActionState["status"] {
  const raw = normalize(message);

  if (/already|ya.*(registr|asist|check)/.test(raw)) return "already";
  if (/not.*participant|no.*participante|no.*registrad/.test(raw)) return "not-participant";
  if (/closed|invalid|expired|no existe|cerrad|codigo.*inval|token.*inval/.test(raw)) return "invalid";

  return "success";
}

function messageFromError(error: MaybeError) {
  const raw = normalize([error.code, error.message, error.details, error.hint].filter(Boolean).join(" "));

  if (/already|ya.*(registr|asist|check)/.test(raw)) return { status: "already", message: "Tu asistencia ya estaba registrada." } satisfies CheckinActionState;
  if (/not.*participant|no.*participante|no.*registrad/.test(raw)) return { status: "not-participant", message: "No estás registrado como participante en esta actividad." } satisfies CheckinActionState;
  if (/closed|invalid|expired|no existe|cerrad|codigo.*inval|token.*inval/.test(raw)) return { status: "invalid", message: "El código de asistencia no existe o ya fue cerrado." } satisfies CheckinActionState;

  return { status: "error", message: "No fue posible registrar la asistencia." } satisfies CheckinActionState;
}

export function checkinMessageFromResult(data: unknown, error?: MaybeError | null): CheckinActionState {
  const result = resultObject(data);
  const returnedMessage = typeof result?.message === "string" ? result.message.trim() : "";
  const attendanceStatus = typeof result?.attendance_status === "string" ? result.attendance_status : null;

  if (returnedMessage) {
    if (attendanceStatus === "attended") {
      return { status: classifyMessage(returnedMessage), message: returnedMessage };
    }

    return { status: classifyMessage(returnedMessage), message: returnedMessage };
  }

  if (attendanceStatus === "attended") {
    return { status: "success", message: "Asistencia registrada correctamente." };
  }

  if (error) return messageFromError(error);

  return { status: "success", message: "Asistencia registrada correctamente." };
}
