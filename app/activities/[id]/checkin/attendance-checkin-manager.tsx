"use client";

import Image from "next/image";
import { useState } from "react";
import { useFormStatus } from "react-dom";
import { closeAttendanceCheckin, openAttendanceCheckin, regenerateAttendanceCheckin } from "./actions";
import type { ActivityAttendanceCheckinState, ActivityCheckinToken } from "@/types/check-in";

function SubmitButton({ idle, pending }: { idle: string; pending: string }) {
  const status = useFormStatus();
  return <button type="submit" disabled={status.pending} className="sitaa-primary-action px-5">
    {status.pending ? pending : idle}
  </button>;
}

function SecondarySubmitButton({ idle, pending, tone = "neutral" }: { idle: string; pending: string; tone?: "neutral" | "danger" }) {
  const status = useFormStatus();
  const color = tone === "danger" ? "sitaa-destructive-action" : "sitaa-secondary-action";
  return <button type="submit" disabled={status.pending} className={color + " px-5"}>
    {status.pending ? pending : idle}
  </button>;
}

function ConfirmableCheckinAction({ activityId, kind }: { activityId: string; kind: "close" | "regenerate" }) {
  const [isOpen, setIsOpen] = useState(false);
  const config = kind === "regenerate"
    ? {
      action: regenerateAttendanceCheckin.bind(null, activityId),
      triggerLabel: "Regenerar código",
      confirmLabel: "Regenerar código",
      pendingLabel: "Regenerando...",
      message: "El código anterior dejará de funcionar. ¿Quieres generar uno nuevo?",
      tone: "neutral" as const,
    }
    : {
      action: closeAttendanceCheckin.bind(null, activityId),
      triggerLabel: "Cerrar asistencia",
      confirmLabel: "Cerrar asistencia",
      pendingLabel: "Cerrando...",
      message: "Los alumnos ya no podrán registrar asistencia con este código.",
      tone: "danger" as const,
    };
  const triggerColor = config.tone === "danger" ? "sitaa-destructive-action" : "sitaa-secondary-action";

  if (!isOpen) {
    return <button type="button" onClick={() => setIsOpen(true)} className={triggerColor + " px-5"}>
      {config.triggerLabel}
    </button>;
  }

  return <div role="group" aria-label={config.triggerLabel} className="sitaa-alert sitaa-alert--warning min-w-0">
    <p className="break-words font-semibold">{config.message}</p>
    <div className="mt-4 flex flex-wrap gap-3">
      <button type="button" onClick={() => setIsOpen(false)} className="sitaa-secondary-action px-5">Cancelar</button>
      <form action={config.action}>
        <input type="hidden" name="confirmation" value="confirmed" />
        <SecondarySubmitButton idle={config.confirmLabel} pending={config.pendingLabel} tone={config.tone} />
      </form>
    </div>
  </div>;
}

function CopyButton({ value, label, copiedLabel }: { value: string; label: string; copiedLabel: string }) {
  const [copied, setCopied] = useState(false);
  return <button type="button" onClick={async () => {
    await navigator.clipboard.writeText(value);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1600);
  }} className="sitaa-secondary-action px-5">
    {copied ? copiedLabel : label}
  </button>;
}

function sanitizeFilenamePart(value: string | null | undefined) {
  return value?.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/^-+|-+$/g, "") || "qr";
}

function svgFromDataUri(dataUri: string) {
  const prefix = "data:image/svg+xml;utf8,";

  if (!dataUri.startsWith(prefix)) return null;

  try {
    return decodeURIComponent(dataUri.slice(prefix.length));
  } catch {
    return null;
  }
}

function downloadBlob(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}

function svgToPngBlob(svg: string) {
  return new Promise<Blob | null>((resolve) => {
    const image = new window.Image();
    const svgBlob = new Blob([svg], { type: "image/svg+xml;charset=utf-8" });
    const url = URL.createObjectURL(svgBlob);

    image.onload = () => {
      const size = 1024;
      const canvas = document.createElement("canvas");
      canvas.width = size;
      canvas.height = size;
      const context = canvas.getContext("2d");

      if (!context) {
        URL.revokeObjectURL(url);
        resolve(null);
        return;
      }

      context.fillStyle = "#ffffff";
      context.fillRect(0, 0, size, size);
      context.imageSmoothingEnabled = false;
      context.drawImage(image, 0, 0, size, size);
      URL.revokeObjectURL(url);
      canvas.toBlob((blob) => resolve(blob), "image/png");
    };

    image.onerror = () => {
      URL.revokeObjectURL(url);
      resolve(null);
    };

    image.src = url;
  });
}

