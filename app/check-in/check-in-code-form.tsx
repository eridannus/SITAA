"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { submitCheckinCode } from "./actions";
import type { CheckinActionState } from "@/types/check-in";

function SubmitButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending} className="rounded-full bg-emerald-800 px-6 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 disabled:cursor-not-allowed disabled:bg-slate-400 disabled:opacity-60 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">
    {pending ? "Registrando..." : "Registrar asistencia"}
  </button>;
}

export function CheckinCodeForm() {
  const [state, action] = useActionState<CheckinActionState, FormData>(submitCheckinCode, { status: "idle", message: null });
  const isError = state.status === "error";
  const isWarning = state.status === "invalid" || state.status === "not-participant";
  const messageClass = isError
    ? "border-red-200 bg-red-50 text-red-800"
    : isWarning
      ? "border-amber-200 bg-amber-50 text-amber-900"
      : "border-emerald-200 bg-emerald-50 text-emerald-800";
  return <form action={action} className="mt-8 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
    <label htmlFor="checkin_code" className="block text-sm font-semibold text-slate-700">Código de asistencia</label>
    <input id="checkin_code" name="checkin_code" required placeholder="palabra palabra palabra" className="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 text-slate-900 outline-none transition focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100" />
    <p className="mt-3 text-sm text-slate-600">Escribe el código de tres palabras que te proporcionó el responsable.</p>
    {state.message ? <div role={isError || isWarning ? "alert" : "status"} className={"mt-5 rounded-xl border px-4 py-3 text-sm font-semibold " + messageClass}>
      {state.activityTitle ? <p className="mb-2 break-words text-xs opacity-80">{state.activityTitle}</p> : null}
      <p className="break-words">{state.message}</p>
      {state.checkedInAt ? <p className="mt-2 text-xs opacity-80">Asistencia registrada.</p> : null}
    </div> : null}
    <div className="mt-6"><SubmitButton /></div>
  </form>;
}
