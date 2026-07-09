import type { Metadata } from "next";
import Link from "next/link";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { CheckinCodeForm } from "./check-in-code-form";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Registrar asistencia" };

export default async function CheckinPage() {
  const context = await getAuthenticatedUserContext();
  if (!context) {
    return <main className="mx-auto max-w-3xl px-5 py-16 sm:px-8 sm:py-20">
      <h1 className="text-3xl font-bold text-emerald-950">Inicia sesi?n para registrar asistencia</h1>
      <p className="mt-4 text-slate-600">Despu?s de iniciar sesi?n, vuelve a abrir esta p?gina o escanea nuevamente el QR.</p>
      <Link href="/login?error=sesion-requerida" className="mt-7 inline-flex cursor-pointer rounded-full bg-emerald-800 px-6 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Iniciar sesi?n</Link>
    </main>;
  }
  return <main className="mx-auto max-w-3xl px-5 py-16 sm:px-8 sm:py-20">
    <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Asistencia</p>
    <h1 className="mt-3 text-3xl font-bold text-emerald-950 sm:text-4xl">Registrar asistencia</h1>
    <CheckinCodeForm />
  </main>;
}