function QrAssetActions({ qrDataUri, codeWords }: { qrDataUri: string; codeWords: string | null | undefined }) {
  const [message, setMessage] = useState<string | null>(null);
  const filename = "sitaa-asistencia-" + sanitizeFilenamePart(codeWords) + ".svg";

  function showMessage(value: string) {
    setMessage(value);
    window.setTimeout(() => setMessage(null), 2200);
  }

  function downloadSvg() {
    const svg = svgFromDataUri(qrDataUri);

    if (!svg) {
      showMessage("No fue posible descargar el QR.");
      return;
    }

    downloadBlob(new Blob([svg], { type: "image/svg+xml;charset=utf-8" }), filename);
  }

  async function copyPng() {
    const svg = svgFromDataUri(qrDataUri);
    const ClipboardItemConstructor = globalThis.ClipboardItem;

    if (!svg || !navigator.clipboard || !ClipboardItemConstructor) {
      showMessage("No fue posible copiar el QR como imagen. Usa Descargar QR.");
      return;
    }

    const blob = await svgToPngBlob(svg);

    if (!blob || blob.size === 0) {
      showMessage("No fue posible copiar el QR como imagen. Usa Descargar QR.");
      return;
    }

    try {
      await navigator.clipboard.write([new ClipboardItemConstructor({ "image/png": blob })]);
      showMessage("QR copiado como imagen.");
    } catch {
      showMessage("No fue posible copiar el QR como imagen. Usa Descargar QR.");
    }
  }

  return <div className="mt-4 space-y-3">
    <div className="flex flex-wrap justify-center gap-2">
      <button type="button" onClick={copyPng} className="sitaa-secondary-action min-h-11 px-4 py-2">Copiar QR</button>
      <button type="button" onClick={downloadSvg} className="sitaa-secondary-action min-h-11 px-4 py-2">Descargar QR</button>
    </div>
    {message ? <p role="status" className="text-sm font-semibold text-slate-700">{message}</p> : null}
  </div>;
}

function formatMexicoCityDateTime(value: string | null | undefined) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;

  return new Intl.DateTimeFormat("es-MX", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
    timeZone: "America/Mexico_City",
  }).format(date);
}

function sameInstant(left: string | null | undefined, right: string | null | undefined) {
  if (!left || !right) return false;
  const leftDate = new Date(left);
  const rightDate = new Date(right);
  if (Number.isNaN(leftDate.getTime()) || Number.isNaN(rightDate.getTime())) return false;
  return leftDate.getTime() === rightDate.getTime();
}

type CheckinPresentationState = {
  kind: "open" | "not-yet-available" | "normal-open" | "reopen" | "missing-schedule" | "closed";
  message: string;
  buttonLabel: string | null;
  pendingLabel: string | null;
  secondaryLines?: string[];
};

function isFutureTimestamp(value: string | null | undefined) {
  if (!value) return false;
  const date = new Date(value);
  return !Number.isNaN(date.getTime()) && date.getTime() > Date.now();
}

