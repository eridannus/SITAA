import type { Metadata } from "next";
import Link from "next/link";
import { revalidatePath } from "next/cache";
import { getAuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import { checkinMessageFromResult } from "@/lib/check-in/check-in-result";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Confirmar asistencia" };

type Props = { params: Promise<{ token: string }> };

export default async function TokenCheckinPage({ params }: Props) {
  const { token } = await params;
  const context = await getAuthenticatedUserContext();
  if (!context) {
    return <main className="mx-auto max-w-3xl px-5 py-16 sm:px-8 sm:py-20">
      <h1 className="text-3xl font-bold text-emerald-950">Inicia sesión para registrar asistencia</h1>
      <p className="mt-4 text-slate-600">El inicio de sesión todavía no conserva automáticamente el enlace de regreso. Inicia sesión y vuelve a escanear el QR o abre nuevamente este enlace.</p>
      <Link href="/login?error=sesion-requerida" className="mt-7 inline-flex cursor-pointer rounded-full bg-emerald-800 px-6 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Iniciar sesión</Link>
    </main>;
  }
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("check_in_activity", { checkin_input: token });
  const result = checkinMessageFromResult(data, error);
  revalidatePath("/activities");
  const isError = result.status === "error" || result.status === "invalid" || result.status === "not-participant";
  const messageClass = isError ? "border-red-200 bg-red-50 text-red-800" : "border-emerald-200 bg-emerald-50 text-emerald-800";
  return <main className="mx-auto max-w-3xl px-5 py-16 sm:px-8 sm:py-20">
    <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Asistencia</p>
    <h1 className="mt-3 text-3xl font-bold text-emerald-950 sm:text-4xl">Confirmación de asistencia</h1>
    <div role={isError ? "alert" : "status"} className={"mt-8 rounded-3xl border p-7 text-lg font-bold shadow-sm " + messageClass}>{result.message}</div>
    <div className="mt-7 flex flex-wrap gap-3">
      <Link href="/activities" className="inline-flex cursor-pointer rounded-full bg-emerald-800 px-6 py-3 text-sm font-bold text-white transition hover:bg-emerald-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Ver mis actividades</Link>
      <Link href="/check-in" className="inline-flex cursor-pointer rounded-full border border-slate-300 px-6 py-3 text-sm font-bold text-slate-800 transition hover:border-emerald-700 hover:text-emerald-900 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-emerald-600 focus-visible:ring-offset-2">Ingresar código manualmente</Link>
    </div>
  </main>;
}
