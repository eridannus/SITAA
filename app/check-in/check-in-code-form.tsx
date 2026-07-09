"use client";

import jsQR from "jsqr";
import Link from "next/link";
import { useActionState, useEffect, useRef, useState, useSyncExternalStore } from "react";
import { useFormStatus } from "react-dom";
import { submitCheckinCode } from "./actions";
import type { CheckinActionState } from "@/types/check-in";

type BarcodeDetectionResult = { rawValue?: string };
type BarcodeDetectorInstance = { detect(source: HTMLVideoElement): Promise<BarcodeDetectionResult[]> };
type BarcodeDetectorConstructor = new (options?: { formats?: string[] }) => BarcodeDetectorInstance;
type WindowWithBarcodeDetector = Window & typeof globalThis & { BarcodeDetector?: BarcodeDetectorConstructor };

function SubmitButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending} className="cursor-pointer rounded-full bg-emerald-800 px-6 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 disabled:cursor-not-allowed disabled:bg-slate-400 disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">
    {pending ? "Registrando..." : "Registrar asistencia"}
  </button>;
}

function validateCode(value: string) {
  const parts = value.trim().split(/[\s-]+/).filter(Boolean);
    const hasOnlyAllowedCharacters = /^[A-Za-z\u00c1\u00c9\u00cd\u00d3\u00da\u00dc\u00d1\u00e1\u00e9\u00ed\u00f3\u00fa\u00fc\u00f1\s-]+$/.test(value.trim());

  if (!value.trim()) return "Escribe el código de asistencia.";
  if (!hasOnlyAllowedCharacters) return "Usa sólo letras, guiones o espacios.";
  if (parts.length !== 3) return "El código debe tener exactamente tres palabras.";

  return null;
}

function getBarcodeDetectorConstructor() {
  if (typeof window === "undefined") return null;
  return (window as WindowWithBarcodeDetector).BarcodeDetector ?? null;
}

function subscribeToScannerSupport() {
  return () => {};
}

function getScannerSupportSnapshot() {
  const canUseCamera =
    typeof window !== "undefined" &&
    window.isSecureContext &&
    typeof navigator !== "undefined" &&
    typeof navigator.mediaDevices !== "undefined" &&
    typeof navigator.mediaDevices.getUserMedia === "function";

  return canUseCamera && (Boolean(getBarcodeDetectorConstructor()) || Boolean(jsQR));
}

function getScannerSupportServerSnapshot() {
  return false;
}

function extractInternalCheckinPath(value: string) {
  try {
    const url = new URL(value, window.location.origin);
    if (url.origin === window.location.origin && /^\/check-in\/[^/]+$/.test(url.pathname)) {
      return url.pathname;
    }
  } catch {
    return null;
  }

  return null;
}

function extractTokenFromInternalPath(value: string) {
  const path = extractInternalCheckinPath(value);
  if (!path) return null;
  return decodeURIComponent(path.replace("/check-in/", ""));
}

function decodeQrFromCanvas(video: HTMLVideoElement, canvas: HTMLCanvasElement) {
  const width = video.videoWidth;
  const height = video.videoHeight;

  if (!width || !height) return null;

  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext("2d", { willReadFrequently: true });
  if (!context) return null;

  context.drawImage(video, 0, 0, width, height);
  const imageData = context.getImageData(0, 0, width, height);
  return jsQR(imageData.data, width, height)?.data?.trim() ?? null;
}

function CheckinScanner({ onScanned }: { onScanned: (value: string) => void }) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const scanningRef = useRef(false);
  const supported = useSyncExternalStore(subscribeToScannerSupport, getScannerSupportSnapshot, getScannerSupportServerSnapshot);
  const [scanning, setScanning] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  function stopCamera() {
    scanningRef.current = false;
    setScanning(false);
    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;
  }

  useEffect(() => {
    return () => stopCamera();
  }, []);

  async function startScanning() {
    const canUseCamera =
      typeof navigator !== "undefined" &&
      typeof navigator.mediaDevices !== "undefined" &&
      typeof navigator.mediaDevices.getUserMedia === "function";

    if (!supported || !canUseCamera) return;

    const getUserMedia = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
    const BarcodeDetector = getBarcodeDetectorConstructor();
    setMessage("Apunta la cámara al código QR de asistencia.");

    try {
      const stream = await getUserMedia({ video: { facingMode: { ideal: "environment" } } });
      streamRef.current = stream;
      scanningRef.current = true;
      setScanning(true);

      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
      }

      const detector = BarcodeDetector ? new BarcodeDetector({ formats: ["qr_code"] }) : null;

      const scanFrame = async () => {
        if (!scanningRef.current || !videoRef.current) return;

        try {
          const rawValue = detector
            ? (await detector.detect(videoRef.current))[0]?.rawValue?.trim() ?? null
            : canvasRef.current
              ? decodeQrFromCanvas(videoRef.current, canvasRef.current)
              : null;

          if (rawValue) {
            stopCamera();
            onScanned(rawValue);
            return;
          }
        } catch {
          stopCamera();
          setMessage("No fue posible leer el QR. Ingresa el código manualmente.");
          return;
        }

        window.requestAnimationFrame(scanFrame);
      };

      window.requestAnimationFrame(scanFrame);
    } catch {
      stopCamera();
      setMessage("No se pudo acceder a la cámara. Ingresa el código manualmente.");
    }
  }

  if (!supported) return null;

  return <div className="mt-8 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
    <h2 className="text-xl font-bold text-slate-900">Escanear QR</h2>
    <p className="mt-3 text-sm text-slate-600">Usa esta opción sólo si tienes el QR de asistencia. La cámara se solicitará hasta que pulses el botón.</p>
    <div className="mt-5 flex flex-wrap gap-3">
      <button type="button" onClick={startScanning} disabled={scanning} className="cursor-pointer rounded-full bg-emerald-800 px-6 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 disabled:cursor-not-allowed disabled:bg-slate-400 disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">
        {scanning ? "Escaneando..." : "Escanear QR"}
      </button>
      {scanning ? <button type="button" onClick={stopCamera} className="cursor-pointer rounded-full border border-slate-300 px-6 py-3 text-sm font-bold text-slate-800 transition hover:border-slate-500 hover:text-slate-950 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Cancelar</button> : null}
    </div>
    {scanning ? <>
      <video ref={videoRef} muted playsInline className="mt-5 aspect-video w-full rounded-2xl bg-slate-950 object-cover" />
      <canvas ref={canvasRef} className="hidden" aria-hidden="true" />
    </> : null}
    {message ? <p role={message.startsWith("Apunta") ? "status" : "alert"} className="mt-4 rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm font-semibold text-amber-900">{message}</p> : null}
  </div>;
}