function checkinPresentationState(
  token: ActivityCheckinToken | null,
  state: ActivityAttendanceCheckinState | null,
  attendanceOpenAt?: string | null,
  attendanceDeadline?: string | null,
  attendanceDeadlinePassed?: boolean,
): CheckinPresentationState {
  if (token) {
    return {
      kind: "open",
      message: "La asistencia está abierta.",
      buttonLabel: null,
      pendingLabel: null,
    };
  }

  const windowStatus = state?.windowStatus?.toLowerCase() ?? "";
  const openAt = state?.opensAt ?? attendanceOpenAt ?? null;
  const deadline = state?.ordinaryClosesAt ?? attendanceDeadline ?? null;
  const formattedOpenAt = formatMexicoCityDateTime(openAt);
  const formattedDeadline = formatMexicoCityDateTime(deadline);
  const secondaryLines = [
    formattedOpenAt ? "Podrás abrirla desde: " + formattedOpenAt : null,
    formattedDeadline ? "Disponible hasta: " + formattedDeadline : null,
  ].filter(Boolean) as string[];

  const missingSchedule = ["missing_schedule", "missing-schedule", "missing_schedule_data"].includes(windowStatus) || windowStatus.includes("missing");
  if (missingSchedule) {
    return {
      kind: "missing-schedule",
      message: "La actividad no tiene horario suficiente para abrir asistencia.",
      buttonLabel: null,
      pendingLabel: null,
    };
  }

  const notYetAvailable = ["not_yet_available", "not-yet-available", "future", "before_open", "before-opening"].includes(windowStatus) || (state?.canOpenNow !== true && attendanceDeadlinePassed !== true && isFutureTimestamp(openAt));
  if (notYetAvailable) {
    return {
      kind: "not-yet-available",
      message: "La asistencia todavía no puede abrirse.",
      buttonLabel: null,
      pendingLabel: null,
      secondaryLines,
    };
  }

  const canOpenNormally = state?.canOpenNow === true && attendanceDeadlinePassed !== true;
  if (canOpenNormally) {
    return {
      kind: "normal-open",
      message: "Puedes abrir asistencia para esta actividad.",
      buttonLabel: "Abrir asistencia",
      pendingLabel: "Abriendo...",
    };
  }

  const canReopen = attendanceDeadlinePassed === true || state?.windowStatus === "reopen_available" || ["expired", "ended", "deadline_passed"].includes(windowStatus);
  if (canReopen) {
    return {
      kind: "reopen",
      message: "El periodo normal de asistencia ya terminó. Puedes reabrir asistencia por 15 minutos.",
      buttonLabel: "Reabrir asistencia",
      pendingLabel: "Reabriendo...",
    };
  }

  return {
    kind: "closed",
    message: "La asistencia por QR y código está cerrada.",
    buttonLabel: null,
    pendingLabel: null,
  };
}

