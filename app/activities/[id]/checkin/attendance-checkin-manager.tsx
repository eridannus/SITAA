"use client";

import Image from "next/image";
import { useState } from "react";
import { useFormStatus } from "react-dom";
import { closeAttendanceCheckin, openAttendanceCheckin, regenerateAttendanceCheckin } from "./actions";
import type { ActivityCheckinToken } from "@/types/check-in";

function SubmitButton({ idle, pending }: { idle: string; pending: string }) {
  const status = useFormStatus();
  return <button type="submit" disabled={status.pending} className="rounded-full bg-emerald-800 px-5 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 disabled:cursor-not-allowed disabled:bg-slate-400 disabled:opacity-60 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">
    {status.pending ? pending : idle}
  </button>;
}

function SecondarySubmitButton({ idle, pending, tone = "neutral" }: { idle: string; pending: string; tone?: "neutral" | "danger" }) {
  const status = useFormStatus();
  const color = tone === "danger" ? "border-red-300 text-red-800 hover:border-red-700 hover:text-red-950" : "border-slate-300 text-slate-800 hover:border-emerald-700 hover:text-emerald-900";
  return <button type="submit" disabled={status.pending} className={"rounded-full border px-5 py-3 text-sm font-bold transition disabled:cursor-not-allowed disabled:border-slate-200 disabled:text-slate-400 disabled:opacity-60 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2 " + color}>
    {status.pending ? pending : idle}
  </button>;
}

function CopyButton({ value, label, copiedLabel }: { value: string; label: string; copiedLabel: string }) {
  const [copied, setCopied] = useState(false);
  return <button type="button" onClick={async () => {
    await navigator.clipboard.writeText(value);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1600);
  }} className="rounded-full border border-slate-300 px-5 py-3 text-sm font-bold text-slate-800 transition hover:border-emerald-700 hover:text-emerald-900 cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">
    {copied ? copiedLabel : label}
  </button>;
}

export function AttendanceCheckinManager({ activityId, token, directLink, qrDataUri, status, detail }: {
  activityId: string;
  token: ActivityCheckinToken | null;
  directLink: string | null;
  qrDataUri: string | null;
  status?: string;
  detail?: string;
}) {
  const messages: Record<string, string> = {
    opened: "Asistencia abierta correctamente.",
    closed: "Asistencia cerrada correctamente.",
    regenerated: "Código regenerado correctamente.",
    "open-forbidden": "No tienes permiso para abrir asistencia en esta actividad.",
    "open-draft": "No puedes abrir asistencia en una actividad en borrador.",
    "open-error": "No fue posible abrir la asistencia.",
    "close-forbidden": "No tienes permiso para cerrar asistencia en esta actividad.",
    "close-draft": "No puedes cerrar asistencia en una actividad en borrador.",
    "close-error": "No fue posible cerrar la asistencia.",
    "regenerate-forbidden": "No tienes permiso para regenerar asistencia en esta actividad.",
    "regenerate-draft": "No puedes regenerar asistencia en una actividad en borrador.",
    "regenerate-error": "No fue posible regenerar el código.",
  };
  const isError = status?.includes("error") || status?.includes("forbidden") || status?.includes("draft") || false;
  const messageClass = isError ? "border-red-200 bg-red-50 text-red-800" : "border-emerald-200 bg-emerald-50 text-emerald-800";

  return <section id="attendance-checkin" className="mt-10 scroll-mt-24 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
    <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
      <div>
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Confirmación de asistencia</p>
        <h2 className="mt-2 text-2xl font-bold text-slate-900">Asistencia por QR y código</h2>
        <p className="mt-3 max-w-2xl text-slate-600">Sólo los participantes ya registrados pueden confirmar asistencia con estos accesos.</p>
      </div>
      {!token && <form action={openAttendanceCheckin.bind(null, activityId)}><SubmitButton idle="Abrir asistencia" pending="Abriendo..." /></form>}
    </div>

    {status && messages[status] ? <div role={isError ? "alert" : "status"} className={"mt-6 rounded-xl border px-4 py-3 text-sm font-semibold " + messageClass}>
      <p>{messages[status]}</p>
      {isError && detail ? <p className="mt-2 break-words text-xs font-medium opacity-85">Detalle: {detail}</p> : null}
    </div> : null}

    {token && directLink ? <div className="mt-7 grid gap-6 lg:grid-cols-[18rem_minmax(0,1fr)]">
      <div className="rounded-2xl border border-slate-200 bg-slate-50 p-5 text-center">
        {qrDataUri ? <Image src={qrDataUri} alt="Código QR para registrar asistencia" width={256} height={256} unoptimized className="mx-auto size-64 rounded-xl bg-white p-3" /> : <p className="text-sm font-semibold text-red-700">No fue posible generar el QR porque el enlace es demasiado largo.</p>}
      </div>
      <div className="min-w-0 space-y-5">
        <div>
          <p className="text-sm font-semibold text-slate-500">Enlace directo</p>
          <a href={directLink} target="_blank" rel="noopener noreferrer" className="mt-2 block break-all rounded-2xl border border-slate-200 bg-slate-50 p-4 text-sm font-semibold text-slate-900 underline decoration-emerald-500 underline-offset-4 transition hover:text-emerald-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">{directLink}</a>
        </div>
        <div>
          <p className="text-sm font-semibold text-slate-500">Código de tres palabras</p>
          <p className="mt-2 break-words rounded-2xl border border-slate-200 bg-slate-50 p-4 text-2xl font-bold tracking-wide text-slate-900">{token.three_word_code}</p>
        </div>
        <div className="flex flex-wrap gap-3">
          <CopyButton value={directLink} label="Copiar enlace" copiedLabel="Enlace copiado" />
          <CopyButton value={token.three_word_code} label="Copiar código" copiedLabel="Código copiado" />
          <form action={regenerateAttendanceCheckin.bind(null, activityId)} onSubmit={(event) => {
            if (!window.confirm("El código anterior dejará de funcionar. ¿Quieres generar uno nuevo?")) event.preventDefault();
          }}>
            <input type="hidden" name="confirmation" value="confirmed" />
            <SecondarySubmitButton idle="Regenerar código" pending="Regenerando..." />
          </form>
          <form action={closeAttendanceCheckin.bind(null, activityId)} onSubmit={(event) => {
            if (!window.confirm("Los alumnos ya no podrán registrar asistencia con este código.")) event.preventDefault();
          }}>
            <input type="hidden" name="confirmation" value="confirmed" />
            <SecondarySubmitButton idle="Cerrar asistencia" pending="Cerrando..." tone="danger" />
          </form>
        </div>
      </div>
    </div> : <p className="mt-7 rounded-2xl bg-slate-50 p-5 text-slate-600">La asistencia por QR y código está cerrada.</p>}
  </section>;
}