export function CheckinCodeForm({ returnHref = "/activities" }: { returnHref?: string }) {
  const formRef = useRef<HTMLFormElement | null>(null);
  const [state, action] = useActionState<CheckinActionState, FormData>(submitCheckinCode, { status: "idle", message: null });
  const [clientError, setClientError] = useState<string | null>(null);
  const [codeValue, setCodeValue] = useState("");
  const [inputSource, setInputSource] = useState<"manual" | "scanner">("manual");
  const isError = state.status === "error";
  const isWarning = state.status === "invalid" || state.status === "not-participant";
  const isRegistered = state.status === "success" || state.status === "already";
  const messageClass = isError
    ? "border-red-200 bg-red-50 text-red-800"
    : isWarning
      ? "border-amber-200 bg-amber-50 text-amber-900"
      : "border-emerald-200 bg-emerald-50 text-emerald-800";

  function handleScanned(value: string) {
    const internalPath = extractInternalCheckinPath(value);

    if (internalPath) {
      window.location.assign(internalPath);
      return;
    }

    if (/^https?:\/\//i.test(value) || value.startsWith("//")) {
      setClientError("El QR no pertenece a SITAA. Ingresa el código manualmente.");
      return;
    }

    const token = extractTokenFromInternalPath(value) ?? value.trim();
    setInputSource("scanner");
    setCodeValue(token);
    setClientError(null);
    window.setTimeout(() => formRef.current?.requestSubmit(), 0);
  }

  if (isRegistered) {
    return <div className="mt-8 rounded-3xl border border-emerald-200 bg-emerald-50 p-7 text-emerald-900 shadow-sm sm:p-10">
      {state.activityTitle ? <p className="mb-3 break-words text-sm font-semibold opacity-80">{state.activityTitle}</p> : null}
      <p className="break-words text-lg font-bold">{state.message}</p>
      <Link href={returnHref} className="mt-7 inline-flex cursor-pointer rounded-full bg-emerald-800 px-6 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Ver mis actividades</Link>
    </div>;
  }

  return <>
    <form ref={formRef} action={action} onSubmit={(event) => {
      const formData = new FormData(event.currentTarget);
      const source = formData.get("input_source");
      const value = formData.get("checkin_code");
      const validationMessage = source === "scanner" ? null : typeof value === "string" ? validateCode(value) : "Escribe el código de asistencia.";

      if (validationMessage) {
        event.preventDefault();
        setClientError(validationMessage);
        return;
      }

      setClientError(null);
    }} className="mt-8 rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
      <input type="hidden" name="input_source" value={inputSource} />
      <input type="hidden" name="checkin_input" value={codeValue} />
      <label htmlFor="checkin_code" className="block text-sm font-semibold text-slate-700">Código de asistencia</label>
      <input id="checkin_code" name="checkin_code" required placeholder="mar-foco-papel" value={codeValue} onChange={(event) => {
        setInputSource("manual");
        setCodeValue(event.target.value);
      }} className="mt-2 w-full rounded-xl border border-slate-300 px-4 py-3 text-slate-900 outline-none transition focus:border-emerald-700 focus:ring-4 focus:ring-emerald-100" />
      <p className="mt-3 text-sm text-slate-600">Puedes escribirlo con guiones o espacios. Ejemplo: mar-foco-papel.</p>
      {clientError ? <p role="alert" className="mt-3 text-sm font-semibold text-red-700">{clientError}</p> : null}
      {state.message ? <div role={isError || isWarning ? "alert" : "status"} className={"mt-5 rounded-xl border px-4 py-3 text-sm font-semibold " + messageClass}>
        {state.activityTitle ? <p className="mb-2 break-words text-xs opacity-80">{state.activityTitle}</p> : null}
        <p className="break-words">{state.message}</p>
      </div> : null}
      <div className="mt-6"><SubmitButton /></div>
    </form>
    <CheckinScanner onScanned={handleScanned} />
  </>;
}