export function AttendanceCheckinManager({ activityId, token, directLink, qrDataUri, checkinState, attendanceOpenAt, attendanceDeadline, attendanceDeadlinePassed, status, detail }: {
  activityId: string;
  token: ActivityCheckinToken | null;
  directLink: string | null;
  qrDataUri: string | null;
  checkinState: ActivityAttendanceCheckinState | null;
  attendanceOpenAt?: string | null;
  attendanceDeadline?: string | null;
  attendanceDeadlinePassed?: boolean;
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
    "open-not-yet-available": "La asistencia aún no puede abrirse para esta actividad.",
    "open-expired": "El periodo para registrar asistencia ya terminó.",
    "fetch-error": "No fue posible consultar el estado de asistencia.",
    "close-forbidden": "No tienes permiso para cerrar asistencia en esta actividad.",
    "close-draft": "No puedes cerrar asistencia en una actividad en borrador.",
    "close-error": "No fue posible cerrar la asistencia.",
    "regenerate-forbidden": "No tienes permiso para regenerar asistencia en esta actividad.",
    "regenerate-draft": "No puedes regenerar asistencia en una actividad en borrador.",
    "regenerate-error": "No fue posible regenerar el código.",
    "regenerate-not-yet-available": "La asistencia aún no puede abrirse para esta actividad.",
    "regenerate-expired": "El periodo para registrar asistencia ya terminó.",
  };
  const isError = status?.includes("error") || status?.includes("forbidden") || status?.includes("draft") || false;
  const messageClass = isError ? "sitaa-alert--error" : "sitaa-alert--success";
  const presentationState = checkinPresentationState(token, checkinState, attendanceOpenAt, attendanceDeadline, attendanceDeadlinePassed);
  const presentationTone = presentationState.kind === "reopen"
    ? "sitaa-alert--warning"
    : presentationState.kind === "open" || presentationState.kind === "normal-open" || presentationState.kind === "not-yet-available"
      ? "sitaa-alert--info"
      : "";
  const canOpenNow = Boolean(presentationState.buttonLabel && presentationState.pendingLabel);
  const activeExpiresAt = token?.expires_at ?? checkinState?.activeExpiresAt ?? null;
  const formattedExpiresAt = formatMexicoCityDateTime(activeExpiresAt);
  const isPostEventReopening = Boolean(token && token.expires_at && checkinState?.ordinaryClosesAt && !sameInstant(token.expires_at, checkinState.ordinaryClosesAt));

  return <section id="attendance-checkin" className="sitaa-card mt-10 scroll-mt-24 p-7 sm:p-10">
    <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
      <div>
        <p className="sitaa-section-eyebrow">Confirmación de asistencia</p>
        <h2 className="mt-2 text-2xl font-bold text-slate-900">Asistencia por QR y código</h2>
        <p className="mt-3 max-w-2xl text-slate-600">Sólo los participantes ya registrados pueden confirmar asistencia con estos accesos.</p>
      </div>
      {canOpenNow && presentationState.buttonLabel && presentationState.pendingLabel ? <form action={openAttendanceCheckin.bind(null, activityId)}><SubmitButton idle={presentationState.buttonLabel} pending={presentationState.pendingLabel} /></form> : null}
    </div>

    {status && messages[status] ? <div role={isError ? "alert" : "status"} className={"sitaa-alert mt-6 font-semibold " + messageClass}>
      <p>{messages[status]}</p>
      {isError && detail ? <p className="mt-2 break-words text-xs font-medium opacity-85">Detalle: {detail}</p> : null}
    </div> : null}

    <div role={presentationState.kind === "open" ? "status" : undefined} className={`sitaa-alert mt-6 ${presentationTone}`}>
      <p className="font-semibold">{presentationState.message}</p>
      {presentationState.secondaryLines?.map((line) => <p key={line} className="mt-2 font-medium">{line}</p>)}
    </div>

    {token && directLink ? <div className="mt-7 grid gap-6 lg:grid-cols-[18rem_minmax(0,1fr)]">
      <div className="sitaa-detail-card bg-[var(--sitaa-surface-subdued)] p-5 text-center">
        {qrDataUri ? <>
          <Image src={qrDataUri} alt="Código QR para registrar asistencia" width={320} height={320} unoptimized className="mx-auto size-72 rounded-xl bg-white p-3 sm:size-80" />
          <QrAssetActions qrDataUri={qrDataUri} codeWords={token.three_word_code} />
        </> : <p className="text-sm font-semibold text-red-700">No fue posible generar el QR. Usa el enlace directo o el código.</p>}
      </div>
      <div className="min-w-0 space-y-5">
        {formattedExpiresAt ? <div className="sitaa-alert sitaa-alert--info font-semibold">
          <p>Disponible hasta: {formattedExpiresAt}</p>
          {isPostEventReopening ? <p className="mt-1 text-xs font-medium text-[var(--sitaa-info-foreground)]">Reapertura posterior al evento: este código dura 15 minutos.</p> : null}
        </div> : null}
        <div>
          <p className="text-sm font-semibold text-slate-500">Enlace directo</p>
          <a href={directLink} target="_blank" rel="noopener noreferrer" className="sitaa-text-action mt-2 block break-all rounded-2xl border border-[var(--sitaa-border)] bg-[var(--sitaa-surface-subdued)] p-4 text-sm">{directLink}</a>
        </div>
        <div>
          <p className="text-sm font-semibold text-slate-500">Código de tres palabras</p>
          <p className="mt-2 break-words rounded-2xl border border-slate-200 bg-slate-50 p-4 text-2xl font-bold tracking-wide text-slate-900">{token.three_word_code}</p>
        </div>
        <div className="flex flex-wrap gap-3">
          <CopyButton value={directLink} label="Copiar enlace" copiedLabel="Enlace copiado" />
          <CopyButton value={token.three_word_code} label="Copiar código" copiedLabel="Código copiado" />
          <ConfirmableCheckinAction activityId={activityId} kind="regenerate" />
          <ConfirmableCheckinAction activityId={activityId} kind="close" />
        </div>
      </div>
    </div> : null}
  </section>;
}
